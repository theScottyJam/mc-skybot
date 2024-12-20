--[[
    A "taskRunner" holds the logic associated with a specific task, while a "task" holds the state.
--]]

local util = import('util.lua')
local stateModule = import('./_state.lua')
local commands = import('./_commands.lua')
local highLevelCommands = import('./highLevelCommands.lua')
local mill = import('./mill.lua')

local module = {}

local taskRegistry = {}

--[[
inputs:
  opts.createTaskState() (optional) returns any arbitrary table.
    If not provided, it default to an empty table.
  opts.enter() (optional) takes commands, state, and taskState. It will run before the task
    starts and whenever the task continues after an interruption, and is supposed
    to bring the turtle from anywhere in the world to a desired position.
  opts.exit() (optional) takes commands, state, taskState, and an info object. The info object
    contains a "complete" boolean property that indicates if the task has been completed at this point.
    This function will run after the task finishes and whenever the task needs to pause
    for an interruption, and is supposed to bring the turtle to the position of a registered location.
    After completing a mill or farm, you may also activate those in this function.
  opts.nextSprint() takes commands, state, a taskState, and any other arbitrary
    arguments it might need and returns a tuple containing an updated task state and
    a "complete" boolean, which, when true, indicates that the sprint finished
    (i.e. it is not at an interruption point).
--]]
function module.registerTaskRunner(id, opts)
    local createTaskState = opts.createTaskState or function() return {} end
    local enter = opts.enter or function() end
    local exit = opts.exit or function() end
    local nextSprint = opts.nextSprint

    if taskRegistry[id] ~= nil then error('A taskRunner with that id already exists') end
    taskRegistry[id] = {
        id = id,

        -- Takes a state and a reference to this task.
        enter = function(state, currentTask)
            if not currentTask.initialized then
                currentTask.initialized = true
                currentTask.taskState = createTaskState()
            end

            enter(commands, state, currentTask.taskState)
            currentTask.entered = true
        end,

        -- Takes a state and a reference to this task.
        exit = function(state, currentTask)
            exit(commands, state, currentTask.taskState, { complete = currentTask.completed })
            currentTask.entered = false
        end,

        -- Takes a state and a reference to this task.
        nextSprint = function(state, currentTask)
            if currentTask.completed == true then
                error('This task is already finished')
            end

            local newTaskState, complete = nextSprint(commands, state, currentTask.taskState, currentTask.args)
            currentTask.taskState = newTaskState
            currentTask.completed = complete
        end
    }
    return id
end

-- What to do when there's nothing to do
local idleTaskRunner = module.registerTaskRunner('act:idle', { -- This "act:idle" id is also used elsewhere, see §7kUI2
    nextSprint = function(commands, state, taskState)
        highLevelCommands.busyWait(commands, state)
        return taskState, true
    end,
})

--<-- Only used within act/
-- Returns a task that will collect some of the required resources, or nil if there
-- aren't any requirements left to fulfill.
function module.collectResources(state, project, resourcesInInventory_)
    local resourceMap = {}
    local resourcesInInventory = util.copyTable(resourcesInInventory_)

    -- Collect the nested requirement tree into a flat mapping (resourceMap)
    -- Factors in your inventory's contents to figure out what's needed.

    local requiredResourcesToProcess = util.copyTable(project.requiredResources)
    while util.tableSize(requiredResourcesToProcess) > 0 do
        local resourceName, requiredQuantity = util.getASortedEntry(requiredResourcesToProcess)
        requiredResourcesToProcess[resourceName] = nil
        -- Factor in quantities from the inventory
        local contributionFromInventory = 0
        if resourcesInInventory[resourceName] ~= nil then
            contributionFromInventory = util.minNumber(
                resourcesInInventory[resourceName],
                requiredQuantity
            )
            resourcesInInventory[resourceName] = resourcesInInventory[resourceName] - contributionFromInventory
            if resourcesInInventory[resourceName] == 0 then resourcesInInventory[resourceName] = nil end
        end

        -- If, after factoring in the inventory, there's still requirements to be fulfilled...
        local insufficientResourcesOnHand = contributionFromInventory < requiredQuantity

        if insufficientResourcesOnHand then
            if state.resourceSuppliers[resourceName] == nil then
                error(
                    'Attempted to start the task "'..project.taskRunnerId..
                    '" that requires the resource '..resourceName..', '..
                    'but there are no registered sources for this resource, nor is there enough of it on hand.'
                )
            end
            local supplier = state.resourceSuppliers[resourceName][1]

            if supplier.type == 'farm' then
                if resourceMap[resourceName] == nil then
                    resourceMap[resourceName] = {
                        type = 'farm'
                    }
                else
                    -- If this throws, it means there was a conflict, and some other non-farm action
                    -- got registered as being capable of supplying this resource. But at the moment,
                    -- having multiple suppliers for a single resource is not supported.
                    util.assert(resourceMap[resourceName].type == 'farm')
                end
            elseif supplier.type == 'mill' then
                if resourceMap[resourceName] == nil then
                    local subTaskRunner = module.lookupTaskRunner(supplier.taskRunnerId)
                    resourceMap[resourceName] = {
                        type = 'mill',
                        quantity = 0,
                        taskRunner = subTaskRunner,
                    }
                else
                    util.assert(resourceMap[resourceName].type == 'mill')
                end

                local previousQuantity = resourceMap[resourceName].quantity
                local previousRequiredResources = mill.getRequiredResources(
                    supplier.taskRunnerId,
                    { resourceName = resourceName, quantity = previousQuantity }
                )

                local newQuantity = resourceMap[resourceName].quantity + requiredQuantity
                local requiredResources = mill.getRequiredResources(
                    supplier.taskRunnerId,
                    { resourceName = resourceName, quantity = newQuantity }
                )

                for dependentResourceName, previousDependentQuantity in util.sortedMapTablePairs(previousRequiredResources) do
                    -- It's possible this assertion isn't really necessary, and we could maybe remove it with little to no changes
                    -- if we really need to. This kind of behavior just hasn't been tested yet.
                    util.assert(
                        requiredResources[dependentResourceName] ~= nil and requiredResources[dependentResourceName] >= previousDependentQuantity,
                        'getRequiredResources() currently must return larger quantities whenever larger requests are passed in. ' ..
                        'The quantities can never shrink.'
                    )
                end

                for dependentResourceName, dependentQuantity in util.sortedMapTablePairs(requiredResources) do
                    if requiredResourcesToProcess[dependentResourceName] == nil then
                        requiredResourcesToProcess[dependentResourceName] = 0
                    end
                    local dependentQuantityDiff = dependentQuantity - previousRequiredResources[dependentResourceName]
                    -- Only adding the difference, because the quantity from previousRequiredResources should already be accounted for.
                    requiredResourcesToProcess[dependentResourceName] = requiredResourcesToProcess[dependentResourceName] + dependentQuantityDiff
                end

                resourceMap[resourceName].quantity = newQuantity
            else
                error('Invalid supplier type "'..tostring(supplier.type)..'" found when trying to fetch the resource '..resourceName)
            end
        end
    end

    if util.tableSize(resourceMap) == 0 then
        -- Return nil if there aren't any additional resources that need to be collected.
        return nil
    end

    -- Loop over the mapping, looking for an entry that has all of its requirements satisfied.
    -- Right now it uses the first found requirement. In the future we could use the closest task instead.
    for resourceName, resourceInfo in util.sortedMapTablePairs(resourceMap) do
        if resourceInfo.type == 'mill' then
            local requirementsFulfilled = true
            local requiredResources = mill.getRequiredResources(
                resourceInfo.taskRunner.id,
                { resourceName = resourceName, quantity = resourceInfo.quantity }
            )
            for subResourceName, _ in pairs(requiredResources) do
                if resourceMap[subResourceName] ~= nil then
                    requirementsFulfilled = false
                    break
                end
            end

            if requirementsFulfilled then
                return module.create(resourceInfo.taskRunner.id, { [resourceName] = resourceInfo.quantity })
            end
        end
    end

    -- It's assumed we got to this point because there is no active "mill" work that could be done,
    -- but there are farms we need to wait on.
    return module.create(idleTaskRunner)
end

-- args is optional
function module.create(taskRunnerId, args)
    return {
        taskRunnerId = taskRunnerId,
        -- Auto-initializes the first time you request a sprint
        initialized = false,
        -- "complete" means you've requested the last available sprint.
        -- It doesn't necessarily mean all requested sprints have been executed.
        completed = false,
        -- true when enter() gets called. false when exit() gets called.
        entered = false,
        -- Arbitrary state, to help keep track of what's going on between interruptions
        taskState = nil,
        -- Configuration for the task
        args = args,

        getTaskRunner = function()
            return module.lookupTaskRunner(taskRunnerId)
        end,
    }
end

function module.lookupTaskRunner(taskRunnerId)
    return taskRegistry[taskRunnerId]
end

return module