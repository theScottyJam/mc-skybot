local module = {}

function module.init(base)
    local entities = {}

    entities.mainIsland = import(base..'mainIsland.lua').init()

    return entities
end

return module