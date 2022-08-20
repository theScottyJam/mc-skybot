local module = {}

local projectRegistry = {}

-- opts.requiredResources is an optional mapping of resource names to quantities.
--   Fetching these resources must be done before the project starts.
-- opts.createProjectState() returns any arbitrary record.
--   If not provided, it default to an empty record.
-- opts.nextShortTermPlan() takes a state and project state and returns a tuple
--   containing an updated project state and a short-term plan.
--   Return `nil` for the project state to signal that the project will be complete
--   once the returned plan finishes.
function module.register(id, opts)
    local createProjectState = opts.createProjectState or function() return {} end
    local nextShortTermPlan = opts.nextShortTermPlan
    local requiredResources = opts.requiredResources or {}

    projectRegistry[id] = {
        requiredResources = requiredResources,
        -- Takes a state and a reference to this task.
        -- Returns a shortTermPlan.
        nextStep = function(state, currentTask)
            if currentTask.stage == nil then
                currentTask.stage = 'RESOURCE_FETCHING'
                -- A mapping of resources collected to `true` if it was done,
                -- or `nil` if it needs to be done.
                currentTask.projectState = {}
            elseif currentTask.stage == 'EXHAUSTED' then
                error('This project is already finished')
            end

            if currentTask.stage == 'RESOURCE_FETCHING' then
                for resourceName, quantity in pairs(requiredResources) do
                    if currentTask.projectState[resourceName] == nil then
                        currentTask.projectState[resourceName] = true
                        return collectResource(state, resourceName, quantity)
                    end
                end
                currentTask.stage = 'EXECUTING'
                currentTask.projectState = createProjectState()
            end

            local newProjectState, newShortTermPlan = nextShortTermPlan(state, currentTask.projectState)
            currentTask.projectState = newProjectState

            if newProjectState == nil then
                currentTask.stage = 'EXHAUSTED'
            end
            return newShortTermPlan
        end,
        -- "exhausted" means all steps have been given.
        -- It might not be "complete" yet, as it's unknown if those steps have been carried out.
        isExhausted = function(currentTask)
            return currentTask.stage == 'EXHAUSTED'
        end
    }
    return id
end

function collectResource(state, resourceName, quantity)
    local resource = state.resourceSuppliers[resourceName][1]
    if resource.type ~= 'mill' then error('Invalid resource type') end
    local mill = _G.act.mill.lookup(resource.millId)
    return mill.harvest(state, { [resourceName] = quantity })
end

function module.lookup(projectId)
    return projectRegistry[projectId]
end

return module