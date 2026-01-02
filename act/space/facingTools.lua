local util = import('util.lua')

local module = {}

local assertValidFacing = function(facing)
    util.assert(
        util.tableContains({'forward', 'right', 'backward', 'left'}, facing),
        'Bad facing value.'
    )
end

-- `amount` is optional
function module.rotateFacingClockwise(facing, amount)
    assertValidFacing(facing)
    if amount == nil then amount = 1 end
    for i = 1, amount do
        facing = ({ forward = 'right', right = 'backward', backward = 'left', left = 'forward' })[facing]
    end
    return facing
end

-- `amount` is optional
function module.rotateFacingCounterClockwise(facing, amount)
    assertValidFacing(facing)
    if amount == nil then amount = 1 end
    for i = 1, amount do
        facing = ({ forward = 'left', left = 'backward', backward = 'right', right = 'forward' })[facing]
    end
    return facing
end

-- To count counterclockwise rotations, just flip the parameters.
function module.countClockwiseRotations(fromFacing, toFacing)
    assertValidFacing(fromFacing)
    assertValidFacing(toFacing)
    local count = 0
    local facing = fromFacing
    while facing ~= toFacing do
        count = count + 1
        facing = module.rotateFacingClockwise(facing)
    end
    return count
end

function module.convertFacingIn(outFace, bridge)
    return module.rotateFacingClockwise(outFace, module.countClockwiseRotations(bridge.outPos.facing, bridge.inPos.facing))
end

function module.convertFacingOut(inFace, bridge)
    return module.rotateFacingClockwise(inFace, module.countClockwiseRotations(bridge.inPos.facing, bridge.outPos.facing))
end

return module