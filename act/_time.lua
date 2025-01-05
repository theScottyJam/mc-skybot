--[[
terms:
* timespan: A timespan in minecraft days.
    (One minecraft day is 20 minutes)
]]

local module = {}

local initialTime = os.day() + os.time() / 24

-- Returns a timestamp that isn't necessarily relative to when the program started.
function module.getRawTimestamp()
    return os.day() + os.time() / 24
end

-- Returns the number of minecraft days that have elapsed since the program started, as a decimal.
function module.get(state)
    return module.getRawTimestamp() - state.initialTime
end

return module
