--[[
    Bridges two coordinate planes.

    Generally you won't interact with the bridge's properties directly unless you're creating
    a helper function to help convert an entity between the two coordinate planes. (such as the
    Coord class providing functions to move coordinates from one coordinate plane to another
    via a bridge instance).
]]

local util = import('util.lua')
local facingTools = import('./facingTools.lua')

local static = {}
local prototype = {}

-- Creates a bridge between two coordinate planes. This bridge can be used to convert coordinates/positions/etc from
-- one coordinate plane to the other and back.
-- By providing these two positions, you're stating that the two positions are actually the exact same (for the purposes of this bridge instance),
-- only they're located on different coordinate planes.
-- All translations will use this information to figure out how the two coordinate planes relate to each other.
--
-- Conventionally the "outPos" will be on the absolute coordinate plane, or at least one step closer to an absolute plane.
-- You cross the bridge "in" to the relative plane or "out" of it, back to the more absolute plane.
function static.new(outPos, inPos)
    util.assert(
        not outPos.coord:isCompatible(inPos.coord),
        'The two positions provided must reference different coordinate planes.'
    )

    return util.attachPrototype(prototype, {
        outPos = outPos,
        inPos = inPos,
    })
end

-- Creates an bridge that doesn't perform any translations when used.
-- The bridge only works for the coordinate plane of the supplied coordinate.
function static.noop(coord)
    local originPos = coord:origin():face('forward')
    return util.attachPrototype(prototype, {
        outPos = originPos,
        inPos = originPos,
    })
end

return static
