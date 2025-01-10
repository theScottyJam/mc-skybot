--[[
    Utilities that revolve around navigating 3d space.
    For traveling to a location, see Location.lua.
]]

local util = import('util.lua')
local space = import('./space.lua')
local state = import('./state.lua')
local commands = import('./commands.lua')

local module = {}

function module.assertTurtleFacing(expectedFace)
    local currentFace = state.getTurtlePos().face
    if currentFace ~= expectedFace then
        error('Expected current face '..currentFace..' to be expected face '..expectedFace)
    end
end

function module.assertAtCoord(expectedCoord)
    local currentCoord = state.getTurtleCmps().coord
    currentCoordStr = '(f='..currentCoord.forward..',r='..currentCoord.right..',u='..currentCoord.up..')'
    expectedCoordStr = '(f='..expectedCoord.forward..',r='..expectedCoord.right..',u='..expectedCoord.up..')'
    if currentCoordStr ~= expectedCoordStr then
        error('Expected current coord '..currentCoordStr..' to be expected coord '..expectedCoordStr)
    end
end

function module.assertAtPos(expectedPos)
    local currentPos = state.getTurtlePos()
    currentPosStr = '(f='..currentPos.forward..',r='..currentPos.right..',u='..currentPos.up..',f='..currentPos.face..')'
    expectedPosStr = '(f='..expectedPos.forward..',r='..expectedPos.right..',u='..expectedPos.up..',f='..expectedPos.face..')'
    if currentPosStr ~= expectedPosStr then
        error('Expected current pos '..currentPosStr..' to be expected pos '..expectedPosStr)
    end
end

-- destinationCoord fields default to fields from the turtle's coordinate.
-- The turtle will end facing the direction of travel. (To pick a different facing or preserve facing, use moveToPos())
-- dimensionOrder is optional, and indicates which dimensions to travel first. e.g. {'right', 'up'}.
-- It defaults to { 'forward', 'right', 'up' }. Dimensions can be omited to prevent movement in that direction.
function module.moveToCoord(destinationCoord, dimensionOrder)
    local dimensionOrder = dimensionOrder or { 'forward', 'right', 'up' }

    for _, dimension in ipairs(dimensionOrder) do
        while dimension == 'forward' and state.getTurtlePos().forward < destinationCoord.forward do
            module.face({ face='forward' })
            commands.turtle.forward()
        end
        while dimension == 'forward' and state.getTurtlePos().forward > destinationCoord.forward do
            module.face({ face='backward' })
            commands.turtle.forward()
        end
        while dimension == 'right' and state.getTurtlePos().right < destinationCoord.right do
            module.face({ face='right' })
            commands.turtle.forward()
        end
        while dimension == 'right' and state.getTurtlePos().right > destinationCoord.right do
            module.face({ face='left' })
            commands.turtle.forward()
        end
        while dimension == 'up' and state.getTurtlePos().up < destinationCoord.up do
            commands.turtle.up()
        end
        while dimension == 'up' and state.getTurtlePos().up > destinationCoord.up do
            commands.turtle.down()
        end
    end
end

-- Parameters are generally the same as module.moveToCoord().
-- destinationPos has a "face" field, which decides the final direction the turtle will face.
function module.moveToPos(destinationPos, dimensionOrder)
    local destinationCmps = space.createCompass(destinationPos)

    module.moveToCoord(destinationCmps.coord, dimensionOrder)
    module.face(destinationCmps.facing)
end

function module.face(targetFacing)
    local beforeFace = state.getTurtlePos().face
    local rotations = space.__countClockwiseRotations(beforeFace, targetFacing.face)

    if rotations == 1 then
        commands.turtle.turnRight()
    elseif rotations == 2 then
        commands.turtle.turnRight()
        commands.turtle.turnRight()
    elseif rotations == 3 then
        commands.turtle.turnLeft()
    end
end

return module