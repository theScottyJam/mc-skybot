-- TODO: When ready, I probably should split this module into a "strategy" module and a "scheduler" module.
-- The "strategy" module would be in charge of the big picture, while the "scheduler" would be in charge
-- of working on a single active task and its interruptions.

local util = require('util')

local module = {}

-- onStep is optional
function module.exec(strategy, onStep)
    local state = _G.act._state.createInitialState({ startingLoc = strategy.initialTurtleLoc })
    while true do
        -- Go through strategy until you find a primary task to do
        while true do
            local step = strategy.steps[state.strategyStepNumber]
            if step == nil then break end
            doStrategyStep(state, step)
            if state.primaryTask == nil then
                state.strategyStepNumber = state.strategyStepNumber + 1
            else
                break
            end
        end

        -- Reached the end without finding a task to do
        if state.primaryTask == nil then break end

        -- Go through primary task
        while true do
            local newProjectState, newShortTermPlan = _G.act.project
                .lookup(state.primaryTask.projectId)
                .nextShortTermPlan(state, state.primaryTask.projectState)

            if newShortTermPlan == nil then
                state.primaryTask = nil
                state.strategyStepNumber = state.strategyStepNumber + 1
                break
            end
            state.primaryTask.projectState = newProjectState
            state.shortTermPlan = newShortTermPlan

            -- for each command in state.shortTermPlan
            while true do
                -- TODO: I need to actually save the state off to a file between each step, and
                -- make it so it can automatically load where it's at from a file if it got interrupted.
                local command = table.remove(state.shortTermPlan, 1)
                if command == nil then
                    break
                end
                -- Executing a command can put more commands into the shortTermPlan
                _G.act.commands.execCommand(state, command)

                if onStep ~= nil then onStep() end
            end
        end
    end
end

function doStrategyStep(state, step)
    if step.type == 'DO_PROJECT' then
        state.primaryTask = {
            projectId = step.value,
            projectState = act.project.lookup(step.value).createProjectState()
        }
    elseif step.type == 'INIT_ENTITY' then
        step.value.init()
    else
        error('Invalid step.type')
    end
end

--[[
    (Not all of these methods are implemented yet)
    initEntity() - Does things like register initial locations.
    updateEntity() - Adds or removes locations from an entity
    provide() - Registers a resource that can always be retrieved when needed
        (might need to be harvested, but there's a plan in place to wait and harvest if needed)
    schedule() - A resource that needs constant attendance to accumulate
    doProject() - Start working on a project
--]]
function module.createBuilder()
    local plan = {}

    local initialTurtleLoc = { x = 0, y = 0, z = 0, face = 'N' }
    local instructions = {}

    function plan.setInitialTurtleLocation(loc)
        initialTurtleLoc = loc
    end

    function plan.initEntity(entityFactory, args)
        local entityInfo = entityFactory.build(args)
        table.insert(instructions, { type = 'INIT_ENTITY', value = { init = entityInfo.init } })
        return entityInfo.entity
    end

    function plan.doProject(projectId)
        table.insert(instructions, { type = 'DO_PROJECT', value = projectId })
    end

    function plan.build()
        return { initialTurtleLoc = initialTurtleLoc, steps = util.copyTable(instructions) }
    end

    return plan
end

return module