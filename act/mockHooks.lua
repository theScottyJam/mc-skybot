--[[
    A place for a mocking tool (and other consumers) to listen for interesting events.
--]]

local util = import('util.lua')

local module = {}

function module.init(hookListeners)
    local mockHooks = util.copyTable(hookListeners)

    local noop = function() end

    if mockHooks.registerCobblestoneRegenerationBlock == nil then
        mockHooks.registerCobblestoneRegenerationBlock = noop
    end

    if mockHooks.idleStart == nil then
        mockHooks.idleStart = noop
    end

    if mockHooks.idleEnd == nil then
        mockHooks.idleEnd = noop
    end

    return mockHooks
end

return module
