--[[
Contains various functions to inspect 2d ASCII maps.
]]

local util = import('util.lua')
local space = import('../space.lua')

local static = {}
local prototype = {}

function prototype:getBackwardLeftCmps()
    return self._backwardLeftCmps
end

function prototype:getForwardRightCmps()
    return self._backwardLeftCmps.compassAt({
        forward = self.bounds.depth - 1,
        right = self.bounds.width - 1,
    })
end

function prototype:hasMarker(markerId)
    return self._markerIdToCmps[markerId] ~= nil
end

function prototype:getCmpsAtMarker(markerId)
    local cmps = self._markerIdToCmps[markerId]
    util.assert(cmps ~= nil, 'The marker '..markerId..' does not exist.')
    -- Recalculate the cmps against whatever is currently set as the backward-left
    return self._backwardLeftCmps.compassAt({
        forward = cmps.coord.forward,
        right = cmps.coord.right,
        up = cmps.coord.up,
    })
end

function prototype:cmpsListFromMarkerSet(markerSetId)
    local cmpsList = self._markerSetIdToCmpsList[markerSetId]
    util.assert(cmpsList ~= nil)
    return util.mapArrayTable(cmpsList, function(cmps)
        -- Recalculate the cmps against whatever is currently set as the backward-left
        return self._backwardLeftCmps.compassAt({
            forward = cmps.coord.forward,
            right = cmps.coord.right,
            up = cmps.coord.up,
        })
    end)
end

-- Returns a table containing left/forward/right/backward fields, saying how many steps
-- you have to move to reach (and not cross) a boundary.
-- For example, A 1x1 grid containing the marker would have all values set to 0.
function prototype:borderDistancesAtMarker(markerId)
    local cmps = self._markerIdToCmps[markerId]
    util.assert(cmps ~= nil, 'The marker '..markerId..' does not exist.')
    local coord = cmps.coord

    return {
        forward = self.bounds.depth - coord.forward - 1,
        right = self.bounds.width - coord.right - 1,
        backward = coord.forward,
        left = coord.right,
    }
end

-- May return nil if it is out of range
function prototype:planeIndexFromCoord(coord)
    local deltaCoord = self._backwardLeftCmps.distanceTo(coord)
    local planeIndex = {
        x = deltaCoord.right + 1,
        y = self.bounds.depth - deltaCoord.forward
    }

    local inBounds = (
        planeIndex.x >= 1 and
        planeIndex.x <= self.bounds.width and
        planeIndex.y >= 1 and
        planeIndex.y <= self.bounds.depth and
        deltaCoord.up == 0
    )

    if not inBounds then
        return nil
    end
    return planeIndex
end

--<-- Continue to return the planeIndex, or have callers use the dedicated function to get it if they want it?
--<-- The planeIndex return value makes more sense on getCharAt() instead of tryGetCharAt(), because this it won't be nil
-- Attempts to get the character at the coordinate, or returns nil if it is out of bounds.
-- The second return value is the plane-index used for the lookup. Mostly useful for building error messages.
function prototype:tryGetCharAt(coord)
    local planeIndex = self:planeIndexFromCoord(coord)
    if planeIndex == nil then
        return nil, planeIndex
    end

    local row = self._asciiMap[planeIndex.y]
    local char = util.charAt(row, planeIndex.x)
    return char, planeIndex
end

--<-- Keep the double return?
function prototype:getCharAt(coord)
    local char, planeIndex = self:tryGetCharAt(coord)
    assert(char ~= nil, 'Attempted to get an out-of-bounds character in the plane')
    return char, planeIndex
end

function prototype:anchorMarker(markerId, coord)
    return util.attachPrototype(prototype, util.mergeTables(
        self,
        {
            _backwardLeftCmps = space.createCompass({
                forward = coord.forward - self._markerIdToCmps[markerId].coord.forward,
                right = coord.right - self._markerIdToCmps[markerId].coord.right,
                up = coord.up,
                face = 'forward',
            }),
        }
    )):_init()
end

function prototype:anchorBottomLeft(coord)
    return util.attachPrototype(prototype, util.mergeTables(
        self,
        {
            _backwardLeftCmps = space.createCompass({
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
    asciiMap: A list of strings containing a 2d map of tiles and markers.
    markers?: This is used to mark interesting areas in the ascii map.
        A mapping is expected which maps marker names to info tables with the shape of:
            { char = <char>, targetOffset ?= <rel coord>, optional ?= true }

    markerSets?: Similar to markers, but lets you mark zero or more spots with the same character.
        A mapping is expected which maps marker names to info tables with the shape of:
            { char = <char> }
]]
function static.new(opts)
    local asciiMap = opts.asciiMap
    local markerConfs = opts.markers or {}
    local markerSetConfs = opts.markerSets or {}

    local width = #asciiMap[1]
    local depth = #asciiMap
    util.assert(width > 0)
    util.assert(depth > 0)

    -- The backward-left corner is, by default, set to (0,0,0). To change it, call an anchor function.
    local backwardLeftCmps = space.createCompass({
        forward = 0,
        right = 0,
        up = 0,
        face = 'forward',
    })

    local charToIntermediateMarkerData = {} -- Intermediate mapping to help us populate markerIdToCmps and markerSetIdToCmpsList
    local markerIdToCmps = {}
    local markerSetIdToCmpsList = {}
    for markerId, markerConf in util.sortedMapTablePairs(markerConfs or {}) do
        charToIntermediateMarkerData[markerConf.char] = { type = 'marker', id = markerId, conf = markerConf }
    end
    for markerSetId, markerSetConf in util.sortedMapTablePairs(markerSetConfs or {}) do
        charToIntermediateMarkerData[markerSetConf.char] = { type = 'markerSet', id = markerSetId, conf = markerSetConf }
        markerSetIdToCmpsList[markerSetId] = {}
    end

    for yIndex, row in ipairs(asciiMap) do
        util.assert(#row == width, 'All rows must be of the same length')
        for xIndex, cell in util.stringPairs(row) do
            local intermediateMarkerData = charToIntermediateMarkerData[cell]
            if intermediateMarkerData ~= nil and intermediateMarkerData.type == 'marker' then
                local markerId = intermediateMarkerData.id
                local markerConf = intermediateMarkerData.conf
                util.assert(markerIdToCmps[markerId] == nil, 'Marker "'..markerConf.char..'" was found multiple times')

                local targetOffset = markerConf.targetOffset or {}
                markerIdToCmps[markerId] = backwardLeftCmps.compassAt({
                    forward = depth - yIndex + (targetOffset.forward or 0),
                    right = xIndex - 1 + (targetOffset.right or 0),
                    up = targetOffset.up or 0,
                })
            elseif intermediateMarkerData ~= nil and intermediateMarkerData.type == 'markerSet' then
                local markerId = intermediateMarkerData.id
                local markerConf = intermediateMarkerData.conf
                util.assert(markerConf.targetOffset == nil, 'targetOffset is currently not supported with marker sets')
                table.insert(markerSetIdToCmpsList[markerId], backwardLeftCmps.compassAt({
                    forward = depth - yIndex,
                    right = xIndex - 1,
                }))
            end
        end
    end

    for markerId, markerConf in util.sortedMapTablePairs(markerConfs) do
        if not markerConf.optional then
            util.assert(markerIdToCmps[markerId] ~= nil, 'Marker "'..markerConf.char..'" was not found')
        end
    end

    return util.attachPrototype(prototype, {
        width = width,
        depth = depth,
        _asciiMap = asciiMap,
        _markerIdToCmps = markerIdToCmps,
        _markerSetIdToCmpsList = markerSetIdToCmpsList,
        _backwardLeftCmps = backwardLeftCmps,
    }):_init()
end

function prototype:_init()
    --<-- I believe all of these are actually unused at the moment
    local width = #self._asciiMap[1]
    local depth = #self._asciiMap
    self.bounds = {
        width = width,
        depth = depth,
        -- All inclusive
        left = self._backwardLeftCmps.coord.right,
        backward = self._backwardLeftCmps.coord.forward,
        right = self._backwardLeftCmps.coord.right + width - 1,
        forward = self._backwardLeftCmps.coord.forward + depth - 1,
        up = self._backwardLeftCmps.coord.up,
        down = self._backwardLeftCmps.coord.up,
    }
    return self
end

return static