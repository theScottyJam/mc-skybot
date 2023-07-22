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
        -- Returns the primary task, or if we're in the middle of an interruption, returns the interrupt task.
        -- May return nil if there are currently no tasks being run.
        getActiveTask = function()
            return state.primaryTask or state.interruptTask
        end,
    }
    return state
end

-- "miniState" is passed around to tasks that don't need the full-blown state,
-- and who might be receiving a fake state as well if we're trying to sense it's behavior
-- without actually running it.

function module.asMiniState(state)
    local space = _G.act.space

    local miniState
    miniState = {
        turtlePos = util.copyTable(state.turtlePos),
        resourceSuppliers = util.copyTable(state.resourceSuppliers),
        activeFarms = util.copyTable(state.activeFarms),
        turtleCmps = function()
            return space.createCompass(util.copyTable(miniState.turtlePos))
        end,
    }
    return miniState
end

function module.joinMiniStateToState(miniState, state)
    state.turtlePos = miniState.turtlePos
    state.resourceSuppliers = miniState.resourceSuppliers
    state.activeFarms = miniState.activeFarms
end

return module