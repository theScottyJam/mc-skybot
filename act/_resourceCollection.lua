local util = import('util.lua')
local TaskFactory = import('./_TaskFactory.lua')
local commands = import('./_commands.lua')
local highLevelCommands = import('./highLevelCommands.lua')
local Mill = import('./Mill.lua')
local Farm = import('./Farm.lua')
local serializer = import('./_serializer.lua')

local module = {}

module.idleTaskRunnerFactory = TaskFactory.register({
    id = 'act:idle',
    init = function(self, state)
        self.state = state
    end,
    nextSprint = function(self, commands)
        highLevelCommands.busyWait(commands, self.state)
        return true
    end,
})

-- Returns a task that will collect some of the required resources, or nil if there
-- aren't any requirements left to fulfill.
-- The second return value is a flag indicating if this was an idling task,
-- because we have to wait for farms to produce resources. This will also
-- be set to nil if the first return value was nil.
function module.collectResources(state, project, resourcesInInventory_)
    local resourceMap = {}
    local resourcesInInventory = util.copyTable(resourcesInInventory_)

    -- Collect the nested requirement tree into a flat mapping (resourceMap)
    -- Factors in your inventory's contents to figure out what's needed.

    local requiredResourcesToProcess = util.copyTable(project.requiredResources)
    while util.tableSize(requiredResourcesToProcess) > 0 do
        local resourceName, requiredQuantity = util.getASortedEntry(requiredResourcesToProcess)
        requiredResourcesToProcess[resourceName] = nil
        -- Factor in quantities from the inventory
        local contributionFromInventory = 0
        if resourcesInInventory[resourceName] ~= nil then
            contributionFromInventory = util.minNumber(
                resourcesInInventory[resourceName],
                requiredQuantity
            )
            resourcesInInventory[resourceName] = resourcesInInventory[resourceName] - contributionFromInventory
            if resourcesInInventory[resourceName] == 0 then resourcesInInventory[resourceName] = nil end
        end

        -- If, after factoring in the inventory, there's still requirements to be fulfilled...
        local insufficientResourcesOnHand = contributionFromInventory < requiredQuantity

        if insufficientResourcesOnHand then
            if state.resourceSuppliers[resourceName] == nil then
                error(
                    'Attempted to start the project "'..project.displayName..
                    '" that requires the resource '..resourceName..', '..
                    'but there are no registered sources for this resource, nor is there enough of it on hand.'
                )
            end
            -- We only bother to check the first supplier in the list.
            -- Other suppliers are still valid, but will be ignored until the first supplier is decommissioned.
            local supplier = state.resourceSuppliers[resourceName][1]

            if Farm.__isInstance(supplier) then
                if resourceMap[resourceName] == nil then
                    resourceMap[resourceName] = {
                        type = 'farm'
                    }
                else
                    -- If this throws, it means there was a conflict, and some other non-farm action
                    -- got registered as being capable of supplying this resource. But at the moment,
                    -- having multiple suppliers for a single resource is not supported.
                    util.assert(resourceMap[resourceName].type == 'farm')
                end
            elseif Mill.__isInstance(supplier) then
                if resourceMap[resourceName] == nil then
                    resourceMap[resourceName] = {
                        type = 'mill',
                        quantity = 0,
                        mill = supplier,
                    }
                else
                    util.assert(resourceMap[resourceName].type == 'mill')
                end

                local previousQuantity = resourceMap[resourceName].quantity
                local previousRequiredResources = supplier:__getRequiredResources({
                    resourceName = resourceName,
                    quantity = previousQuantity
                })

                local newQuantity = resourceMap[resourceName].quantity + requiredQuantity
                local requiredResources = supplier:__getRequiredResources({
                    resourceName = resourceName,
                    quantity = newQuantity
                })

                for dependentResourceName, previousDependentQuantity in util.sortedMapTablePairs(previousRequiredResources) do
                    -- It's possible this assertion isn't really necessary, and we could maybe remove it with little to no changes
                    -- if we really need to. This kind of behavior just hasn't been tested yet.
                    util.assert(
                        requiredResources[dependentResourceName] ~= nil and requiredResources[dependentResourceName] >= previousDependentQuantity,
                        -- This message is referring to the getRequiredResources() function the end-user passes in when initializing the Mill,
                        -- not the Mill's __getRequiredResources() method.
                        'getRequiredResources() currently must return larger quantities whenever larger requests are passed in. ' ..
                        'The quantities can never shrink.'
                    )
                end

                for dependentResourceName, dependentQuantity in util.sortedMapTablePairs(requiredResources) do
                    if requiredResourcesToProcess[dependentResourceName] == nil then
                        requiredResourcesToProcess[dependentResourceName] = 0
                    end
                    local dependentQuantityDiff = dependentQuantity - previousRequiredResources[dependentResourceName]
                    -- Only adding the difference, because the quantity from previousRequiredResources should already be accounted for.
                    requiredResourcesToProcess[dependentResourceName] = requiredResourcesToProcess[dependentResourceName] + dependentQuantityDiff
                end

                resourceMap[resourceName].quantity = newQuantity
            else
                error('Invalid supplier instance type found when trying to fetch the resource '..resourceName)
            end
        end
    end

    if util.tableSize(resourceMap) == 0 then
        -- Return nil if there aren't any additional resources that need to be collected.
        return nil, nil
    end

    -- Loop over the mapping, looking for an entry that has all of its requirements satisfied.
    -- Right now it uses the first found requirement. In the future we could use the closest task instead.
    for resourceName, resourceInfo in util.sortedMapTablePairs(resourceMap) do
        if resourceInfo.type == 'mill' then
            local requirementsFulfilled = true
            local requiredResources = resourceInfo.mill:__getRequiredResources({
                resourceName = resourceName,
                quantity = resourceInfo.quantity
            })
            for subResourceName, _ in pairs(requiredResources) do
                if resourceMap[subResourceName] ~= nil then
                    requirementsFulfilled = false
                    break
                end
            end

            if requirementsFulfilled then
                return resourceInfo.mill:__createTask(state, { [resourceName] = resourceInfo.quantity }), false
            end
        end
    end

    -- It's assumed we got to this point because there is no active "mill" work that could be done,
    -- but there are farms we need to wait on.
    return module.idleTaskRunnerFactory:createTask(state), true
end

return module