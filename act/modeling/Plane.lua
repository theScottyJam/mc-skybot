--[[
Contains various functions to inspect 2d ASCII maps.
]]

local util = import('util.lua')
local Region = import('./Region.lua')
local space = import('../space.lua')

local static = {}
local prototype = {}

function prototype:getBackwardLeftCmps()
    return self._region:getBackwardBottomLeftCmps()
end

function prototype:getForwardRightCmps()
    return self._region:getBackwardBottomLeftCmps().compassAt({
        forward = self.bounds.depth - 1,
        right = self.bounds.width - 1,
    })
end

--<-- unused
function prototype:getCmpsAtMarker(markerId)
    return self._region:getCmpsAtMarker(markerId)
end

-- Attempts to get the character at the coordinate, or returns nil if it is out of bounds.
function prototype:tryGetCharAt(coord)
    return self._region:tryGetCharAt(coord)
end

function prototype:getCharAt(coord)
    return self._region:getCharAt(coord)
end

function prototype:anchorMarker(markerId, relCoord)
    return util.attachPrototype(prototype, util.mergeTables(
        self,
        {
            _region = self._region:anchorMarker(markerId, relCoord),
        }
    )):_init()
end

--<-- Unused.
function prototype:anchorBackwardLeft(relCoord)
    return util.attachPrototype(prototype, util.mergeTables(
        self,
        {
            _region = self._region:anchorBackwardBottomLeft(relCoord),
        }
    )):_init()
end

--[[
Inputs:
    asciiMap: A list of strings containing a 2d map of tiles and markers.
    markers?: This is used to mark interesting areas in the ascii map.
        A mapping is expected which maps marker names to info tables with the shape of:
            { char = <char>, targetOffset ?= <rel coord> }
]]
function static.new(opts)
    --<-- Document: "." and "," are reserved
    return util.attachPrototype(prototype, {
        _region = Region.new({
            layeredAsciiMap = {opts.asciiMap},
            markers = opts.markers,
        }),
    }):_init()
end

function prototype:_init()
    self.bounds = self._region.bounds
    return self
end

return static