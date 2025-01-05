--[[
    A farm is something that required periodic attention in order to obtain its resources.
]]

local util = import('util.lua')
local time = import('./_time.lua')
local TaskFactory = import('./_TaskFactory.lua')
local serializer = import('./_serializer.lua')

local static = {}
local prototype = {}

local resourceValues = {}

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
        init = function(self, state)
            self.state = state
        end,
        after = function(self, commands)
            if after then
                after(self, commands)
            end
            for i, iterFarmInfo in pairs(self.state.activeFarms) do
                if iterFarmInfo.farm._id == id then
                    iterFarmInfo.lastVisited = time.get(self.state)
                    return
                end
            end
            error('Failed to find a matching active farm.')
        end,
    }))

    local farm = util.attachPrototype(prototype, {
        _id = id,
        _taskFactory = taskFactory,
        _calcExpectedYield = calcExpectedYield,
        _supplies = supplies,
    })
    serializer.registerValue(id, farm)
    return farm
end

function static.__isInstance(self)
    return util.hasPrototype(self, prototype)
end

function prototype:__calcExpectedYield(elapsedTime)
    return self._calcExpectedYield(elapsedTime)
end

function prototype:activate(commands, state)
    table.insert(state.activeFarms, {
        farm = self,
        -- We're going to count a newly activated farm as just visited,
        -- because we typically don't need to harvest it right after it has been built.
        lastVisited = time.get(state),
    })

    for _, resourceName in ipairs(self._supplies) do
        if state.resourceSuppliers[resourceName] == nil then
            state.resourceSuppliers[resourceName] = {}
        end

        table.insert(state.resourceSuppliers[resourceName], 1, self)
    end
end

function prototype:__createTask(state)
    return self._taskFactory:createTask(state)
end

return static
