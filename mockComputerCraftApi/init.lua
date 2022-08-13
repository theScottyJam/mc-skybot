local module = {}

function module.registerGlobals(base)
    _G.mockComputerCraftApi = {}
    _G.turtle = require(base..'turtle')
    _G.mockComputerCraftApi._currentWorld = nil -- Any mockComputerCraftApi module is allowed to access this
    _G.mockComputerCraftApi.present = require(base..'present')
    _G.mockComputerCraftApi.world = require(base..'world')

    -- This world comes from _G.mockComputerCraftApi.world
    function _G.mockComputerCraftApi.setWorld(world)
        _G.mockComputerCraftApi._currentWorld = world
    end
end

return module
