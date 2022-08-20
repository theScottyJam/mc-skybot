--[[
    This module is in charge of managing persistent state.
    The state object is intended to be mutable - anyone with a reference can update it.
--]]

local util = import('util.lua')

local module = {}

--[[
    opts.startingLoc is a location instance indicating where the turtle starts.
--]]
function module.createInitialState(opts)
    local space = _G.act.space

    local startingPos = opts.startingPos

    return {
        turtlePos = opts.startingPos,
        shortTermPlan = {},
        -- Which step are you in in the overall strategy, so we can skip to that.
        strategyStepNumber = 1,
        primaryTask = nil,
        resourceSuppliers = {},
    }
end

return module