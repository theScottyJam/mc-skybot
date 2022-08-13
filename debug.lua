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

function debugModule.busySleep (seconds)
    local sec = tonumber(os.clock() + seconds);
    while (os.clock() < sec) do 
    end 
end

function module.registerGlobal()
    _G.debug = debugModule
end

return module