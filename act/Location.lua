--[[
    A location represents a specific, marked point in space that you might frequently travel to.

    A location should always have a spot above it that's empty. This allows the turtle
    to place a chest there, to craft at any location.
]]

local util = import('util.lua')
local navigate = import('./navigate.lua')
local state = import('./state.lua')

local static = {}
local prototype = {}

local allLocations = {}

local availablePathsStateManager = state.__registerPieceOfState('module:Location', function()
    -- A mapping of paths the turtle can travel to move from one location to the next.
    return {}
end)

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

local calcPathCost = function(coords)
    local length = 0
    for i=1, #coords-1 do
        coords[i]:assertAbsolute()
        length = length + (
            math.abs(coords[i+1].forward - coords[i].forward) +
            math.abs(coords[i+1].right - coords[i].right) +
            math.abs(coords[i+1].up - coords[i].up)
        )
    end
    coords[#coords]:assertAbsolute()
    return length
end

function prototype:_getPaths()
    return availablePathsStateManager:get()[self._key]
end

-- Finds the best route by exploring all closets locations until it runs into the target.
-- (this means it'll have to look at almost every registered location to find distant routes).
local findBestRoute = function(loc1, loc2)
    if loc1._key == loc2._key then return {} end
    local toExplore = {{ to = loc1, route = {}, routeCost = 0 }}
    local seen = { [loc1._key] = true }

    while #toExplore > 0 do
        local bestIndex = 1
        for i, entry in ipairs(toExplore) do
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
                local newEntry = {
                    to = lookupLoc(path.to),
                    routeCost = entry.routeCost + path.cost,
                    route = newRoute,
                }
                if path.to == loc2._key then
                    return { routeCost = newEntry.routeCost, route = newEntry.route }
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

    local allCoordsInPath = util.copyTable(midPoints)
    table.insert(allCoordsInPath, 1, loc1.pos.coord)
    table.insert(allCoordsInPath, loc2.pos.coord)
    local cost = calcPathCost(allCoordsInPath)

    local availablePaths = availablePathsStateManager:getAndModify()
    if availablePaths[loc1._key] == nil then
        availablePaths[loc1._key] = {}
    end
    table.insert(availablePaths[loc1._key], {
        to = loc2._key,
        midPoints = midPoints,
        cost = cost,
    })

    if availablePaths[loc2._key] == nil then
        availablePaths[loc2._key] = {}
    end

    table.insert(availablePaths[loc2._key], {
        to = loc1._key,
        midPoints = util.reverseTable(midPoints),
        cost = cost,
    })
end

-- Finds the shortest route to a location among the registered paths and travels there.
function prototype:travelHere()
    if navigate.getAbsoluteTurtlePos():equals(self.pos) then return end
    local turtleLoc = lookupLoc(posToKey(navigate.getAbsoluteTurtlePos()))
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

return static
