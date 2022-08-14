local module = {}

function module.registerGlobals(base)
    _G.mockComputerCraftApi = {}
    _G.turtle, _G.mockComputerCraftApi.hookListeners = import(base..'turtle.lua')
    _G.mockComputerCraftApi._currentWorld = nil -- Any mockComputerCraftApi module is allowed to access this
    _G.mockComputerCraftApi.present = import(base..'present.lua')
    _G.mockComputerCraftApi.world = import(base..'world.lua')

    -- This world comes from _G.mockComputerCraftApi.world
    function _G.mockComputerCraftApi.setWorld(world)
        _G.mockComputerCraftApi._currentWorld = world
    end
end

return module
