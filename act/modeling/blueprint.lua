local util = import('util.lua')
local space = import('../space.lua')
local navigate = import('../navigate.lua')
local highLevelCommands = import('../highLevelCommands.lua')
local Region = import('./Region.lua')

local module = {}

-- See the end of this function for documentation on what it returns
local examineMap = function(region, opts)
    local mapKey = opts.mapKey
    local labeledPositions = opts.labeledPositions

    -- Converts labeledPositions into a lookup table.
    local labelKey = {}
    for name, info in pairs(labeledPositions) do
        labelKey[info.char] = {
            name = name,
            behavior = info.behavior,
            targetOffset = info.targetOffset, -- might be nil
        }
    end

    -- These variables get mutated by normalizeCell()
    local requiredResources = {} -- maps block ids to quantity required for the build
    local buildStartCoord = nil

    region:forEachFilledCell(function (cell, coord)
        if labelKey[cell] ~= nil then
            util.assert(labelKey[cell].behavior == 'buildStartCoord', 'For now, a label must have a behavior set to "buildStartCoord"')
            util.assert(buildStartCoord == nil, 'Two buildStartCoord labels were found.')
            local delta = labelKey[cell].targetOffset or {}
            buildStartCoord = {
                forward = coord.forward + (delta.forward or 0),
                right = coord.right + (delta.right or 0),
                up = coord.up + (delta.up or 0),
            }
            return
        elseif mapKey[cell] ~= nil then
            local id = mapKey[cell]
            if requiredResources[id] == nil then
                requiredResources[id] = 0
            end
            requiredResources[id] = requiredResources[id] + 1

            return
        else
            error('Found the character "'..cell..'" in a blueprint, which did not have a corresponding ID in the key.')
        end
    end)

    util.assert(buildStartCoord ~= nil, 'A buildStartCoord coord must be placed somewhere in the blueprint.')
    -- (As promised by the comments above this function definition, this is some documentation on each property)
    return {
        -- Maps block IDs to the quantity of them found in the blueprint.
        requiredResources = requiredResources,
        -- A coordinate relative from 1,1,1 to the build start coordinate.
        buildStartCoord = buildStartCoord,
    }
end

-- The return coordinate is relative to the 1,1,1 of the entire blueprint
-- previousCoord can be nil
-- Returns `nil` when there's no more coordinates to visit.
local nextCoordToVisit = function (region, mapKey, previousCoord)
    local isEven = function(n) return n % 2 == 0 end
    local bounds = region.bounds

    -- This behavior is done, because the first find will always be
    -- the coordinate we're currently at. We want to skip that and
    -- find the next one
    local skipFirstFind = true

    if previousCoord == nil then
        previousCoord = {
            right = bounds.left,
            forward = bounds.backward,
            up = bounds.down,
        }
        -- When looking for the first block to place,
        -- there is no previous block we want to skip.
        skipFirstFind = false
    end

    for up = previousCoord.up, bounds.up do
        local forwardRange = { bounds.backward, bounds.forward, 1 }
        if not isEven(up - bounds.down) then
            forwardRange = { bounds.forward, bounds.backward, -1 }
        end
        if up == previousCoord.up then
            forwardRange[1] = previousCoord.forward
        end
        for forward = forwardRange[1], forwardRange[2], forwardRange[3] do
            local rightRange = { bounds.left, bounds.right, 1 }
            if not isEven(forward - bounds.backward) then
                rightRange = { bounds.right, bounds.left, -1 }
            end
            if up == previousCoord.up and forward == previousCoord.forward then
                rightRange[1] = previousCoord.right
            end
            for right = rightRange[1], rightRange[2], rightRange[3] do
                local targetCoord = { forward = forward, right = right, up = up }
                local char = region:getCharAt(targetCoord)
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

-- Note that "." and "," have special behaviors to make sure things line up as you construct the blueprint.
-- See Region.lua for more information.
--
-- You are required to place a buildStartCoord label somewhere in the area. This label marks where the turtle will start
-- when it works on the project. The label should be placed at an edge, and there should be a column of empty space above it.
function module.create(opts) -- opts should contain { key=..., labeledPositions=..., layers=... }
    local mapKey = util.flipMapTable(opts.key) -- Flips the key so it maps characters to ids, which is more useful internally.
    local relRegion = Region.new({
        layeredAsciiMap = opts.layers
    })
    local examineMapResult = examineMap(relRegion, {
        labeledPositions = opts.labeledPositions,
        mapKey = mapKey,
    })
    local requiredResources = examineMapResult.requiredResources
    local buildStartRelCoord = examineMapResult.buildStartCoord -- Relative to the 1,1,1 coordinate of the blueprint.

    return function(buildStartCmps)
        local region = relRegion:anchorBackwardBottomLeft(buildStartCmps.compassAt({
            forward = -buildStartRelCoord.forward,
            right = -buildStartRelCoord.right,
            up = -buildStartRelCoord.up,
        }).coord)

        return {
            requiredResources = util.mapMapTable(requiredResources, function(quantity)
                return { quantity=quantity, at='INVENTORY' }
            end),
            createTaskState = function()
                local nextCoord = nextCoordToVisit(region, mapKey)
                util.assert(nextCoord ~= nil, 'Attempted to use an empty blueprint')
                return {
                    buildStartPos = buildStartCmps.pos,
                    nextCoord = nextCoord,
                }
            end,
            enter = function(taskState)
                navigate.assertAtPos(taskState.buildStartPos)
            end,
            exit = function(taskState, info)
                navigate.moveToPos(taskState.buildStartPos, {'forward', 'right', 'up'})
            end,
            nextSprint = function(taskState)
                local nextTaskState = util.copyTable(taskState)
                local targetCoord = taskState.nextCoord

                local targetChar = region:getCharAt(targetCoord)
                util.assert(mapKey[targetChar])

                navigate.moveToCoord(
                    {
                        forward = targetCoord.forward,
                        right = targetCoord.right,
                        up = targetCoord.up + 1,
                        face = 'forward',
                    },
                    {'up', 'right', 'forward'}
                )
                highLevelCommands.placeItemDown(mapKey[targetChar])

                nextTaskState.nextCoord = nextCoordToVisit(region, mapKey, taskState.nextCoord)
                util.mergeTablesInPlace(taskState, nextTaskState)
                return nextTaskState.nextCoord == nil
            end,
        }
    end
end

return module
