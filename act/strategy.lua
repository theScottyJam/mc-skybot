local util = import('util.lua')
local stateModule = import('./_state.lua')
local commands = import('./_commands.lua')
local inspect = tryImport('inspect.lua')

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

    local countNonReservedResourcesInInventory = function(state)
        local resourcesInInventory = util.copyTable(
            highLevelCommands.countResourcesInInventory(highLevelCommands.takeInventory(commands, state))
        )

        -- At least one charcoal is reserved so if you need to smelt something, you can get more charcoal to do so.
        if resourcesInInventory['minecraft:charcoal'] ~= nil then
            resourcesInInventory['minecraft:charcoal'] = resourcesInInventory['minecraft:charcoal'] - 1 or nil
            if resourcesInInventory['minecraft:charcoal'] == 0 then
                resourcesInInventory['minecraft:charcoal'] = nil
            end
        end

        return resourcesInInventory
    end

    local state = stateModule.createInitialState({
        startingPos = strategy.initialTurtlePos,
        projectList = strategy.projectList,
    })
    local isIdling = false
    while #state.projectList > 0 do
        -- Prepare the next project task, or resource-fetching task
        local resourcesInInventory = countNonReservedResourcesInInventory(state)
        local nextProject = _G.act.project.lookup(state.projectList[1])
        local nextProjectTaskRunner = task.lookupTaskRunner(state.projectList[1])
        local resourceCollectionTask = task.collectResources(state, nextProject, resourcesInInventory)
        if resourceCollectionTask ~= nil then
            -- This "act:idle" id is defined elsewhere. §7kUI2
            if not isIdling and resourceCollectionTask.taskRunnerId == 'act:idle' then
                isIdling = true
                if inspect.onIdleStart ~= nil then
                    inspect.onIdleStart()
                end
            end
            if isIdling and resourceCollectionTask.taskRunnerId ~= 'act:idle' then
                isIdling = false
                if inspect.onIdleEnd ~= nil then
                    inspect.onIdleEnd()
                end
            end
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
            local interruptTask = _G.act.farm.checkForInterruptions(
                state,
                highLevelCommands.countResourcesInInventory(highLevelCommands.takeInventory(commands, state))
            )
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