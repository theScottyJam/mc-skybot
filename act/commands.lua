local util = import('util.lua')

local turtleActions = {}
local generalActions = {}
local module = { turtle = turtleActions, general = generalActions }

local commandListeners = {}

function module.registerCommand(id, execute, updatePos)
    commandListeners[id] = function(...)
        local state = ({...})[1]
        if updatePos ~= nil then updatePos(state.turtlePos) end
        execute(table.unpack({...}))
    end
    return function(shortTermPlaner, ...)
        if updatePos ~= nil then updatePos(shortTermPlaner.turtlePos) end
        table.insert(shortTermPlaner.shortTermPlan, { command = id, args = {...} })
    end
end
local registerCommand = module.registerCommand

turtleActions.up = registerCommand('turtle:up', function(state)
    turtle.up()
end, function(turtlePos)
    turtlePos.y = turtlePos.y + 1
end)

turtleActions.down = registerCommand('turtle:down', function(state)
    turtle.down()
end, function(turtlePos)
    turtlePos.y = turtlePos.y - 1
end)

turtleActions.forward = registerCommand('turtle:forward', function(state)
    turtle.forward()
end, function(turtlePos)
    if turtlePos.face == 'N' then turtlePos.z = turtlePos.z - 1
    elseif turtlePos.face == 'S' then turtlePos.z = turtlePos.z + 1
    elseif turtlePos.face == 'E' then turtlePos.x = turtlePos.x + 1
    elseif turtlePos.face == 'W' then turtlePos.x = turtlePos.x - 1
    else error('Invalid face')
    end
end)

turtleActions.backward = registerCommand('turtle:backward', function(state)
    turtle.backward()
end, function(turtlePos)
    if turtlePos.face == 'N' then turtlePos.z = turtlePos.z + 1
    elseif turtlePos.face == 'S' then turtlePos.z = turtlePos.z - 1
    elseif turtlePos.face == 'E' then turtlePos.x = turtlePos.x - 1
    elseif turtlePos.face == 'W' then turtlePos.x = turtlePos.x + 1
    else error('Invalid face')
    end
end)

turtleActions.turnLeft = registerCommand('turtle:turnLeft', function(state)
    turtle.turnLeft()
end, function(turtlePos)
    local newFace = ({ N = 'W', W = 'S', S = 'E', E = 'N' })[turtlePos.face]
    turtlePos.face = newFace
end)

turtleActions.turnRight = registerCommand('turtle:turnRight', function(state)
    turtle.turnRight()
end, function(turtlePos)
    local newFace = ({ N = 'E', E = 'S', S = 'W', W = 'N' })[turtlePos.face]
    turtlePos.face = newFace
end)

turtleActions.select = registerCommand('turtle:select', function(state, slotNum)
    turtle.select(slotNum)
end)

-- signText is optional
turtleActions.place = registerCommand('turtle:place', function(state, signText)
    turtle.place(signText)
end)

turtleActions.placeUp = registerCommand('turtle:placeUp', function(state)
    turtle.placeUp()
end)

turtleActions.placeDown = registerCommand('turtle:placeDown', function(state)
    turtle.placeDown()
end)

turtleActions.dig = registerCommand('turtle:dig', function(state, toolSide)
    turtle.dig(toolSide)
end)

turtleActions.digUp = registerCommand('turtle:digUp', function(state, toolSide)
    turtle.digUp(toolSide)
end)

turtleActions.digDown = registerCommand('turtle:digDown', function(state, toolSide)
    turtle.digDown(toolSide)
end)

turtleActions.suck = registerCommand('turtle:suck', function(state, amount)
    turtle.suck(amount)
end)

turtleActions.suckUp = registerCommand('turtle:suckUp', function(state, amount)
    turtle.suckUp(amount)
end)

turtleActions.suckDown = registerCommand('turtle:suckDown', function(state, amount)
    turtle.suckDown(amount)
end)

-- quantity is optional
turtleActions.transferTo = registerCommand('turtle:transferTo', function(state, destinationSlot, quantity)
    turtle.transferTo(destinationSlot, quantity)
end)

generalActions.setState = registerCommand('general:setState', function(state, updates)
    util.mergeTablesInPlace(state, updates)
end)

generalActions.debug = registerCommand('general:debug', function(state, opts)
    local world = _G.mockComputerCraftApi._currentWorld
    _G.mockComputerCraftApi.present.displayMap(world, { minX = -5, maxX = 5, minZ = -5, maxZ = 5 })
end)

function module.execCommand(state, cmd)
    local type = cmd.command
    local args = cmd.args or {}

    commandListeners[type](state, table.unpack(args))
end

return module
