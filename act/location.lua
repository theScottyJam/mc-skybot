--[[
    A location represents a specific, marked point in space that you might frequently travel to.
    Some helpers related to locations are also found in space.lua.

    A location should always have a spot above it that's empty. This allows the turtle
    to place a chest there, to craft at any location.
--]]

local util = import('util.lua')

local module = {}

local allLocations = {}

function module.register(pos)
    if pos.from ~= 'ORIGIN' then
        error('A location\'s `from` must be set to "ORIGIN"')
    end

    local loc = {
        pos = pos,
        paths = {} -- List of paths that lead to and from this location
    }

    if allLocations[pos.forward] == nil then allLocations[pos.forward] = {} end
    if allLocations[pos.forward][pos.right] == nil then allLocations[pos.forward][pos.right] = {} end
    allLocations[pos.forward][pos.right][pos.up] = loc
    return loc
end

-- midPoints is a list of coordinates
function module.registerPath(loc1, loc2, midPoints)
    local space = _G.act.space

    midPoints = midPoints or {}

    local allCoordsInPath = util.copyTable(midPoints)
    table.insert(allCoordsInPath, 1, space.posToCoord(loc1.pos))
    table.insert(allCoordsInPath, space.posToCoord(loc2.pos))
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

function lookupLoc(coord)
    local loc = (
        allLocations[coord.forward] and
        allLocations[coord.forward][coord.right] and
        allLocations[coord.forward][coord.right][coord.up]
    )

    if loc == nil then
        error('Failed to look up a location at a given coordinate')
    end

    return loc
end

function calcPathCost(coords)
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

-- Finds the shortest route to a location among the registered paths and travels there.
function module.travelToLocation(planner, destLoc)
    local space = _G.act.space
    local navigate = _G.act.navigate

    if space.comparePos(planner.turtlePos, destLoc.pos) then return end
    local turtleLoc = lookupLoc(space.posToCoord(planner.turtlePos))
    local route = findBestRoute(turtleLoc, destLoc).route
    if route == nil then error('Failed to naviage to a particular location - there was no route to this location.') end

    for _, path in ipairs(route) do
        for i, coord in ipairs(path.midPoints) do
            navigate.moveToCoord(planner, coord)
        end
        navigate.moveToCoord(planner, space.posToCoord(path.to.pos))
    end
    navigate.face(planner, space.posToFacing(destLoc.pos))
end

-- May return nil
-- Finds the best route by exploring all closets locations until it runs into the target.
-- (this means it'll have to look at almost every registered location to find distant routes).
function findBestRoute(loc1, loc2)
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

    return nil
end

-- I can implement these when I need them
-- function module.unregisterPath() end
-- function module.unregisterLocation() end

return module