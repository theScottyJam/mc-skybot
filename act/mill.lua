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
    Example shape:
        {
            'minecraft:furnace' = {
                'minecraft:cobblestone' = { quantity=8, at='INVENTORY' }
            }
        }
  opts.supplies is a list of resources the mill is capable of supplying.
  opts.onActivated (optional) gets called when the mill is first activated
Returns a mill instance
--]]
function module.create(taskRunnerId, opts)
    local requiredResourcesPerUnit_ = opts.requiredResourcesPerUnit or {}
    local supplies = opts.supplies
    local onActivated = opts.onActivated or function() end

    local requiredResourcesPerUnit = util.copyTable(requiredResourcesPerUnit_)
    for _, resourceName in ipairs(supplies) do
        if requiredResourcesPerUnit[resourceName] == nil then
            requiredResourcesPerUnit[resourceName] = {}
        end
    end

    return {
        activate = function(commands, state)
            for _, resourceName in ipairs(supplies) do
                if state.resourceSuppliers[resourceName] == nil then
                    state.resourceSuppliers[resourceName] = {}
                end
    
                table.insert(state.resourceSuppliers[resourceName], 1, {
                    type='mill',
                    taskRunnerId = taskRunnerId,
                    requiredResourcesPerUnit = requiredResourcesPerUnit,
                })
            end
            onActivated()
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
