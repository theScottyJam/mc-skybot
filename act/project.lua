local module = {}

local projectRegistry = {}

local startingConditionInitializers = {}

-- taskRunnerId - the task associated with this project.
-- opts.requiredResources (optional) is a mapping of resource names to tables
--   of the shape { quantity=..., at='INVENTORY', consumed=false }
--   Fetching these resources must be done before the project starts.
--
--   The `consumed` property is optional and currently ignored.
--   It is used to indicate that the resource will still be available to be used
--   after this project has completed. It's not so important right now (which is why
--   its unused), because this knowledge only matters if you're trying to gather
--   resources for the next task, after this current task has finished.
-- opts.preConditions() (optional) takes a currentConditions, and returns true if all
--   pre-conditions are met.
-- opts.postConditions() (optional) takes a currentConditions, and mutates it to state
--   what conditions have been fulfilled.
function module.create(taskRunnerId, opts)
    opts = opts or {}
    local requiredResources_ = opts.requiredResources or {}
    local preConditions = opts.preConditions or function() return true end
    local postConditions = opts.postConditions or function() end

    -- Reshape requiredResources in a way that's easier to process.
    local requiredResources = {}
    for resourceName, requirementInfo in pairs(requiredResources_) do
        if requirementInfo.at ~= 'INVENTORY' then error('Only at="INVENTORY" is supported right now.') end
        requiredResources[resourceName] = requirementInfo.quantity
    end

    local project = {
        taskRunnerId = taskRunnerId,
        -- Maps resource names to quantities
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

--<-- Only used within act/
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