local module = {}

local util = import('util.lua')
local inspect = moduleLoader.tryImport('inspect.lua')
local act = import('act/init.lua')
local mainIsland = import('./mainIsland.lua')
local basicTreeFarm = import('./basicTreeFarm.lua')
local curves = act.curves

local debugProject = inspect.debugProject or function(homeLoc)
    error('No debug project specified in inspect.lua.')
end

function module.register()
    local mainIsland = mainIsland.register()
    local basicTreeFarm = basicTreeFarm.register({ homeLoc = mainIsland.homeLoc })

    return act.Plan.register({
        initialTurtlePos = mainIsland.initialLoc.cmps.pos,
        projectList = {
            -- To run a custom project for debugging purposes, use the following anywhere it's needed:
            --   debugProject(mainIsland.homeLoc),
            mainIsland.initialization,
            mainIsland.startBuildingCobblestoneGenerator,
            mainIsland.harvestInitialTreeAndPrepareTreeFarm,
            mainIsland.waitForIceToMeltAndfinishCobblestoneGenerator,
            mainIsland.buildFurnaces,
            mainIsland.smeltInitialCharcoal,
            mainIsland.torchUpIsland,
            mainIsland.harvestExcessDirt,
            basicTreeFarm.functionalScaffolding,
            mainIsland.tower4,
            mainIsland.tower3,
            mainIsland.tower2,
            mainIsland.tower1,
        },
        valueOfFarmableResources = {
            ['minecraft:log'] = function(quantitiesOwned)
                return curves.inverseSqrtCurve({ yIntercept = 35, factor = 1/50 })(quantitiesOwned)
            end,
        },
    })
end

return module
