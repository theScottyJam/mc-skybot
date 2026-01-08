--[[
    A location represents a specific, marked point in space that you might frequently travel to.
]]

local util = import('util.lua')
local navigate = import('./navigate.lua')
local facingTools = import('./space/facingTools.lua')
local state = import('./state.lua')

local static = {}
local prototype = {}

local allLocations = {}

-- Caches the paths between various locations as they are calculated for faster lookup time.
-- This is especially useful because we're often checking the distance to farms at different locations to
-- see how much work it would be to interrupt and visit them.
local routeCache = {}

local availablePathsStateManager = state.__registerPieceOfState('module:Location', function()
    -- A mapping of paths the turtle can travel to move from one location to the next.
    return {}
end)

-- Used for testing
function static.__reset()
    allLocations = {}
    routeCache = {}
    availablePathsStateManager:update({})
end

-- HELPER FUNCTIONS --

-- Turns a position into a key that uniquely identifies that position.
local posToKey = function(pos)
    pos.coord:assertAbsolute()
    return pos.forward..','..pos.right..','..pos.up..':'..pos.facing
end

local lookupLoc = function(key)
    local loc = allLocations[key]
    util.assert(loc ~= nil, 'Failed to look up a location at a given position')
    return loc
end

-- Returns the units of work it will take to travel this path.
-- Also returns the optimal startFace that you would need to be at to get the lowest cost,
-- and what the endFace will be at the end.
-- `nill` will be returned for the start and end facing is no movement happened (e.g. maybe traveling between the
-- two locations only required rotating, which isn't considered by this function which only deals with coordinates).
local calcPathCost = function(coords)
    local startCoord = coords[1]
    startCoord:assertAbsolute()

    local startFace = nil
    for i=2, #coords do
        local coord = coords[i]
        if startCoord.forward < coord.forward then startFace = 'forward' break end
        if startCoord.forward > coord.forward then startFace = 'backward' break end
        if startCoord.right < coord.right then startFace = 'right' break end
        if startCoord.right > coord.right then startFace = 'left' break end
    end

    local effect = navigate.mockEffect(startCoord:face(startFace or 'forward'))

    local length = 0
    for i=2, #coords do
        coords[i]:assertAbsolute()
        -- The direction order doesn't matter much when calculating the path cost, except for the fact
        -- that when we calculate the starting face, we do so expecting this particular order to be used.
        navigate.moveToCoord(coords[i], {'forward', 'right', 'up'}, effect)
    end

    if startFace == nil then
        return effect.getWork(), nil, nil
    else
        return effect.getWork(), startFace, effect.getPos().facing
    end
end

function prototype:_getPaths()
    return availablePathsStateManager:get()[self._key]
end

local countRequiredRotations = function(facing1, facing2)
    local rotations = facingTools.countClockwiseRotations(facing1, facing2)
    if rotations == 3 then
        -- Just turn counter-clockwise instead, which is one turn.
        return 1
    else
        return rotations
    end
end

-- Finds the best route by exploring all closets locations until it runs into the target.
-- (this means it'll have to look at almost every registered location to find distant routes).
local findBestRoute = function(loc1, loc2)
    if loc1._key == loc2._key then
        return { routeCost = 0, route = {} }
    end

    if routeCache[loc1._key] ~= nil and routeCache[loc1._key][loc2._key] ~= nil then
        return routeCache[loc1._key][loc2._key]
    end

    -- optimalEndFace is what direction you'd be facing by the end of your travels,
    -- before we re-orient you to face the direction of the target location.
    -- The routeCost doesn't include this final re-orientation.
    local toExplore = {{ to = loc1, route = {}, routeCost = 0, optimalEndFace = loc1.pos.facing }}
    local seen = { [loc1._key] = true }

    while #toExplore > 0 do
        local bestIndex = 1
        for i, entry in ipairs(toExplore) do
            -- We're not factoring in the fact that different paths may require the turtle to first rotate a bit, which could make
            -- a slight difference between which one really is optimal. It shouldn't matter too much - it just means given two potential paths,
            -- there's a small chance the turtle might take one that requires an extra rotation or two.
            if entry.routeCost < toExplore[bestIndex].routeCost then
                bestIndex = i
            end
        end
        local entry = table.remove(toExplore, bestIndex)
        for i, path in ipairs(entry.to:_getPaths()) do
            if not seen[path.to] then
                seen[path.to] = true
                local newRoute = util.copyTable(entry.route)
                table.insert(newRoute, path)

                local targetLoc = lookupLoc(path.to)
                local newEntry = {
                    to = targetLoc,
                    route = newRoute,
                    routeCost = entry.routeCost + countRequiredRotations(entry.optimalEndFace, path.startFace or entry.optimalEndFace) + path.cost,
                    optimalEndFace = path.endFace or entry.optimalEndFace,
                }

                if path.to == loc2._key then
                    local lastRotationCost = countRequiredRotations(newEntry.optimalEndFace, targetLoc.pos.facing)
                    local result = { routeCost = newEntry.routeCost + lastRotationCost, route = newEntry.route }

                    if routeCache[loc1._key] == nil then
                        routeCache[loc1._key] = {}
                    end
                    routeCache[loc1._key][loc2._key] = result

                    return result
                end
                table.insert(toExplore, newEntry)
            end
        end
    end

    error('Failed to find a path to a target location. Are all of the needed paths currently registered?')
end

-- PUBLIC FUNCTIONS --

function static.register(pos)
    pos.coord:assertAbsolute()
    local loc = util.attachPrototype(prototype, {
        pos = pos,
        coord = pos.coord, -- For easy access
        -- Unique key used for looking up this location inside of maps
        _key = posToKey(pos)
    })

    util.assert(allLocations[loc._key] == nil, 'Registered duplicate location')
    allLocations[loc._key] = loc

    return loc
end

-- midPoints is a list of coordinates
function static.addPath(loc1, loc2, midPoints)
    midPoints = midPoints or {}

    -- Clear the cache - this new path may be adding a shortcut that invalidates some of the cached entries.
    routeCache = {}

    local allCoordsInPath = util.copyTable(midPoints)
    table.insert(allCoordsInPath, 1, loc1.pos.coord)
    table.insert(allCoordsInPath, loc2.pos.coord)
    -- The startFace/endFace are what's optimal to get the lowest cost to travel the path,
    -- they're not necessarily the same as the location's facings. The location's facings are only considered
    -- if you're starting or ending your journey at that location, but the locations could also just be in-between points in a journey.
    local cost, startFace, endFace = calcPathCost(allCoordsInPath)

    local availablePaths = availablePathsStateManager:getAndModify()
    if availablePaths[loc1._key] == nil then
        availablePaths[loc1._key] = {}
    end
    table.insert(availablePaths[loc1._key], {
        to = loc2._key,
        midPoints = midPoints,
        cost = cost,
        -- startFace/endFace may be nil
        startFace = startFace,
        endFace = endFace,
    })

    local cost, startFace, endFace = calcPathCost(util.reverseTable(allCoordsInPath))

    if availablePaths[loc2._key] == nil then
        availablePaths[loc2._key] = {}
    end
    table.insert(availablePaths[loc2._key], {
        to = loc1._key,
        midPoints = util.reverseTable(midPoints),
        cost = cost,
        -- startFace/endFace may be nil
        startFace = startFace,
        endFace = endFace,
    })
end

-- Throws if the turtle isn't at a registered location
function static.currentLocation()
    return lookupLoc(posToKey(navigate.getAbsoluteTurtlePos()))
end

-- Finds the shortest route to a location among the registered paths and travels there.
function prototype:travelHere()
    if navigate.getAbsoluteTurtlePos():equals(self.pos) then return end
    local turtleLoc = static.currentLocation()
    local route = findBestRoute(turtleLoc, self).route
    util.assert(route ~= nil, 'Failed to navigate to a particular location - there was no route to this location.')

    for _, path in ipairs(route) do
        for i, coord in ipairs(path.midPoints) do
            navigate.moveToCoord(coord)
        end
        navigate.moveToCoord(lookupLoc(path.to).pos.coord)
    end
    navigate.face(self.pos.facing)
end

function static.workToMove(loc1, loc2)
    local bestRoute = findBestRoute(loc1, loc2)
    return bestRoute.routeCost
end

return static
