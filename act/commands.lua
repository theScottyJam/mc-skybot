--[[
    This module should be used instead of the global turtle table that's automatically provided.
    The APi provided by this module generally tries to stay similar to the global one,
    but there's some slight modifications to prevent common pitfalls, and the movement
    functions have been altered so it keeps track of the turtle's current position automatically.
]]

local util = moduleLoader.tryImport('util.lua')
local inspect = moduleLoader.tryImport('inspect.lua')
local state = import('./state.lua')
local Coord = import('./space/Coord.lua')

-- The turtle's starting location is the origin of this coordinate system.
-- This allows this module to keep track of the turtle without knowing its absolute coordinate.
-- Others can figure out how to translate to an absolute coordinate if it is needed.
local turtleStartPos = Coord.newCoordSystem('turtleStartAsOrigin').origin:face('forward')

local module = {
    turtleStartOrigin = turtleStartPos.coord,
    -- Copy the global turtle table, then we'll override select methods.
    turtle = util.copyTable(turtle)
}

local commandsStateManager = state.__registerPieceOfState('module:commands', function()
    return { turtlePos = turtleStartPos }
end)

function module.__getTurtlePos()
    return commandsStateManager:get().turtlePos
end

local commandWithStateChanges = function(execute, updateState)
    return function(...)
        local result = table.pack(execute(table.unpack({ ... })))

        local newTurtlePos = updateState(commandsStateManager:get().turtlePos, table.unpack({ ... }))
        newTurtlePos.coord:assertCompatible(turtleStartPos.coord)
        commandsStateManager:getAndModify().turtlePos = newTurtlePos

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
    return turtlePos:at({ up = 1 })
end)

module.turtle.down = commandWithStateChanges(function()
    local success = false
    while not success do
        success = turtle.down()
    end
end, function(turtlePos)
    return turtlePos:at({ up = -1 })
end)

module.turtle.forward = commandWithStateChanges(function()
    local success = false
    while not success do
        success = turtle.forward()
    end
end, function(turtlePos)
    if turtlePos.facing == 'forward' then return turtlePos:at({ forward = 1 })
    elseif turtlePos.facing == 'backward' then return turtlePos:at({ forward = -1 })
    elseif turtlePos.facing == 'right' then return turtlePos:at({ right = 1 })
    elseif turtlePos.facing == 'left' then return turtlePos:at({ right = -1 })
    else error('Invalid face')
    end
end)

module.turtle.back = commandWithStateChanges(function()
    local success = false
    while not success do
        success = turtle.back()
    end
end, function(turtlePos)
    if turtlePos.facing == 'forward' then return turtlePos:at({ forward = -1 })
    elseif turtlePos.facing == 'backward' then return turtlePos:at({ forward = 1 })
    elseif turtlePos.facing == 'right' then return turtlePos:at({ right = -1 })
    elseif turtlePos.facing == 'left' then return turtlePos:at({ right = 1 })
    else error('Invalid face')
    end
end)

module.turtle.turnLeft = commandWithStateChanges(function()
    turtle.turnLeft()
end, function(turtlePos)
    return turtlePos:rotateCounterClockwise()
end)

module.turtle.turnRight = commandWithStateChanges(function()
    turtle.turnRight()
end, function(turtlePos)
    return turtlePos:rotateClockwise()
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