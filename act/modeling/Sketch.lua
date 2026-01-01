--[[
Contains various functions to inspect 3d ASCII maps.

Behavior of special characters in the ASCII map:
    The "," is a "primary reference point". It can be thought of as the origin point for each layer.
        Because the sizes of the layers provided may differ from layer to layer, it's important to have
        an origin point in each layer so we know what everything is relative to.
        The exception is when there's only one layer in a sketch, in which case you're not required to supply a primary reference point.
    The "." is a "secondary reference point". You can place these anywhere you want on a particular layer,
        but wherever you place them, you'll be required to place a "." in the exact same location on every other
        layer (unless this particular layer definition is smaller than others, and the "." would fall outside of the definition area).
        Its purpose is to just provide further reference points to help you eyeball things and make sure
        everything is where it belongs.
]]

local BoundingBox = import('../space/BoundingBox.lua')
local Coord = import('../space/Coord.lua')
local Bridge = import('../space/Bridge.lua')
local util = import('util.lua')

local static = {}
local prototype = {}

--------------------------------------------------------------------------------
-- Get Bearings Logic
--------------------------------------------------------------------------------

-- Lists all primary and secondary reference points, and all markers found in the provided ASCII map.
-- Returns:
-- {
--   primaryReferencePoints = <layerIndex>
--   secondaryReferencePoints = <layerIndex>
--   markers = { layerIndex = <layerIndex>, markerId = <markerId> }[]
-- }[]
local listInterestingSpots = function(layeredAsciiMap, markers)
    util.assert(#layeredAsciiMap > 0, 'At least one layer must be provided.')

    local charToMarkerId = {}
    for markerId, markerConf in util.sortedMapTablePairs(markers or {}) do
        charToMarkerId[markerConf.char] = markerId
    end

    local interestingSpotsPerLayer = {}
    for downIndex, asciiMap in pairs(layeredAsciiMap) do
        util.assert(#asciiMap > 0, 'At least one row must be provided in a layer.')
        local firstRowLength = #asciiMap[1]
        util.assert(firstRowLength > 0, 'At least one cell must be provided in a row.')

        local interestingSpotsInLayer = {
            primaryReferencePoints = {},
            secondaryReferencePoints = {},
            markers = {},
        }

        for backwardIndex, row in ipairs(asciiMap) do
            util.assert(#row == firstRowLength, 'All rows must be of the same length.')
            for rightIndex, cell in util.stringPairs(row) do
                local layerIndex = {
                    backward = backwardIndex,
                    right = rightIndex,
                }

                if cell == ',' then
                    table.insert(interestingSpotsInLayer.primaryReferencePoints, layerIndex)
                elseif cell == '.' then
                    table.insert(interestingSpotsInLayer.secondaryReferencePoints, layerIndex)
                elseif charToMarkerId[cell] ~= nil then
                    table.insert(interestingSpotsInLayer.markers, { layerIndex = layerIndex, markerId = charToMarkerId[cell] })
                end
            end
        end
        table.insert(interestingSpotsPerLayer, interestingSpotsInLayer)
    end

    return interestingSpotsPerLayer
end

-- Validates each primary reference point and lines them up.
-- Documentation for return type found at §AK7uH
local validatePrimaryReferencePoints = function(layeredAsciiMap, interestingSpotsPerLayer)
    local dimensionsOfLayers = {}

    for downIndex, interestingSpotsInLayer in ipairs(interestingSpotsPerLayer) do
        local width = #layeredAsciiMap[downIndex][1]
        local depth = #layeredAsciiMap[downIndex]

        local primaryRefPointLayerIndex = nil
        for _, layerIndex in ipairs(interestingSpotsInLayer.primaryReferencePoints) do
            util.assert(primaryRefPointLayerIndex == nil, 'The primary reference point marker (,) was found multiple times on a layer')
            primaryRefPointLayerIndex = layerIndex
        end

        if primaryRefPointLayerIndex == nil then
            -- You're allowed to omit the primary reference point if only one layer is provided.
            util.assert(#layeredAsciiMap == 1, 'Missing a primary reference point (,) on a layer')
            primaryRefPointLayerIndex = {
                backward = depth,
                right = 1,
            }
        end

        -- The contents of a layer is documented near the top of this function.
        table.insert(dimensionsOfLayers, {
            width = width,
            depth = depth,
            primaryRefPointLayerIndex = primaryRefPointLayerIndex,
            -- A table containing left/forward/right/backward fields, saying how many steps
            -- you have to move to reach (and not cross) a boundary.
            -- For example, A 1x1 grid containing just the primary reference point would have all values set to 0.
            primaryRefBorderDistances = {
                forward = primaryRefPointLayerIndex.backward - 1,
                right = width - primaryRefPointLayerIndex.right,
                backward = depth - primaryRefPointLayerIndex.backward,
                left = primaryRefPointLayerIndex.right - 1,
            },
        })
    end

    return dimensionsOfLayers
end

local validateSecondaryReferencePoints = function(layeredAsciiMap, dimensionsOfLayers, interestingSpotsPerLayer)
    -- Used like secondaryReferencePointMap[backward][right] = { count = ..., firstLayerFoundOn = ... }
    -- where backward/right are relative to the primary reference point.
    local refMap = {}

    for downIndex, interestingSpotsInLayer in ipairs(interestingSpotsPerLayer) do
        local layer = dimensionsOfLayers[downIndex]
        for i, secondaryRefSketchIndex in pairs(interestingSpotsInLayer.secondaryReferencePoints) do
            local backward = secondaryRefSketchIndex.backward - layer.primaryRefPointLayerIndex.backward
            local right = secondaryRefSketchIndex.right - layer.primaryRefPointLayerIndex.right
            if refMap[backward] == nil then
                refMap[backward] = {}
            end
            if refMap[backward][right] == nil then
                refMap[backward][right] = { count = 0, firstLayerFoundOn = downIndex }
            end
            refMap[backward][right].count = refMap[backward][right].count + 1
        end
    end

    -- List of backward/right points relative to the primary reference point
    local secondaryReferencePoints = {}

    for backward, row in util.sortedMapTablePairs(refMap) do
        for right, info in util.sortedMapTablePairs(row) do
            util.assert(
                info.count > 1,
                'Found a secondary reference point (.) on layer ' .. info.firstLayerFoundOn
                .. ' that does not line up with any reference points on any other layer.'
            )
            table.insert(secondaryReferencePoints, { backward = backward, right = right })
        end
    end

    -- Verify secondary reference points are on each layer
    for downIndex, asciiMap in ipairs(layeredAsciiMap) do
        local layer = dimensionsOfLayers[downIndex]
        for i, refPoint in ipairs(secondaryReferencePoints) do
            local backward = layer.primaryRefPointLayerIndex.backward + refPoint.backward
            local right = layer.primaryRefPointLayerIndex.right + refPoint.right

            -- If a secondary reference point would be out-of-bounds, then it does not have to be supplied.
            util.assert(
                asciiMap[backward] == nil or
                util.strictCharAt(asciiMap[backward], right) == nil or
                util.strictCharAt(asciiMap[backward], right) == '.',
                'Expected layer '..downIndex..' to have a secondary reference point at backwardIndex='..backward..' rightIndex='..right..'.'
            )
        end
    end
end

local findAndValidateMarkers = function(origin, dimensionsOfLayers, interestingSpotsPerLayer, primaryRefBorderDistances, markers)
    local markerIdToCoord = {}
    for downIndex, interestingSpotsInLayer in ipairs(interestingSpotsPerLayer) do
        local layer = dimensionsOfLayers[downIndex]

        for _, markerInfo in ipairs(interestingSpotsInLayer.markers) do
            local markerId = markerInfo.markerId
            local layerIndex = markerInfo.layerIndex
            local markerConf = markers[markerId]
            util.assert(markerIdToCoord[markerId] == nil, 'The marker "'..markerConf.char..'" was found multiple times.')

            local targetOffset = markers[markerId].targetOffset or {}
            markerIdToCoord[markerId] = origin:at({
                forward = layer.primaryRefPointLayerIndex.backward - layerIndex.backward + primaryRefBorderDistances.backward + (targetOffset.forward or 0),
                right = -layer.primaryRefPointLayerIndex.right + layerIndex.right + primaryRefBorderDistances.left + (targetOffset.right or 0),
                up = (targetOffset.up or 0) + downIndex - 1,
            })
        end
    end

    for markerId, markerConf in util.sortedMapTablePairs(markers) do
        util.assert(markerIdToCoord[markerId] ~= nil, 'The marker "'..markerConf.char..'" was not found.')
    end

    return markerIdToCoord
end

local calcPrimaryRefBorderDistances = function(dimensionsOfLayers)
    local primaryRefBorderDistances = { left = 0, forward = 0, right = 0, backward = 0 }
    for downIndex, layer in ipairs(dimensionsOfLayers) do
        primaryRefBorderDistances.left = util.maxNumber(primaryRefBorderDistances.left, layer.primaryRefBorderDistances.left)
        primaryRefBorderDistances.forward = util.maxNumber(primaryRefBorderDistances.forward, layer.primaryRefBorderDistances.forward)
        primaryRefBorderDistances.right = util.maxNumber(primaryRefBorderDistances.right, layer.primaryRefBorderDistances.right)
        primaryRefBorderDistances.backward = util.maxNumber(primaryRefBorderDistances.backward, layer.primaryRefBorderDistances.backward)
    end

    return primaryRefBorderDistances
end

-- Asserts the reference points lines up and returns metadata about the layers.
local getBearings = function(origin, layeredAsciiMap, markers)
    local interestingSpotsPerLayer = listInterestingSpots(layeredAsciiMap, markers)
    local dimensionsOfLayers = validatePrimaryReferencePoints(layeredAsciiMap, interestingSpotsPerLayer)
    local primaryRefBorderDistances = calcPrimaryRefBorderDistances(dimensionsOfLayers)
    validateSecondaryReferencePoints(layeredAsciiMap, dimensionsOfLayers, interestingSpotsPerLayer)

    return {
        -- A list of layer dimensions. Each "dimensions" table in the list contains:
        -- * width
        -- * depth
        -- * primaryRefPointLayerIndex: { backward = ..., right = ... }
        -- * primaryRefBorderDistances: The distances to the borders of this layer.
        -- (Logic that calculated this information found at §AK7uH)
        layers = dimensionsOfLayers,
        -- `left = 2` means, starting from the primary reference point, you
        -- can take two steps left and still be in at least one layer's forward/right bounds (the layers' vertical
        -- position is ignored for this)
        primaryRefBorderDistances = primaryRefBorderDistances,
        markerIdToCoord = findAndValidateMarkers(origin, dimensionsOfLayers, interestingSpotsPerLayer, primaryRefBorderDistances, markers),
    }
end

--------------------------------------------------------------------------------
-- Methods
--------------------------------------------------------------------------------

function prototype:_paddingRequiredToMakeLayerFillSketchBounds(layer)
    local padBackward = self._primaryRefBorderDistances.backward - layer.primaryRefBorderDistances.backward
    -- Only returning "left" and "forward" because that's all callers need.
    return {
        padLeft = self._primaryRefBorderDistances.left - layer.primaryRefBorderDistances.left,
        padForward = self.bounds.depth - layer.depth - padBackward,
    }
end

-- The returned sketchIndex is of the shape { backward = ..., right = ..., down = ... }
-- If inside the sketch bounds, but outside an individual layer, 'outside-layer-bounds' is returned.
-- This should be treated the same as the layer being larger but filled with whitespace.
-- If outside the bounds of the entire sketch, 'outside-sketch-bounds' is returned.
function prototype:_sketchIndexFromCoord(coord_)
    local coord = coord_:convertIn(self._bridge)
    if not self._bounds:contains(coord) then
        return 'outside-sketch-bounds'
    end

    local downIndex = self._bounds.height - coord.up

    -- Adjusting the backward and right index to account for the fact that this layer might be smaller.
    local layer = self._layers[downIndex]
    local pad = self:_paddingRequiredToMakeLayerFillSketchBounds(layer)
    local sketchIndex = {
        right = coord.right + 1 - pad.padLeft,
        backward = self._bounds.depth - coord.forward - pad.padForward,
        down = downIndex,
    }

    local inLayerBounds = (
        sketchIndex.right >= 1 and
        sketchIndex.right <= layer.width and
        sketchIndex.backward >= 1 and
        sketchIndex.backward <= layer.depth
    )

    if not inLayerBounds then
        return 'outside-layer-bounds'
    end

    return sketchIndex
end

-- sketchIndex is of the shape { backward = ..., right = ..., down = ... }
function prototype:_coordFromSketchIndex(sketchIndex)
    local layer = self._layers[sketchIndex.down]
    local pad = self:_paddingRequiredToMakeLayerFillSketchBounds(layer)

    -- This is what the sketch index would be if all layers were the same size
    local sketchIndex = {
        right = pad.padLeft + sketchIndex.right,
        backward = pad.padForward + sketchIndex.backward,
        down = sketchIndex.down,
    }

    return self._origin:at({
        forward = self.bounds.depth - sketchIndex.backward,
        right = sketchIndex.right - 1,
        up = self.bounds.height - sketchIndex.down,
    }):convertOut(self._bridge)
end

-- Attempts to get the character at the coordinate, or returns nil if it is out of bounds.
-- The second return value is the plane-index used for the lookup. Mostly useful for building error messages.
function prototype:tryGetCharAt(coord)
    local sketchIndex = self:_sketchIndexFromCoord(coord)
    if sketchIndex == 'outside-sketch-bounds' then
        return nil
    end
    if sketchIndex == 'outside-layer-bounds' then
        -- Acting as if the layer was larger (the size of the sketch), with the extra space filled with ' '.
        return ' '
    end

    local row = self._layeredAsciiMap[sketchIndex.down][sketchIndex.backward]
    util.assert(row ~= nil)
    local char = util.strictCharAt(row, sketchIndex.right)
    util.assert(char ~= nil)
    return char
end

function prototype:getCharAt(coord)
    local char = self:tryGetCharAt(coord)
    assert(char ~= nil, 'Attempted to get an out-of-bounds character in the sketch')
    return char
end

-- Iterates over every cell in the sketch (ignoring empty space and markers)
function prototype:forEachFilledCell(fn)
    for downIndex, layer in ipairs(self._layeredAsciiMap) do
        for backwardIndex, row in ipairs(layer) do
            for rightIndex, cell in util.stringPairs(row) do
                if cell ~= ' ' and cell ~= ',' and cell ~= '.' and not util.tableContains(self._markerChars, cell) then
                    fn(cell)
                    -- -- Ideally we'd provide a coordinate as well, but no one currently needs it,
                    -- -- so the behavior is currently untested (Some of the helper functions to generate the coordinate is also untested).
                    -- local sketchIndex = { right = rightIndex, backward = backwardIndex, down = downIndex }
                    -- fn(cell, self:_coordFromSketchIndex(sketchIndex))
                end
            end
        end
    end
end

-- `sketchFacing` is optional and can be used to rotate the sketch around the marker.
function prototype:anchorMarker(markerId, coord, sketchFacing)
    return util.attachPrototype(prototype, util.mergeTables(
        self,
        {
            _bridge = Bridge.new(coord, self._markerIdToCoord[markerId], sketchFacing),
        }
    )):_init()
end

-- `sketchFacing` is optional and can be used to rotate the sketch around the marker.
function prototype:anchorBackwardBottomLeft(coord, sketchFacing)
    return util.attachPrototype(prototype, util.mergeTables(
        self,
        {
            _bridge = Bridge.new(coord, self._origin, sketchFacing),
        }
    )):_init()
end

--[[
Inputs:
    layers: A list of lists of strings representing a 3d map of tiles and markers.
    markers?: This is used to mark interesting areas in the ascii map.
        A mapping is expected which maps marker names to info tables with the shape of:
            { char = <char>, targetOffset ?= <rel coord> }
]]
function static.new(opts)
    local layeredAsciiMap = opts.layers
    local markers = opts.markers or {}

    local origin = Coord.newCoordSystem('sketch').origin
    local metadata = getBearings(origin, layeredAsciiMap, markers)

    local depth = metadata.primaryRefBorderDistances.forward + 1 + metadata.primaryRefBorderDistances.backward
    local width = metadata.primaryRefBorderDistances.left + 1 + metadata.primaryRefBorderDistances.right
    local height = #layeredAsciiMap

    -- Private properties are relative to the internal "origin" property.
    -- Public properties are relative to the bridged "origin" - wherever this sketch has been anchored to.
    return util.attachPrototype(prototype, {
        _origin = origin,
        _layers = metadata.layers,
        _primaryRefBorderDistances = metadata.primaryRefBorderDistances,
        _markerIdToCoord = metadata.markerIdToCoord,
        _layeredAsciiMap = layeredAsciiMap,
        _markerChars = util.mapArrayTable(
            util.sortedMapTablePairList(markers),
            function (entry)
                return entry[2].char
            end
        ),
        _bounds = BoundingBox.new(
            origin,
            origin:at({ forward = depth - 1, right = width - 1, up = height - 1 })
        ),
        _bridge = Bridge.noop(origin),
    }):_init()
end

function prototype:_init()
    self.origin = self._bridge.outCoord:origin()
    self.bounds = self._bounds:convertOut(self._bridge)
    return self
end

return static