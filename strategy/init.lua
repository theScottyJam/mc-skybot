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
    local project = _G.act.project

    local initialTaskList = {}

    local mainIsland = _G.strategy.entities.mainIsland.initEntity({
        bedrockCoord = { forward = 3, right = 0, up = 64, from = 'ORIGIN' }
    })

    local currentConditions = {}
    mainIsland.init.addToInitialTaskList(initialTaskList, currentConditions)
    mainIsland.startBuildingCobblestoneGenerator.addToInitialTaskList(initialTaskList, currentConditions)
    mainIsland.harvestInitialTreeAndPrepareTreeFarm.addToInitialTaskList(initialTaskList, currentConditions)
    mainIsland.waitForIceToMeltAndfinishCobblestoneGenerator.addToInitialTaskList(initialTaskList, currentConditions)
    mainIsland.createCobbleTower.addToInitialTaskList(initialTaskList, currentConditions)

    return {
        initialTurtlePos = mainIsland.initialLoc.pos,
        taskList = initialTaskList,
    }
end

return module
