-- These ticks don't correspond to "minecraft ticks". They just represent the fact that
-- a relatively small (sub-second) amound of time has passed.

local util = import('util.lua')

local module = {}

local tickListeners = {}
local currentTick = 0
function module.tick()
    currentTick = currentTick + 1
    for i, entry in ipairs(tickListeners) do
        if entry.at == currentTick then
            entry.listener()
        end
    end
    tickListeners = util.filterArrayTable(tickListeners, function(value) return value.at > currentTick end)
end

function module.addTickListener(ticksLater, listener)
    table.insert(tickListeners, {
        at = currentTick + ticksLater,
        listener = listener
    })
end

function module.getTicks()
    return currentTick
end

-- Can be temporarily exposed for introspection purposes
-- function _G._getTimeState()
--     return { tickListeners = tickListeners, currentTick = currentTick }
-- end

return module
