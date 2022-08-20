--[[
    Everything in planner is mutable.
    If you want to pluck a property off, clone it first.
--]]

local util = import('util.lua')

local module = {}

function module.create(opts)
    local turtlePos = opts.turtlePos

    return {
        turtlePos = util.copyTable(turtlePos),
        plan = {}
    }
end

function module.copy(planner)
    return {
        turtlePos = util.copyTable(planner.turtlePos),
        plan = util.copyTable(planner.plan)
    }
end

return module