local util = import('util.lua')
local TaskFactory = import('./_TaskFactory.lua')
local serializer = import('../_serializer.lua')

local static = {}
local prototype = {}

local startingConditionInitializers = {}

--[[
Inputs:
    id: string
    opts?.requiredResources
        A mapping of resource names to tables
        of the shape { quantity=..., at='INVENTORY' }
        Fetching these resources must be done before the project starts.
    opts?.preConditions(currentConditions): boolean
        Returns true if all pre-conditions are met.
    opts?.postConditions(currentConditions)
        Mutates currentConditions to state what conditions have been fulfilled.
    ...taskFactoryOpts
        Any options accepted by the generate-task-factory function
        can also be used here.
]]
function static.register(opts)
    opts = util.copyTable(opts)
    local id = 'project:'..opts.id
    local requiredResources_ = opts.requiredResources or {}
    local preConditions = opts.preConditions or function() return true end
    local postConditions = opts.postConditions or function() end
    opts.id = nil
    opts.requiredResources = nil
    opts.preConditions = nil
    opts.postConditions = nil

    local taskFactory = TaskFactory.register(
        util.mergeTables(opts, { id = id })
    )

    -- Reshape requiredResources in a way that's easier to process.
    local requiredResources = {}
    for resourceName, requirementInfo in pairs(requiredResources_) do
        if requirementInfo.at ~= 'INVENTORY' then error('Only at="INVENTORY" is supported right now.') end
        requiredResources[resourceName] = requirementInfo.quantity
    end

    local project = util.attachPrototype(prototype, {
        -- Used for introspection, so if others want to display this project, they have a name to display it by.
        displayName = id,
        _taskFactory = taskFactory,
        _preConditions = preConditions,
        _postConditions = postConditions,
        -- Maps resource names to quantities
        requiredResources = requiredResources,
    })
    serializer.registerValue(id, project)

    return project
end

function prototype:__createTask()
    return self._taskFactory:createTask()
end

-- Use this to insert initial data into the currentConditions table that gets
-- passed into the project's preConditions() and postConditions() functions.
function static.registerStartingConditionInitializer(startingConditionInitializer)
    table.insert(startingConditionInitializers, startingConditionInitializer)
end

-- Verify that a list of projects can be accomplished in the order given, by going through each
-- project's pre and post conditions.
function static.__validateProjectList(projects)
    local currentConditions = {}
    for _, initializer in ipairs(startingConditionInitializers) do
        initializer(currentConditions)
    end

    for _, project in pairs(projects) do
        if not project._preConditions(currentConditions) then
            error('Project '..project.displayName..' did not have its pre-conditions satisfied.')
        end

        project._postConditions(currentConditions)
    end
end

return static