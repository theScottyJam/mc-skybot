--<-- This still needs to be here?
-- The coordinates used internally within this module are
-- often not the standard { forward=..., right=..., up=... } coordinates.
-- Instead they're { x=..., y=..., z=... } coordinates that are often relative to the
-- tables they index (which could mean different
-- things depending on which table they're intended to index).
-- The origin point is { x=1, y=1, z=1 } (not zeros), as that is the first index in the tables.
--
-- Also, the coordinates used assume that `z` is up and down, which is different from Minecraft.

--<-- Remove any imports?
local util = import('util.lua')
local space = import('../space.lua')
local navigate = import('../navigate.lua')
local highLevelCommands = import('../highLevelCommands.lua')
local Plane = import('./Plane.lua')
local Region = import('./Region.lua')

local module = {}

--<-- We don't actually need a normalizedMap anymore, but we still depend on the other return values of this function.
--<-- We ought to rename this function. It's already been simplified some, but maybe there's more that can be done?
-- See the end of this function for documentation on what it returns
local normalizeMap = function(region, opts) --<-- Do I still need to pass in the same opts with the region?
    local blockKey = opts.key --<-- Rename variable to `mapKey`
    local labeledPositions = opts.labeledPositions
    local layers = opts.layers

    local bounds = region.bounds

    --<-- In module.create(), I flip the key table around. I could probably pass in that flipped table and use that
    --<-- as a partial replacement for some of this stuff
    -- Maps characters found in the layers into what they represent (either blocks or labels).
    local key = {}
    for id, char in pairs(blockKey) do
        key[char] = { type = 'block', id = id }
    end
    for name, info in pairs(labeledPositions) do
        key[info.char] = {
            type = 'label',
            name = name,
            behavior = info.behavior,
            targetOffset = info.targetOffset, -- might be nil
        }
    end

    -- These variables get mutated by normalizeCell()
    local requiredResources = {} -- maps block ids to quantity required for the build
    local buildStartCoord = nil

    region:forEachFilledCell(function (cell, coord)
        if cell == '.' or cell == ',' then
            return
        end

        util.assert(
            key[cell] ~= nil,
            'Found the character "'..cell..'" in a blueprint, which did not have a corresponding ID in the key.'
        )
        if key[cell].type == 'label' then
            util.assert(key[cell].behavior == 'buildStartCoord', 'For now, a label must have a behavior set to "buildStartCoord"')
            util.assert(buildStartCoord == nil, 'Two buildStartCoord labels were found.')
            local delta = key[cell].targetOffset or {}
            buildStartCoord = {
                forward = coord.forward + (delta.forward or 0),
                right = coord.right + (delta.right or 0),
                up = coord.up + (delta.up or 0),
            }
            return
        elseif key[cell].type == 'block' then
            local id = key[cell].id
            if requiredResources[id] == nil then
                requiredResources[id] = 0
            end
            requiredResources[id] = requiredResources[id] + 1

            return
        else
            error('Invalid type')
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

-- Behavior of special characters
--   The "," is a "primary reference point". It can be thought of as the origin point for each layer.
--     Because the sizes of the layers provided may differ from layer to layer, it's important to have
--     an origin point in each layer so we know what everything is relative to.
--   The "." is a "secondary reference point". You can place these anywhere you want on a particular layer,
--     but wherever you place them, you'll be required to place a "." in the exact same location on every other
--     layer (unless this particular layer definition is smaller than others, and the "." would fall outside of the definition area).
--     Its purpose is to just provide further reference points to help you eyeball things and make sure
--     everything is where it belongs.
--
-- You are required to place a buildStartCoord label somewhere in the area. This label marks where the turtle will start
-- when it works on the project. The label should be placed at an edge, and there should be a column of empty space above it.
function module.create(opts) -- opts should contain { key=..., labeledPositions=..., layers=... }
    local mapKey = util.flipMapTable(opts.key) -- Flips the key so it maps characters to ids, which is more useful internally.
    local region = Region.new({
        layeredAsciiMap = opts.layers
    })
    local bounds = region.bounds
    local normalizeMapResult = normalizeMap(region, opts)
    local requiredResources = normalizeMapResult.requiredResources
    local buildStartRelCoord = normalizeMapResult.buildStartCoord

    return {
        requiredResources = util.mapMapTable(requiredResources, function(quantity)
            return { quantity=quantity, at='INVENTORY' }
        end),
        createTaskState = function(buildStartCmps)
            local absOriginPos = buildStartCmps.compassAt({
                forward = -buildStartRelCoord.forward,
                right = -buildStartRelCoord.right,
                up = -buildStartRelCoord.up,
            }).pos

            local nextCoord = nextCoordToVisit(region, mapKey)
            util.assert(nextCoord ~= nil, 'Attempted to use an empty blueprint')
            return {
                -- `origin` is the absolute position of the 1,1,1 position of the blueprint.
                absOriginPos = absOriginPos,
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
            local originCmps = space.createCompass(taskState.absOriginPos)
            local targetCoord = taskState.nextCoord

            local targetCmps = originCmps.compassAt({
                forward = targetCoord.forward,
                right = targetCoord.right,
                up = targetCoord.up,
            })

            local targetChar = region:getCharAt(targetCoord)
            util.assert(mapKey[targetChar])

            navigate.moveToCoord(targetCmps.coordAt({ up = 1 }), {'up', 'right', 'forward'})
            highLevelCommands.placeItemDown(mapKey[targetChar])

            --<-- Consider passing in an anchored region, instead of doing math on the returned coord
            nextTaskState.nextCoord = nextCoordToVisit(region, mapKey, taskState.nextCoord)
            util.mergeTablesInPlace(taskState, nextTaskState)
            return nextTaskState.nextCoord == nil
        end,
    }
end

return module
