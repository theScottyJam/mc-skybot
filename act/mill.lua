--[[
    A mill is something that requires active attention to produce a resource.
    The more attention you give it, the more it produces.
--]]

local util = import('util.lua')

local module = {}

--[[
inputs:
  opts.requiredResourcesPerUnit (optional) Maps resource names that you
    want, to a mapping of required resources to obtain a single unit.
    The requirements may contain fractional units.
    If a resource in opts.supplies is missing from the mapping's first layer,
    it's assumed to be free.
  opts.supplies is a list of resources the mill is capable of supplying.
Returns a mill instance
--]]
function module.create(taskRunnerId, opts)
    local commands = _G.act.commands

    local requiredResourcesPerUnit_ = opts.requiredResourcesPerUnit or {}
    local supplies = opts.supplies

    local requiredResourcesPerUnit = util.copyTable(requiredResourcesPerUnit_)
    for _, resourceName in ipairs(supplies) do
        if requiredResourcesPerUnit[resourceName] == nil then
            requiredResourcesPerUnit[resourceName] = {}
        end
    end

    return {
        activate = function(planner)
            commands.general.activateMill(planner, {
                taskRunnerId = taskRunnerId,
                requiredResourcesPerUnit = requiredResourcesPerUnit,
                supplies = supplies,
            })
        end
    }
end

function module.calculateRequredResources(requiredResourcesPerUnit, resourceRequest)
    local requirements = {}
    for resourceName, quantityDesired in pairs(resourceRequest) do
        local iterRequirements = requiredResourcesPerUnit[resourceName]
        if iterRequirements == nil then
            error('Requested a resource from a mil that the mil does not supply')
        else
            for itemId, costPer in pairs(iterRequirements) do
                if costPer.at ~= 'INVENTORY' then error('Currently, `at` must be `INVENTORY`') end
                if requirements[itemId] == nil then
                    requirements[itemId] = { quantity=0, at='INVENTORY'}
                end
                requirements[itemId].quantity = requirements[itemId].quantity + costPer.quantity * quantityDesired
            end
        end
    end
    for key, value in pairs(requirements) do
        requirements[key].quantity = math.ceil(value.quantity)
    end
    return requirements
end

return module
