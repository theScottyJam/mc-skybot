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

local defaultTo = function(param, fallback)
    if param == nil then
        return fallback
    else
        return param
    end
end

local realEffect = {
    forward = function(count)
        for i = 1, defaultTo(count, 1) do
            commands.turtle.forward()
        end
    end,
    up = function(count)
        for i = 1, defaultTo(count, 1) do
            commands.turtle.up()
        end
    end,
    down = function(count)
        for i = 1, defaultTo(count, 1) do
            commands.turtle.down()
        end
    end,
    turnLeft = commands.turtle.turnLeft,
    turnRight = commands.turtle.turnRight,
    getPos = function()
        util.assert(startPosBridge ~= nil, 'The navigate module has not yet been initialized.')
        return commands.__getTurtlePos():convertOut(startPosBridge)
    end,
}

-- Many functions receive an "effect" table. You can supply this mock one for the purposes
-- of learning how much work a particular action or set of actions would take.
function module.mockEffect(startingPos)
    if startingPos == nil then
        startingPos = realEffect.getPos()
    end
    startingPos.coord:assertAbsolute()

    -- Movement work is 1.5 while turning is 1.0. The added 0.5 is to account for the fact that each movement costs an amount of fuel.

    local work = 0
    local pos = startingPos
    return {
        forward = function(count)
            count = defaultTo(count, 1)
            work = work + count * 1.5
            if pos.facing == 'forward' then pos = pos:at({ forward = count })
            elseif pos.facing == 'right' then pos = pos:at({ right = count })
            elseif pos.facing == 'backward' then pos = pos:at({ forward = -count })
            elseif pos.facing == 'left' then pos = pos:at({ right = -count })
            else error('unreachable') end
        end,
        up = function(count)
            count = defaultTo(count, 1)
            work = work + count * 1.5
            pos = pos:at({ up = count })
        end,
        down = function(count)
            count = defaultTo(count, 1)
            work = work + count * 1.5
            pos = pos:at({ up = -count })
        end,
        turnLeft = function()
            work = work + 1
            pos = pos:rotateCounterClockwise()
        end,
        turnRight = function()
            work = work + 1
            pos = pos:rotateClockwise()
        end,
        getPos = function()
            return pos
        end,
        getWork = function()
            return work
        end
    }
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

function module.getAbsoluteTurtlePos(effect_)
    local effect = effect_ or realEffect
    return effect.getPos()
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
function module.moveToCoord(destinationCoord_, dimensionOrder_, effect_)
    local destinationCoord = convertCoordOut(destinationCoord_)
    local dimensionOrder = dimensionOrder_ or { 'forward', 'right', 'up' }
    local effect = effect_ or realEffect

    for _, dimension in ipairs(dimensionOrder) do
        if dimension == 'forward' and effect.getPos().forward < destinationCoord.forward then
            module._faceAbsolute('forward', effect)
            effect.forward(destinationCoord.forward - effect.getPos().forward)
        end
        if dimension == 'forward' and effect.getPos().forward > destinationCoord.forward then
            module._faceAbsolute('backward', effect)
            effect.forward(effect.getPos().forward - destinationCoord.forward)
        end
        if dimension == 'right' and effect.getPos().right < destinationCoord.right then
            module._faceAbsolute('right', effect)
            effect.forward(destinationCoord.right - effect.getPos().right)
        end
        if dimension == 'right' and effect.getPos().right > destinationCoord.right then
            module._faceAbsolute('left', effect)
            effect.forward(effect.getPos().right - destinationCoord.right)
        end
        if dimension == 'up' and effect.getPos().up < destinationCoord.up then
            effect.up(destinationCoord.up - effect.getPos().up)
        end
        if dimension == 'up' and effect.getPos().up > destinationCoord.up then
            effect.down(effect.getPos().up - destinationCoord.up)
        end
    end
end

-- Similar to moveToCoord(), except it will update the turtle's final facing according to destinationPos's facing value.
-- `effect` can be nil
function module.moveToPos(destinationPos, dimensionOrder, effect)
    module.moveToCoord(destinationPos.coord, dimensionOrder, effect)
    module.face(destinationPos.facing, effect)
end

function module.workToMoveToPos(destinationPos, dimensionOrder)
    local effect = module.mockEffect()
    module.moveToPos(destinationPos, dimensionOrder, effect)
    return effect.getWork()
end

-- The facing will be relative to whatever bridges are currently in the bridgeStack.
-- `effect` can be nil
function module.face(targetFacing, effect)
    module._faceAbsolute(convertFacingOut(targetFacing), effect)
end

function module._faceAbsolute(targetFacing, effect_)
    local effect = effect_ or realEffect

    local beforeFace = effect.getPos().facing
    local rotations = facingTools.countClockwiseRotations(beforeFace, targetFacing)

    if rotations == 1 then
        effect.turnRight()
    elseif rotations == 2 then
        effect.turnRight()
        effect.turnRight()
    elseif rotations == 3 then
        effect.turnLeft()
    end
end

return module