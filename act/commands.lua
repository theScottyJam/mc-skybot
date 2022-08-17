local util = import('util.lua')

local turtleActions = {}
local generalActions = {}
local mockHooksActions = {}
local module = { turtle = turtleActions, general = generalActions, mockHooks = mockHooksActions }

local commandListeners = {}

-- Note, if you ever choose to add a command directly (as a table literal) into the shortTermPlan list
-- (something that higher-level commands might do), take care to handle the onSetup
-- stuff yourself, as that won't run if you bypass the command-initialization function.
function module.registerCommand(id, execute, opts)
    if opts == nil then opts = {} end
    local onSetup = opts.onSetup or nil
    local onExec = opts.onExec or nil

    commandListeners[id] = function(state, setupState, ...)
        if onExec ~= nil then onExec(state, setupState, table.unpack({...})) end
        execute(state, setupState, table.unpack({ ... }))
    end
    return function(shortTermPlanner, ...)
        -- A sanity check, because I mess this up a lot.
        if shortTermPlanner == nil or shortTermPlanner.shortTermPlan == nil then
            error('Forgot to pass in a proper shortTermPlanner object into a command')
        end
        local setupState = nil
        if onSetup ~= nil then setupState = onSetup(shortTermPlanner, table.unpack({...})) end
        table.insert(shortTermPlanner.shortTermPlan, { command = id, args = {...}, setupState = setupState })
    end
end

-- A convinient shorthand function to take away some boilerplate.
function registerDeterministicCommand(id, execute_, updatePos)
    if updatePos == nil then updatePos = function() end end
    function execute(state, setupState, ...) return execute_(state, table.unpack({ ... })) end
    return module.registerCommand(id, execute, {
        onSetup = function(shortTermPlanner)
            updatePos(shortTermPlanner.turtlePos)
        end,
        onExec = function(state, setupState, setupState)
            updatePos(state.turtlePos)
        end
    })
end

turtleActions.up = registerDeterministicCommand('turtle:up', function(state)
    turtle.up()
end, function(turtlePos)
    turtlePos.up = turtlePos.up + 1
end)

turtleActions.down = registerDeterministicCommand('turtle:down', function(state)
    turtle.down()
end, function(turtlePos)
    turtlePos.up = turtlePos.up - 1
end)

turtleActions.forward = registerDeterministicCommand('turtle:forward', function(state)
    turtle.forward()
end, function(turtlePos)
    if turtlePos.face == 'forward' then turtlePos.forward = turtlePos.forward + 1
    elseif turtlePos.face == 'backward' then turtlePos.forward = turtlePos.forward - 1
    elseif turtlePos.face == 'right' then turtlePos.right = turtlePos.right + 1
    elseif turtlePos.face == 'left' then turtlePos.right = turtlePos.right - 1
    else error('Invalid face')
    end
end)

turtleActions.backward = registerDeterministicCommand('turtle:backward', function(state)
    turtle.backward()
end, function(turtlePos)
    if turtlePos.face == 'forward' then turtlePos.forward = turtlePos.forward - 1
    elseif turtlePos.face == 'backward' then turtlePos.forward = turtlePos.forward + 1
    elseif turtlePos.face == 'right' then turtlePos.right = turtlePos.right - 1
    elseif turtlePos.face == 'left' then turtlePos.right = turtlePos.right + 1
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

mockHooksActions.registerCobblestoneRegenerationBlock = module.registerCommand(
    'mockHooks:registerCobblestoneRegenerationBlock',
    function(state, setupState, coord)
        local mockHooks = _G.act.mockHooks
        local space = _G.act.space
        mockHooks.registerCobblestoneRegenerationBlock(coord)
    end
)

generalActions.setState = registerDeterministicCommand('general:setState', function(state, updates)
    util.mergeTablesInPlace(state, updates)
end)

generalActions.debug = registerDeterministicCommand('general:debug', function(state, opts)
    debug.onDebugCommand(state, opts)
end)

function module.execCommand(state, cmd)
    local type = cmd.command
    local args = cmd.args or {}
    local setupState = cmd.setupState -- could be nil

    commandListeners[type](state, setupState, table.unpack(args))
end

return module
