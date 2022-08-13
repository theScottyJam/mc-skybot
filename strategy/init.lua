local module = {}

function module.registerGlobal(base)
    local strategy = {}
  
    strategy.entities = import(base..'entities/init.lua').init(base..'entities/')
  
    _G.strategy = strategy
end

-- onStep is optional
function module.run(onStep)
    if _G.act == nil then error('Must load `act` lib before running the strategy') end

    local strategy = initStrategy()
    _G.act.strategy.exec(strategy, onStep)
end

function initStrategy()
    local plan = _G.act.strategy.createBuilder()

    local mainIsland = plan.initEntity(_G.strategy.entities.mainIsland, {
        bedrockCoord = { x = 0, y = 64, z = -3 }
    })

    plan.setInitialTurtleLocation(mainIsland.homeLoc)
    plan.doProject(mainIsland.buildBasicCobblestoneGenerator)
    -- plan.doProject(mainIsland.harvestInitialTree)

    return plan.build()
end

return module
