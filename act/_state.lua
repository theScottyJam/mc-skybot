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
        -- A place to store vars if there are no active tasks. Should be occasionally cleared out.
        limboVars = {},

        -- Returns the primary task, or if we're in the middle of an interruption, returns the interrupt task.
        -- May return nil if there are currently no tasks being run.
        getActiveTask = function()
            return state.primaryTask or state.interruptTask
        end,

        -- Returns the active task's vars. The caller can mutate this table as needed.
        -- Returns the limboVars table if there are no active tasks.
        getActiveTaskVars = function()
            local activeTask = state.primaryTask or state.interruptTask
            if activeTask == nil then
                return state.limboVars
            else
                return activeTask.taskVars
            end
        end,
    }
    return state
end

return module