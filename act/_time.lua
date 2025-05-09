--[[
terms:
* timespan: A timespan in minecraft days.
    (One minecraft day is 20 minutes)
]]

local state = import('./state.lua')

local module = {}

-- Returns a timestamp that isn't necessarily relative to when the program started.
local getRawTimestamp = function()
    return os.day() + os.time() / 24
end

local initialTimeStateManager = state.__registerPieceOfState('module:time', function()
    return getRawTimestamp()
end)

-- Returns the number of minecraft days that have elapsed since the program started, as a decimal.
function module.get()
    local initialTime = initialTimeStateManager:get()
    return getRawTimestamp() - initialTime
end

return module
