--[[
    A mill is something that requires active attention to produce a resource.
    The more attention you give it, the more it produces.
--]]

local util = import('util.lua')

local module = {}

local taskRunnerIdsToMillInfo = {}

--[[
inputs:
  opts.getRequiredResources (optional) Given a resource request of the shape
    { resourceName = ..., quantity = ... }, this will return what resources
    are required to produce it, in the shape { <name> = <quantity>, ... }
  opts.supplies is a list of resources the mill is capable of supplying.
  opts.onActivated (optional) gets called when the mill is first activated
Returns a mill instance
--]]
function module.create(taskRunnerId, opts)
    local getRequiredResources = opts.getRequiredResources or function() return {} end
    local supplies = opts.supplies
    local onActivated = opts.onActivated or function() end

    taskRunnerIdsToMillInfo[taskRunnerId] = {
        getRequiredResources = getRequiredResources
    }

    return {
        activate = function(commands, state)
            for _, resourceName in ipairs(supplies) do
                if state.resourceSuppliers[resourceName] == nil then
                    state.resourceSuppliers[resourceName] = {}
                end
    
                table.insert(state.resourceSuppliers[resourceName], 1, {
                    type='mill',
                    taskRunnerId = taskRunnerId,
                })
            end
            onActivated()
        end
    }
end

function module.getRequiredResources(taskRunnerIdForMill, resourceRequest)
    local millInfo = taskRunnerIdsToMillInfo[taskRunnerIdForMill]
    if millInfo == nil then
        error('There is no mill is not assosiated with the taskRunnerId provided: ' .. tostring(taskRunnerIdForMill))
    end

    return millInfo.getRequiredResources(resourceRequest)
end

return module
