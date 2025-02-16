--[[
Contains various functions to inspect 3d ASCII maps.

Behavior of special characters in the ASCII map:
    The "," is a "primary reference point". It can be thought of as the origin point for each layer.
        Because the sizes of the layers provided may differ from layer to layer, it's important to have
        an origin point in each layer so we know what everything is relative to.
    The "." is a "secondary reference point". You can place these anywhere you want on a particular layer,
        but wherever you place them, you'll be required to place a "." in the exact same location on every other
        layer (unless this particular layer definition is smaller than others, and the "." would fall outside of the definition area).
        Its purpose is to just provide further reference points to help you eyeball things and make sure
        everything is where it belongs.
]]

local Plane = import('./Plane.lua')
local space = import('../space.lua')
local util = import('util.lua')

local static = {}
local prototype = {}

-- Returns metadata about the layers.
-- Overall, it includes information about where the reference points
-- are, and how large of a region this blueprint will take up.
-- Specific details about the return value are documented inside.
local getBearings = function(layeredAsciiMap)
    -- What gets eventually returned.
    local metadata = {
        -- Contains a list of { plane = <plane> } tables
        layers = {},
        -- `left = 2` means, starting from the primary reference point, you
        -- can take two steps left and still be in bounds.
        primaryRefBorderDistances = { left = 0, forward = 0, right = 0, backward = 0 }
    }

    -- Used like secondaryReferencePointMap[forward][right] = { count = ..., firstLayerFoundOn = ... }
    -- where forward/right are relative to the primary reference point.
    -- Some of this information is used for the returned metadata object, and some is simply used for assertions.
    local secondaryReferencePointsMap = {}

    for zIndex, layer in pairs(layeredAsciiMap) do
        local plane = Plane.new({
            asciiMap = layer,
            markers = {
                primaryReferencePoint = { char = ',' },
            },
            markerSets = {
                secondaryReferencePoints = { char = '.' },
            },
        }):anchorMarker('primaryReferencePoint', { forward = 0, right = 0, up = 0 })

        local primaryRefBorderDistances = plane:borderDistancesAtMarker('primaryReferencePoint')
        local secondaryRefs = util.mapArrayTable(
            plane:cmpsListFromMarkerSet('secondaryReferencePoints'),
            function (cmps) return cmps.coord end
        )

        table.insert(metadata.layers, { plane = plane })

        metadata.primaryRefBorderDistances.left = util.maxNumber(metadata.primaryRefBorderDistances.left, primaryRefBorderDistances.left)
        metadata.primaryRefBorderDistances.forward = util.maxNumber(metadata.primaryRefBorderDistances.forward, primaryRefBorderDistances.forward)
        metadata.primaryRefBorderDistances.right = util.maxNumber(metadata.primaryRefBorderDistances.right, primaryRefBorderDistances.right)
        metadata.primaryRefBorderDistances.backward = util.maxNumber(metadata.primaryRefBorderDistances.backward, primaryRefBorderDistances.backward)

        for i, point in pairs(secondaryRefs) do
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

    -- List of forward/right points relative to the primary reference point
    local secondaryReferencePoints = {}
    for forward, row in pairs(secondaryReferencePointsMap) do
        for right, info in pairs(row) do
            util.assert(
                info.count > 1,
                'Found a secondary reference point (.) on layer ' .. info.firstLayerFoundOn
                .. ' that does not line up with any reference points on any other layer.'
            )
            table.insert(secondaryReferencePoints, { forward = forward, right = right })
        end
    end

    local verifySecondaryReferencePoints = function(zIndex)
        local plane = metadata.layers[zIndex].plane
        for i, refPoint in ipairs(secondaryReferencePoints) do
            local char, planeIndex = plane:tryGetCharAt({ forward = refPoint.forward, right = refPoint.right, up = plane.bounds.up })
            -- If a secondary reference point would be out-of-bounds, then it does not have to be supplied.
            -- An out-of-bounds reference point will cause both `char` and `planeIndex` to be nil.
            -- This `if` must be here (instead of, say, adding `planeIndex == nil` to the assertion), because when
            -- the assertion line runs, the error message will always be evaluated, even if there isn't an error,
            -- and it will try to concatenate values from planeIndex, but that might be nil.
            if planeIndex ~= nil then
                util.assert(
                    char == '.',
                    'Expected layer '..zIndex..' to have a secondary reference point at xIndex='..planeIndex.x..' yIndex='..planeIndex.y..'.'
                )
            end
        end
    end

    for zIndex, asciiMap in ipairs(layeredAsciiMap) do
        verifySecondaryReferencePoints(zIndex)
    end

    return metadata
end

--<-- This function doesn't make much sense for regions - each layer can be a different size, but this function will allow any coord-to-index conversion as long as it is in bounds.
-- The forward/right indicis are relative to an individual layer, so if the layer is only 2X2 in size, only 4 possible region
-- indicis are available for that layer, even if the region itself is much wider.
-- May return nil if it is out of range
function prototype:regionIndexFromCoord(coord)
    local deltaCoord = self._backwardLeftBottomCmps.distanceTo(coord)
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
    local layerPrimaryRefBorderDistances = self._metadata.layers[regionIndex_.z].plane:borderDistancesAtMarker('primaryReferencePoint')
    local padBackward = self._metadata.primaryRefBorderDistances.backward - layerPrimaryRefBorderDistances.backward
    local padForward = self.bounds.depth - self._metadata.layers[regionIndex_.z].plane.depth - padBackward
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
    local layerPrimaryRefBorderDistances = self._metadata.layers[regionIndex.z].plane:borderDistancesAtMarker('primaryReferencePoint')
    local padBackward = self._metadata.primaryRefBorderDistances.backward - layerPrimaryRefBorderDistances.backward
    local padForward = self.bounds.depth - self._metadata.layers[regionIndex.z].plane.depth - padBackward
    local padLeft = self._metadata.primaryRefBorderDistances.left - layerPrimaryRefBorderDistances.left

    -- This is what the region index would be if all layers were the same size
    local regionIndex_ = {
        x = padLeft + regionIndex.x,
        y = padForward + regionIndex.y,
        z = regionIndex.z,
    }

    return self._backwardLeftBottomCmps.coordAt({
        forward = self.bounds.depth - regionIndex_.y,
        right = regionIndex_.x - 1,
        up = self.bounds.height - regionIndex_.z,
    })
end

--<-- Not sure how much I like these returning two values, I might try stopping that. Callers can use [region/plane]IndexFromCoord() instead.
--<-- The regionIndex return value makes more sense on getCharAt() instead of tryGetCharAt(), because this it won't be nil
--<-- Play with secondary-reference-point errors to see how the second return value gets used.
--<-- Third return value informs us if it was technically part of an undefined territory (i.e. the space that gets padded after a plane ends). Keep?
-- Attempts to get the character at the coordinate, or returns nil if it is out of bounds.
-- The second return value is the plane-index used for the lookup. Mostly useful for building error messages.
function prototype:tryGetCharAt(coord)
    local regionIndex = self:regionIndexFromCoord(coord)
    if regionIndex == nil then
        return nil, regionIndex, nil
    end

    local row = self._layeredAsciiMap[regionIndex.z][regionIndex.y]
    if row == nil then return ' ', regionIndex, true end -- Pretending the smaller plan is filled with ' '.
    local char = util.charAt(row, regionIndex.x)
    if char == nil then return ' ', regionIndex, true end -- Pretending the smaller plan is filled with ' '.
    return char, planeIndex, false
end

--<-- The third return value is now unused I believe. I'm not sure I even want it returning two things.
function prototype:getCharAt(coord)
    local char, regionIndex, wasUndefined = self:tryGetCharAt(coord)
    assert(char ~= nil, 'Attempted to get an out-of-bounds character in the region')
    return char, regionIndex, wasUndefined
end

--<-- Iterates over every cell in the region (ignoring empty space)
--<-- Plane.lua could benefit from something like this as well - I believe there's code that's manually looping over its bounds.
function prototype:forEachFilledCell(fn)
    for zIndex, layer in ipairs(self._layeredAsciiMap) do
        for yIndex, row in ipairs(layer) do
            for xIndex, cell in util.stringPairs(row) do
                if cell ~= ' ' then
                    fn(cell, self:coordFromRegionIndex({ x = xIndex, y = yIndex, z = zIndex }))
                end
            end
        end
    end
end

--[[
Inputs:
    layeredAsciiMap: A list of lists of strings representing a 3d map of tiles and markers.
    markers?: This is used to mark interesting areas in the ascii map.
        A mapping is expected which maps marker names to info tables with the shape of:
            { char = <char>, targetOffset ?= <x/y coord> }
]]
function static.new(opts)
    --<-- Document: "." and "," are reserved markers
    local layeredAsciiMap = opts.layeredAsciiMap
    -- local markers = opts.markers --<-- Not yet implemented

    local metadata = getBearings(layeredAsciiMap)

    -- The backward-left-bottom corner is, by default, set to (0,0,0). To change it, call an anchor function. --<-- TODO: No such anchor functions exist yet
    local backwardLeftBottomCmps = space.createCompass({
        forward = 0,
        right = 0,
        up = 0,
        face = 'forward',
    })

    return util.attachPrototype(prototype, {
        _metadata = metadata, --<-- Needed?
        _layeredAsciiMap = layeredAsciiMap, --<-- Needed?
        _backwardLeftBottomCmps = backwardLeftBottomCmps,
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
        left = self._backwardLeftBottomCmps.coord.right,
        backward = self._backwardLeftBottomCmps.coord.forward,
        down = self._backwardLeftBottomCmps.coord.up,
        right = self._backwardLeftBottomCmps.coord.right + width - 1,
        forward = self._backwardLeftBottomCmps.coord.forward + depth - 1,
        up = self._backwardLeftBottomCmps.coord.up + height - 1,
    }
    return self
end

return static