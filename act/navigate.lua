--[[
    Utilities that revolve around navigating 3d space.
    For traveling to a location, see location.lua.
--]]

local util = import('util.lua')
local space = import('./space.lua')

local module = {}

function module.assertFace(state, expectedFace)
    local currentFace = state.turtlePos.face
    if currentFace ~= expectedFace then
        error('Expected current face '..currentFace..' to be expected face '..expectedFace)
    end
end

function module.assertCoord(state, expectedCoord)
    local currentCoord = state.turtleCmps().coord
    currentCoordStr = '(f='..currentCoord.forward..',r='..currentCoord.right..',u='..currentCoord.up..')'
    expectedCoordStr = '(f='..expectedCoord.forward..',r='..expectedCoord.right..',u='..expectedCoord.up..')'
    if currentCoordStr ~= expectedCoordStr then
        error('Expected current coord '..currentCoordStr..' to be expected coord '..expectedCoordStr)
    end
end

function module.assertPos(state, expectedPos)
    local currentPos = state.turtlePos
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
function module.moveToCoord(commands, state, destinationCoord, dimensionOrder)
    if state.turtlePos == nil then error('Failed to provide a valid state') end
    local dimensionOrder = dimensionOrder or { 'forward', 'right', 'up' }

    for _, dimension in ipairs(dimensionOrder) do
        while dimension == 'forward' and state.turtlePos.forward < destinationCoord.forward do
            module.face(commands, state, { face='forward' })
            commands.turtle.forward(state)
        end
        while dimension == 'forward' and state.turtlePos.forward > destinationCoord.forward do
            module.face(commands, state, { face='backward' })
            commands.turtle.forward(state)
        end
        while dimension == 'right' and state.turtlePos.right < destinationCoord.right do
            module.face(commands, state, { face='right' })
            commands.turtle.forward(state)
        end
        while dimension == 'right' and state.turtlePos.right > destinationCoord.right do
            module.face(commands, state, { face='left' })
            commands.turtle.forward(state)
        end
        while dimension == 'up' and state.turtlePos.up < destinationCoord.up do
            commands.turtle.up(state)
        end
        while dimension == 'up' and state.turtlePos.up > destinationCoord.up do
            commands.turtle.down(state)
        end
    end
end

-- Parameters are generally the same as module.moveToCoord().
-- destinationPos has a "face" field, which decides the final direction the turtle will face.
function module.moveToPos(commands, state, destinationPos, dimensionOrder)
    if state.turtlePos == nil then error('Failed to provide a valid state') end
    local destinationCmps = space.createCompass(destinationPos)

    module.moveToCoord(commands, state, destinationCmps.coord, dimensionOrder)
    module.face(commands, state, destinationCmps.facing)
end

function module.face(commands, state, targetFacing)
    local beforeFace = state.turtlePos.face
    local rotations = space.countClockwiseRotations(beforeFace, targetFacing.face)

    if rotations == 1 then
        commands.turtle.turnRight(state)
    elseif rotations == 2 then
        commands.turtle.turnRight(state)
        commands.turtle.turnRight(state)
    elseif rotations == 3 then
        commands.turtle.turnLeft(state)
    end
end

return module