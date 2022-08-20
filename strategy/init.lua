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

    local steps = {}
    local currentConditions = {}
    function doProject(projectId)
        local projectToAdd = project.lookup(projectId)
        if not projectToAdd.preConditions(currentConditions) then
            error('Project '..projectId..' did not have its pre-conditions satisfied.')
        end

        table.insert(steps, projectId)
        projectToAdd.postConditions(currentConditions)
    end

    local mainIsland = _G.strategy.entities.mainIsland.initEntity({
        bedrockCoord = { forward = 3, right = 0, up = 64, from = 'ORIGIN' }
    })

    doProject(mainIsland.init)
    doProject(mainIsland.prepareCobblestoneGenerator)
    doProject(mainIsland.harvestInitialTreeAndPrepareTreeFarm)
    doProject(mainIsland.waitForIceToMeltAndfinishCobblestoneGenerator)
    doProject(mainIsland.createCobbleTower)

    return {
        initialTurtlePos = mainIsland.initialLoc.pos,
        steps = steps,
    }
end

return module
