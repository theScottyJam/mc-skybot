local util = import('util.lua')
local stateModule = import('./_state.lua')
local commands = import('./_commands.lua')

local module = {}

-- HELPER FUNCTIONS --

local handleInterruption = function(state, interruptTask)
    state.interruptTask = interruptTask
    local taskRunnerBeingDone = state.interruptTask.getTaskRunner()
    taskRunnerBeingDone.enter(state, state.interruptTask)
    while not state.interruptTask.completed do
        taskRunnerBeingDone.nextPlan(state, state.interruptTask)
    end
    taskRunnerBeingDone.exit(state, state.interruptTask)
    _G.act.farm.markFarmTaskAsCompleted(state, state.interruptTask.taskRunnerId)
    state.interruptTask = nil
end

-- PUBLIC FUNCTIONS --

-- A strategy is of the shape { initialTurtlePos=..., projectList=<list of taskRunnerIds> }
function module.exec(strategy)
    local task = _G.act.task
    local highLevelCommands = _G.act.highLevelCommands

    local countResourcesInInventory = function(state)
        return highLevelCommands.countResourcesInInventory(highLevelCommands.takeInventory(commands, state))
    end

    local state = stateModule.createInitialState({
        startingPos = strategy.initialTurtlePos,
        projectList = strategy.projectList,
    })
    while #state.projectList > 0 do
        -- Prepare the next project task, or resource-fetching task
        local resourcesInInventory = countResourcesInInventory(state)
        local nextProject = _G.act.project.lookup(state.projectList[1])
        local nextProjectTaskRunner = task.lookupTaskRunner(state.projectList[1])
        local resourceCollectionTask = task.collectResources(state, nextProject, resourcesInInventory)
        if resourceCollectionTask ~= nil then
            state.primaryTask = resourceCollectionTask
        else
            table.remove(state.projectList, 1)
            state.primaryTask = task.create(nextProjectTaskRunner.id)
        end

        -- Check for interruptions
        local interruptTask = _G.act.farm.checkForInterruptions(state, resourcesInInventory)
        if interruptTask ~= nil then
            handleInterruption(state, interruptTask)
        end

        -- Go through the task's plans
        local taskRunnerBeingDone = state.primaryTask.getTaskRunner()
        taskRunnerBeingDone.enter(state, state.primaryTask)
        while true do
            taskRunnerBeingDone.nextPlan(state, state.primaryTask)
            if state.primaryTask.completed then break end

            -- Handle interruptions
            local interruptTask = _G.act.farm.checkForInterruptions(state, countResourcesInInventory(state))
            if interruptTask ~= nil then
                taskRunnerBeingDone.exit(state, state.primaryTask)
                handleInterruption(state, interruptTask)
                taskRunnerBeingDone.enter(state, state.primaryTask)
            end
        end
        taskRunnerBeingDone.exit(state, state.primaryTask)
        state.primaryTask = nil
    end
end

return module