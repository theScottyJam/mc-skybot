--[[
    A "taskRunner" holds the logic assosiated with a specific task, while a "task" holds the state.
--]]

local util = import('util.lua')

local module = {}

local taskRegistry = {}

--[[
inputs:
  opts.createTaskState() (optional) returns any arbitrary record.
    If not provided, it default to an empty record.
  opts.enter() (optional) takes a planner and a taskState. It will run before the task
    starts and whenever the task continues after an interruption, and is supposed
    to bring the turtle from anywhere in the world to a desired position.
  opts.exit() (optional) takes a planner, a taskState, and an info object. The info object contains a
    "complete" boolean property that indicates if the task has been completed at this point.
    This function will run after the task finishes and whenever the task needs to pause
    for an interruption, and is supposed to bring the turtle to the position of a registered location.
    It can also be used to activate mills and farms.
  opts.nextPlan() takes a planner, a taskState, and any other arbitrary
    arguments it might need and returns a tuple containing an updated task state and
    a "complete" boolean, which when true indicates thatonce everything registered in the
    provided plan happens, exit() should be used, and this task will be complete.
--]]
function module.registerTaskRunner(id, opts)
    local createTaskState = opts.createTaskState or function() return {} end
    local enter = opts.enter or function() end
    local exit = opts.exit or function() end
    local nextPlan = opts.nextPlan

    if taskRegistry[id] ~= nil then error('A taskRunner with that id already exists') end
    taskRegistry[id] = {
        id = id,

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
function module.collectResources(state, initialProject, resourcesInInventory)
    local resourceMap = {}

    -- Collect the nested requirement tree into a flat mapping (resourceMap)
    local requiredResourcesToProcess = {
        initialProject.requiredResources
    }
    while #requiredResourcesToProcess > 0 do
        local requiredResources = table.remove(requiredResourcesToProcess)
        for resourceName, rawRequirements in pairs(requiredResources) do
            if rawRequirements.at ~= 'INVENTORY' then error('Only at="INVENTORY" is supported right now.') end

            if resourceMap[resourceName] == nil and state.resourceSuppliers[resourceName] == nil then
                resourceMap[resourceName] = {
                    quantity = 0,
                    taskRunner = nil, -- nil means there are no registered resource suppliers
                    requiredResources = {},
                }
            elseif resourceMap[resourceName] == nil then
                local supplier = state.resourceSuppliers[resourceName][1]
                if supplier.type ~= 'mill' then error('Invalid supplier type') end
                local subTaskRunner = module.lookupTaskRunner(supplier.taskRunnerId)
                resourceMap[resourceName] = {
                    quantity = 0,
                    taskRunner = subTaskRunner,
                    requiredResourcesPerUnit = supplier.requiredResourcesPerUnit,
                }
                local resourceRequest = { [resourceName] = rawRequirements.quantity }
                local requiredResources = _G.act.mill.calculateRequredResources(
                    supplier.requiredResourcesPerUnit,
                    resourceRequest
                )
                table.insert(requiredResourcesToProcess, requiredResources)
            end
            resourceMap[resourceName].quantity = resourceMap[resourceName].quantity + rawRequirements.quantity
        end
    end

    --------------------------------------------------
    -- ERROR: It's fetching the 256 cobblestone twice.
    -- This is because the following loop isn't recognizing the cobble-fetching task as done
    -- after it's been turned into furnaces.
    --
    -- 1. Build resource tree and record initial quantities required
    -- 2. Apply current inventory, subtracting values from the resource tree and their child nodes (potentially removing children)
    -- 3. Find a leaf node without any dependencies and work on it. (Note for future: Do the closets one)

    -- Loop over the mapping, removing things that are already satisfied, until
    -- you find a resource that needs to be done, who's requirements are all fulfilled.
    while util.tableSize(resourceMap) > 0 do
        local fieldsToRemoveFromMap = {}
        for resourceName, resourceInfo in pairs(resourceMap) do
            local quantityNeeded = util.maxNumber(0, resourceInfo.quantity - (resourcesInInventory[resourceName] or 0))
            if quantityNeeded == 0 then
                table.insert(fieldsToRemoveFromMap, resourceName)
            elseif resourceInfo.taskRunner == nil then
                error(
                    'Attempted to start a task that requires the resource '..resourceName..', '..
                    'but there are no registered sources for this resource, nor is there enough of it on hand.'
                )
            else
                local resourceRequest = { [resourceName] = resourceInfo.quantity }
                local requiredResources = _G.act.mill.calculateRequredResources(
                    resourceInfo.requiredResourcesPerUnit,
                    resourceRequest
                )

                local requirementsFulfilled = true
                for subResourceName, subRawRequirements in pairs(requiredResources) do
                    if resourceMap[subResourceName] ~= nil then
                        requirementsFulfilled = false
                        break
                    end
                end
                if requirementsFulfilled then
                    return module.create(resourceInfo.taskRunner.id, { [resourceName] = quantityNeeded })
                end
            end
        end

        for _, fieldToRemove in pairs(fieldsToRemoveFromMap) do
            resourceMap[fieldToRemove] = nil
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