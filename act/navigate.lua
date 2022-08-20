--[[
    Utilities that revolve around navigating 3d space.
    For traveling to a location, see location.lua.
--]]

local util = import('util.lua')

local module = {}

function module.assertFace(planner, expectedFace)
    local currentFace = planner.turtlePos.face
    if currentFace ~= expectedFace then
        error('Expected current face '..currentFace..' to be expected face '..expectedFace)
    end
end

function module.assertCoord(planner, expectedCoord)
    local space = _G.act.space
    local currentCoord = space.posToCoord(planner.turtlePos)
    currentCoordStr = '(f='..currentCoord.forward..',r='..currentCoord.right..',u='..currentCoord.up..')'
    expectedCoordStr = '(f='..expectedCoord.forward..',r='..expectedCoord.right..',u='..expectedCoord.up..')'
    if currentCoordStr ~= expectedCoordStr then
        error('Expected current coord '..currentCoordStr..' to be expected coord '..expectedCoordStr)
    end
end

function module.assertPos(planner, expectedPos)
    local currentPos = planner.turtlePos
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
function module.moveToCoord(planner, destinationCoord, dimensionOrder)
    if planner.plan == nil then error('Failed to provide a valid planner') end
    if planner.turtlePos.from ~= destinationCoord.from then error('incompatible "from" fields') end
    local commands = _G.act.commands
    local space = _G.act.space
    local resolveFacing = space.resolveRelFacing
    local dimensionOrder = dimensionOrder or { 'forward', 'right', 'up' }

    for _, dimension in ipairs(dimensionOrder) do
        while dimension == 'forward' and planner.turtlePos.forward < destinationCoord.forward do
            module.face(planner, { face='forward', from=destinationCoord.from })
            commands.turtle.forward(planner)
        end
        while dimension == 'forward' and planner.turtlePos.forward > destinationCoord.forward do
            module.face(planner, { face='backward', from=destinationCoord.from })
            commands.turtle.forward(planner)
        end
        while dimension == 'right' and planner.turtlePos.right < destinationCoord.right do
            module.face(planner, { face='right', from=destinationCoord.from })
            commands.turtle.forward(planner)
        end
        while dimension == 'right' and planner.turtlePos.right > destinationCoord.right do
            module.face(planner, { face='left', from=destinationCoord.from })
            commands.turtle.forward(planner)
        end
        while dimension == 'up' and planner.turtlePos.up < destinationCoord.up do
            commands.turtle.up(planner)
        end
        while dimension == 'up' and planner.turtlePos.up > destinationCoord.up do
            commands.turtle.down(planner)
        end
    end
end

-- Parameters are generally the same as module.moveToCoord().
-- destinationPos has a "face" field, which decides the final direction the turtle will face.
function module.moveToPos(planner, destinationPos, dimensionOrder)
    if planner.plan == nil then error('Failed to provide a valid planner') end
    local space = _G.act.space

    module.moveToCoord(planner, space.posToCoord(destinationPos), dimensionOrder)
    module.face(planner, space.posToFacing(destinationPos))
end

function module.face(planner, targetFacing)
    if planner.turtlePos.from ~= targetFacing.from then error('incompatible "from" fields') end
    local space = _G.act.space
    local commands = _G.act.commands

    local beforeFace = planner.turtlePos.face
    local rotations = space.countClockwiseRotations(beforeFace, targetFacing.face)

    if rotations == 1 then
        commands.turtle.turnRight(planner)
    elseif rotations == 2 then
        commands.turtle.turnRight(planner)
        commands.turtle.turnRight(planner)
    elseif rotations == 3 then
        commands.turtle.turnLeft(planner)
    end
end

return module