--[[
    A "taskRunner" holds the logic assosiated with a specific task, while a "task" holds the state.
--]]

local util = import('util.lua')
local stateModule = import('./_state.lua')
local commands = import('./_commands.lua')
local highLevelCommands = import('./highLevelCommands.lua')

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
  opts.nextPlan() takes commands, state, a taskState, and any other arbitrary
    arguments it might need and returns a tuple containing an updated task state and
    a "complete" boolean, which, when true, indicates that the plan finished
    (i.e. it is not at an interruption point).
--]]
function module.registerTaskRunner(id, opts)
    local createTaskState = opts.createTaskState or function() return {} end
    local enter = opts.enter or function() end
    local exit = opts.exit or function() end
    local nextPlan = opts.nextPlan

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
        nextPlan = function(state, currentTask)
            if currentTask.completed == true then
                error('This task is already finished')
            end

            local newTaskState, complete = nextPlan(commands, state, currentTask.taskState, currentTask.args)
            currentTask.taskState = newTaskState
            currentTask.completed = complete
        end
    }
    return id
end

-- What to do when there's nothing to do
local busyWaitTaskRunner = module.registerTaskRunner('act:busyWait', {
    nextPlan = function(commands, state, taskState)
        highLevelCommands.busyWait(commands, state)
        return taskState, true
    end,
})

-- Returns a task that will collect some of the required resources, or nil if there
-- aren't any requirements left to fulfill.
function module.collectResources(state, initialProject, resourcesInInventory_)
    local resourceMap = {}
    local resourcesInInventory = util.copyTable(resourcesInInventory_)

    -- Collect the nested requirement tree into a flat mapping (resourceMap)
    -- Factors in your inventory's contents to figure out what's needed.

    local requiredResourcesToProcess = util.copyTable(initialProject.requiredResources)
    while util.tableSize(requiredResourcesToProcess) > 0 do
        local resourceName, requiredQuantity = util.getAnEntry(requiredResourcesToProcess)
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
        local insuffecientResourcesOnHand = contributionFromInventory < requiredQuantity

        if insuffecientResourcesOnHand then
            if state.resourceSuppliers[resourceName] == nil then
                error(
                    'Attempted to start the task "'..initialProject.taskRunnerId..
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

                -- This logic isn't as effecient as it could be.
                -- If we reach this point and are trying to figure out what it costs to obtain 5 of X resource,
                -- but we've already reached this point previously calculating the cost for 3 X resources,
                -- then we're going to end up calculating the dependent resource cost of gathering requirements
                -- for 3 X resource followed by 5 X resources, instead of just doing 8 X resources.
                --
                -- It's assumed that _G.act.mill.getRequiredResources() will only return numbers that are
                -- relatively cheaper as you gather in bulk. If this is ever not the case, then this ineffeciency
                -- could turn into a real problem.
                --
                -- Right now, the innefeciency just means it'll gather a little more extra dependent resources,
                -- meaning we'll get a little more for storage. When it comes time to actually go and gather
                -- a dependency for the X resource, it'll still go and gather the dependent resource in one go,
                -- not broken up over multiple trips.
                local resourceRequest = { resourceName = resourceName, quantity = requiredQuantity }
                local requiredResources = _G.act.mill.getRequiredResources(
                    supplier.taskRunnerId,
                    resourceRequest
                )
                for resourceName, quantity in pairs(requiredResources) do
                    if requiredResourcesToProcess[resourceName] == nil then
                        requiredResourcesToProcess[resourceName] = 0
                    end
                    requiredResourcesToProcess[resourceName] = requiredResourcesToProcess[resourceName] + quantity
                end

                resourceMap[resourceName].quantity = resourceMap[resourceName].quantity + requiredQuantity
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
    for resourceName, resourceInfo in pairs(resourceMap) do

        if resourceInfo.type == 'mill' then
            local requirementsFulfilled = true
            local requiredResources = _G.act.mill.getRequiredResources(
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
    return module.create(busyWaitTaskRunner)
end

-- args is optional
function module.create(taskRunnerId, args)
    return {
        taskRunnerId = taskRunnerId,
        -- Auto-initializes the first time you request a plan
        initialized = false,
        -- "complete" means you've requested the last available plan.
        -- It doesn't necessarily mean all requested plans have been executed.
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