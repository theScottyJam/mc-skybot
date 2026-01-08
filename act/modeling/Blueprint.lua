local util = import('util.lua')
local Coord = import('../space/Coord.lua')
local Position = import('../space/Position.lua')
local navigate = import('../navigate.lua')
local Project = import('../planner/Project.lua')
local highLevelCommands = import('../highLevelCommands.lua')
local Sketch = import('./Sketch.lua')

local static = {}
local prototype = {}

local calcRequiredResources = function(sketch, mapKey)
    local requiredResources = {} -- maps block ids to quantity required for the build
    sketch:forEachFilledCell(function (cell, coord)
        util.assert(mapKey[cell] ~= nil, 'Found the character "'..cell..'" in a blueprint, which did not have a corresponding ID in the key.')

        local id = mapKey[cell]
        if requiredResources[id] == nil then
            requiredResources[id] = 0
        end
        requiredResources[id] = requiredResources[id] + 1
    end)

    -- Maps block IDs to the quantity of them found in the blueprint.
    return requiredResources
end

-- The return coordinate is relative to the 1,1,1 of the entire blueprint
-- previousCoord can be nil
-- Returns `nil` when there's no more coordinates to visit.
local nextCoordToVisit = function (sketch, mapKey, previousCoord)
    sketch.origin:assertAbsolute()
    if previousCoord ~= nil then
        previousCoord:assertAbsolute()
    end

    local isEven = function(n) return n % 2 == 0 end
    local bounds = sketch.bounds

    -- This behavior is done, because the first find will always be
    -- the coordinate we're currently at. We want to skip that and
    -- find the next one
    local skipFirstFind = true

    if previousCoord == nil then
        previousCoord = Coord.absolute({
            right = bounds.leastRight,
            forward = bounds.leastForward,
            up = bounds.leastUp,
        })
        -- When looking for the first block to place,
        -- there is no previous block we want to skip.
        skipFirstFind = false
    end

    for up = previousCoord.up, bounds.mostUp do
        local forwardRange = { bounds.leastForward, bounds.mostForward, 1 }
        if not isEven(up - bounds.leastUp) then
            forwardRange = { bounds.mostForward, bounds.leastForward, -1 }
        end
        if up == previousCoord.up then
            forwardRange[1] = previousCoord.forward
        end
        for forward = forwardRange[1], forwardRange[2], forwardRange[3] do
            local rightRange = { bounds.leastRight, bounds.mostRight, 1 }
            if not isEven(forward - bounds.leastForward) then
                rightRange = { bounds.mostRight, bounds.leastRight, -1 }
            end
            if up == previousCoord.up and forward == previousCoord.forward then
                rightRange[1] = previousCoord.right
            end
            for right = rightRange[1], rightRange[2], rightRange[3] do
                local targetCoord = Coord.absolute({ forward = forward, right = right, up = up })
                local char = sketch:getCharAt(targetCoord)
                if mapKey[char] ~= nil then -- If it's a block (not a marker)
                    if skipFirstFind then
                        skipFirstFind = false
                    else
                        return targetCoord
                    end
                end
            end
        end
    end

    return nil
end

--[[
Inputs:
    buildStartPos = where the blueprint will be built. The orientation will determine which way the blueprint will be facing.
    ...Many taskFactory options are also supported. For interruptions, you will be placed at the buildStartPos before exit() is called,
       and you must send the turtle back to buildStartPos during the enter() call.
       An `ifExits` function is required and should also assume the turtle is at buildStartPos when calculating the information.
]]
function prototype:registerConstructionProject(opts)
    local buildStartPos = opts.buildStartPos
    local init = opts.init or function() end
    local before = opts.before or function() end
    local enter = opts.enter or function() end
    local ifExits = opts.ifExits
    local exit = opts.exit or function() end
    local after = opts.after or function() end
    local requiredResourcesRequested = opts.requiredResources or {}
    util.assert(ifExits ~= nil)

    local sketch = self._relSketch:anchorMarker(self._buildStartMarker, buildStartPos)
    local mapKey = self._mapKey

    local requiredResources = {}
    for id, quantity in util.sortedMapTablePairs(self._requiredResources) do
        requiredResources[id] = { quantity = quantity, at = 'INVENTORY' }
    end
    for id, resourceInfo in util.sortedMapTablePairs(requiredResourcesRequested) do
        util.assert(resourceInfo.at == 'INVENTORY')
        if requiredResources[id] == nil then
            requiredResources[id] = { quantity = 0, at = 'INVENTORY' }
        end
        requiredResources[id].quantity = requiredResources[id].quantity + resourceInfo.quantity
    end

    -- Anything stored on "self" will be prefixed with "_blueprint_" to namespace it, because the "self" table
    -- will also be passed to the hooks for others to use, and they don't need to be aware of the internal blueprint state.
    return Project.register({
        id = 'blueprint:'..self._id,
        requiredResources = requiredResources,
        init = function(self)
            init(self)
            self._blueprint_nextCoord = nextCoordToVisit(sketch, mapKey)
            util.assert(self._blueprint_nextCoord ~= nil, 'Attempted to use an empty blueprint')
        end,
        before = function(self)
            before(self)
        end,
        enter = function(self)
            enter(self)
            navigate.assertAtPos(buildStartPos)
        end,
        ifExits = function(self)
            local moveToBuildStartWork = navigate.workToMoveToPos(buildStartPos, {'forward', 'right', 'up'})
            local response = ifExits(self)
            return { location = response.location, work = response.work + moveToBuildStartWork }
        end,
        exit = function(self)
            navigate.moveToPos(buildStartPos, {'forward', 'right', 'up'})
            exit(self)
        end,
        after = function(self)
            after(self)
        end,
        nextSprint = function(self)
            local targetCoord = self._blueprint_nextCoord

            local targetChar = sketch:getCharAt(targetCoord)
            util.assert(mapKey[targetChar])

            navigate.moveToCoord(
                targetCoord:at({ up = 1 }),
                {'up', 'right', 'forward'}
            )
            highLevelCommands.placeItemDown(mapKey[targetChar])

            self._blueprint_nextCoord = nextCoordToVisit(sketch, mapKey, targetCoord)
            return self._blueprint_nextCoord == nil
        end,
    })
end

--[[
inputs:
    ...Everything Sketch.new() expects
    id = Unique id to register this blueprint under.
    key = Maps resource names to characters
    buildStartMarker = The name of a marker that marks where the turtle will be at when it starts building.

You are required to provide a "build start marker" somewhere in the area. This marks where the turtle will start
when it works on the project. The marker should be placed at an edge, and there should be a column of empty space above it.
]]
function static.new(opts_)
    local opts = util.copyTable(opts_)
    local id = opts.id
    local key = opts.key
    local buildStartMarker = opts.buildStartMarker
    opts.id = nil
    opts.key = nil
    opts.buildStartMarker = nil

    local mapKey = util.flipMapTable(key) -- Flips the key so it maps characters to ids, which is more useful internally.
    local relSketch = Sketch.new(opts)

    return util.attachPrototype(prototype, {
        _id = id,
        _relSketch = relSketch,
        _buildStartMarker = buildStartMarker,
        _mapKey = mapKey,
        _requiredResources = calcRequiredResources(relSketch, mapKey),
    })
end

return static
