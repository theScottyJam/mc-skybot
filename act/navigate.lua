--[[
    Utilities that revolve around navigating 3d space.
    For convertIng to a location, see Location.lua.
]]

local util = import('util.lua')
local Bridge = import('./space/Bridge.lua')
local facingTools = import('./space/facingTools.lua')
local state = import('./state.lua')
local commands = import('./commands.lua')

local module = {}

local bridgeStack = {}
local startPosBridge = nil

local convertCoordOut = function(coord)
    for i = #bridgeStack, 1, -1 do
        local bridge = bridgeStack[i]
        coord = coord:convertOut(bridge)
    end
    coord:assertAbsolute()
    return coord
end

local convertPosOut = function(pos)
    for i = #bridgeStack, 1, -1 do
        local bridge = bridgeStack[i]
        pos = pos:convertOut(bridge)
    end
    pos.coord:assertAbsolute()
    return pos
end

local convertFacingOut = function(facing)
    for i = #bridgeStack, 1, -1 do
        local bridge = bridgeStack[i]
        facing = facingTools.convertFacingOut(facing, bridge)
    end
    return facing
end

-- Decorates the provided function. While it's being called, all values passed to this navigate module must
-- be relative to the bridged coordinate plane instead of the absolute one. This module will automatically
-- translate the coordinates to absolute coordinates.
function module.withBridge(bridge, callback)
    return function(...)
        table.insert(bridgeStack, bridge)
        local result = callback(table.unpack({ ... }))
        table.remove(bridgeStack)
        return result
    end
end

-- You can call this directly if you plan on using act/ without the plan/ component.
-- Otherwise, prepare a plan, and the plan will call this for you.
function module.init(opts)
    local initialTurtlePos = opts.initialTurtlePos
    initialTurtlePos.coord:assertAbsolute()
    startPosBridge = Bridge.new(initialTurtlePos, commands.turtleStartOrigin:face('forward'))
end

function module.getAbsoluteTurtlePos()
    util.assert(startPosBridge ~= nil, 'The navigate module has not yet been initialized.')
    return commands.__getTurtlePos():convertOut(startPosBridge)
end

-- Returns the turtle position, relative to the contents of bridgeStack.
function module.getTurtlePos()
    local pos = module.getAbsoluteTurtlePos()
    for i, bridge in ipairs(bridgeStack) do
        pos = pos:convertIn(bridge)
    end
    return pos
end

function module.assertTurtleFacing(expectedFacing_)
    local expectedFacing = convertFacingOut(expectedFacing_)
    local currentFace = module.getAbsoluteTurtlePos().facing
    if currentFace ~= expectedFacing then
        error('Expected current face '..currentFace..' to be expected face '..expectedFacing)
    end
end

function module.assertAtCoord(expectedCoord_)
    local expectedCoord = convertCoordOut(expectedCoord_)
    local currentCoord = module.getAbsoluteTurtlePos().coord
    if not currentCoord:looseEquals(expectedCoord) then
        local currentCoordStr = '(f='..currentCoord.forward..',r='..currentCoord.right..',u='..currentCoord.up..')'
        local expectedCoordStr = '(f='..expectedCoord.forward..',r='..expectedCoord.right..',u='..expectedCoord.up..')'
        error('Expected current coord '..currentCoordStr..' to be expected coord '..expectedCoordStr)
    end
end

function module.assertAtPos(expectedPos_)
    local expectedPos = convertPosOut(expectedPos_)
    local currentPos = module.getAbsoluteTurtlePos()
    if not currentPos:looseEquals(expectedPos) then
        local currentPosStr = '(f='..currentPos.forward..',r='..currentPos.right..',u='..currentPos.up..','..currentPos.facing..')'
        local expectedPosStr = '(f='..expectedPos.forward..',r='..expectedPos.right..',u='..expectedPos.up..','..expectedPos.facing..')'
        error('Expected current pos '..currentPosStr..' to be expected pos '..expectedPosStr)
    end
end

-- destinationCoord fields default to fields from the turtle's coordinate.
-- The turtle will end facing the direction of travel. (To pick a different facing or preserve facing, use moveToPos())
-- dimensionOrder is optional, and indicates which dimensions to travel first. e.g. {'right', 'up'}.
-- It defaults to { 'forward', 'right', 'up' }. Dimensions can be omited to prevent movement in that direction.
function module.moveToCoord(destinationCoord_, dimensionOrder)
    local destinationCoord = convertCoordOut(destinationCoord_)
    local dimensionOrder = dimensionOrder or { 'forward', 'right', 'up' }

    for _, dimension in ipairs(dimensionOrder) do
        while dimension == 'forward' and module.getAbsoluteTurtlePos().forward < destinationCoord.forward do
            module._faceAbsolute('forward')
            commands.turtle.forward()
        end
        while dimension == 'forward' and module.getAbsoluteTurtlePos().forward > destinationCoord.forward do
            module._faceAbsolute('backward')
            commands.turtle.forward()
        end
        while dimension == 'right' and module.getAbsoluteTurtlePos().right < destinationCoord.right do
            module._faceAbsolute('right')
            commands.turtle.forward()
        end
        while dimension == 'right' and module.getAbsoluteTurtlePos().right > destinationCoord.right do
            module._faceAbsolute('left')
            commands.turtle.forward()
        end
        while dimension == 'up' and module.getAbsoluteTurtlePos().up < destinationCoord.up do
            commands.turtle.up()
        end
        while dimension == 'up' and module.getAbsoluteTurtlePos().up > destinationCoord.up do
            commands.turtle.down()
        end
    end
end

-- Similar to moveToCoord(), except it will update the turtle's final facing according to destinationPos's facing value.
function module.moveToPos(destinationPos, dimensionOrder)
    module.moveToCoord(destinationPos.coord, dimensionOrder)
    module.face(destinationPos.facing)
end

-- The facing will be relative to whatever bridges are currently in the bridgeStack.
function module.face(targetFacing_)
    module._faceAbsolute(convertFacingOut(targetFacing_))
end

function module._faceAbsolute(targetFacing)
    local beforeFace = module.getAbsoluteTurtlePos().facing
    local rotations = facingTools.countClockwiseRotations(beforeFace, targetFacing)

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