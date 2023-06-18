local module = {}

if _G.act == nil then error('Must load `act` lib before importing this module') end

local curves = _G.act.curves
local entities = import('./entities/init.lua')
local util = import('util.lua')

-- onStep is optional
local initStrategy
local debugProject
function module.run(onStep)
    local strategy = initStrategy()
    _G.act.strategy.exec(strategy, onStep)
end

initStrategy = function()
    local project = _G.act.project

    local mainIsland = entities.mainIsland.initEntity()

    return {
        initialTurtlePos = mainIsland.initialLoc.pos,
        projectList = _G.act.project.createProjectList({
            mainIsland.startBuildingCobblestoneGenerator,
            mainIsland.harvestInitialTreeAndPrepareTreeFarm,
            mainIsland.waitForIceToMeltAndfinishCobblestoneGenerator,
            mainIsland.buildFurnaces,
            debugProject(mainIsland.homeLoc),
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
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    local homeCmps = space.createCompass(homeLoc.pos)
    local taskRunnerId = 'project:init:debugProject'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(planner, taskState)
            -- location.travelToLocation(planner, homeLoc)
        end,
        nextPlan = function(planner, taskState)
            -- local startPos = util.copyTable(planner.turtlePos)
            -- local currentWorld = _G.mockComputerCraftApi._currentWorld
            _G._debug.debugCommand(planner, { action='obtain', itemId='minecraft:charcoal', quantity=64 })
            _debug.showStepByStep = true

            -- navigate.moveToPos(planner, startPos)
            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId)
end

return module
