-- TODO: When ready, I probably should split this module into a "strategy" module and a "scheduler" module.
-- The "strategy" module would be in charge of the big picture, while the "scheduler" would be in charge
-- of working on a single active task and its interruptions.

local util = import('util.lua')

local module = {}

-- onStep is optional
-- A strategy is of the shape { initialTurtlePos=..., taskList=<list of taskIds> }
function module.exec(strategy, onStep)
    local state = _G.act._state.createInitialState({ startingPos = strategy.initialTurtlePos })
    for i, taskId in ipairs(strategy.taskList) do
        state.strategyStepNumber = i
        state.primaryTask = _G.act.task.create(taskId)

        -- Go through primary task
        local currentTask = _G.act.task.lookup(state.primaryTask.taskId)
        while not currentTask.isExhausted(state.primaryTask) do
            state.plan = currentTask.nextPlan(state, state.primaryTask)

            -- for each command in state.plan
            while #state.plan > 0 do
                -- TODO: I need to actually save the state off to a file between each step, and
                -- make it so it can automatically load where it's at from a file if it got interrupted.
                local command = table.remove(state.plan, 1)
                -- Executing a command can put more commands into the plan
                _G.act.commands.execCommand(state, command)

                if onStep ~= nil then onStep() end
            end
        end
        state.primaryTask = nil
    end
end

return module