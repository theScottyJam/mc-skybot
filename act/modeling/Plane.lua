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
    local relCoordFromTopLeft = self._markerIdToMetadata[markerId].relCoordFromTopLeft
    return self._topLeftCmps.compassAt({
        forward = -relCoordFromTopLeft.y,
        right = relCoordFromTopLeft.x,
    })
end

function prototype:cmpsListFromMarkerSet(markerSetId)
    local metadataList = self._markerSetIdToMetadataList[markerSetId]
    return util.mapArrayTable(metadataList, function(metadata)
        local relCoordFromTopLeft = metadata.relCoordFromTopLeft
        return self._topLeftCmps.compassAt({
            forward = -relCoordFromTopLeft.y,
            right = relCoordFromTopLeft.x,
        })
    end)
end

-- Returns a table containing left/forward/right/backward fields, saying how many steps
-- you have to move to reach (and not cross) a boundary.
-- For example, A 1x1 grid containing the marker would have all values set to 0.
function prototype:getBoundsAtMarker(markerId)
    local relCoordFromTopLeft = self._markerIdToMetadata[markerId].relCoordFromTopLeft
    local dimensions = self:_getSize()

    return {
        left = relCoordFromTopLeft.x,
        forward = relCoordFromTopLeft.y,
        right = dimensions.width - relCoordFromTopLeft.x - 1,
        backward = dimensions.height - relCoordFromTopLeft.y - 1,
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
                forward = coord.forward - self._markerIdToMetadata[markerId].relCoordFromTopLeft.y,
                right = coord.right - self._markerIdToMetadata[markerId].relCoordFromTopLeft.x,
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

    local charToIntermediateMarkerData = {} -- Intermediate mapping to help us populate markerIdToMetadata and markerSetIdToMetadataList
    local markerIdToMetadata = {}
    local markerSetIdToMetadataList = {}
    for markerId, markerConf in util.sortedMapTablePairs(markerConfs or {}) do
        charToIntermediateMarkerData[markerConf.char] = { type = 'marker', id = markerId, conf = markerConf }
    end
    for markerSetId, markerSetConf in util.sortedMapTablePairs(markerSetConfs or {}) do
        charToIntermediateMarkerData[markerSetConf.char] = { type = 'markerSet', id = markerSetId, conf = markerSetConf }
        markerSetIdToMetadataList[markerSetId] = {}
    end

    for y, row in ipairs(asciiMap) do
        util.assert(#row == #asciiMap[1], 'All rows must be of the same length')
        for x, cell in util.stringPairs(row) do
            local intermediateMarkerData = charToIntermediateMarkerData[cell]
            if intermediateMarkerData ~= nil and intermediateMarkerData.type == 'marker' then
                local markerId = intermediateMarkerData.id
                local markerConf = intermediateMarkerData.conf
                util.assert(markerIdToMetadata[markerId] == nil, 'Marker "'..markerConf.char..'" was found multiple times')

                local targetOffset = markerConf.targetOffset or {}
                markerIdToMetadata[markerId] = {
                    relCoordFromTopLeft = {
                        x = x - 1 + (targetOffset.x or 0),
                        y = y - 1 + (targetOffset.y or 0),
                    }
                }
            elseif intermediateMarkerData ~= nil and intermediateMarkerData.type == 'markerSet' then
                local markerId = intermediateMarkerData.id
                local markerConf = intermediateMarkerData.conf
                util.assert(markerConf.targetOffset == nil, 'targetOffset is currently not supported with marker sets')
                table.insert(markerSetIdToMetadataList[markerId], {
                    relCoordFromTopLeft = {
                        x = x - 1,
                        y = y - 1,
                    }
                })
            end
        end
    end

    for markerId, markerConf in util.sortedMapTablePairs(markerConfs) do
        util.assert(markerIdToMetadata[markerId] ~= nil, 'Marker "'..markerConf.char..'" was not found')
    end

    return util.attachPrototype(prototype, {
        _asciiMap = asciiMap,
        _markerIdToMetadata = markerIdToMetadata,
        _markerSetIdToMetadataList = markerSetIdToMetadataList,
        -- The top-left corner is, by default, set to (0,0,0). To change it, call an anchor function.
        _topLeftCmps = space.createCompass({
            forward = 0,
            right = 0,
            up = 0,
            face = 'forward',
        })
    })
end

return static