--[[
    A farm is something that required periodic attention in order to obtain its resources.
]]

local util = import('util.lua')
local time = import('../_time.lua')
local TaskFactory = import('./_TaskFactory.lua')
local serializer = import('../_serializer.lua')
local state = import('../state.lua')

local static = {}
local prototype = {}

local resourceValues = {}

local farmStateManager = state.__registerPieceOfState('module:Farm', function()
    return {
        -- A list of info objects related to enabled farms that require occasional attention.
        activeFarms = {},
    }
end)

-- resourceValues_ is a mapping of resource names to a function
-- that takes, as input, the quantity of it owned.
-- It's output should be a work-to-yield ratio threshold.
-- The resource will only be harvested if it's able to be done
-- in less work than the returned threshold. The farther below
-- the threshold, the higher priority there is to harvest it.
-- If a resource is not present in this mapping,
-- it's assumed there's no desire to harvest it.
function static.registerValueOfFarmableResources(resourceValues_)
    resourceValues = resourceValues_
end

-- Returns nil if the resource is not registered (e.g. because it can't be farmed).
function static.__getValueOfFarmableResource(resourceName)
    local getWorkToYieldThreshold = resourceValues[resourceName]
    return getWorkToYieldThreshold
end

-- Triggered with a farm instance as an argument.
-- Outside modules can subscribe to it, but should not trigger it.
static.__onActivated = util.createEventEmitter()

--[[
Inputs:
    id: string
    opts.supplies
        A list of resources the farm is capable of supplying.
    opts.calcExpectedYield(timeSpan)
        A function that takes a time-span (in days) as
        input (representing the time since the last harvest) and
        return an object of the shape { work = ..., yield = { ... } }
        where `work` is the number of units of work it's expected to take to
        harvest the farm at this time, and `yield` is a mapping of resources
        to expected quantities after a harvest is performed.
    ...taskFactoryOpts
        Any options accepted by the generate-task-factory function
        can also be used here.
        Because farms don't get interrupted, there's not really a difference
        between the behaviors of before()/after() and enter()/exit() except
        for a conceptual difference - typically movement actions are handled
        by enter()/exit() while before()/after() handles other kinds of
        state changes.
        Even if farms don't get interrupted by other tasks, they still
        need to be capable of pausing in the middle in case the game
        needs to be shut down. As such, it is still a good idea to split
        the task up into multiple sprints when reasonably possible.
]]
function static.register(opts)
    opts = util.copyTable(opts or {})
    local id = 'farm:'..opts.id
    local supplies = opts.supplies
    local calcExpectedYield = opts.calcExpectedYield
    local after = opts.after
    opts.id = nil
    opts.supplies = nil
    opts.calcExpectedYield = nil
    opts.after = nil

    local taskFactory = TaskFactory.register(util.mergeTables(opts, {
        id = id,
        after = function(self)
            if after then
                after(self)
            end
            local farmState = farmStateManager:getAndModify()
            for i, iterFarmInfo in pairs(farmState.activeFarms) do
                if iterFarmInfo.farm._id == id then
                    iterFarmInfo.lastVisited = time.get()
                    return
                end
            end
            error('Failed to find a matching active farm.')
        end,
    }))

    local farm = util.attachPrototype(prototype, {
        _id = id,
        _taskFactory = taskFactory,
        __calcExpectedYield = calcExpectedYield,
        __supplies = supplies,
    })
    serializer.registerValue(id, farm)
    return farm
end

function static.__isInstance(instance)
    return util.hasPrototype(instance, prototype)
end

function static.__getActiveFarms()
    return farmStateManager:get().activeFarms
end

function prototype:activate()
    local farmState = farmStateManager:getAndModify()
    table.insert(farmState.activeFarms, {
        farm = self,
        -- We're going to count a newly activated farm as just visited,
        -- because we typically don't need to harvest it right after it has been built.
        lastVisited = time.get(),
    })

    static.__onActivated:trigger(self)
end

function prototype:__createTask()
    return self._taskFactory:createTask()
end

return static
