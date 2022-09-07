local module = {}

if _G.act == nil then error('Must load `act` lib before importing this module') end

local curves = _G.act.curves
local entities = import('./entities/init.lua')
local util = import('util.lua')

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
            mainIsland.buildFurnaces,
            -- mainIsland.createCobbleTower4,
            -- mainIsland.createCobbleTower3,
            -- mainIsland.createCobbleTower2,
            mainIsland.createCobbleTower1,
            -- debugProject(mainIsland.homeLoc)
        }),
    }
end

_G.act.farm.registerValueOfResources({
    ['minecraft:log'] = function(quantitiesOwned)
        return curves.inverseSqrtCurve({ yIntercept = 35, factor = 1/50 })(quantitiesOwned)
    end,
})

function debugProject(homeLoc)
    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    local homeCmps = space.createCompass(homeLoc.pos)
    local taskRunnerId = 'project:init:debugProject'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(planner, taskState)
            location.travelToLocation(planner, homeLoc)
        end,
        nextPlan = function(planner, taskState)
            local startPos = util.copyTable(planner.turtlePos)
            local currentWorld = _G.mockComputerCraftApi._currentWorld

            -- currentWorld.turtle.inventory[1] = { id = 'minecraft:chest', quantity = 1 }
            -- for i = 3, 16 do
            --     currentWorld.turtle.inventory[i] = { id = 'minecraft:cobblestone', quantity = 64 }
            -- end
            -- highLevelCommands.craft(planner, {
            --     from = {
            --         {'minecraft:cobblestone', 'minecraft:cobblestone', 'minecraft:cobblestone'},
            --         {'minecraft:cobblestone', nil, 'minecraft:cobblestone'},
            --         {'minecraft:cobblestone', 'minecraft:cobblestone', 'minecraft:cobblestone'},
            --     },
            --     to = 'minecraft:furnace',
            --     yields = 1
            -- })

            -- navigate.moveToPos(planner, startPos)
            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId)
end

return module
