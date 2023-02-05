local publicHelpers = import('./_publicHelpers.lua')

local module = {}

local registerCommand = publicHelpers.registerCommand
local registerMovementCommand = publicHelpers.registerMovementCommand
local registerCommandWithFuture = publicHelpers.registerCommandWithFuture

module.up = registerMovementCommand('turtle:up', function(state)
    local success = false
    while not success do
        success = turtle.up()
    end
end, function(turtlePos)
    turtlePos.up = turtlePos.up + 1
end)

module.down = registerMovementCommand('turtle:down', function(state)
    local success = false
    while not success do
        success = turtle.down()
    end
end, function(turtlePos)
    turtlePos.up = turtlePos.up - 1
end)

module.forward = registerMovementCommand('turtle:forward', function(state)
    local success = false
    while not success do
        success = turtle.forward()
    end
end, function(turtlePos)
    if turtlePos.face == 'forward' then turtlePos.forward = turtlePos.forward + 1
    elseif turtlePos.face == 'backward' then turtlePos.forward = turtlePos.forward - 1
    elseif turtlePos.face == 'right' then turtlePos.right = turtlePos.right + 1
    elseif turtlePos.face == 'left' then turtlePos.right = turtlePos.right - 1
    else error('Invalid face')
    end
end)

module.backward = registerMovementCommand('turtle:backward', function(state)
    local success = false
    while not success do
        success = turtle.backward()
        if not success then _G.act.mockHooks.onFailToMove() end
    end
end, function(turtlePos)
    if turtlePos.face == 'forward' then turtlePos.forward = turtlePos.forward - 1
    elseif turtlePos.face == 'backward' then turtlePos.forward = turtlePos.forward + 1
    elseif turtlePos.face == 'right' then turtlePos.right = turtlePos.right - 1
    elseif turtlePos.face == 'left' then turtlePos.right = turtlePos.right + 1
    else error('Invalid face')
    end
end)

module.turnLeft = registerMovementCommand('turtle:turnLeft', function(state)
    turtle.turnLeft()
end, function(turtlePos)
    turtlePos.face = _G.act.space.rotateFaceCounterClockwise(turtlePos.face)
end)

module.turnRight = registerMovementCommand('turtle:turnRight', function(state)
    turtle.turnRight()
end, function(turtlePos)
    turtlePos.face = _G.act.space.rotateFaceClockwise(turtlePos.face)
end)

module.select = registerCommand('turtle:select', function(state, slotNum)
    turtle.select(slotNum)
end)

-- (opts) or (slotNum, opts)
-- opts looks like { out=... }
module.getItemCount = registerCommandWithFuture('turtle:getItemCount', function(state, arg1, arg2)
    local slotNum = nil
    if arg2 ~= nil then
        slotNum = arg1
    end

    return turtle.getItemCount(slotNum)
end, function (arg1, arg2)
    if arg2 == nil then
        return arg1.out
    else
        return arg2.out
    end
end)

module.equipLeft = registerCommand('turtle:equipLeft', function(state)
    turtle.equipLeft()
end)

module.equipRight = registerCommand('turtle:equipRight', function(state)
    turtle.equipRight()
end)

-- signText is optional
module.place = registerCommand('turtle:place', function(state, signText)
    turtle.place(signText)
end)

module.placeUp = registerCommand('turtle:placeUp', function(state)
    turtle.placeUp()
end)

module.placeDown = registerCommand('turtle:placeDown', function(state)
    turtle.placeDown()
end)

-- opts looks like { out=... }
module.inspect = registerCommandWithFuture('turtle:inspect', function(state, opts)
    local success, blockInfo = turtle.inspect()
    return { success, blockInfo }
end, function(opts) return opts.out end)

-- opts looks like { out=... }
module.inspectUp = registerCommandWithFuture('turtle:inspectUp', function(state, opts)
    local success, blockInfo = turtle.inspectUp()
    return { success, blockInfo }
end, function(opts) return opts.out end)

-- opts looks like { out=... }
module.inspectDown = registerCommandWithFuture('turtle:inspectDown', function(state, opts)
    local success, blockInfo = turtle.inspectDown()
    return { success, blockInfo }
end, function(opts) return opts.out end)

module.dig = registerCommand('turtle:dig', function(state, toolSide)
    turtle.dig(toolSide)
end)

module.digUp = registerCommand('turtle:digUp', function(state, toolSide)
    turtle.digUp(toolSide)
end)

module.digDown = registerCommand('turtle:digDown', function(state, toolSide)
    turtle.digDown(toolSide)
end)

module.drop = registerCommand('turtle:drop', function(state, amount)
    turtle.drop(amount)
end)

module.dropUp = registerCommand('turtle:dropUp', function(state, amount)
    turtle.dropUp(amount)
end)

module.dropDown = registerCommand('turtle:dropDown', function(state, amount)
    turtle.dropDown(amount)
end)

-- (amount, opts?)
-- opts looks like { out=... }
module.suck = registerCommandWithFuture('turtle:suck', function(state, amount, opts)
    local success = turtle.suck(amount)
    return success
end, function (amount, opts)
    if opts ~= nil then
        return opts.out
    else
        return nil
    end
end)

-- (amount, opts?)
-- opts looks like { out=... }
module.suckUp = registerCommandWithFuture('turtle:suckUp', function(state, amount, opts)
    local success = turtle.suckUp(amount)
    return success
end, function (amount, opts)
    if opts ~= nil then
        return opts.out
    else
        return nil
    end
end)

-- (amount, opts?)
-- opts looks like { out=... }
module.suckDown = registerCommandWithFuture('turtle:suckDown', function(state, amount, opts)
    local success = turtle.suckDown(amount)
    return success
end, function (amount, opts)
    if opts ~= nil then
        return opts.out
    else
        return nil
    end
end)

-- quantity is optional
module.transferTo = registerCommand('turtle:transferTo', function(state, destinationSlot, quantity)
    turtle.transferTo(destinationSlot, quantity)
end)

return module
