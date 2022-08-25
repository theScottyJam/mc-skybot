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

function debugModule.debugCommand(planner, ...)
    table.insert(planner.plan, { command = 'general:debug', args = {...} })
end

-- Arbitrary code that gets used when the debug command is hit.
function debugModule.onDebugCommand(state, opts)
    local present = _G.mockComputerCraftApi.present
    local world = _G.mockComputerCraftApi._currentWorld
    debugModule.showStepByStep = true
    present.displayMap(world, { minX = -8, maxX = 5, minY = 0, maxY = 79, minZ = -5, maxZ = 4 }, { showKey = false })
    -- present.inventory(world)
    -- present.showTurtlePosition(world)
    -- debugModule.printTable(state.getActiveTask().taskVars)
end

function module.registerGlobal()
    _G.debug = debugModule
end

return module