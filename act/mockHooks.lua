--[[
    A place for a mocking tool to listen for interesting events.
--]]

local util = import('util.lua')

local module = {}

function module.init(hookListeners)
    local mockHooks = util.copyTable(hookListeners)

    local noop = function() end

    if mockHooks.registerCobblestoneRegenerationBlock == nil then
        mockHooks.registerCobblestoneRegenerationBlock = noop
    end

    return mockHooks
end

return module
