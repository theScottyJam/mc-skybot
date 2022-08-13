local util = import('util.lua')

local turtleActions = {}
local generalActions = {}
local module = { turtle = turtleActions, general = generalActions }

local commandListeners = {}

-- Note, if you ever choose to add a command directly (as a table literal) into the shortTermPlan list
-- (something that higher-level commands might do), take care to handle the onSetup
-- stuff yourself, as that won't run if you bypass the command-initialization function.
function module.registerCommand(id, execute, opts)
    if opts == nil then opts = {} end
    local onSetup = opts.onSetup or nil
    local onExec = opts.onExec or nil

    commandListeners[id] = function(state, ...)
        if onExec ~= nil then onExec(state, table.unpack({...})) end
        execute(state, table.unpack({...}))
    end
    return function(shortTermPlaner, ...)
        -- A sanity check, because I mess this up a lot.
        if shortTermPlaner == nil or shortTermPlaner.shortTermPlan == nil then
            error('Forgot to pass in a proper shortTermPlaner object into a command')
        end
        if onSetup ~= nil then onSetup(shortTermPlaner, table.unpack({...})) end
        table.insert(shortTermPlaner.shortTermPlan, { command = id, args = {...} })
    end
end

-- A convinient shorthand function to take away some boilerplate.
function registerDeterministicCommand(id, execute, updatePos)
    if updatePos == nil then updatePos = function() end end
    return module.registerCommand(id, execute, {
        onSetup = function(shortTermPlaner)
            updatePos(shortTermPlaner.turtlePos)
        end,
        onExec = function(state)
            updatePos(state.turtlePos)
        end
    })
end

turtleActions.up = registerDeterministicCommand('turtle:up', function(state)
    turtle.up()
end, function(turtlePos)
    turtlePos.y = turtlePos.y + 1
end)

turtleActions.down = registerDeterministicCommand('turtle:down', function(state)
    turtle.down()
end, function(turtlePos)
    turtlePos.y = turtlePos.y - 1
end)

turtleActions.forward = registerDeterministicCommand('turtle:forward', function(state)
    turtle.forward()
end, function(turtlePos)
    if turtlePos.face == 'N' then turtlePos.z = turtlePos.z - 1
    elseif turtlePos.face == 'S' then turtlePos.z = turtlePos.z + 1
    elseif turtlePos.face == 'E' then turtlePos.x = turtlePos.x + 1
    elseif turtlePos.face == 'W' then turtlePos.x = turtlePos.x - 1
    else error('Invalid face')
    end
end)

turtleActions.backward = registerDeterministicCommand('turtle:backward', function(state)
    turtle.backward()
end, function(turtlePos)
    if turtlePos.face == 'N' then turtlePos.z = turtlePos.z + 1
    elseif turtlePos.face == 'S' then turtlePos.z = turtlePos.z - 1
    elseif turtlePos.face == 'E' then turtlePos.x = turtlePos.x - 1
    elseif turtlePos.face == 'W' then turtlePos.x = turtlePos.x + 1
    else error('Invalid face')
    end
end)

turtleActions.turnLeft = registerDeterministicCommand('turtle:turnLeft', function(state)
    turtle.turnLeft()
end, function(turtlePos)
    turtlePos.face = _G.act.space.rotateFaceCounterClockwise(turtlePos.face)
end)

turtleActions.turnRight = registerDeterministicCommand('turtle:turnRight', function(state)
    turtle.turnRight()
end, function(turtlePos)
    turtlePos.face = _G.act.space.rotateFaceClockwise(turtlePos.face)
end)

turtleActions.select = registerDeterministicCommand('turtle:select', function(state, slotNum)
    turtle.select(slotNum)
end)

-- signText is optional
turtleActions.place = registerDeterministicCommand('turtle:place', function(state, signText)
    turtle.place(signText)
end)

turtleActions.placeUp = registerDeterministicCommand('turtle:placeUp', function(state)
    turtle.placeUp()
end)

turtleActions.placeDown = registerDeterministicCommand('turtle:placeDown', function(state)
    turtle.placeDown()
end)

turtleActions.dig = registerDeterministicCommand('turtle:dig', function(state, toolSide)
    turtle.dig(toolSide)
end)

turtleActions.digUp = registerDeterministicCommand('turtle:digUp', function(state, toolSide)
    turtle.digUp(toolSide)
end)

turtleActions.digDown = registerDeterministicCommand('turtle:digDown', function(state, toolSide)
    turtle.digDown(toolSide)
end)

turtleActions.suck = registerDeterministicCommand('turtle:suck', function(state, amount)
    turtle.suck(amount)
end)

turtleActions.suckUp = registerDeterministicCommand('turtle:suckUp', function(state, amount)
    turtle.suckUp(amount)
end)

turtleActions.suckDown = registerDeterministicCommand('turtle:suckDown', function(state, amount)
    turtle.suckDown(amount)
end)

-- quantity is optional
turtleActions.transferTo = registerDeterministicCommand('turtle:transferTo', function(state, destinationSlot, quantity)
    turtle.transferTo(destinationSlot, quantity)
end)

generalActions.setState = registerDeterministicCommand('general:setState', function(state, updates)
    util.mergeTablesInPlace(state, updates)
end)

generalActions.debug = registerDeterministicCommand('general:debug', function(state, opts)
    local world = _G.mockComputerCraftApi._currentWorld
    _G.mockComputerCraftApi.present.displayMap(world, { minX = -5, maxX = 5, minZ = -5, maxZ = 5 })
end)

function module.execCommand(state, cmd)
    local type = cmd.command
    local args = cmd.args or {}

    commandListeners[type](state, table.unpack(args))
end

return module
