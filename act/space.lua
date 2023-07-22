--[[
    Utilities related to 3d space
    Terms:
    * facing: A table with a "face" field.
    * coordinate: a forward,right,up coordinate.
    * position: A coordinate and facing combined - it has the fields from both.
    * location: A specific, known point in space that you often travel to. These are managed in location.lua.
    * compass: A tool to generate coords/positions/facings from the compass's location. Often abreviated "cmps"

    Some APIs accept relative coordinates/positions/facings. Generally, all fields in a relative
    coordinate/position/facing are optional, and default to the position they're relative to.
--]]

local util = import('util.lua')

local module = {}

-- HELPER FUNCTIONS --

local rotateRelCoordClockwiseAroundOrigin = function(coord, count)
    if count == nil then count = 1 end
    for i = 1, count do
        coord = { right = coord.forward, forward = -coord.right, up = coord.up }
    end
    return coord
end

local assertValidFace = function(face)
    local isValid = util.tableContains({'forward', 'right', 'backward', 'left'}, face)
    if not isValid then
        error('Bad face value')
    end
end

-- PUBLIC FUNCTIONS --
-- Also includes functions pertaining to space management, that we
-- could flip to public at any point in time when needed.

local posToFacing = function(pos)
    return { face = pos.face }
end

local posToCoord = function(pos)
    return { forward = pos.forward, right = pos.right, up = pos.up }
end

local compareCoord = function(coord1, coord2)
    return (
        coord1.forward == coord2.forward and
        coord1.right == coord2.right and
        coord1.up == coord2.up
    )
end

local comparePos = function(pos1, pos2)
    return compareCoord(posToCoord(pos1), posToCoord(pos2)) and pos1.face == pos2.face
end

-- `amount` is optional
function module.rotateFaceClockwise(face, amount)
    assertValidFace(face)
    if amount == nil then amount = 1 end
    for i = 1, amount do
        face = ({ forward = 'right', right = 'backward', backward = 'left', left = 'forward' })[face]
    end
    return face
end

-- `amount` is optional
function module.rotateFaceCounterClockwise(face, amount)
    assertValidFace(face)
    if amount == nil then amount = 1 end
    for i = 1, amount do
        face = ({ forward = 'left', left = 'backward', backward = 'right', right = 'forward' })[face]
        if face == nil then error('Bad face value') end
    end
    return face
end

-- To count counterclockwise rotations, just flip the parameters.
function module.countClockwiseRotations(fromFace, toFace)
    assertValidFace(fromFace)
    assertValidFace(toFace)
    local count = 0
    local face = fromFace
    while face ~= toFace do
        count = count + 1
        face = module.rotateFaceClockwise(face)
    end
    return count
end

local resolveRelFacing = function(relFacing, basePos)
    local rotations = module.countClockwiseRotations('forward', basePos.face)
    return {
        face = module.rotateFaceClockwise(relFacing.face, rotations),
    }
end

-- Adds the coordinates, and also rotates the coordinate around the
-- base position, depending on which direction the basePos faces.
-- 'forward' no rotation, 'right' 90 deg rotation, etc.
-- if basePos was { forward=0, right=0, up=0, face='forward' }, then relCoord would remain untouched.
-- If forward, right, or up is missing from relCoord, they'll default to 0.
local resolveRelCoord = function(relCoord_, basePos)
    local relCoord = util.mergeTables({ forward=0, right=0, up=0 }, relCoord_)
    local rotations = module.countClockwiseRotations('forward', basePos.face)
    local rotatedRelCoord = rotateRelCoordClockwiseAroundOrigin(relCoord, rotations)

    return {
        forward = basePos.forward + rotatedRelCoord.forward,
        right = basePos.right + rotatedRelCoord.right,
        up = basePos.up + rotatedRelCoord.up,
    }
end

-- If forward, right, or up is missing from relCoord, they'll default to 0.
-- relPos.face is also optional and defaults to `forward`
local resolveRelPos = function(relPos_, basePos)
    local relPos = util.mergeTables({ forward=0, right=0, up=0, face='forward' }, relPos_)
    local rotations = module.countClockwiseRotations('forward', basePos.face)

    return util.mergeTables(
        resolveRelCoord(posToCoord(relPos), basePos),
        { face = module.rotateFaceClockwise(relPos.face, rotations) }
    )
end

local relativeCoordTo = function(targetAbsCoord, basePos)
    local unrotatedRelCoord = {
        forward = targetAbsCoord.forward - basePos.forward,
        right = targetAbsCoord.right - basePos.right,
        up = targetAbsCoord.up - basePos.up
    }

    local rotations = module.countClockwiseRotations(basePos.face, 'forward')
    return rotateRelCoordClockwiseAroundOrigin(unrotatedRelCoord, rotations)
end

local relativePosTo = function(targetAbsPos, basePos)
    local rotations = module.countClockwiseRotations(basePos.face, 'forward')

    return util.mergeTables(
        module.relativeCoordTo(posToCoord(targetAbsPos), basePos),
        { face = module.rotateFaceClockwise(targetAbsPos.face, rotations) }
    )
end

-- Meant to provide quick access to some of the above functions
function module.createCompass(pos)
    return {
        pos = pos,
        coord = posToCoord(pos),
        facing = posToFacing(pos),
        facingAt = function(relFacing) return resolveRelFacing(relFacing, pos) end,
        coordAt = function(relCoord) return resolveRelCoord(relCoord, pos) end,
        posAt = function(relPos) return resolveRelPos(relPos, pos) end,
        compassAt = function(relPos) return module.createCompass(resolveRelPos(relPos, pos)) end,
        compareCmps = function(otherCmps) return comparePos(pos, otherCmps.pos) end,
    }
end

return module