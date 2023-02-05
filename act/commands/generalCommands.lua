local time = import('../_time.lua')
local publicHelpers = import('./_publicHelpers.lua')

local module = {}

local registerCommand = publicHelpers.registerCommand

-- path is optional
module.registerLocPath = registerCommand('general:registerLocPath', function(state, loc1, loc2, path)
    local location = _G.act.location
    location.registerPath(loc1, loc2, path)
end)

module.activateMill = registerCommand(
    'general:activateMill',
    function(state, opts)
        local taskRunnerId = opts.taskRunnerId
        local supplies = opts.supplies
        local requiredResourcesPerUnit = opts.requiredResourcesPerUnit

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
    end
)

module.activateFarm = registerCommand(
    'general:activateFarm',
    function(state, opts)
        local taskRunnerId = opts.taskRunnerId
        local supplies = opts.supplies

        table.insert(state.activeFarms, {
            taskRunnerId = taskRunnerId,
            lastVisited = time.get(),
        })

        for _, resourceName in ipairs(supplies) do
            if state.resourceSuppliers[resourceName] == nil then
                state.resourceSuppliers[resourceName] = {}
            end

            table.insert(state.resourceSuppliers[resourceName], 1, {
                type='farm',
                taskRunnerId = taskRunnerId,
            })
        end
    end
)

registerCommand('general:debug', function(state, opts)
    debug.onDebugCommand(state, opts)
end)

return module
