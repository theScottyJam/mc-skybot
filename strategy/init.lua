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

    local projectList = {}

    local mainIsland = _G.strategy.entities.mainIsland.initEntity({
        bedrockCoord = { forward = 3, right = 0, up = 64, from = 'ORIGIN' }
    })

    local currentConditions = {}
    mainIsland.init.addToProjectList(projectList, currentConditions)
    mainIsland.startBuildingCobblestoneGenerator.addToProjectList(projectList, currentConditions)
    mainIsland.harvestInitialTreeAndPrepareTreeFarm.addToProjectList(projectList, currentConditions)
    mainIsland.waitForIceToMeltAndfinishCobblestoneGenerator.addToProjectList(projectList, currentConditions)
    mainIsland.createCobbleTower.addToProjectList(projectList, currentConditions)

    return {
        initialTurtlePos = mainIsland.initialLoc.pos,
        projectList = projectList,
    }
end

return module
