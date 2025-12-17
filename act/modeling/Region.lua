--[[
Contains various functions to inspect 3d ASCII maps.

Behavior of special characters in the ASCII map:
    The "," is a "primary reference point". It can be thought of as the origin point for each layer.
        Because the sizes of the layers provided may differ from layer to layer, it's important to have
        an origin point in each layer so we know what everything is relative to.
        The exception is when there's only one layer in a region, in which case you're not required to supply a primary reference point.
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

--<-- This function is getting large, can I break it up?
-- Returns metadata about the layers.
-- Overall, it includes information about where the reference points and markers
-- are, and how large of a region this blueprint will take up.
-- Specific details about the return value are documented inside.
local getBearings = function(layeredAsciiMap, markers)
    -- What gets eventually returned.
    local metadata = {
        -- Contains a list of { plane = <plane> } tables
        layers = {},
        -- `left = 2` means, starting from the primary reference point, you
        -- can take two steps left and still be in bounds.
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
                    util.assert(markerIdToIndices[markerId] == nil, 'Marker "'..markerConf.char..'" was found multiple times') --<-- Test

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
            --<-- - Or do I want this to be 1,1?
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

        table.insert(metadata.layers, {
            width = width,
            depth = depth,
            primaryRefPointIndices = primaryRefPointIndices,
            primaryRefBorderDistances = primaryRefBorderDistances,
        })

        --<-- - Are all of these used?
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
                util.charAt(asciiMap[backward], right) == nil or
                util.charAt(asciiMap[backward], right) == '.',
                'Expected layer '..downIndex..' to have a secondary reference point at backwardIndex='..backward..' rightIndex='..right..'.'
            )
        end
    end

    return metadata
end

function prototype:getBackwardBottomLeftCmps()
    return self._backwardBottomLeftCmps
end

function prototype:getForwardBottomRightCmps()
    return self._backwardBottomLeftCmps.compassAt({
        forward = self.bounds.depth - 1,
        right = self.bounds.width - 1,
    })
end

function prototype:getCmpsAtMarker(markerId)
    local cmps = self._metadata.markerIdToCmps[markerId]
    util.assert(cmps ~= nil, 'The marker '..markerId..' does not exist.')
    -- Recalculate the cmps against whatever is currently set as the backward-left
    return self._backwardBottomLeftCmps.compassAt({
        forward = cmps.coord.forward,
        right = cmps.coord.right,
        up = cmps.coord.up,
    })
end

--<-- This function doesn't make much sense for regions - each layer can be a different size, but this function will allow any coord-to-index conversion as long as it is in bounds.
-- The forward/right indices are relative to an individual layer, so if the layer is only 2X2 in size, only 4 possible region
-- indices are available for that layer, even if the region itself is much wider.
-- May return nil if it is out of range
function prototype:regionIndexFromCoord(coord)
    local deltaCoord = self._backwardBottomLeftCmps.distanceTo(coord)
    -- This is what the region index would be if all layers were the same size
    local regionIndex_ = {
        x = deltaCoord.right + 1,
        y = self.bounds.depth - deltaCoord.forward,
        z = self.bounds.height - deltaCoord.up,
    }

    local inBounds = (
        regionIndex_.x >= 1 and
        regionIndex_.x <= self.bounds.width and
        regionIndex_.y >= 1 and
        regionIndex_.y <= self.bounds.depth and
        regionIndex_.z >= 1 and
        regionIndex_.z <= self.bounds.height
    )

    if not inBounds then
        return nil
    end

    -- Adjusting the x and y index to account for the fact that this layer might be smaller.
    --<-- This same pad math is done elsewhere
    local layerPrimaryRefBorderDistances = self._metadata.layers[regionIndex_.z].primaryRefBorderDistances
    local padBackward = self._metadata.primaryRefBorderDistances.backward - layerPrimaryRefBorderDistances.backward
    local padForward = self.bounds.depth - self._metadata.layers[regionIndex_.z].depth - padBackward
    local padLeft = self._metadata.primaryRefBorderDistances.left - layerPrimaryRefBorderDistances.left
    return {
        x = regionIndex_.x - padLeft,
        y = regionIndex_.y - padForward,
        z = regionIndex_.z,
    }
end

--<-- Not sure if this needs to be public
function prototype:coordFromRegionIndex(regionIndex)
    --<-- This same pad math is done elsewhere
    local layerPrimaryRefBorderDistances = self._metadata.layers[regionIndex.z].primaryRefBorderDistances
    local padBackward = self._metadata.primaryRefBorderDistances.backward - layerPrimaryRefBorderDistances.backward
    local padForward = self.bounds.depth - self._metadata.layers[regionIndex.z].depth - padBackward
    local padLeft = self._metadata.primaryRefBorderDistances.left - layerPrimaryRefBorderDistances.left

    -- This is what the region index would be if all layers were the same size
    local regionIndex_ = {
        x = padLeft + regionIndex.x,
        y = padForward + regionIndex.y,
        z = regionIndex.z,
    }

    return self._backwardBottomLeftCmps.coordAt({
        forward = self.bounds.depth - regionIndex_.y,
        right = regionIndex_.x - 1,
        up = self.bounds.height - regionIndex_.z,
    })
end

-- Attempts to get the character at the coordinate, or returns nil if it is out of bounds.
-- The second return value is the plane-index used for the lookup. Mostly useful for building error messages.
function prototype:tryGetCharAt(coord)
    local regionIndex = self:regionIndexFromCoord(coord)
    if regionIndex == nil then
        return nil
    end

    local row = self._layeredAsciiMap[regionIndex.z][regionIndex.y]
    if row == nil then return ' ' end -- Pretending the smaller plane is filled with ' '.
    local char = util.charAt(row, regionIndex.x)
    if char == nil then return ' ' end -- Pretending the smaller plane is filled with ' '.
    return char
end

function prototype:getCharAt(coord)
    local char = self:tryGetCharAt(coord)
    assert(char ~= nil, 'Attempted to get an out-of-bounds character in the region')
    return char
end

--<-- Plane.lua could benefit from something like this as well - I believe there's code that's manually looping over its bounds.
-- Iterates over every cell in the region (ignoring empty space and markers)
function prototype:forEachFilledCell(fn)
    for downIndex, layer in ipairs(self._layeredAsciiMap) do
        for backwardIndex, row in ipairs(layer) do
            for rightIndex, cell in util.stringPairs(row) do
                if cell ~= ' ' and cell ~= ',' and cell ~= '.' and not util.tableContains(self._markerChars, cell) then
                    fn(cell, self:coordFromRegionIndex({ x = rightIndex, y = backwardIndex, z = downIndex }))
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
                forward = coord.forward - self._metadata.markerIdToCmps[markerId].coord.forward,
                right = coord.right - self._metadata.markerIdToCmps[markerId].coord.right,
                up = coord.up - self._metadata.markerIdToCmps[markerId].coord.up,
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
        _metadata = metadata, --<-- Needed?
        _layeredAsciiMap = layeredAsciiMap, --<-- Needed?
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
    local width = self._metadata.primaryRefBorderDistances.left + 1 + self._metadata.primaryRefBorderDistances.right
    local depth = self._metadata.primaryRefBorderDistances.forward + 1 + self._metadata.primaryRefBorderDistances.backward
    local height = #self._layeredAsciiMap
    self.bounds = {
        width = width,
        depth = depth,
        height = height,
        -- All inclusive
        left = self._backwardBottomLeftCmps.coord.right,
        backward = self._backwardBottomLeftCmps.coord.forward,
        down = self._backwardBottomLeftCmps.coord.up,
        right = self._backwardBottomLeftCmps.coord.right + width - 1,
        forward = self._backwardBottomLeftCmps.coord.forward + depth - 1,
        up = self._backwardBottomLeftCmps.coord.up + height - 1,
    }
    return self
end

return static