local time = import('./_time.lua')
local worldTools = import('./worldTools.lua')

local module = {}

function module.registerCobblestoneRegenerationBlock(deltaCoord)
    local coord = {
        x = deltaCoord.right,
        y = deltaCoord.up,
        z = -deltaCoord.forward
    }
    local regenerateCobblestone
    regenerateCobblestone = function()
        time.addTickListener(4, regenerateCobblestone)
        local world = _G.mockComputerCraftApi.world
        local cell = worldTools.lookupInMap(coord)
        if cell ~= nil then return end
        worldTools.setInMap(coord, { id = 'minecraft:cobblestone' })
    end

    time.addTickListener(4, regenerateCobblestone)
end

return module
