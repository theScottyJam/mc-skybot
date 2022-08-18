--[[
    Everything in shortTermPlanner is mutable.
    If you want to pluck a property off, clone it first.
--]]

local util = import('util.lua')

local module = {}

function module.create(opts)
    local turtlePos = opts.turtlePos

    return {
        turtlePos = util.copyTable(turtlePos),
        shortTermPlan = {}
    }
end

function module.copy(shortTermPlanner)
    return {
        turtlePos = util.copyTable(shortTermPlanner.turtlePos),
        shortTermPlan = util.copyTable(shortTermPlanner.shortTermPlan)
    }
end

return module