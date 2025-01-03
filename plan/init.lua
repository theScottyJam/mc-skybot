local module = {}

local util = import('util.lua')
local inspect = moduleLoader.tryImport('inspect.lua')
local act = import('act/init.lua')
local mainIsland = import('./mainIsland.lua')
local basicTreeFarm = import('./basicTreeFarm.lua')
local curves = act.curves

local mainIsland = mainIsland.init()
local basicTreeFarm = basicTreeFarm.init({ homeLoc = mainIsland.homeLoc })

local debugProject = inspect.debugProject or function(homeLoc)
    error('No debug project specified in inspect.lua.')
end

function module.createPlan()
    return {
        initialTurtlePos = mainIsland.initialLoc.cmps.pos,
        projectList = act.project.createProjectList({
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

act.farm.registerValueOfResources({
    ['minecraft:log'] = function(quantitiesOwned)
        return curves.inverseSqrtCurve({ yIntercept = 35, factor = 1/50 })(quantitiesOwned)
    end,
})

return module
