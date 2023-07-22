--[[
    A location represents a specific, marked point in space that you might frequently travel to.
    Some helpers related to locations are also found in space.lua.

    A location should always have a spot above it that's empty. This allows the turtle
    to place a chest there, to craft at any location.
--]]

local util = import('util.lua')

local module = {}

local allLocations = {}

-- HELPER FUNCTIONS --

local lookupLoc = function(pos)
    local loc = (
        allLocations[pos.forward] and
        allLocations[pos.forward][pos.right] and
        allLocations[pos.forward][pos.right][pos.up] and
        allLocations[pos.forward][pos.right][pos.up][pos.face]
    )

    if loc == nil then
        error('Failed to look up a location at a given position')
    end

    return loc
end

local calcPathCost = function(coords)
    local length = 0
    for i=1, #coords-1 do
        length = length + (
            math.abs(coords[i+1].forward - coords[i].forward) +
            math.abs(coords[i+1].right - coords[i].right) +
            math.abs(coords[i+1].up - coords[i].up)
        )
    end
    return length
end

-- Finds the best route by exploring all closets locations until it runs into the target.
-- (this means it'll have to look at almost every registered location to find distant routes).
local findBestRoute = function(loc1, loc2)
    if loc1 == loc2 then return {} end
    local toExplore = {{to=loc1, route={}, routeCost=0}}
    local seen = { [loc1] = true }

    while #toExplore > 0 do
        local bestIndex = 1
        for i, entry in ipairs(toExplore) do
            if entry.routeCost < toExplore[bestIndex].routeCost then
                bestIndex = i
            end
        end
        local entry = table.remove(toExplore, bestIndex)
        for i, path in ipairs(entry.to.paths) do
            if not seen[path.to] then
                seen[path.to] = true
                local newRoute = util.copyTable(entry.route)
                table.insert(newRoute, path)
                local newEntry = {
                    to = path.to,
                    routeCost = entry.routeCost + path.cost,
                    route = newRoute,
                }
                if path.to == loc2 then
                    return { routeCost = newEntry.routeCost, route = newEntry.route }
                end
                table.insert(toExplore, newEntry)
            end
        end
    end

    error('Failed to find a path to a target location. Are all of the needed paths currently registered?')
end

-- PUBLIC FUNCTIONS --

function module.register(pos)
    local loc = {
        cmps = _G.act.space.createCompass(pos),
        paths = {} -- List of paths that lead to and from this location
    }

    if allLocations[pos.forward] == nil then allLocations[pos.forward] = {} end
    if allLocations[pos.forward][pos.right] == nil then allLocations[pos.forward][pos.right] = {} end
    if allLocations[pos.forward][pos.right][pos.up] == nil then allLocations[pos.forward][pos.right][pos.up] = {} end
    allLocations[pos.forward][pos.right][pos.up][pos.face] = loc
    return loc
end

-- midPoints is a list of coordinates
function module.registerPath(loc1, loc2, midPoints)
    midPoints = midPoints or {}

    local allCoordsInPath = util.copyTable(midPoints)
    table.insert(allCoordsInPath, 1, loc1.cmps.coord)
    table.insert(allCoordsInPath, loc2.cmps.coord)
    local cost = calcPathCost(allCoordsInPath)

    table.insert(loc1.paths, {
        from = loc1,
        to = loc2,
        midPoints = midPoints,
        cost = cost,
    })
    table.insert(loc2.paths, {
        from = loc2,
        to = loc1,
        midPoints = util.reverseTable(midPoints),
        cost = cost,
    })
end

-- Finds the shortest route to a location among the registered paths and travels there.
function module.travelToLocation(commands, state, destLoc)
    local navigate = _G.act.navigate

    if state.turtleCmps().compareCmps(destLoc.cmps) then return end
    local turtleLoc = lookupLoc(state.turtlePos)
    local route = findBestRoute(turtleLoc, destLoc).route
    if route == nil then error('Failed to naviage to a particular location - there was no route to this location.') end

    for _, path in ipairs(route) do
        for i, coord in ipairs(path.midPoints) do
            navigate.moveToCoord(commands, state, coord)
        end
        navigate.moveToCoord(commands, state, path.to.cmps.coord)
    end
    navigate.face(commands, state, destLoc.cmps.facing)
end

-- I can implement these when I need them
-- function module.unregisterPath() end
-- function module.unregisterLocation() end

return module