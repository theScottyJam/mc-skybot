--[[
    A farm is something that required periodic attention in order to obtain its resources.
--]]

local time = import('./_time.lua')
local util = import('util.lua')

local module = {}

local farms = {}
local resourceValues = {}

-- HELPER FUNCTIONS --

-- `expectedYieldInfo` is what gets returned by a farm's calcExpectedYield() function.
local scoreFromExpectedYieldInfo = function(expectedYieldInfo, resourcesInInventory)
    local work = expectedYieldInfo.work
    local expectedResources = expectedYieldInfo.yield

    local score = 0
    for resourceName, quantity in pairs(expectedResources) do
        local getWorkToYieldThreshold = resourceValues[resourceName]
        if getWorkToYieldThreshold ~= nil then
            local threshold = getWorkToYieldThreshold(resourcesInInventory[resourceName] or 0)
            local workToYield = work / quantity
            score = score + util.maxNumber(0, threshold - workToYield)
        end
    end
    return score
end

-- PUBLIC FUNCTIONS --

-- resourceValues_ is a mapping of resource names to a function
-- that takes, as input, the quanity of it owned.
-- It's output should be a work-to-yield ratio threshold.
-- The resource will only be hahrvested if it's able to be done
-- in less work than the returned threshold. The farther below
-- the threshold, the higher priority there is to harvest it.
-- If a resource is not present in this mapping,
-- it's assumed there's no desire to harvest it.
function module.registerValueOfResources(resourceValues_)
    resourceValues = resourceValues_
end

-- opts.supplies is a list of resources the farm is capable of supplying.
-- opts.calcExpectedYield() is a function that takes a timespan (in days) as
--   input (representing the time since the last harvest) and
--   return an object of the shape { work = ..., yield = { ... } }
--   where `work` is the number of units of work it's expected to take to
--   harvest the farm at this time, and `yield` is a mapping of resources
--   to expected quantities after a harvest is performed.
-- Returns a farm instance
function module.register(taskRunnerId, opts)
    local supplies = opts.supplies
    local calcExpectedYield = opts.calcExpectedYield

    local farm = {
        calcExpectedYield = calcExpectedYield,
        activate = function(commands, miniState)
            table.insert(miniState.activeFarms, {
                taskRunnerId = taskRunnerId,
                lastVisited = time.get(),
            })
    
            for _, resourceName in ipairs(supplies) do
                if miniState.resourceSuppliers[resourceName] == nil then
                    miniState.resourceSuppliers[resourceName] = {}
                end
    
                table.insert(miniState.resourceSuppliers[resourceName], 1, {
                    type='farm',
                    taskRunnerId = taskRunnerId,
                })
            end
        end,
    }

    farms[taskRunnerId] = farm
    return farm
end

-- Should be called at each interrupable point during a project or mill,
-- and whenever an inerruption has finished.
-- Returns an interrupt task, or nil if there
-- are no interruptions.
function module.checkForInterruptions(state, resourcesInInventory)
    local currentTime = time.get()
    local winningFarm = {
        taskRunnerId = nil,
        score = 0,
    }

    for _, farmInfo in pairs(state.activeFarms) do
        local ellapsedTime = currentTime - farmInfo.lastVisited

        local expectedYieldInfo = farms[farmInfo.taskRunnerId].calcExpectedYield(ellapsedTime)
        local score = scoreFromExpectedYieldInfo(expectedYieldInfo, resourcesInInventory)
        if score > winningFarm.score then
            winningFarm = {
                taskRunnerId = farmInfo.taskRunnerId,
                score = score,
            }
        end
    end

    if winningFarm.taskRunnerId ~= nil then
        return _G.act.task.create(winningFarm.taskRunnerId)
    else
        return nil
    end
end

-- Must be called after you've tended a farm.
-- This marks when it was done, so it can be rescheduled
-- for more attention.
function module.markFarmTaskAsCompleted(state, taskRunnerId)
    for _, farmInfo in pairs(state.activeFarms) do
        if farmInfo.taskRunnerId == taskRunnerId then
            farmInfo.lastVisited = time.get()
            return
        end
    end
    error('Failed to find a farm with the provided taskRunnerId')
end

return module
