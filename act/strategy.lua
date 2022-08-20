-- TODO: When ready, I probably should split this module into a "strategy" module and a "scheduler" module.
-- The "strategy" module would be in charge of the big picture, while the "scheduler" would be in charge
-- of working on a single active task and its interruptions.

local util = import('util.lua')

local module = {}

-- onStep is optional
-- A strategy is of the shape { initialTurtlePos=..., projectList=<list of taskRunnerIds> }
function module.exec(strategy, onStep)
    local state = _G.act._state.createInitialState({
        startingPos = strategy.initialTurtlePos,
        projectList = strategy.projectList,
    })
    while #state.projectList > 0 do
        local taskRunnerId = table.remove(state.projectList, 1)

        -- Go through the project task
        state.currentProjectTask = _G.act.task.create(taskRunnerId)
        local currentTaskRunner = _G.act.task.lookup(taskRunnerId)
        while not currentTaskRunner.isExhausted(state.currentProjectTask) do
            state.plan = currentTaskRunner.nextPlan(state, state.currentProjectTask)

            while #state.plan > 0 do
                -- TODO: I need to actually save the state off to a file between each step, and
                -- make it so it can automatically load where it's at from a file if it got interrupted.
                local command = table.remove(state.plan, 1)
                -- Executing a command can put more commands into the plan
                _G.act.commands.execCommand(state, command)

                if onStep ~= nil then onStep() end
            end
        end
        state.currentProjectTask = nil
    end
end

return module