-- TODO: When ready, I probably should split this module into a "strategy" module and a "scheduler" module.
-- The "strategy" module would be in charge of the big picture, while the "scheduler" would be in charge
-- of working on a single active task and its interruptions.

local util = import('util.lua')

local module = {}

-- onStep is optional
-- A strategy is of the shape { initialTurtlePos=..., steps=<list of projectIds> }
function module.exec(strategy, onStep)
    local state = _G.act._state.createInitialState({ startingPos = strategy.initialTurtlePos })
    for i, projectId in ipairs(strategy.steps) do
        state.strategyStepNumber = i
        state.primaryTask = initTask(projectId)

        -- Go through primary task
        local currentProject = _G.act.project.lookup(state.primaryTask.projectId)
        while not currentProject.isExhausted(state.primaryTask) do
            state.shortTermPlan = currentProject.nextStep(state, state.primaryTask)

            -- for each command in state.shortTermPlan
            while #state.shortTermPlan > 0 do
                -- TODO: I need to actually save the state off to a file between each step, and
                -- make it so it can automatically load where it's at from a file if it got interrupted.
                local command = table.remove(state.shortTermPlan, 1)
                -- Executing a command can put more commands into the shortTermPlan
                _G.act.commands.execCommand(state, command)

                if onStep ~= nil then onStep() end
            end
        end
        state.primaryTask = nil
    end
end

function initTask(projectId)
    return {
        projectId = projectId,
        stage = nil,
        projectState = nil,
        projectVars = {},
    }
end

return module