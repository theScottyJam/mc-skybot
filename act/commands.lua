local util = moduleLoader.tryImport('util.lua')
local inspect = moduleLoader.tryImport('inspect.lua')
local space = import('./space.lua')
local state = import('./state.lua')

local module = {
    -- Copy the global turtle table, then we'll override select methods.
    turtle = util.copyTable(turtle)
}

local commandWithStateChanges = function(execute, updateState)
    return function(...)
        local result = table.pack(execute(table.unpack({ ... })))

        if updateState ~= nil then
            local newTurtlePos = util.copyTable(state.getTurtlePos())
            updateState(newTurtlePos, table.unpack({ ... }))
            state.setTurtlePos(newTurtlePos)
        end

        if inspect.onStep ~= nil then
            inspect.onStep()
        end

        return table.unpack(result)
    end
end

module.turtle.up = commandWithStateChanges(function()
    local success = false
    while not success do
        success = turtle.up()
    end
end, function(turtlePos)
    turtlePos.up = turtlePos.up + 1
end)

module.turtle.down = commandWithStateChanges(function()
    local success = false
    while not success do
        success = turtle.down()
    end
end, function(turtlePos)
    turtlePos.up = turtlePos.up - 1
end)

module.turtle.forward = commandWithStateChanges(function()
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

module.turtle.backward = commandWithStateChanges(function()
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

module.turtle.turnLeft = commandWithStateChanges(function()
    turtle.turnLeft()
end, function(turtlePos)
    turtlePos.face = space.__rotateFaceCounterClockwise(turtlePos.face)
end)

module.turtle.turnRight = commandWithStateChanges(function()
    turtle.turnRight()
end, function(turtlePos)
    turtlePos.face = space.__rotateFaceClockwise(turtlePos.face)
end)

-- The place functions return a success boolean.
-- Usually you want to assert that the boolean is true, but it's easy to forget this.
-- For this reason, the original methods have been replaced with these duds that throw errors,
-- instead, you're required to explicitly state that you want to assert or not assert, by choosing
-- an alternative method.
module.turtle.place = function() error('Either use placeAndAssert() or tryPlace() instead') end
module.turtle.placeUp = function() error('Either use placeUpAndAssert() or tryPlaceUp() instead') end
module.turtle.placeDown = function() error('Either use placeDownAndAssert() or tryPlaceDown() instead') end
module.turtle.placeAndAssert = function(...) util.assert(turtle.place(table.unpack({ ... }))) end
module.turtle.placeUpAndAssert = function(...) util.assert(turtle.placeUp(table.unpack({ ... }))) end
module.turtle.placeDownAndAssert = function(...) util.assert(turtle.placeDown(table.unpack({ ... }))) end
module.turtle.tryPlace = turtle.place
module.turtle.tryPlaceUp = turtle.placeUp
module.turtle.tryPlaceDown = turtle.placeDown

return module