local util = import('util.lua')
local time = import('./_time.lua')
local Farm = import('./Farm.lua')

local module = {}

-- `expectedYieldInfo` is what gets returned by a farm's __calcExpectedYield() function.
local scoreFromExpectedYieldInfo = function(expectedYieldInfo, resourcesInInventory)
    local work = expectedYieldInfo.work
    local expectedResources = expectedYieldInfo.yield

    local score = 0
    for resourceName, quantity in pairs(expectedResources) do
        local getWorkToYieldThreshold = Farm.__getValueOfFarmableResource(resourceName)
        if getWorkToYieldThreshold ~= nil then
            local threshold = getWorkToYieldThreshold(resourcesInInventory[resourceName] or 0)
            local workToYield = work / quantity
            score = score + util.maxNumber(0, threshold - workToYield)
        end
    end
    return score
end

-- Should be called at each interruptible point during a project or mill,
-- and whenever an interruption has finished.
-- Returns an interrupt task, or nil if there
-- are no interruptions.
function module.checkForInterruptions(state, resourcesInInventory)
    local currentTime = time.get(state)
    local winningFarm = {
        farm = nil,
        score = 0,
    }

    for _, farmInfo in pairs(state.activeFarms) do
        local elapsedTime = currentTime - farmInfo.lastVisited

        local expectedYieldInfo = farmInfo.farm:__calcExpectedYield(elapsedTime)
        local score = scoreFromExpectedYieldInfo(expectedYieldInfo, resourcesInInventory)
        if score > winningFarm.score then
            winningFarm = {
                farm = farmInfo.farm,
                score = score,
            }
        end
    end

    if winningFarm.farm ~= nil then
        return winningFarm.farm:__createTask(state)
    else
        return nil
    end
end

return module