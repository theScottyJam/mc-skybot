--[[
    Everything in shortTermPlaner is mutable.
    If you want to pluck a property off, clone it first.
--]]

local util = import('util.lua')

local module = {}

function module.create(opts)
    local absTurtlePos = opts.absTurtlePos

    return {
        turtlePos = util.copyTable(absTurtlePos),
        relativeTo = { x=0, y=0, z=0, face='N' },
        shortTermPlan = {}
    }
end

function clone(shortTermPlaner)
    return {
        turtlePos = util.copyTable(shortTermPlaner.turtlePos),
        relativeTo = util.copyTable(shortTermPlaner.relativeTo),
        shortTermPlan = util.copyTable(shortTermPlaner.shortTermPlan),
    }
end

function module.withRelativePos(shortTermPlaner, relativeTo)
    local space = _G.act.space

    if not space.comparePos(shortTermPlaner.relativeTo, { x=0, y=0, z=0, face='N' }) then
        error('You current can not use withRelativePos() on a shortTermPlaner that is already set to a relative coordinate.')
    end

    return util.mergeTables(
        clone(shortTermPlaner),
        {
            relativeTo = relativeTo,
            turtlePos = space.relativePosTo(shortTermPlaner.turtlePos, relativeTo)
        }
    )
end

return module