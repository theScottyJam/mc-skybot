local module = {}

local turtleImport = import('./turtle.lua')
local util = import('util.lua')

local globals
globals = {
    turtle = turtleImport[1],
    originalOs = _G.os,
    os = import('./os.lua'),
    mockComputerCraftApi = {
        hookListeners = turtleImport[2],
        present = import('./present.lua'),
        world = import('./world.lua'),
        _currentWorld = nil, -- Any mockComputerCraftApi module is allowed to access this
        setWorld = function(world)
            globals.mockComputerCraftApi._currentWorld = world
        end,
    }
}

function module.registerGlobals()
    util.mergeTablesInPlace(_G, globals)
end

return module
