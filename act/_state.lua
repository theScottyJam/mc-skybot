--[[
    This module is in charge of managing persistent state.
    The state object is intended to be mutable - anyone with a reference can update it.
--]]

local util = import('util.lua')

local module = {}

function module.createInitialState(opts)
    local space = _G.act.space

    local startingPos = opts.startingPos
    local projectList = opts.projectList

    local state
    state = {
        -- Note that the "from" field should always be set to "ORIGIN".
        -- Worrying about unknown positions are only needed during the planning phase.
        turtlePos = opts.startingPos,
        -- List of projects that still need to be tackled
        projectList = util.copyTable(projectList),
        -- List of steps that need to be taken to get to a good interrupt point
        plan = {},
        -- The project currently being worked on, or that we're currently gathering resources for
        primaryTask = nil,
        -- A task, like a farm-tending task, that's interrupting the active one
        interruptTask = nil,
        -- A mapping that lets us know where resources can be found.
        resourceSuppliers = {},
        -- A list of info objects related to enabled farms that require occasional attention.
        activeFarms = {},

        getActiveTask = function()
            return state.primaryTask or state.interruptTask
        end,
    }
    return state
end

return module