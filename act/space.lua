--[[
    Utilities related to 3d space
    Terms:
    * facing: A table with a "face" and "from" field.
    * coordinate: a forward,right,up coordinate which a `from` field.
        `from` is either `ORIGIN` or another coordinate where at least one of its fields is set to 'UNKNOWN'.
    * position: A coordinate and facing combined - it has the fields from both.
    * location: A specific, known point in space that you often travel to. These are managed in location.lua.
    * compass: A tool to generate coords/positions/facings from the compass's location. Often abreviated "cmps"

    A "relative" coordinate/position/facing is considered to be a value without a `from` field. What they're relative
    to depends on context. Generally, all fields in a relative coordinate/position/facing are optional, and default to
    the position they're relative to.
    (You could technically consider normal coordinates to be relative, since a non-origin "from" does not provide
    enough information to pinpoint exactly where the coordinate is at, but for our purposes we'll think of these as
    absolute).
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

-- A "navUnit" is a position, coordinate, or facing.
-- Returns a list, where the first item is the passed-in pos/coord/facing,
-- the second it that value's "from" field, the third is the "from"'s "from" field,
-- and so on. Useful to make iteration easier.
-- opts.limit can be provided to have it return all fields up to and excluding the limit
local listFromFieldChain = function(navUnit, opts)
    local limit = (opts or {}).limit -- may be nil
    local result = { navUnit }
    repeat
        navUnit = navUnit.from
        if navUnit == limit then break end
        table.insert(result, navUnit)
    until navUnit == 'ORIGIN'
    return result
end

assertValidFace = function(face)
    local isValid = util.tableContains({'forward', 'right', 'backward', 'left'}, face)
    if not isValid then
        error('Bad face value')
    end
end

-- PUBLIC FUNCTIONS --

function module.posToFacing(pos)
    return { face = pos.face, from = pos.from }
end

function module.posToCoord(pos)
    return { forward = pos.forward, right = pos.right, up = pos.up, from = pos.from }
end

function module.relPosToRelCoord(pos)
    return { forward = pos.forward, right = pos.right, up = pos.up }
end

function module.compareFacing(facing1, facing2)
    return facing1.face == facing2.face and facing1.from == facing2.face
end

function module.compareCoord(coord1, coord2)
    return (
        coord1.forward == coord2.forward and
        coord1.right == coord2.right and
        coord1.up == coord2.up and
        coord1.from == coord2.from
    )
end

function module.comparePos(pos1, pos2)
    return module.compareCoord(module.posToCoord(pos1), module.posToCoord(pos2)) and pos1.face == pos2.face
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

function module.resolveRelFacing(relFacing, basePos)
    local rotations = module.countClockwiseRotations('forward', basePos.face)
    return {
        face = module.rotateFaceClockwise(relFacing.face, rotations),
        from = basePos.from
    }
end

-- Adds the coordinates, and also rotates the coordinate around the
-- base position, depending on which direction the basePos faces.
-- 'forward' no rotation, 'right' 90 deg rotation, etc.
-- if basePos was { forward=0, right=0, up=0, face='forward' }, then relCoord would remain untouched.
-- If forward, right, or up is missing from relCoord, they'll default to 0.
function module.resolveRelCoord(relCoord_, basePos)
    local relCoord = util.mergeTables({ forward=0, right=0, up=0 }, relCoord_)
    local rotations = module.countClockwiseRotations('forward', basePos.face)
    local rotatedRelCoord = rotateRelCoordClockwiseAroundOrigin(relCoord, rotations)

    return {
        forward = basePos.forward + rotatedRelCoord.forward,
        right = basePos.right + rotatedRelCoord.right,
        up = basePos.up + rotatedRelCoord.up,
        from = basePos.from
    }
end

-- If forward, right, or up is missing from relCoord, they'll default to 0.
-- relPos.face is also optional and defaults to `forward`
function module.resolveRelPos(relPos_, basePos)
    local relPos = util.mergeTables({ forward=0, right=0, up=0, face='forward' }, relPos_)
    local rotations = module.countClockwiseRotations('forward', basePos.face)

    return util.mergeTables(
        module.resolveRelCoord(module.relPosToRelCoord(relPos), basePos),
        { face = module.rotateFaceClockwise(relPos.face, rotations) }
    )
end

function module.relativeCoordTo(targetAbsCoord, basePos)
    if targetAbsCoord.from ~= basePos.from then error('incompatible "from" fields') end
    local unrotatedRelCoord = {
        forward = targetAbsCoord.forward - basePos.forward,
        right = targetAbsCoord.right - basePos.right,
        up = targetAbsCoord.up - basePos.up
    }

    local rotations = module.countClockwiseRotations(basePos.face, 'forward')
    return rotateRelCoordClockwiseAroundOrigin(unrotatedRelCoord, rotations)
end

function module.relativePosTo(targetAbsPos, basePos)
    if targetAbsPos.from ~= basePos.from then error('incompatible "from" fields') end
    local rotations = module.countClockwiseRotations(basePos.face, 'forward')

    return util.mergeTables(
        module.relativeCoordTo(module.posToCoord(targetAbsPos), basePos),
        { face = module.rotateFaceClockwise(targetAbsPos.face, rotations) }
    )
end

-- A "navUnit" is a position, coordinate, or facing.
-- Returns the "from" field that's common between the two.
function module.findCommonFromField(navUnit1, navUnit2)
    fromChain1 = util.reverseTable(listFromFieldChain(navUnit1))
    fromChain2 = util.reverseTable(listFromFieldChain(navUnit2))
    if fromChain1[1] ~= 'ORIGIN' or fromChain2[1] ~= 'ORIGIN' then
        listFromFieldChain(navUnit1)
        error('UNREACHABLE: The from chain is missing the ORIGIN point')
    end

    local shortestChain = util.minNumber(#fromChain1, #fromChain2)
    for i = 1, shortestChain do
        if fromChain1[i] ~= fromChain2[i] then
            return fromChain1[i - 1]
        end
    end
    return fromChain1[shortestChain]
end

-- Go through all "from" fields to find an absolute position.
-- The returned object will have fields set to "unknown" if a "from" field set it as such.
-- opts.endAt can be supplied to tell it to squash up to and excluding that point.
function module.squashFromFields(pos, opts)
    local limit = (opts or {}).endAt or 'ORIGIN'

    local result = { from = limit }

    for _, field in pairs({ 'forward', 'right', 'up' }) do
        result[field] = 0
        for _, iterPos in ipairs(listFromFieldChain(pos, { limit = limit })) do
            if iterPos[field] == 'UNKNOWN' then
                result[field] = 'UNKNOWN'
                break
            else
                result[field] = result[field] + iterPos[field]
            end
        end
    end

    result.face = 'forward'
    for _, iterPos in ipairs(listFromFieldChain(pos, { limit = limit })) do
        if iterPos.face == 'UNKNOWN' then
            result.face = 'UNKNOWN'
            break
        else
            result.face = module.resolveRelFacing({ face=result.face }, module.posToFacing(iterPos)).face
        end
    end

    return result
end

-- Meant to provide quick access to some of the above functions
function module.createCompass(pos)
    return {
        pos = pos,
        coord = module.posToCoord(pos),
        facing = module.posToFacing(pos),
        facingAt = function(relFacing) return module.resolveRelFacing(relFacing, pos) end,
        coordAt = function(relCoord) return module.resolveRelCoord(relCoord, pos) end,
        posAt = function(relPos) return module.resolveRelPos(relPos, pos) end,
        compassAt = function(relPos) return module.createCompass(module.resolveRelPos(relPos, pos)) end
    }
end

return module