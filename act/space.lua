--[[
    Utilities related to 3d space
    Terms:
    * facing: A table with a "face" field.
    * coordinate: a forward,right,up coordinate.
    * position: A coordinate and facing combined - it has the fields from both.
    * location: A specific, known point in space that you often travel to. These are managed in Location.lua.
    * compass: A tool to generate coords/positions/facings from the compass's location. Often abreviated "cmps"
]]

local util = import('util.lua')

local module = {}

local rotateCoordClockwiseAroundOrigin = function(coord, count)
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
function module.__rotateFaceClockwise(face, amount)
    assertValidFace(face)
    if amount == nil then amount = 1 end
    for i = 1, amount do
        face = ({ forward = 'right', right = 'backward', backward = 'left', left = 'forward' })[face]
    end
    return face
end

-- `amount` is optional
function module.__rotateFaceCounterClockwise(face, amount)
    assertValidFace(face)
    if amount == nil then amount = 1 end
    for i = 1, amount do
        face = ({ forward = 'left', left = 'backward', backward = 'right', right = 'forward' })[face]
        if face == nil then error('Bad face value') end
    end
    return face
end

-- To count counterclockwise rotations, just flip the parameters.
function module.__countClockwiseRotations(fromFace, toFace)
    assertValidFace(fromFace)
    assertValidFace(toFace)
    local count = 0
    local face = fromFace
    while face ~= toFace do
        count = count + 1
        face = module.__rotateFaceClockwise(face)
    end
    return count
end

local moveFacing = function(basePos, deltaFacing)
    local rotations = module.__countClockwiseRotations('forward', basePos.face)
    return {
        face = module.__rotateFaceClockwise(deltaFacing.face, rotations),
    }
end

-- Adds the coordinates, and also rotates the coordinate around the
-- base position, depending on which direction the basePos faces.
-- 'forward' no rotation, 'right' 90 deg rotation, etc.
-- if basePos was { forward=0, right=0, up=0, face='forward' }, then partialDeltaCoord would remain untouched.
-- If forward, right, or up is missing from partialDeltaCoord, they'll default to 0.
local moveCoord = function(basePos, partialDeltaCoord)
    local deltaCoord = util.mergeTables({ forward=0, right=0, up=0 }, partialDeltaCoord)
    local rotations = module.__countClockwiseRotations('forward', basePos.face)
    local rotatedDeltaCoord = rotateCoordClockwiseAroundOrigin(deltaCoord, rotations)

    return {
        forward = basePos.forward + rotatedDeltaCoord.forward,
        right = basePos.right + rotatedDeltaCoord.right,
        up = basePos.up + rotatedDeltaCoord.up,
    }
end

-- If forward, right, or up is missing from partialDeltaPos, they'll default to 0.
-- partialDeltaPos.face is also optional and defaults to `forward`
local movePos = function(basePos, partialDeltaPos)
    local deltaPos = util.mergeTables({ forward=0, right=0, up=0, face='forward' }, partialDeltaPos)
    local rotations = module.__countClockwiseRotations('forward', basePos.face)

    return util.mergeTables(
        moveCoord(basePos, posToCoord(deltaPos)),
        { face = module.__rotateFaceClockwise(deltaPos.face, rotations) }
    )
end

local distanceBetween = function(startPos, endCoord)
    local rotations = module.__countClockwiseRotations(startPos.face, 'forward')
    -- Rotate the two coordinates until we're facing forwards.
    -- The distance will be preserved during the rotation.
    local rotatedStartCoord = rotateCoordClockwiseAroundOrigin(posToCoord(startPos), rotations)
    local rotatedEndCoord = rotateCoordClockwiseAroundOrigin(endCoord, rotations)

    return {
        forward = rotatedEndCoord.forward - rotatedStartCoord.forward,
        right = rotatedEndCoord.right - rotatedStartCoord.right,
        up = rotatedEndCoord.up - rotatedStartCoord.up,
    }
end

-- Meant to provide quick access to some of the above functions
function module.createCompass(pos)
    return {
        pos = pos,
        coord = posToCoord(pos),
        facing = posToFacing(pos),
        facingAt = function(deltaFacing) return moveFacing(pos, deltaFacing) end,
        coordAt = function(partialDeltaCoord) return moveCoord(pos, partialDeltaCoord) end,
        posAt = function(partialDeltaPos) return movePos(pos, partialDeltaPos) end,
        compassAt = function(partialDeltaPos) return module.createCompass(movePos(pos, partialDeltaPos)) end,
        distanceTo = function(coord) return distanceBetween(pos, coord) end,
        compareCoord = function(otherCoord) return compareCoord(posToCoord(pos), otherCoord) end,
        compareCmps = function(otherCmps) return comparePos(pos, otherCmps.pos) end,
    }
end

return module