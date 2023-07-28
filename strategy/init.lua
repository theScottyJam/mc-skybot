local module = {}

if _G.act == nil then error('Must load `act` lib before importing this module') end

local curves = _G.act.curves
local entities = import('./entities/init.lua')
local util = import('util.lua')

local initStrategy
local debugProject
function module.run()
    local strategy = initStrategy()
    _G.act.strategy.exec(strategy)
end

initStrategy = function()
    local project = _G.act.project

    local mainIsland = entities.mainIsland.initEntity()

    return {
        initialTurtlePos = mainIsland.initialLoc.cmps.pos,
        projectList = _G.act.project.createProjectList({
            mainIsland.startBuildingCobblestoneGenerator,
            mainIsland.harvestInitialTreeAndPrepareTreeFarm,
            mainIsland.waitForIceToMeltAndfinishCobblestoneGenerator,
            mainIsland.buildFurnaces,
            mainIsland.smeltInitialCharcoal,
            -- debugProject(mainIsland.homeLoc),
            -- mainIsland.createTower4,
            -- mainIsland.createTower3,
            -- mainIsland.createTower2,
            mainIsland.createTower1,
        }),
    }
end

_G.act.farm.registerValueOfResources({
    ['minecraft:log'] = function(quantitiesOwned)
        return curves.inverseSqrtCurve({ yIntercept = 35, factor = 1/50 })(quantitiesOwned)
    end,
})

debugProject = function(homeLoc)
    local location = _G.act.location
    local navigate = _G.act.navigate
    local highLevelCommands = _G.act.highLevelCommands

    local taskRunnerId = 'project:init:debugProject'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(commands, state, taskState)
            -- location.travelToLocation(planner, homeLoc)
        end,
        nextPlan = function(commands, state, taskState)
            -- local startPos = util.copyTable(planner.turtlePos)
            -- local currentWorld = _G.mockComputerCraftApi._currentWorld
            -- _G._debug.debugCommand(commands, state, { action='obtain', itemId='minecraft:charcoal', quantity=64 })
            _G._debug.debugCommand(commands, state, { action='obtain', itemId='minecraft:log', quantity=64 })
            _G._debug.showStepByStep = true

            -- navigate.moveToPos(planner, startPos)
            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId)
end

return module
