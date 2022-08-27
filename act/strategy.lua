local util = import('util.lua')
local stateModule = import('./_state.lua')

local module = {}

-- onStep is optional
-- A strategy is of the shape { initialTurtlePos=..., projectList=<list of taskRunnerIds> }
function module.exec(strategy, onStep)
    local task = _G.act.task

    local state = stateModule.createInitialState({
        startingPos = strategy.initialTurtlePos,
        projectList = strategy.projectList,
    })
    while #state.projectList > 0 do
        -- Prepare the next project task, or resource-fetching task
        local resourcesInInventory = takeInventory(state, onStep)
        local nextProjectTaskRunner = task.lookupTaskRunner(state.projectList[1])
        local resourceCollectionTask = task.collectResources(state, nextProjectTaskRunner, resourcesInInventory)
        if resourceCollectionTask ~= nil then
            state.primaryTask = resourceCollectionTask
        else
            table.remove(state.projectList, 1)
            state.primaryTask = task.create(nextProjectTaskRunner.id)
        end

        -- Check for interruptions
        local interruptTask = _G.act.farm.checkForInterruptions(state, takeInventory(state, onStep))
        if interruptTask ~= nil then
            handleInterruption(state, interruptTask)
        end

        -- Go through the task's plans
        local taskRunnerBeingDone = state.primaryTask.getTaskRunner()
        executePlan(state, onStep, taskRunnerBeingDone.enter(state, state.primaryTask))
        while true do
            executePlan(state, onStep, taskRunnerBeingDone.nextPlan(state, state.primaryTask))
            if state.primaryTask.completed then break end

            -- Handle interruptions
            local interruptTask = _G.act.farm.checkForInterruptions(state, takeInventory(state, onStep))
            if interruptTask ~= nil then
                executePlan(state, onStep, taskRunnerBeingDone.exit(state, state.primaryTask))
                handleInterruption(state, interruptTask)
                executePlan(state, onStep, taskRunnerBeingDone.enter(state, state.primaryTask))
            end
        end
        executePlan(state, onStep, taskRunnerBeingDone.exit(state, state.primaryTask))
        state.primaryTask = nil
    end
end

function handleInterruption(state, interruptTask)
    state.interruptTask = interruptTask
    local taskRunnerBeingDone = state.interruptTask.getTaskRunner()
    executePlan(state, onStep, taskRunnerBeingDone.enter(state, state.interruptTask))
    while not state.interruptTask.completed do
        executePlan(state, onStep, taskRunnerBeingDone.nextPlan(state, state.interruptTask))
    end
    executePlan(state, onStep, taskRunnerBeingDone.exit(state, state.interruptTask))
    _G.act.farm.markFarmTaskAsCompleted(state, state.interruptTask.taskRunnerId)
    state.interruptTask = nil
end

function takeInventory(state, onStep)
    local resourcesInInventory = {}
    for i = 1, 16 do
        local itemDetails = turtle.getItemDetail(i)    
        if itemDetails ~= nil then
            if resourcesInInventory[itemDetails.name] == nil then
                resourcesInInventory[itemDetails.name] = 0
            end
            resourcesInInventory[itemDetails.name] = resourcesInInventory[itemDetails.name] + itemDetails.count
        end
    end
    return resourcesInInventory
end

function executePlan(state, onStep, plan)
    state.plan = plan
    while #state.plan > 0 do
        -- TODO: I need to actually save the state off to a file between each step, and
        -- make it so it can automatically load where it's at from a file if it got interrupted.
        local command = table.remove(state.plan, 1)
        -- Executing a command can put more commands into the plan
        _G.act.commands.execCommand(state, command)

        if onStep ~= nil then onStep() end
    end
end

return module