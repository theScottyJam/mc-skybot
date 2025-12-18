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

local space = import('../space.lua')
local util = import('util.lua')

local static = {}
local prototype = {}

-- Returns metadata about the layers.
-- Overall, it includes information about where the reference points and markers
-- are, and how large of a sketch this is.
-- Specific details about the return value are documented inside.
local getBearings = function(layeredAsciiMap, markers)
    -- What gets eventually returned.
    local metadata = {
        -- Contains a list of layers. Each layer table contains the following:
        -- * width
        -- * depth
        -- * primaryRefPointIndices: { backward = ..., right = ... }
        -- * primaryRefBorderDistances: The distances to the borders of this layer.
        layers = {},
        -- `left = 2` means, starting from the primary reference point, you
        -- can take two steps left and still be in at least one layer's forward/right bounds (the layers' vertical
        -- position is ignored for this)
        primaryRefBorderDistances = { left = 0, forward = 0, right = 0, backward = 0 },
        markerIdToCmps = {},
    }

    -- Used like secondaryReferencePointMap[backward][right] = { count = ..., firstLayerFoundOn = ... }
    -- where backward/right are relative to the primary reference point.
    -- Some of this information is used for the returned metadata object, and some is simply used for assertions.
    -- Using the "backward" direction instead of "forward" as it works more naturally when doing math with indices.
    local secondaryReferencePointsMap = {}

    local charToMarkerId = {}
    for markerId, markerConf in util.sortedMapTablePairs(markers or {}) do
        charToMarkerId[markerConf.char] = markerId
    end

    ---- Examine each character ----

    local markerIdToIndices = {}
    for downIndex, asciiMap in pairs(layeredAsciiMap) do
        local width = #asciiMap[1]
        local depth = #asciiMap
        util.assert(width > 0)
        util.assert(depth > 0)

        local primaryRefPointIndices = nil
        local secondaryRefIndicesList = {}
        for backwardIndex, row in ipairs(asciiMap) do
            util.assert(#row == width, 'All rows must be of the same length')
            for rightIndex, cell in util.stringPairs(row) do
                if cell == ',' then
                    util.assert(primaryRefPointIndices == nil, 'The primary reference point marker (,) was found multiple times on a layer')
                    primaryRefPointIndices = {
                        backward = backwardIndex,
                        right = rightIndex,
                    }
                elseif cell == '.' then
                    table.insert(secondaryRefIndicesList, {
                        backward = backwardIndex,
                        right = rightIndex
                    })
                elseif charToMarkerId[cell] ~= nil then
                    local markerId = charToMarkerId[cell]
                    local markerConf = markers[markerId]
                    util.assert(markerIdToIndices[markerId] == nil, 'Marker "'..markerConf.char..'" was found multiple times')

                    markerIdToIndices[markerId] = {
                        backward = backwardIndex,
                        right = rightIndex,
                        down = downIndex,
                    }
                end
            end
        end

        if primaryRefPointIndices == nil then
            util.assert(#layeredAsciiMap == 1, 'Missing a primary reference point (,) on a layer')
            primaryRefPointIndices = {
                backward = depth,
                right = 1,
            }
        end

        -- A table containing left/forward/right/backward fields, saying how many steps
        -- you have to move to reach (and not cross) a boundary.
        -- For example, A 1x1 grid containing just the primary reference point would have all values set to 0.
        local primaryRefBorderDistances
        primaryRefBorderDistances = {
            forward = primaryRefPointIndices.backward - 1,
            right = width - primaryRefPointIndices.right,
            backward = depth - primaryRefPointIndices.backward,
            left = primaryRefPointIndices.right - 1,
        }

        -- The contents of a layer is documented near the top of this function.
        table.insert(metadata.layers, {
            width = width,
            depth = depth,
            primaryRefPointIndices = primaryRefPointIndices,
            primaryRefBorderDistances = primaryRefBorderDistances,
        })

        metadata.primaryRefBorderDistances.left = util.maxNumber(metadata.primaryRefBorderDistances.left, primaryRefBorderDistances.left)
        metadata.primaryRefBorderDistances.forward = util.maxNumber(metadata.primaryRefBorderDistances.forward, primaryRefBorderDistances.forward)
        metadata.primaryRefBorderDistances.right = util.maxNumber(metadata.primaryRefBorderDistances.right, primaryRefBorderDistances.right)
        metadata.primaryRefBorderDistances.backward = util.maxNumber(metadata.primaryRefBorderDistances.backward, primaryRefBorderDistances.backward)

        for i, secondaryRefIndices in pairs(secondaryRefIndicesList) do
            local refMap = secondaryReferencePointsMap
            local backward = secondaryRefIndices.backward - primaryRefPointIndices.backward
            local right = secondaryRefIndices.right - primaryRefPointIndices.right
            if refMap[backward] == nil then
                refMap[backward] = {}
            end
            if refMap[backward][right] == nil then
                refMap[backward][right] = { count = 0, firstLayerFoundOn = downIndex }
            end
            refMap[backward][right].count = refMap[backward][right].count + 1
        end
    end

    ---- Tidy up gathered data and run assertions ----

    for markerId, indices in util.sortedMapTablePairs(markerIdToIndices) do
        local targetOffset = markers[markerId].targetOffset or {}

        local layer = metadata.layers[indices.down]
        metadata.markerIdToCmps[markerId] = space.createCompass({
            forward = layer.primaryRefPointIndices.backward - indices.backward + metadata.primaryRefBorderDistances.backward + (targetOffset.forward or 0),
            right = -layer.primaryRefPointIndices.right + indices.right + metadata.primaryRefBorderDistances.left + (targetOffset.right or 0),
            up = (targetOffset.up or 0) + indices.down - 1,
            face = 'forward',
        })
    end

    for markerId, markerConf in util.sortedMapTablePairs(markers) do
        util.assert(metadata.markerIdToCmps[markerId] ~= nil, 'Marker "'..markerConf.char..'" was not found')
    end

    -- List of backward/right points relative to the primary reference point
    local secondaryReferencePoints = {}
    for backward, row in pairs(secondaryReferencePointsMap) do
        for right, info in pairs(row) do
            util.assert(
                info.count > 1,
                'Found a secondary reference point (.) on layer ' .. info.firstLayerFoundOn
                .. ' that does not line up with any reference points on any other layer.'
            )
            table.insert(secondaryReferencePoints, { backward = backward, right = right })
        end
    end

    -- Verify secondary reference points are on each layer
    -- Alternatively, they can be omitted from a layer if they would be out of its bounds.
    for downIndex, asciiMap in ipairs(layeredAsciiMap) do
        local layer = metadata.layers[downIndex]
        for i, refPoint in ipairs(secondaryReferencePoints) do
            local backward = layer.primaryRefPointIndices.backward + refPoint.backward
            local right = layer.primaryRefPointIndices.right + refPoint.right

            -- If a secondary reference point would be out-of-bounds, then it does not have to be supplied.
            util.assert(
                asciiMap[backward] == nil or
                util.strictCharAt(asciiMap[backward], right) == nil or
                util.strictCharAt(asciiMap[backward], right) == '.',
                'Expected layer '..downIndex..' to have a secondary reference point at backwardIndex='..backward..' rightIndex='..right..'.'
            )
        end
    end

    return metadata
end

function prototype:getCmpsAtMarker(markerId)
    local cmps = self._markerIdToCmps[markerId]
    util.assert(cmps ~= nil, 'The marker '..markerId..' does not exist.')
    -- Recalculate the cmps against whatever is currently set as the backward-left
    return self._backwardBottomLeftCmps.compassAt({
        forward = cmps.coord.forward,
        right = cmps.coord.right,
        up = cmps.coord.up,
    })
end

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
function prototype:_sketchIndexFromCoord(coord)
    if not space.__isCoordInBoundingBox(coord, self.bounds) then
        return 'outside-sketch-bounds'
    end

    local deltaCoord = self._backwardBottomLeftCmps.distanceTo(coord)
    local downIndex = self.bounds.height - deltaCoord.up

    -- Adjusting the backward and right index to account for the fact that this layer might be smaller.
    local layer = self._layers[downIndex]
    local pad = self:_paddingRequiredToMakeLayerFillSketchBounds(layer)
    local sketchIndex = {
        right = deltaCoord.right + 1 - pad.padLeft,
        backward = self.bounds.depth - deltaCoord.forward - pad.padForward,
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
    local sketchIndex_ = {
        right = pad.padLeft + sketchIndex.right,
        backward = pad.padForward + sketchIndex.backward,
        down = sketchIndex.down,
    }

    return self._backwardBottomLeftCmps.coordAt({
        forward = self.bounds.depth - sketchIndex_.backward,
        right = sketchIndex_.right - 1,
        up = self.bounds.height - sketchIndex_.down,
    })
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
                    local sketchIndex = { right = rightIndex, backward = backwardIndex, down = downIndex }
                    fn(cell, self:_coordFromSketchIndex(sketchIndex))
                end
            end
        end
    end
end

function prototype:anchorMarker(markerId, coord)
    return util.attachPrototype(prototype, util.mergeTables(
        self,
        {
            _backwardBottomLeftCmps = space.createCompass({
                forward = coord.forward - self._markerIdToCmps[markerId].coord.forward,
                right = coord.right - self._markerIdToCmps[markerId].coord.right,
                up = coord.up - self._markerIdToCmps[markerId].coord.up,
                face = 'forward',
            }),
        }
    )):_init()
end

function prototype:anchorBackwardBottomLeft(coord)
    return util.attachPrototype(prototype, util.mergeTables(
        self,
        {
            _backwardBottomLeftCmps = space.createCompass({
                forward = coord.forward,
                right = coord.right,
                up = coord.up,
                face = 'forward',
            }),
        }
    )):_init()
end

--[[
Inputs:
    layeredAsciiMap: A list of lists of strings representing a 3d map of tiles and markers.
    markers?: This is used to mark interesting areas in the ascii map.
        A mapping is expected which maps marker names to info tables with the shape of:
            { char = <char>, targetOffset ?= <rel coord> }
]]
function static.new(opts)
    local layeredAsciiMap = opts.layeredAsciiMap
    local markers = opts.markers or {}

    local metadata = getBearings(layeredAsciiMap, markers)

    -- The backward-bottom-left corner is, by default, set to (0,0,0). To change it, call an anchor function.
    local backwardBottomLeftCmps = space.createCompass({
        forward = 0,
        right = 0,
        up = 0,
        face = 'forward',
    })

    return util.attachPrototype(prototype, {
        _layers = metadata.layers,
        _primaryRefBorderDistances = metadata.primaryRefBorderDistances,
        _markerIdToCmps = metadata.markerIdToCmps,
        _layeredAsciiMap = layeredAsciiMap,
        _markerChars = util.mapArrayTable(
            util.sortedMapTablePairList(markers),
            function (entry)
                return entry[2].char
            end
        ),
        _backwardBottomLeftCmps = backwardBottomLeftCmps,
    }):_init()
end

function prototype:_init()
    local depth = self._primaryRefBorderDistances.forward + 1 + self._primaryRefBorderDistances.backward
    local width = self._primaryRefBorderDistances.left + 1 + self._primaryRefBorderDistances.right
    local height = #self._layeredAsciiMap

    self.bounds = space.__boundingBoxFromCoords(
        self._backwardBottomLeftCmps.coord,
        self._backwardBottomLeftCmps.compassAt({
            forward = depth - 1,
            right = width - 1,
            up = height - 1,
        }).coord
    )
    return self
end

return static