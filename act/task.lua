--[[
    A "taskRunner" holds the logic assosiated with a specific task, while a "task" holds the state.
--]]

local util = import('util.lua')

local module = {}

local taskRegistry = {}

--[[
inputs:
  opts.requiredResources (optional) is a mapping of resource names to tables
    of the shape { quantity=..., at='INVENTORY' }
    Fetching these resources must be done before the project starts.
  opts.createTaskState() (optional) returns any arbitrary record.
    If not provided, it default to an empty record.
  opts.enter() takes a planner and a taskState. It will run before the task
    starts and whenever the task continues after an interruption, and is supposed
    to bring the turtle from anywhere in the world to a desired position.
  opts.exit() takes a planner, a taskState, and an info object. The info object contains a
    "complete" boolean property that indicates if the task has been completed at this point.
    This function will run after the task finishes and whenever the task needs to pause
    for an interruption, and is supposed to bring the turtle to the position of a registered location.
  opts.nextPlan() takes a planner, a taskState, and any other arbitrary
    arguments it might need and returns a tuple containing an updated task state and
    a "complete" boolean, which when true indicates thatonce everything registered in the
    provided plan happens, exit() should be used, and this task will be complete.
--]]
function module.registerTaskRunner(id, opts)
    local requiredResources = opts.requiredResources or {}
    local createTaskState = opts.createTaskState or function() return {} end
    local enter = opts.enter
    local exit = opts.exit
    local nextPlan = opts.nextPlan

    if taskRegistry[id] ~= nil then error('A taskRunner with that id already exists') end
    taskRegistry[id] = {
        id = id,
        requiredResources = requiredResources,

        -- Takes a state and a reference to this task. Returns a plan.
        enter = function(state, currentTask)
            if not currentTask.initialized then
                currentTask.initialized = true
                currentTask.taskState = createTaskState()
            end

            local planner = _G.act.planner.create({ turtlePos = state.turtlePos })
            enter(planner, currentTask.taskState)
            currentTask.entered = true

            return planner.plan
        end,

        -- Takes a state and a reference to this task. Returns a plan.
        exit = function(state, currentTask)
            local planner = _G.act.planner.create({ turtlePos = state.turtlePos })
            exit(planner, currentTask.taskState, { complete = currentTask.completed })
            currentTask.entered = false

            return planner.plan
        end,

        -- Takes a state and a reference to this task. Returns a plan.
        nextPlan = function(state, currentTask)
            if currentTask.completed == true then
                error('This task is already finished')
            end

            local planner = _G.act.planner.create({ turtlePos = state.turtlePos })
            local newTaskState, complete = nextPlan(planner, currentTask.taskState, currentTask.args)
            currentTask.taskState = newTaskState
            currentTask.completed = complete

            return planner.plan
        end,
    }
    return id
end

-- Returns a task that will collect some of the required resources, or nil if there
-- aren't any requirements left to fulfill.
function module.collectResources(state, initialTaskRunner, resourcesInInventory)
    local resourceMap = {}

    -- Collect the nested requirement tree into a flat mapping (resourceMap)
    local requiredResourcesToProcess = { initialTaskRunner.requiredResources }
    while #requiredResourcesToProcess > 0 do
        local requiredResources = table.remove(requiredResourcesToProcess)
        for resourceName, rawRequirements in pairs(requiredResources) do
            if rawRequirements.at ~= 'INVENTORY' then error('Only at="INVENTORY" is supported right now.') end
            if resourceMap[resourceName] == nil then
                if state.resourceSuppliers[resourceName] == nil then
                    error(
                        'Attempted to start a task that requires the resource '..resourceName..', '..
                        'but there are no registered sources for this resource.'
                    )
                end
                local supplier = state.resourceSuppliers[resourceName][1]
                if supplier.type ~= 'mill' then error('Invalid supplier type') end
                local subTaskRunner = module.lookupTaskRunner(supplier.taskRunnerId)
                resourceMap[resourceName] = {
                    quantity = 0,
                    taskRunner = subTaskRunner,
                }
                table.insert(requiredResourcesToProcess, subTaskRunner.requiredResources)
            end
            resourceMap[resourceName].quantity = resourceMap[resourceName].quantity + rawRequirements.quantity
        end
    end

    -- Loop over the mapping, removing things that are already satisfied, until
    -- you find a resource that needs to be done, who's requirements are all fulfilled.
    while util.tableSize(resourceMap) > 0 do
        for resourceName, resourceInfo in pairs(resourceMap) do
            local quantityNeeded = util.maxNumber(0, resourceInfo.quantity - (resourcesInInventory[resourceName] or 0))
            if quantityNeeded == 0 then
                resourceMap[resourceName] = nil
            else
                local requirementsFulfilled = true
                for subResourceName, subRawRequirements in pairs(resourceInfo.taskRunner.requiredResources) do
                    if resourceMap[resourceName] ~= nil then
                        requirementsFulfilled = false
                        break
                    end
                end
                if requirementsFulfilled then
                    return module.create(resourceInfo.taskRunner.id, { [resourceName] = quantityNeeded })
                end
            end
        end
    end

    -- Return nil if there aren't any additional resources that need to be collected.
    return nil
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
        -- Contains the values of futures
        taskVars = {},
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