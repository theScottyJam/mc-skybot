local module = {}

local util = import('util.lua')

local globals = {
    turtle = import('./turtle.lua'),
    originalOs = _G.os,
    os = import('./os.lua'),
    mockComputerCraftApi = {
        hooks = import('./hooks.lua'),
        present = import('./present.lua'),
        world = import('./_worldGenerator.lua').createWorld(),
        worldTools = import('./worldTools.lua'),
    }
}

function module.registerGlobals()
    util.mergeTablesInPlace(_G, globals)
end

return module
