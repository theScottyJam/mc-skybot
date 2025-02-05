-- The coordinates used internally within this module are
-- often not the standard { forward=..., right=..., up=... } coordinates.
-- Instead they're { x=..., y=..., z=... } coordinates that are often relative to the
-- tables they index (which could mean different
-- things depending on which table they're intended to index).
-- The origin point is { x=1, y=1, z=1 } (not zeros), as that is the first index in the tables.
--
-- Also, the coordinates used assume that `z` is up and down, which is different from Minecraft.

local util = import('util.lua')
local space = import('../space.lua')
local navigate = import('../navigate.lua')
local highLevelCommands = import('../highLevelCommands.lua')
local Plane = import('./Plane.lua')

local module = {}

-- Returns metadata about the layers.
-- Overall, it includes information about where the reference points
-- are, and how large of a region this blueprint will take up.
-- Specific details about the return value are documented inside.
function getBearings(opts)
    local layers = opts.layers

    -- What gets eventually returned.
    local metadata = {
        -- Contains a list of { plane = <plane> } tables
        layers = {},
        -- List of forward/right points relative to the primary reference point
        secondaryReferencePoints = {},
        -- `left = 2` means, starting from the primary reference point, you
        -- can take two steps left and still be in bounds.
        bounds = { left = 0, forward = 0, right = 0, backward = 0 }
    }

    -- Used like secondaryReferencePointMap[forward][right] = { count = ..., firstLayerFoundOn = ... }
    -- where forward/right are relative to the primary reference point.
    -- Some of this information is used for the returned metadata object, and some is simply used for assertions.
    local secondaryReferencePointsMap = {}

    for zIndex, layer in pairs(layers) do
        local plane = Plane.new({
            asciiMap = layer,
            markers = {
                primaryReferencePoint = { char = ',' },
            },
            markerSets = {
                secondaryReferencePoints = { char = '.' },
            },
        }):anchorMarker('primaryReferencePoint', { forward = 0, right = 0, up = 0 })

        local primaryReferencePointBounds = plane:getBoundsAtMarker('primaryReferencePoint')
        local secondaryReferencePoints = util.mapArrayTable(
            plane:cmpsListFromMarkerSet('secondaryReferencePoints'),
            function (cmps) return cmps.coord end
        )

        table.insert(metadata.layers, { plane = plane })

        metadata.bounds.left = util.maxNumber(metadata.bounds.left, primaryReferencePointBounds.left)
        metadata.bounds.forward = util.maxNumber(metadata.bounds.forward, primaryReferencePointBounds.forward)
        metadata.bounds.right = util.maxNumber(metadata.bounds.right, primaryReferencePointBounds.right)
        metadata.bounds.backward = util.maxNumber(metadata.bounds.backward, primaryReferencePointBounds.backward)

        for i, point in pairs(secondaryReferencePoints) do
            local refMap = secondaryReferencePointsMap
            if refMap[point.forward] == nil then
                refMap[point.forward] = {}
            end
            if refMap[point.forward][point.right] == nil then
                refMap[point.forward][point.right] = { count = 0, firstLayerFoundOn = zIndex }
            end
            refMap[point.forward][point.right].count = refMap[point.forward][point.right].count + 1
        end
    end

    for forward, row in pairs(secondaryReferencePointsMap) do
        for right, info in pairs(row) do
            util.assert(
                info.count > 1,
                'Found a secondary reference point (.) on layer ' .. info.firstLayerFoundOn
                .. ' that does not line up with any reference points on any other layer.'
            )
            table.insert(metadata.secondaryReferencePoints, { forward = forward, right = right })
        end
    end

    return metadata
end

-- See the end of this function for documentation on what it returns
function normalizeMap(opts)
    local blockKey = opts.key
    local labeledPositions = opts.labeledPositions
    local layers = opts.layers

    local metadata = getBearings({ layers = layers })

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

    local overallWidth = metadata.bounds.left + 1 + metadata.bounds.right
    local overallHeight = metadata.bounds.forward + 1 + metadata.bounds.backward
    local empty = { type = 'empty' }

    -- These variables get mutated by normalizeCell()
    local requiredResources = {} -- maps block ids to quantity required for the build
    local buildStartCoord = nil
    local normalizeCell = function(cell, layersIndex)
        if cell == ' ' or cell == '.' or cell == ',' then
            return empty
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
                x = layersIndex.xIndex + (delta.right or 0),
                y = layersIndex.yIndex - (delta.forward or 0),
                z = layersIndex.zIndex - (delta.up or 0),
            }
            return empty
        elseif key[cell].type == 'block' then
            local id = key[cell].id
            if requiredResources[id] == nil then
                requiredResources[id] = 0
            end
            requiredResources[id] = requiredResources[id] + 1

            return { type = 'block', id = id }
        else
            error('Invalid type')
        end
    end

    local verifySecondaryReferencePoints = function(layer, zIndex)
        for i, refPoint in ipairs(metadata.secondaryReferencePoints) do
            local char, planeIndex = metadata.layers[zIndex].plane:tryGetCharAt(
                -- Recalculate the secondary reference point to have an "up" field relative to the layer.
                {
                    forward = refPoint.forward,
                    right = refPoint.right,
                    up = 0,
                }
            )
            util.assert(
                char == nil or char == '.',
                'Expected layer '..zIndex..' to have a secondary reference point at xIndex='..planeIndex.x..' yIndex='..planeIndex.y..'.'
            )
        end
    end

    -- Append `amount` empty objects to the end of the row
    local padRow = function(row, amount)
        for i = 1, amount do
            table.insert(row, empty)
        end
    end

    -- Append `numOfNewRows` number of rows of size `sizeOfRows`
    -- filled with empty objects to the end of the layer
    local padLayer = function(layer, opts)
        local numOfNewRows = opts.numOfNewRows
        local sizeOfRows = opts.sizeOfRows
        for i = 1, numOfNewRows do
            local row = {}
            padRow(row, sizeOfRows)
            table.insert(layer, row)
        end
    end

    local newLayers = {}
    for zIndex, layer in ipairs(layers) do
        verifySecondaryReferencePoints(layer, zIndex)
        local newLayer = {}
        local layerBounds = metadata.layers[zIndex].plane:getBoundsAtMarker('primaryReferencePoint')
        local padBottom = metadata.bounds.backward - layerBounds.backward
        local padTop = overallHeight - #layer - padBottom
        padLayer(newLayer, {
            numOfNewRows = padTop,
            sizeOfRows = overallWidth,
        })
        for yIndex, row in ipairs(layer) do
            local newRow = {}
            local padLeft = metadata.bounds.left - layerBounds.left
            local padRight = overallWidth - #row - padLeft
            padRow(newRow, padLeft)
            for xIndex, cell in util.stringPairs(row) do
                -- The x, y, z variables are relative to 1,1,1 of `layers`, while this new layers-index
                -- variable is instead relative to 1,1,1 of `newLayers` (i.e. the layers that have extra padding).
                local layersIndex = {
                    xIndex = padLeft + xIndex,
                    yIndex = padTop + yIndex,
                    zIndex = zIndex,
                }
                table.insert(newRow, normalizeCell(cell, layersIndex))
            end
            padRow(newRow, padRight)
            table.insert(newLayer, newRow)
        end
        padLayer(newLayer, {
            numOfNewRows = padBottom,
            sizeOfRows = overallWidth,
        })
        table.insert(newLayers, newLayer)
    end

    util.assert(buildStartCoord ~= nil, 'A buildStartCoord coord must be placed somewhere in the blueprint.')
    -- (As promised by the comments above this function definition, this is some documentation on each property)
    return {
        -- normalizedLayers contains the same information as the raw layers passed in, except
        -- instead of being strings, this contains tables with objects such as `{ type = 'block', id = ... }` or `{ type = 'empty' }`.
        -- The layers have also been padded with `{ type = 'empty' }` to align the contents of each layer.
        normalizedLayers = newLayers,
        -- Maps block IDs to the quantity of them found in the blueprint.
        requiredResources = requiredResources,
        -- A coordinate relative from 1,1,1 to the build start coordinate.
        buildStartCoord = buildStartCoord,
    }
end

-- The return coordinate is relative to the 1,1,1 of the entire blueprint
-- previousCoord can be nil
-- Returns `nil` when there's no more coordinates to visit.
local nextCoordToVisit = function (normalizedLayers, previousCoord)
    local isEven = function(n) return n % 2 == 0 end

    -- This behavior is done, because the first find will always be
    -- the coordinate we're currently at. We want to skip that and
    -- find the next one
    local skipFirstFind = true

    if previousCoord == nil then
        previousCoord = {
            x = 1,
            y = #normalizedLayers[1],
            z = #normalizedLayers,
        }
        -- When looking for the first block to place,
        -- there is no previous block we want to skip.
        skipFirstFind = false
    end

    for z = previousCoord.z, 1, -1 do
        local layer = normalizedLayers[z]
        local flipLayer = isEven(#normalizedLayers - z)
        if flipLayer then
            layer = util.reverseTable(layer)
        end

        local startY = 1
        if z == previousCoord.z then
            startY = previousCoord.y
            if flipLayer then
                startY = #layer + 1 - startY
            end
        end

        for y = startY, #normalizedLayers[1] do
            local row = layer[y]
            local flipRow = isEven(#row - y)
            if flipRow then
                row = util.reverseTable(row)
            end

            local startX = 1
            if z == previousCoord.z and y == startY then
                startX = previousCoord.x
                if flipRow then
                    startX = #row + 1 - startX
                end
            end

            for x = startX, #normalizedLayers[1][1] do
                local cell = row[x]
                if cell.type == 'block' then
                    if skipFirstFind then
                        skipFirstFind = false
                    else
                        -- Unflip the coordinate
                        if flipRow then x = #row + 1 - x end
                        if flipLayer then y = #layer + 1 - y end
                        -- Ensure we did it all right
                        assert(normalizedLayers[z][y][x] == cell)
                        return { x = x, y = y, z = z }
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
    local normalizeMapResult = normalizeMap(opts)
    local normalizedLayers = normalizeMapResult.normalizedLayers
    local requiredResources = normalizeMapResult.requiredResources
    local buildStartRelCoord = normalizeMapResult.buildStartCoord

    return {
        requiredResources = util.mapMapTable(requiredResources, function(quantity)
            return { quantity=quantity, at='INVENTORY' }
        end),
        createTaskState = function(buildStartCmps)
            local absOriginPos = buildStartCmps.compassAt({
                forward = buildStartRelCoord.y,
                right = -buildStartRelCoord.x,
                up = buildStartRelCoord.z,
            }).pos

            local nextRelCoord = nextCoordToVisit(normalizedLayers)
            util.assert(nextRelCoord ~= nil, 'Attempted to use an empty blueprint')
            return {
                -- `origin` is the absolute position of the 1,1,1 position of the blueprint.
                absOriginPos = absOriginPos,
                buildStartPos = buildStartCmps.pos,
                nextRelCoord = nextRelCoord,
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
            local relTargetCoord = taskState.nextRelCoord

            local targetCmps = originCmps.compassAt({
                forward = -relTargetCoord.y,
                right = relTargetCoord.x,
                up = -relTargetCoord.z,
            })
            local targetItem = normalizedLayers[relTargetCoord.z][relTargetCoord.y][relTargetCoord.x].id
            util.assert(targetItem)

            navigate.moveToCoord(targetCmps.coordAt({ up = 1 }), {'up', 'right', 'forward'})
            highLevelCommands.placeItemDown(targetItem)

            nextTaskState.nextRelCoord = nextCoordToVisit(normalizedLayers, taskState.nextRelCoord)
            util.mergeTablesInPlace(taskState, nextTaskState)
            return nextTaskState.nextRelCoord == nil
        end,
    }
end

return module
