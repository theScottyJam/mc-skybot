local module = {}

if _G.act == nil then error('Must load `act` lib before importing this module') end

local curves = _G.act.curves
local entities = import('./entities/init.lua')

-- onStep is optional
function module.run(onStep)
    local strategy = initStrategy()
    _G.act.strategy.exec(strategy, onStep)
end

function initStrategy()
    local project = _G.act.project

    local projectList = {}

    local mainIsland = entities.mainIsland.initEntity()

    return {
        initialTurtlePos = mainIsland.initialLoc.pos,
        projectList = _G.act.project.createProjectList({
            mainIsland.startBuildingCobblestoneGenerator,
            mainIsland.harvestInitialTreeAndPrepareTreeFarm,
            mainIsland.waitForIceToMeltAndfinishCobblestoneGenerator,
            mainIsland.createCobbleTower4,
            mainIsland.createCobbleTower3,
            mainIsland.createCobbleTower2,
            mainIsland.createCobbleTower1,
        }),
    }
end

_G.act.farm.registerValueOfResources({
    ['minecraft:log'] = function(quantitiesOwned)
        return curves.inverseSqrtCurve({ yIntercept = 35, factor = 1/50 })(quantitiesOwned)
    end,
})

return module
