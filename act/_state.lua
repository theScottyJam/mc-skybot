--[[
    This module is in charge of managing persistent state.
    The state object is intended to be mutable - anyone with a reference can update it.
--]]

local util = import('util.lua')
local space = import('./space.lua')

local module = {}

function module.createInitialState(opts)
    local startingPos = opts.startingPos
    local projectList = opts.projectList

    local state
    state = {
        turtlePos = opts.startingPos,
        -- List of projects that still need to be tackled
        projectList = util.copyTable(projectList),
        -- The project currently being worked on, or that we're currently gathering resources for
        primaryTask = nil,
        -- A task, like a farm-tending task, that's interrupting the active one
        interruptTask = nil,
        -- A mapping that lets us know where resources can be found.
        resourceSuppliers = {},
        -- A list of info objects related to enabled farms that require occasional attention.
        activeFarms = {},

        turtleCmps = function()
            return space.createCompass(util.copyTable(state.turtlePos))
        end,
        --<-- unused
        -- Returns the primary task, or if we're in the middle of an interruption, returns the interrupt task.
        -- May return nil if there are currently no tasks being run.
        getActiveTask = function()
            return state.primaryTask or state.interruptTask
        end,
    }
    return state
end

return module