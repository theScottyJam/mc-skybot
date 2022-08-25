--[[
    A farm is something that required periodic attention in order to obtain its resources.
--]]

local time = import('./_time.lua')
local util = import('util.lua')

local module = {}

-- opts.supplies is a list of resources the farm is capable of supplying.
-- opts.scheduleOpts contains information about how often this farm needs attention.
-- Returns a farm instance
function module.create(taskRunnerId, opts)
    local commands = _G.act.commands

    local supplies = opts.supplies
    local scheduleOpts = opts.scheduleOpts

    if util.tableSize(_G.act.task.lookupTaskRunner(taskRunnerId).requiredResources) > 0 then
        error('Farms do not support gathering required resources at this time.')
    end

    return {
        activate = function(planner)
            commands.general.activateFarm(planner, {
                taskRunnerId = taskRunnerId,
                supplies = supplies,
                scheduleOpts = scheduleOpts,
            })
        end
    }
end

-- Should be called at each interrupable point during a project,
-- and whenever an inerruption has finished.
-- Returns an interrupt task, or nil if there
-- are no interruptions.
function module.checkForInterruptions(state)
    local currentTime = time.get()
    local winningFarm = {
        taskRunnerId = nil,
        ellapsedTime = 0,
    }

    for _, farmInfo in pairs(state.activeFarms) do
        -- TOOD: I can use farmInfo.scheduleOpts to refine the algorithm,
        --       once I decide on what should go in that object.
        local ellapsedTime = currentTime - farmInfo.lastVisited
        if ellapsedTime > 0.5 and ellapsedTime > winningFarm.ellapsedTime then
            winningFarm = {
                taskRunnerId = farmInfo.taskRunnerId,
                ellapsedTime = ellapsedTime,
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
