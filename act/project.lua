local module = {}

local projectRegistry = {}

local startingConditionInitializers = {}

-- taskRunnerId - the task assosiated with this project.
-- opts.requiredResources (optional) is a mapping of resource names to tables
--   of the shape { quantity=..., at='INVENTORY' }
--   Fetching these resources must be done before the project starts.
-- opts.preConditions() (optional) takes a currentConditions, and returns true if all
--   pre-conditions are met.
-- opts.postConditions() (optional) takes a currentConditions, and mutates it to state
--   what conditions have been fulfilled.
function module.create(taskRunnerId, opts)
    opts = opts or {}
    local requiredResources = opts.requiredResources or {}
    local preConditions = opts.preConditions or function() return true end
    local postConditions = opts.postConditions or function() end

    local project = {
        taskRunnerId = taskRunnerId,
        requiredResources = requiredResources,
        preConditions = preConditions,
        postConditions = postConditions,
    }

    projectRegistry[taskRunnerId] = project
    return project
end

function module.registerStartingConditionInitializer(startingConditionInitializer)
    table.insert(startingConditionInitializers, startingConditionInitializer)
end

function module.createProjectList(projects)
    local currentConditions = {}
    for _, initializer in ipairs(startingConditionInitializers) do
        initializer(currentConditions)
    end

    local projectList = {}
    for _, project in pairs(projects) do
        if not project.preConditions(currentConditions) then
            error('Project '..project.taskRunnerId..' did not have its pre-conditions satisfied.')
        end

        table.insert(projectList, project.taskRunnerId)
        project.postConditions(currentConditions)
    end
    return projectList
end

function module.lookup(projectTaskRunnerId)
    return projectRegistry[projectTaskRunnerId]
end

return module