local module = {}

function module.registerGlobals(base)
    _G.mockComputerCraftApi = {}
    local turtleImport = import(base..'turtle.lua')
    _G.turtle = turtleImport[1]
    _G.mockComputerCraftApi.hookListeners = turtleImport[2]
    _G.originalOs = _G.os
    _G.os = import(base..'os.lua')
    _G.mockComputerCraftApi._currentWorld = nil -- Any mockComputerCraftApi module is allowed to access this
    _G.mockComputerCraftApi.present = import(base..'present.lua')
    _G.mockComputerCraftApi.world = import(base..'world.lua')

    -- This world comes from _G.mockComputerCraftApi.world
    function _G.mockComputerCraftApi.setWorld(world)
        _G.mockComputerCraftApi._currentWorld = world
    end
end

return module
