--[[
    Utilities that revolve around navigating 3d space.
    For traveling to a location, see location.lua.
--]]

local util = import('util.lua')

local module = {}

function module.assertFace(shortTermPlaner, expectedFace)
    local currentFace = shortTermPlaner.turtlePos.face
    if currentFace ~= expectedFace then
        error('Expected current face '..currentFace..' to be expected face '..expectedFace)
    end
end

function module.assertCoord(shortTermPlaner, expectedCoord)
    local space = _G.act.space
    local currentCoord = space.posToCoord(shortTermPlaner.turtlePos)
    currentCoordStr = '('..currentCoord.forward..','..currentCoord.right..','..currentCoord.up..')'
    expectedCoordStr = '('..expectedCoord.forward..','..expectedCoord.right..','..expectedCoord.up..')'
    if currentCoordStr ~= expectedCoordStr then
        error('Expected current coord '..currentCoordStr..' to be expected coord '..expectedCoordStr)
    end
end

function module.assertPos(shortTermPlaner, expectedPos)
    local currentCoord = shortTermPlaner.turtlePos
    currentPosStr = '('..currentPos.forward..','..currentPos.right..','..currentPos.up..','..currentPos.face..')'
    expectedPosStr = '('..expectedPos.forward..','..expectedPos.right..','..expectedPos.up..','..expectedPos.face..')'
    if currentPosStr ~= expectedPosStr then
        error('Expected current pos '..currentPosStr..' to be expected pos '..expectedPosStr)
    end
end

-- destinationCoord fields default to fields from the turtle's coordinate.
-- The turtle will end, facing the direction of travel. (To pick a different facing or preserve facing, use moveToPos())
-- dimensionOrder is optional, and indicates which dimensions to travel first. e.g. {'right', 'up'}.
-- It defaults to { 'forward', 'right', 'up' }. Dimensions can be omited to prevent movement in that direction.
function module.moveToCoord(shortTermPlaner, destinationCoord, dimensionOrder)
    if shortTermPlaner.turtlePos.from ~= destinationCoord.from then error('incompatible "from" fields') end
    local commands = _G.act.commands
    local space = _G.act.space
    local resolveFacing = space.resolveRelFacing
    local dimensionOrder = dimensionOrder or { 'forward', 'right', 'up' }

    for _, dimension in ipairs(dimensionOrder) do
        while dimension == 'forward' and shortTermPlaner.turtlePos.forward < destinationCoord.forward do
            module.face(shortTermPlaner, { face='forward', from=destinationCoord.from })
            commands.turtle.forward(shortTermPlaner)
        end
        while dimension == 'forward' and shortTermPlaner.turtlePos.forward > destinationCoord.forward do
            module.face(shortTermPlaner, { face='backward', from=destinationCoord.from })
            commands.turtle.forward(shortTermPlaner)
        end
        while dimension == 'right' and shortTermPlaner.turtlePos.right < destinationCoord.right do
            module.face(shortTermPlaner, { face='right', from=destinationCoord.from })
            commands.turtle.forward(shortTermPlaner)
        end
        while dimension == 'right' and shortTermPlaner.turtlePos.right > destinationCoord.right do
            module.face(shortTermPlaner, { face='left', from=destinationCoord.from })
            commands.turtle.forward(shortTermPlaner)
        end
        while dimension == 'up' and shortTermPlaner.turtlePos.up < destinationCoord.up do
            commands.turtle.up(shortTermPlaner)
        end
        while dimension == 'up' and shortTermPlaner.turtlePos.up > destinationCoord.up do
            commands.turtle.down(shortTermPlaner)
        end
    end
end

-- Parameters are generally the same as module.moveToCoord().
-- destinationPos has a "face" field, which decides the final direction the turtle will face.
function module.moveToPos(shortTermPlaner, destinationPos, dimensionOrder)
    local space = _G.act.space

    module.moveToCoord(shortTermPlaner, space.posToCoord(destinationPos), dimensionOrder)
    module.face(shortTermPlaner, space.posToFacing(destinationPos))
end

function module.face(shortTermPlaner, targetFacing)
    if shortTermPlaner.turtlePos.from ~= targetFacing.from then error('incompatible "from" fields') end
    local space = _G.act.space
    local commands = _G.act.commands

    local beforeFace = shortTermPlaner.turtlePos.face
    local rotations = space.countClockwiseRotations(beforeFace, targetFacing.face)

    if rotations == 1 then
        commands.turtle.turnRight(shortTermPlaner)
    elseif rotations == 2 then
        commands.turtle.turnRight(shortTermPlaner)
        commands.turtle.turnRight(shortTermPlaner)
    elseif rotations == 3 then
        commands.turtle.turnLeft(shortTermPlaner)
    end
end

return module