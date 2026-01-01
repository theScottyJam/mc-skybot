local time = import('./_time.lua')
local worldTools = import('./worldTools.lua')

local module = {}

-- `coord` is an x/y/z coordinate.
function module.registerCobblestoneRegenerationBlock(coord)
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
