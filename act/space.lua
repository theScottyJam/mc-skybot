--[[
    Utilities related to 3d space
    Terms:
    * coordinate: An x, y, z coordinate
    * position: A coordinate with a `face`ing.
    * location: A specific, known point in space that you often travel to. Mostly managed in location.lua.
--]]

local util = import('util.lua')

local module = {}

function module.locToPos(loc)
    return { x = loc.x, y = loc.y, z = loc.z, face = loc.face }
end

function module.posToCoord(pos)
    return { x = pos.x, y = pos.y, z = pos.z }
end

function module.locToCoord(loc)
    return { x = loc.x, y = loc.y, z = loc.z }
end

function module.compareCoord(coord1, coord2)
    return coord1.x == coord2.x and coord1.y == coord2.y and coord1.z == coord2.z
end

function module.comparePos(pos1, pos2)
    return module.compareCoord(module.posToCoord(pos1), module.posToCoord(pos2)) and pos1.face == pos2.face
end

-- `amount` is optional
function module.rotateFaceClockwise(face, amount)
    for i = 1, amount or 1 do
        face = ({ N = 'E', E = 'S', S = 'W', W = 'N' })[face]
    end
    return face
end

-- `amount` is optional
function module.rotateFaceCounterClockwise(face, amount)
    for i = 1, amount or 1 do
        face = ({ N = 'W', W = 'S', S = 'E', E = 'N' })[face]
    end
    return face
end

-- Adds the coordinates, and also rotates the coordinate around the
-- base position, depending on which direction the basePos faces.
-- 'N' no rotation, 'E' 90 deg rotation, etc.
-- if basePos was { x=0, y=0, z=0, face='N' }, then relCoord would remain untouched.
-- If x, y, or z is missing from relCoord, they'll default to 0.
function module.resolveRelCoord(relCoord_, basePos)
    local relCoord = util.mergeTables({ x=0, y=0, z=0 }, relCoord_)
    local rotatedCoord
    if basePos.face == 'N' then
        rotatedCoord = relCoord
    elseif basePos.face == 'E' then
        rotatedCoord = rotateCoordClockwiseAroundOrigin(relCoord, 1)
    elseif basePos.face == 'S' then
        rotatedCoord = rotateCoordClockwiseAroundOrigin(relCoord, 2)
    elseif basePos.face == 'W' then
        rotatedCoord = rotateCoordClockwiseAroundOrigin(relCoord, 3)
    else
        error('bad basePos.face value')
    end

    return {
        x = basePos.x + rotatedCoord.x,
        y = basePos.y + rotatedCoord.y,
        z = basePos.z + rotatedCoord.z
    }
end

-- If x, y, or z is missing from relCoord, they'll default to 0.
function module.resolveRelPos(relPos, basePos)
    local rotations = ({ N = 0, E = 1, S = 2, W = 3 })[basePos.face]

    return util.mergeTables(
        module.resolveRelCoord(module.posToCoord(relPos), basePos),
        { face = module.rotateFaceClockwise(relPos.face, rotations) }
    )
end

function module.relativeCoordTo(targetAbsCoord, basePos)
    local unrotatedRelCoord = {
        x = targetAbsCoord.x - basePos.x,
        y = targetAbsCoord.y - basePos.y,
        z = targetAbsCoord.z - basePos.z
    }

    if basePos.face == 'N' then
        return unrotatedRelCoord
    elseif basePos.face == 'W' then
        return rotateCoordClockwiseAroundOrigin(unrotatedRelCoord, 1)
    elseif basePos.face == 'S' then
        return rotateCoordClockwiseAroundOrigin(unrotatedRelCoord, 2)
    elseif basePos.face == 'E' then
        return rotateCoordClockwiseAroundOrigin(unrotatedRelCoord, 3)
    else
        error('bad basePos.face value')
    end
end

function module.relativePosTo(targetAbsPos, basePos)
    local rotations = ({ N = 0, W = 1, S = 2, E = 3 })[basePos.face]

    return util.mergeTables(
        module.relativeCoordTo(module.posToCoord(targetAbsPos), basePos),
        { face = module.rotateFaceClockwise(targetAbsPos.face, rotations) }
    )
end

function rotateCoordClockwiseAroundOrigin(coord, count)
    if count == nil then count = 1 end
    for i = 1, count do
        coord = { x = -coord.z, y = coord.y, z = coord.x }
    end
    return coord
end

return module