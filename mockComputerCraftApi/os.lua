local time = import('./_time.lua')

local module = {}

function module.day()
    return math.floor(time.getTicks() / 100 / 24)
end

function module.time()
    return math.fmod(time.getTicks() / 100, 24)
end

return module
