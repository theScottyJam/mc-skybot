--[[
    Utilities that revolve around navigating 3d space.
    For traveling to a location, see location.lua.
--]]

local util = import('util.lua')

local module = {}

function module.assertFace(miniState, expectedFace)
    local currentFace = miniState.turtlePos.face
    if currentFace ~= expectedFace then
        error('Expected current face '..currentFace..' to be expected face '..expectedFace)
    end
end

function module.assertCoord(miniState, expectedCoord)
    local currentCoord = miniState.turtleCmps().coord
    currentCoordStr = '(f='..currentCoord.forward..',r='..currentCoord.right..',u='..currentCoord.up..')'
    expectedCoordStr = '(f='..expectedCoord.forward..',r='..expectedCoord.right..',u='..expectedCoord.up..')'
    if currentCoordStr ~= expectedCoordStr then
        error('Expected current coord '..currentCoordStr..' to be expected coord '..expectedCoordStr)
    end
end

function module.assertPos(miniState, expectedPos)
    local currentPos = miniState.turtlePos
    currentPosStr = '(f='..currentPos.forward..',r='..currentPos.right..',u='..currentPos.up..',f='..currentPos.face..')'
    expectedPosStr = '(f='..expectedPos.forward..',r='..expectedPos.right..',u='..expectedPos.up..',f='..expectedPos.face..')'
    if currentPosStr ~= expectedPosStr then
        error('Expected current pos '..currentPosStr..' to be expected pos '..expectedPosStr)
    end
end

-- destinationCoord fields default to fields from the turtle's coordinate.
-- The turtle will end, facing the direction of travel. (To pick a different facing or preserve facing, use moveToPos())
-- dimensionOrder is optional, and indicates which dimensions to travel first. e.g. {'right', 'up'}.
-- It defaults to { 'forward', 'right', 'up' }. Dimensions can be omited to prevent movement in that direction.
function module.moveToCoord(commands, miniState, destinationCoord, dimensionOrder)
    if miniState.turtlePos == nil then error('Failed to provide a valid miniState') end
    local dimensionOrder = dimensionOrder or { 'forward', 'right', 'up' }

    for _, dimension in ipairs(dimensionOrder) do
        while dimension == 'forward' and miniState.turtlePos.forward < destinationCoord.forward do
            module.face(commands, miniState, { face='forward' })
            commands.turtle.forward(miniState)
        end
        while dimension == 'forward' and miniState.turtlePos.forward > destinationCoord.forward do
            module.face(commands, miniState, { face='backward' })
            commands.turtle.forward(miniState)
        end
        while dimension == 'right' and miniState.turtlePos.right < destinationCoord.right do
            module.face(commands, miniState, { face='right' })
            commands.turtle.forward(miniState)
        end
        while dimension == 'right' and miniState.turtlePos.right > destinationCoord.right do
            module.face(commands, miniState, { face='left' })
            commands.turtle.forward(miniState)
        end
        while dimension == 'up' and miniState.turtlePos.up < destinationCoord.up do
            commands.turtle.up(miniState)
        end
        while dimension == 'up' and miniState.turtlePos.up > destinationCoord.up do
            commands.turtle.down(miniState)
        end
    end
end

-- Parameters are generally the same as module.moveToCoord().
-- destinationPos has a "face" field, which decides the final direction the turtle will face.
function module.moveToPos(commands, miniState, destinationPos, dimensionOrder)
    if miniState.turtlePos == nil then error('Failed to provide a valid miniState') end
    local space = _G.act.space
    local destinationCmps = space.createCompass(destinationPos)

    module.moveToCoord(commands, miniState, destinationCmps.coord, dimensionOrder)
    module.face(commands, miniState, destinationCmps.facing)
end

function module.face(commands, miniState, targetFacing)
    local space = _G.act.space

    local beforeFace = miniState.turtlePos.face
    local rotations = space.countClockwiseRotations(beforeFace, targetFacing.face)

    if rotations == 1 then
        commands.turtle.turnRight(miniState)
    elseif rotations == 2 then
        commands.turtle.turnRight(miniState)
        commands.turtle.turnRight(miniState)
    elseif rotations == 3 then
        commands.turtle.turnLeft(miniState)
    end
end

return module