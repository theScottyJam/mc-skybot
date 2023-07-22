local util = import('util.lua')

local module = {}
local debugModule = {}

debugModule.showStepByStep = false

function debugModule.printTable(table)
    if util.tableSize(table) == 0 then print('{}'); return end
    print('{')
    for k, v in pairs(table) do
        print('  ' .. tostring(k) .. ' = ' .. tostring(v))
    end
    print('}')
end

function debugModule.busySleep(seconds)
    -- The os module gets overwritten to act more like computerCraft's version of `os`.
    -- The original os module is still needed to count real time passing, if it's available.
    -- (When mocking, the original is backed-up to _G.originalOs)
    local osModule = _G.originalOs or _G.os
    local sec = tonumber(osModule.clock() + seconds);
    while (osModule.clock() < sec) do 
    end 
end

local onStepListener
function debugModule.registerStepListener(onStep)
    onStepListener = onStep
end

function debugModule.triggerStepListener()
    if onStepListener ~= nil then
        onStepListener()
    end
end

-- Executes arbitrary debugging-related code.
function debugModule.debugCommand(commands, miniState, opts)
    local present = _G.mockComputerCraftApi.present
    local world = _G.mockComputerCraftApi._currentWorld
    local highLevelCommands = _G.act.highLevelCommands

    if opts == nil then opts = {} end
    if opts.action == 'obtain' then
        local itemId = opts.itemId
        local quantity = opts.quantity
        if quantity == nil then quantity = 1 end
        highLevelCommands.findAndSelectEmptpySlot(commands, miniState)
        world.turtle.inventory[world.turtle.selectedSlot] = { id = itemId, quantity = quantity }
        return
    end

    -- debugModule.showStepByStep = true
    -- present.displayMap(world, { minX = -8, maxX = 5, minY = 0, maxY = 79, minZ = -5, maxZ = 4 }, { showKey = false })
    present.inventory(world)
    -- present.showTurtlePosition(world)
end

function module.registerGlobal()
    _G._debug = debugModule
end

return module