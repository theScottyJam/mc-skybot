--[[
Contains various functions to inspect 2d ASCII maps.
]]

local util = import('util.lua')
local space = import('../space.lua')

local static = {}
local prototype = {}

function prototype:getTopLeftCmps()
    return self._topLeftCmps
end

function prototype:getBottomRightCmps()
    return self._topLeftCmps.compassAt({
        forward = -(#self._asciiMap - 1),
        right = #self._asciiMap[1] - 1,
    })
end

function prototype:_getSize()
    return {
        width = #self._asciiMap[1],
        height = #self._asciiMap,
    }
end

function prototype:getCmpsAtMarker(markerId)
    local cmps = self._markerIdToCmps[markerId]
    util.assert(cmps ~= nil)
    return cmps
end

function prototype:cmpsListFromMarkerSet(markerSetId)
    local cmpsList = self._markerSetIdToCmpsList[markerSetId]
    util.assert(cmpsList ~= nil)
    return cmpsList
end

-- Returns a table containing left/forward/right/backward fields, saying how many steps
-- you have to move to reach (and not cross) a boundary.
-- For example, A 1x1 grid containing the marker would have all values set to 0.
function prototype:getBoundsAtMarker(markerId)
    local coord = self._markerIdToCmps[markerId].coord
    local dimensions = self:_getSize()

    return {
        left = coord.right,
        forward = -coord.forward,
        right = dimensions.width - coord.right - 1,
        backward = dimensions.height + coord.forward - 1,
    }
end

function prototype:getCharAt(coord)
    local deltaCoord = self._topLeftCmps.distanceTo(coord)
    assert(deltaCoord.up == 0)
    local char = self._asciiMap[-deltaCoord.forward + 1] and util.charAt(self._asciiMap[-deltaCoord.forward + 1], deltaCoord.right + 1)
    assert(char ~= nil)
    return char
end

function prototype:anchorMarker(markerId, coord)
    return util.attachPrototype(prototype, util.mergeTables(
        self,
        {
            _topLeftCmps = space.createCompass({
                forward = coord.forward + self._markerIdToCmps[markerId].coord.forward,
                right = coord.right - self._markerIdToCmps[markerId].coord.right,
                up = coord.up,
                face = 'forward',
            }),
        }
    ))
end

function prototype:anchorTopLeft(coord)
    return util.attachPrototype(prototype, util.mergeTables(
        self,
        {
            _topLeftCmps = space.createCompass({
                forward = coord.forward,
                right = coord.right,
                up = coord.up,
                face = 'forward',
            }),
        }
    ))
end

--[[
Inputs:
    asciiMap: A list of strings containing a 2d map of tiles and markers.
    markers?: This is used to mark interesting areas in the ascii map.
        A mapping is expected which maps marker names to info tables with the shape of:
            { char = <char>, targetOffset ?= <x/y coord> }

    markerSets?: Similar to markers, but lets you mark zero or more spots with the same character.
        A mapping is expected which maps marker names to info tables with the shape of:
            { char = <char> }
]]
function static.new(opts)
    local asciiMap = opts.asciiMap
    local markerConfs = opts.markers or {}
    local markerSetConfs = opts.markerSets or {}

    -- The asciiMap must contain something
    util.assert(#asciiMap > 0)
    util.assert(#asciiMap[1] > 0)

    -- The top-left corner is, by default, set to (0,0,0). To change it, call an anchor function.
    local topLeftCmps = space.createCompass({
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

    for y, row in ipairs(asciiMap) do
        util.assert(#row == #asciiMap[1], 'All rows must be of the same length')
        for x, cell in util.stringPairs(row) do
            local intermediateMarkerData = charToIntermediateMarkerData[cell]
            if intermediateMarkerData ~= nil and intermediateMarkerData.type == 'marker' then
                local markerId = intermediateMarkerData.id
                local markerConf = intermediateMarkerData.conf
                util.assert(markerIdToCmps[markerId] == nil, 'Marker "'..markerConf.char..'" was found multiple times')

                local targetOffset = markerConf.targetOffset or {}
                markerIdToCmps[markerId] = topLeftCmps.compassAt({
                    forward = -(y - 1 + (targetOffset.y or 0)),
                    right = x - 1 + (targetOffset.x or 0),
                })
            elseif intermediateMarkerData ~= nil and intermediateMarkerData.type == 'markerSet' then
                local markerId = intermediateMarkerData.id
                local markerConf = intermediateMarkerData.conf
                util.assert(markerConf.targetOffset == nil, 'targetOffset is currently not supported with marker sets')
                table.insert(markerSetIdToCmpsList[markerId], topLeftCmps.compassAt({
                    forward = -(y - 1),
                    right = x - 1,
                }))
            end
        end
    end

    for markerId, markerConf in util.sortedMapTablePairs(markerConfs) do
        util.assert(markerIdToCmps[markerId] ~= nil, 'Marker "'..markerConf.char..'" was not found')
    end

    return util.attachPrototype(prototype, {
        _asciiMap = asciiMap,
        _markerIdToCmps = markerIdToCmps,
        _markerSetIdToCmpsList = markerSetIdToCmpsList,
        _topLeftCmps = topLeftCmps,
    })
end

return static