--[[
    A location represents a specific, marked point in space that you might frequently travel to.
    Some helpers related to locations are also found in space.lua
--]]

local util = import('util.lua')

local module = {}

local allLocations = {}

function module.register(pos)
    local loc = {}
    loc.x = pos.x
    loc.y = pos.y
    loc.z = pos.z
    loc.face = pos.face
    loc.paths = {} -- List of paths that lead to and from this location

    if allLocations[loc.x] == nil then allLocations[loc.x] = {} end
    if allLocations[loc.x][loc.y] == nil then allLocations[loc.x][loc.y] = {} end
    allLocations[loc.x][loc.y][loc.z] = loc
    return loc
end

-- midPoints is a list of coordinates
function module.registerPath(loc1, loc2, midPoints)
    local space = _G.act.space

    midPoints = midPoints or {}

    local allCoordsInPath = util.copyTable(midPoints)
    table.insert(allCoordsInPath, 1, space.locToCoord(loc1))
    table.insert(allCoordsInPath, space.locToCoord(loc2))
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
    local loc = allLocations[coord.x] and allLocations[coord.x][coord.y] and allLocations[coord.x][coord.y][coord.z]
    if loc == nil then
        error('Failed to look up a location at a given coordinate')
    end
    return loc
end

function calcPathCost(coords)
    local length = 0
    for i=1, #coords-1 do
        length = length + math.abs(coords[i+1].x - coords[i].x)
        length = length + math.abs(coords[i+1].y - coords[i].y)
        length = length + math.abs(coords[i+1].z - coords[i].z)
    end
    return length
end

-- Finds the shortest route to a location among the registered paths and travels there.
function module.travelToLocation(shortTermPlaner, destLoc)
    local space = _G.act.space
    local commands = _G.act.commands
    local location = _G.act.location
    local navigate = _G.act.navigate

    if space.comparePos(shortTermPlaner.turtlePos, space.locToPos(destLoc)) then return end
    local turtleLoc = lookupLoc(space.locToCoord(shortTermPlaner.turtlePos))
    local route = findBestRoute(turtleLoc, destLoc).route
    if route == nil then error('Failed to naviage to a particular location - there was no route to this location.') end

    for _, path in ipairs(route) do
        for i, coord in ipairs(path.midPoints) do
            navigate.moveTo(shortTermPlaner, coord)
        end
        navigate.moveTo(shortTermPlaner, space.locToCoord(path.to))
    end
    navigate.face(shortTermPlaner, destLoc.face)
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
-- function module.destroyPath() end
-- function module.destroyLocation() end

return module