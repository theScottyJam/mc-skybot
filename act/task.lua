--[[
    A "taskRunner" holds the logic assosiated with a specific task, while a "task" holds the state.
--]]

local module = {}

local taskRegistry = {}

-- opts.requiredResources (optional) is a mapping of resource names to quantities.
--   Fetching these resources must be done before the project starts.
-- opts.createTaskState() (optional) returns any arbitrary record.
--   If not provided, it default to an empty record.
-- opts.nextExecutionPlan() takes a state and project state and returns a tuple
--   containing an updated project state and a plan.
--   Return `nil` for the project state to signal that the project will be complete
--   once the returned plan finishes.
function module.registerTaskRunner(id, opts)
    local createTaskState = opts.createTaskState or function() return {} end
    local nextExecutionPlan = opts.nextExecutionPlan
    local requiredResources = opts.requiredResources or {}

    taskRegistry[id] = {
        requiredResources = requiredResources,
        -- Takes a state and a reference to this task.
        -- Returns a plan.
        nextPlan = function(state, currentTask)
            if currentTask.stage == nil then
                currentTask.stage = 'RESOURCE_FETCHING'
                -- A mapping of resources collected to `true` if it was done,
                -- or `nil` if it needs to be done.
                currentTask.taskState = {}
            elseif currentTask.stage == 'EXHAUSTED' then
                error('This project is already finished')
            end

            if currentTask.stage == 'RESOURCE_FETCHING' then
                for resourceName, quantity in pairs(requiredResources) do
                    if currentTask.taskState[resourceName] == nil then
                        currentTask.taskState[resourceName] = true
                        return collectResource(state, resourceName, quantity)
                    end
                end
                currentTask.stage = 'EXECUTING'
                currentTask.taskState = createTaskState()
            end

            local newTaskState, newPlan = nextExecutionPlan(state, currentTask.taskState)
            currentTask.taskState = newTaskState

            if newTaskState == nil then
                currentTask.stage = 'EXHAUSTED'
            end
            return newPlan
        end,
        -- "exhausted" means all steps have been given.
        -- It might not be "complete" yet, as it's unknown if those steps have been carried out.
        isExhausted = function(currentTask)
            return currentTask.stage == 'EXHAUSTED'
        end
    }
    return id
end

function module.create(taskId)
    return {
        taskId = taskId,
        -- Are we actively doing this task? Gathering resources? Is it done?
        stage = nil,
        -- Arbitrary state, to help keep track of what's going on between interruptions
        taskState = nil,
        -- Contains the values of futures
        taskVars = {},
    }
end

function collectResource(state, resourceName, quantity)
    if state.resourceSuppliers[resourceName] == nil then
        error('The next task requires the resource '..resourceName..', but there are no registered sources for this resource.')
    end
    local resource = state.resourceSuppliers[resourceName][1]
    if resource.type ~= 'mill' then error('Invalid resource type') end
    local mill = _G.act.mill.lookup(resource.millId)
    return mill.harvest(state, { [resourceName] = quantity })
end

function module.lookup(taskId)
    return taskRegistry[taskId]
end

return module