local module = {}

local commandWithStateChanges = function(execute, updateState)
    return function(miniState, ...)
        -- A sanity check, because I mess this up a lot.
        if miniState == nil or miniState.turtlePos == nil then
            error('Forgot to pass in a proper miniState object into a command')
        end

        local result = table.pack(execute(miniState, table.unpack({ ... })))

        if updateState ~= nil then
            updateState(miniState.turtlePos, table.unpack({...}))
        end

        _G._debug.triggerStepListener()

        return table.unpack(result)
    end
end

local ignoreFirstArg = function(fn)
    return function(firstArg, ...)
        return fn(table.unpack({ ... }))
    end
end

module.craft = commandWithStateChanges(function(miniState)
    turtle.craft()
end)

module.up = commandWithStateChanges(function(miniState)
    local success = false
    while not success do
        success = turtle.up()
    end
end, function(turtlePos)
    turtlePos.up = turtlePos.up + 1
end)

module.down = commandWithStateChanges(function(miniState)
    local success = false
    while not success do
        success = turtle.down()
    end
end, function(turtlePos)
    turtlePos.up = turtlePos.up - 1
end)

module.forward = commandWithStateChanges(function(miniState)
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

module.backward = commandWithStateChanges(function(miniState)
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

module.turnLeft = commandWithStateChanges(function(miniState)
    turtle.turnLeft()
end, function(turtlePos)
    turtlePos.face = _G.act.space.rotateFaceCounterClockwise(turtlePos.face)
end)

module.turnRight = commandWithStateChanges(function(miniState)
    turtle.turnRight()
end, function(turtlePos)
    turtlePos.face = _G.act.space.rotateFaceClockwise(turtlePos.face)
end)

module.select = ignoreFirstArg(turtle.select)
module.getItemCount = ignoreFirstArg(turtle.getItemCount)
module.getItemSpace = ignoreFirstArg(turtle.getItemSpace)
module.getItemDetail = ignoreFirstArg(turtle.getItemDetail)
module.equipLeft = ignoreFirstArg(turtle.equipLeft)
module.equipRight = ignoreFirstArg(turtle.equipRight)
module.place = ignoreFirstArg(turtle.place)
module.placeUp = ignoreFirstArg(turtle.placeUp)
module.placeDown = ignoreFirstArg(turtle.placeDown)
module.detect = ignoreFirstArg(turtle.detect)
module.detectUp = ignoreFirstArg(turtle.detectUp)
module.detectDown = ignoreFirstArg(turtle.detectDown)
module.inspect = ignoreFirstArg(turtle.inspect)
module.inspectUp = ignoreFirstArg(turtle.inspectUp)
module.inspectDown = ignoreFirstArg(turtle.inspectDown)
module.dig = ignoreFirstArg(turtle.dig)
module.digUp = ignoreFirstArg(turtle.digUp)
module.digDown = ignoreFirstArg(turtle.digDown)
module.drop = ignoreFirstArg(turtle.drop)
module.dropUp = ignoreFirstArg(turtle.dropUp)
module.dropDown = ignoreFirstArg(turtle.dropDown)
module.suck = ignoreFirstArg(turtle.suck)
module.suckUp = ignoreFirstArg(turtle.suckUp)
module.suckDown = ignoreFirstArg(turtle.suckDown)
module.transferTo = ignoreFirstArg(turtle.transferTo)

return { turtle = module }
