local module = {}

if _G.act == nil then error('Must load `act` lib before importing this module') end

local curves = _G.act.curves
local util = import('util.lua')
local inspect = tryImport('inspect.lua')
local mainIsland = import('./mainIsland.lua')
local basicTreeFarm = import('./basicTreeFarm.lua')

local initStrategy
function module.run()
    local strategy = initStrategy()
    _G.act.strategy.exec(strategy)
end

local debugProject = inspect.debugProject or function(homeLoc)
    error('No debug project specified in inspect.lua.')
end

initStrategy = function()
    local project = _G.act.project

    local mainIsland = mainIsland.initEntity()
    local basicTreeFarm = basicTreeFarm.initEntity({ homeLoc = mainIsland.homeLoc })

    return {
        initialTurtlePos = mainIsland.initialLoc.cmps.pos,
        projectList = _G.act.project.createProjectList({
            -- To run a custom project for debugging purposes, use the following anywhere it's needed:
            --   debugProject(mainIsland.homeLoc),
            mainIsland.startBuildingCobblestoneGenerator,
            mainIsland.harvestInitialTreeAndPrepareTreeFarm,
            mainIsland.waitForIceToMeltAndfinishCobblestoneGenerator,
            mainIsland.buildFurnaces,
            mainIsland.smeltInitialCharcoal,
            mainIsland.torchUpIsland,
            mainIsland.harvestExcessDirt,
            basicTreeFarm.createFunctionalScaffolding,
            mainIsland.createTower4,
            mainIsland.createTower3,
            mainIsland.createTower2,
            mainIsland.createTower1,
        }),
    }
end

_G.act.farm.registerValueOfResources({
    ['minecraft:log'] = function(quantitiesOwned)
        return curves.inverseSqrtCurve({ yIntercept = 35, factor = 1/50 })(quantitiesOwned)
    end,
})

return module
