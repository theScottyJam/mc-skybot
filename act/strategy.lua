-- TODO: When ready, I probably should split this module into a "strategy" module and a "scheduler" module.
-- The "strategy" module would be in charge of the big picture, while the "scheduler" would be in charge
-- of working on a single active task and its interruptions.

local util = import('util.lua')

local module = {}

-- onStep is optional
-- A strategy is of the shape { initialTurtlePos=..., projectList=<list of taskRunnerIds> }
function module.exec(strategy, onStep)
    local task = _G.act.task

    local state = _G.act._state.createInitialState({
        startingPos = strategy.initialTurtlePos,
        projectList = strategy.projectList,
    })
    while #state.projectList > 0 do
        local resourcesInInventory = takeInventory(state, onStep)
        local nextProjectTaskRunner = task.lookupTaskRunner(state.projectList[1])
        local resourceCollectionTask = task.collectResources(state, nextProjectTaskRunner, resourcesInInventory)
        if resourceCollectionTask ~= nil then
            state.activeTask = resourceCollectionTask
        else
            table.remove(state.projectList, 1)
            state.activeTask = task.create(nextProjectTaskRunner.id)
        end

        -- Go through the task's plans
        local taskRunnerBeingDone = state.activeTask.getTaskRunner()
        executePlan(state, onStep, taskRunnerBeingDone.enter(state, state.activeTask))
        while not state.activeTask.completed do
            executePlan(state, onStep, taskRunnerBeingDone.nextPlan(state, state.activeTask))
        end
        executePlan(state, onStep, taskRunnerBeingDone.exit(state, state.activeTask))
        state.activeTask = nil
    end
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