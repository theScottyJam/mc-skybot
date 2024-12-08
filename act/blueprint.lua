-- The coordinates used internally within this module are
-- often not the standard { forward=..., right=..., up=... } coordinates.
-- Instead they're { x=..., y=..., z=... } coordinates that are often relative to the
-- tables they index (which could mean different
-- things depending on which table they're intended to index).
-- The origin point is { x=1, y=1, z=1 } (not zeros), as that is the first index in the tables.
--
-- Also, the coordinates used assume that `z` is up and down, which is different from Minecraft.

local util = import('util.lua')
local space = import('./space.lua')
local navigate = import('./navigate.lua')
local highLevelCommands = import('./highLevelCommands.lua')

local module = {}

-- Returns metadata about the layers.
-- Overall, it includes information about where the reference points
-- are, and how large of a region this blueprint will take up.
-- Specific details about the return value are documented inside.
function getBearings(opts)
    local layers = opts.layers

    -- What gets eventually returned.
    local metadata = {
        -- Contains a list of { primaryReferencePoint = {x=x, y=y} } tables
        -- These are relative to index 1, 1 of the (unnormalized) layer (not 0, 0 - these coordinates act like layer indices).
        layers = {},
        -- List of points relative to the primary reference point
        secondaryReferencePoints = {},
        -- `left = 2` means, starting from the primary reference point, you
        -- can take two steps left and still be in bounds.
        bounds = { left = 0, forward = 0, right = 0, backward = 0 }
    }

    -- Used like secondaryReferencePointMap[y][x] = { count = ..., firstLayerFoundOn = ... }
    -- Some of this information is used for the returned metadata object, and some is simply used for assertions.
    local secondaryReferencePointsMap = {}

    for z, layer in pairs(layers) do
        local primaryReferencePoint = nil
        local secondaryReferencePoints = {}
        local rowLen = nil
        for y, row in pairs(layer) do
            if rowLen == nil then
                rowLen = #row
            else
                util.assert(rowLen == #row)
            end

            for x, cell in util.stringPairs(row) do
                if cell == ',' then
                    util.assert(primaryReferencePoint == nil, 'Duplicate primary reference point (,) found in layer '..z)
                    primaryReferencePoint = { x = x, y = y }
                elseif cell == '.' then
                    table.insert(secondaryReferencePoints, { x = x, y = y })
                end
            end
        end
        util.assert(rowLen ~= nil, 'The rows must have some length to them')
        util.assert(primaryReferencePoint ~= nil, 'No primary reference point (,) found in layer '..z)
        table.insert(metadata.layers, { primaryReferencePoint = primaryReferencePoint })

        metadata.bounds.left = util.maxNumber(metadata.bounds.left, primaryReferencePoint.x - 1)
        metadata.bounds.forward = util.maxNumber(metadata.bounds.forward, primaryReferencePoint.y - 1)
        metadata.bounds.right = util.maxNumber(metadata.bounds.right, rowLen - primaryReferencePoint.x)
        metadata.bounds.backward = util.maxNumber(metadata.bounds.backward, #layer - primaryReferencePoint.y)

        for i, refPoint in pairs(secondaryReferencePoints) do
            local relX = refPoint.x - primaryReferencePoint.x
            local relY = refPoint.y - primaryReferencePoint.y
            if secondaryReferencePointsMap[relY] == nil then
                secondaryReferencePointsMap[relY] = {}
            end
            if secondaryReferencePointsMap[relY][relX] == nil then
                secondaryReferencePointsMap[relY][relX] = { count = 0, firstLayerFoundOn = z }
            end
            secondaryReferencePointsMap[relY][relX].count = secondaryReferencePointsMap[relY][relX].count + 1
        end
    end

    for y, row in pairs(secondaryReferencePointsMap) do
        for x, info in pairs(row) do
            util.assert(info.count > 1,'Found a lone secondary reference point (.) on layer '..info.firstLayerFoundOn)
            table.insert(metadata.secondaryReferencePoints, { x = x, y = y })
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
    local normalizeCell = function(cell, coord)
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
                x = coord.x + (delta.right or 0),
                y = coord.y - (delta.forward or 0),
                z = coord.z - (delta.up or 0),
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

    local verifySecondaryReferencePoints = function(layer, z)
        for i, refPoint in ipairs(metadata.secondaryReferencePoints) do
            -- Get coordinates relative to the layer's original 1, 1
            local x = metadata.layers[z].primaryReferencePoint.x + refPoint.x
            local y = metadata.layers[z].primaryReferencePoint.y + refPoint.y
            if x >= 1 and y >= 1 and x <= #layer[1] and y <= #layer then
                local char = string.sub(layer[y], x, x)
                util.assert(char == '.', 'Expected layer '..z..' to have a reference point at row='..y..' col='..x..'.')
            end
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
    for z, layer in ipairs(layers) do
        verifySecondaryReferencePoints(layer, z)
        local newLayer = {}
        local padTop = metadata.bounds.forward + 1 - metadata.layers[z].primaryReferencePoint.y
        padLayer(newLayer, {
            numOfNewRows = padTop,
            sizeOfRows = overallWidth,
        })
        for y, row in ipairs(layer) do
            local newRow = {}
            local padLeft = metadata.bounds.left + 1 - metadata.layers[z].primaryReferencePoint.x
            padRow(newRow, padLeft)
            for x, cell in util.stringPairs(row) do
                -- The x, y, z variables are relative to 1,1,1 of `layers`, while this new coord
                -- variable is instead relative to 1,1,1 of `newLayers` (i.e. the layers that have extra padding).
                local coord = {
                    x = padLeft + x,
                    y = padTop + y,
                    z = z,
                }
                table.insert(newRow, normalizeCell(cell, coord))
            end
            padRow(newRow, overallWidth - #row - padLeft)
            table.insert(newLayer, newRow)
        end
        padLayer(newLayer, {
            numOfNewRows = overallHeight - #layer - padTop,
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
            return { quantity=quantity, at='INVENTORY', consumed=false }
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
        enter = function(commands, state, taskState)
            navigate.assertPos(state, taskState.buildStartPos)
        end,
        exit = function(commands, state, taskState, info)
            navigate.moveToPos(commands, state, taskState.buildStartPos, {'forward', 'right', 'up'})
        end,
        nextPlan = function(commands, state, taskState)
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

            navigate.moveToCoord(commands, state, targetCmps.coordAt({ up = 1 }), {'up', 'right', 'forward'})
            highLevelCommands.placeItemDown(commands, state, targetItem)

            nextTaskState.nextRelCoord = nextCoordToVisit(normalizedLayers, taskState.nextRelCoord)
            return nextTaskState, nextTaskState.nextRelCoord == nil
        end,
    }
end

return module
