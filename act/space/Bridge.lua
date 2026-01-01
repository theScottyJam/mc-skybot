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

-- Generally the "outCoord" will be on the absolute coordinate plane, or at least one step closer to an absolute plane.
-- You cross the bridge "in" to the relative plane or "out" of it, back to the more absolute plane.
--
-- The "in" coordinate plane can be rotated if "inFacing" is provided. For example, if "inFacing" is "right",
-- then all points in the "in" coordinate plane will be rotated 90 degrees clockwise around "inCoord".
function static.new(outCoord, inCoord, inFacing)
    -- The only reason you can bridge a coordinate system to itself (using the same position as both values)
    -- is to allow "no-op" bridges to be created that don't perform any conversions on the coordinates.
    util.assert(
        not outCoord:isCompatible(inCoord) or outCoord:equals(inCoord),
        'Both the source and destination reference the same coordinate system. This can only be done if the two positions are exactly the same.'
    )

    return util.attachPrototype(prototype, {
        outCoord = outCoord:origin(),
        inCoord = inCoord:origin(),
        delta = {
            forward = inCoord.forward - outCoord.forward,
            right = inCoord.right - outCoord.right,
            up = inCoord.up - outCoord.up,
            clockwiseTurns = facingTools.countClockwiseRotations(inFacing or 'forward', 'forward'),
        }
    })
end

-- Creates an bridge that doesn't perform any translations when used.
-- The bridge only works for the coordinate plan of the supplied coordinate.
function static.noop(coord)
    local origin = coord:origin()
    return static.new(origin, origin)
end

return static
