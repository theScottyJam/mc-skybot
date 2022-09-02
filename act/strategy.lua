local util = import('util.lua')
local stateModule = import('./_state.lua')
local commands = import('./commands/init.lua')

local module = {}

local moduleId = 'act:highLevelCommands'
local genId = commands.createIdGenerator(moduleId)

-- onStep is optional
-- A strategy is of the shape { initialTurtlePos=..., projectList=<list of taskRunnerIds> }
function module.exec(strategy, onStep)
    local task = _G.act.task
    local highLevelCommands = _G.act.highLevelCommands

    function countResourcesInInventoryNow()
        return highLevelCommands.countResourcesInInventory(highLevelCommands.takeInventoryNow())
    end

    local state = stateModule.createInitialState({
        startingPos = strategy.initialTurtlePos,
        projectList = strategy.projectList,
    })
    while #state.projectList > 0 do
        -- Prepare the next project task, or resource-fetching task
        local resourcesInInventory = countResourcesInInventoryNow(state)
        local nextProjectTaskRunner = task.lookupTaskRunner(state.projectList[1])
        local resourceCollectionTask = task.collectResources(state, nextProjectTaskRunner, resourcesInInventory)
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
        executePlan(state, onStep, taskRunnerBeingDone.enter(state, state.primaryTask))
        while true do
            executePlan(state, onStep, taskRunnerBeingDone.nextPlan(state, state.primaryTask))
            if state.primaryTask.completed then break end

            -- Handle interruptions
            local interruptTask = _G.act.farm.checkForInterruptions(state, countResourcesInInventoryNow(state))
            if interruptTask ~= nil then
                executePlan(state, onStep, taskRunnerBeingDone.exit(state, state.primaryTask))
                handleInterruption(state, interruptTask)
                executePlan(state, onStep, taskRunnerBeingDone.enter(state, state.primaryTask))
            end
        end
        executePlan(state, onStep, taskRunnerBeingDone.exit(state, state.primaryTask))
        state.primaryTask = nil
        state.limboVars = {}
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

-- Should be used sparingly. If the plan isn't tied to
-- state, then you can't pause the turtle in the middle of its execution,
-- which is why it's "atomic".
function module.atomicallyExecuteSubplan(state, callback)
    local planner = _G.act.planner.create({ turtlePos = state.turtlePos })
    local maybeFutureId = callback(planner)

    for _, command in pairs(planner.plan) do
        _G.act.commands.execCommand(state, command)
    end

    if maybeFutureId == nil then
        return nil
    else
        return state.getActiveTaskVars()[maybeFutureId]
    end
end

return module