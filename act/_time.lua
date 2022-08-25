--[[
terms:
* timespan: A timespan in minecraft days.
    (One minecraft day is 20 minutes)
--]]

local module = {}

local initialTime = os.day() + os.time() / 24

-- Returns the number of minecraft days that have elapsed since the program started, as a decimal.
function module.get()
    return (os.day() + os.time() / 24) - initialTime
end

return module
