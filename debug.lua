local util = import('util.lua')

local module = {}
local debugModule = {}

function debugModule.printTable(table)
    if util.tableSize(table) == 0 then print('{}'); return end
    print('{')
    for k, v in pairs(table) do
        print('  ' .. tostring(k) .. ' = ' .. tostring(v))
    end
    print('}')
end

function debugModule.busySleep(seconds)
    local sec = tonumber(os.clock() + seconds);
    while (os.clock() < sec) do 
    end 
end

function debugModule.debugCommand(planner, ...)
    table.insert(planner.plan, { command = 'general:debug', args = {...} })
end

-- Arbitrary code that gets used when the debug command is hit.
function debugModule.onDebugCommand(state, opts)
    local present = _G.mockComputerCraftApi.present
    local world = _G.mockComputerCraftApi._currentWorld
    -- present.inventory(world)
    present.displayMap(world, { minX = -5, maxX = 5, minZ = -5, maxZ = 5 })
    -- debugModule.printTable(state.primaryTask.taskVars)
end

function module.registerGlobal()
    _G.debug = debugModule
end

return module