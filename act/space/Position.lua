--[[
    A coordinate and facing.
]]

local util = import('util.lua')
local serializer = import('../_serializer.lua')
local facingTools = import('./facingTools.lua')

local static = {}
local prototype = {}
-- The Coord class restricts it so you're allowed to serialize absolute coordinates.
serializer.registerValue('class-prototype:Position', prototype)

local assertValidFacing = function(facing)
    local isValid = util.tableContains({'forward', 'right', 'backward', 'left'}, facing)
    util.assert(isValid, 'Bad "facing" value')
end

function prototype:at(opts)
    return static.new({
        coord = self.coord:at({
            forward = opts.forward,
            right = opts.right,
            up = opts.up,
        }),
        facing = self.facing,
    })
end

function prototype:face(facing)
    return static.new({
        coord = self.coord,
        facing = facing,
    })
end

function prototype:rotateClockwise()
    return static.new({
        coord = self.coord,
        facing = facingTools.rotateFacingClockwise(self.facing),
    })
end

function prototype:rotateCounterClockwise()
    return static.new({
        coord = self.coord,
        facing = facingTools.rotateFacingCounterClockwise(self.facing),
    })
end

-- "looseEquals" will return `false` if the positions are from different coordinate planes,
-- while the regular "equals" function will throw an error.
function prototype:looseEquals(otherPos)
    return self.facing == otherPos.facing and self.coord:equals(otherPos.coord)
end

function prototype:equals(otherPos)
    self.coord:assertCompatible(otherPos.coord)
    return self:looseEquals(otherPos)
end

function prototype:convertIn(bridge)
    return static.new({
        coord = self.coord:convertIn(bridge),
        facing = facingTools.convertFacingIn(self.facing, bridge),
    })
end

function prototype:convertOut(bridge)
    return static.new({
        coord = self.coord:convertOut(bridge),
        facing = facingTools.convertFacingOut(self.facing, bridge),
    })
end

function static.new(opts)
    local coord = opts.coord
    local facing = opts.facing

    assertValidFacing(facing)

    return util.attachPrototype(prototype, {
        coord = coord,
        facing = facing,
        -- Provided for easier access
        forward = coord.forward,
        right = coord.right,
        up = coord.up,
    })
end

return static
