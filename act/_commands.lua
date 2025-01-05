local util = moduleLoader.tryImport('util.lua')
local inspect = moduleLoader.tryImport('inspect.lua')
local space = import('./space.lua')
local State = import('./_State.lua')

local module = {}

local commandWithStateChanges = function(execute, updateState)
    return function(state, ...)
        -- A sanity check, because I mess this up a lot.
        if not State.__isInstance(state) then
            error('Forgot to pass in a proper state object into a command')
        end

        local result = table.pack(execute(state, table.unpack({ ... })))

        if updateState ~= nil then
            local newTurtlePos = util.copyTable(state.turtlePos)
            updateState(newTurtlePos, table.unpack({...}))
            state.turtlePos = newTurtlePos
        end

        if inspect.onStep ~= nil then
            inspect.onStep(state)
        end

        return table.unpack(result)
    end
end

local ignoreFirstArg = function(fn)
    return function(firstArg, ...)
        return fn(table.unpack({ ... }))
    end
end

module.craft = ignoreFirstArg(turtle.craft)

module.up = commandWithStateChanges(function(state)
    local success = false
    while not success do
        success = turtle.up()
    end
end, function(turtlePos)
    turtlePos.up = turtlePos.up + 1
end)

module.down = commandWithStateChanges(function(state)
    local success = false
    while not success do
        success = turtle.down()
    end
end, function(turtlePos)
    turtlePos.up = turtlePos.up - 1
end)

module.forward = commandWithStateChanges(function(state)
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

module.backward = commandWithStateChanges(function(state)
    local success = false
    while not success do
        success = turtle.backward()
    end
end, function(turtlePos)
    if turtlePos.face == 'forward' then turtlePos.forward = turtlePos.forward - 1
    elseif turtlePos.face == 'backward' then turtlePos.forward = turtlePos.forward + 1
    elseif turtlePos.face == 'right' then turtlePos.right = turtlePos.right - 1
    elseif turtlePos.face == 'left' then turtlePos.right = turtlePos.right + 1
    else error('Invalid face')
    end
end)

module.turnLeft = commandWithStateChanges(function(state)
    turtle.turnLeft()
end, function(turtlePos)
    turtlePos.face = space.__rotateFaceCounterClockwise(turtlePos.face)
end)

module.turnRight = commandWithStateChanges(function(state)
    turtle.turnRight()
end, function(turtlePos)
    turtlePos.face = space.__rotateFaceClockwise(turtlePos.face)
end)

module.select = ignoreFirstArg(turtle.select)
module.getItemCount = ignoreFirstArg(turtle.getItemCount)
module.getItemSpace = ignoreFirstArg(turtle.getItemSpace)
module.getItemDetail = ignoreFirstArg(turtle.getItemDetail)
module.equipLeft = ignoreFirstArg(turtle.equipLeft)
module.equipRight = ignoreFirstArg(turtle.equipRight)

-- Note that these return a `success` boolean.
-- You may want to assert that the boolean is true after using these functions.
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
