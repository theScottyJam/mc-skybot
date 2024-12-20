--[[
    This module is in charge of managing persistent state.
    The state object is intended to be mutable - anyone with a reference can update it.
--]]

local util = import('util.lua')
local space = import('./space.lua')
local taskModule = moduleLoader.lazyImport('./task.lua')
local json = import('./_json.lua')

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
    }
    return state
end

function module.serialize(state)
    state = util.copyTable(state)
    state.turtleCmps = nil
    if state.primaryTask ~= nil then
        state.primaryTask = util.copyTable(state.primaryTask)
        state.primaryTask.getTaskRunner = nil
    end
    if state.interruptTask ~= nil then
        state.interruptTask = util.copyTable(state.interruptTask)
        state.interruptTask.getTaskRunner = nil
    end
    return json.encode(state)
end

function module.deserialize(text)
    local state = json.decode(text)
    state.turtleCmps = function()
        return space.createCompass(util.copyTable(state.turtlePos))
    end
    if state.primaryTask ~= nil then
        state.primaryTask.getTaskRunner = function()
            return taskModule.load().lookupTaskRunner(state.primaryTask.taskRunnerId)
        end
    end
    if state.interruptTask ~= nil then
        state.interruptTask.getTaskRunner = function()
            return taskModule.load().lookupTaskRunner(state.interruptTask.taskRunnerId)
        end
    end
    return state
end

return module