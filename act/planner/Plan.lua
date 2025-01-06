--[[
    A Plan is a wrapper around a state object, intended as an interface for users
    outside of act/ to create and run plans.
]]

local util = import('util.lua')
local inspect = moduleLoader.tryImport('inspect.lua')
local State = import('../_State.lua')
local commands = import('../_commands.lua')
local Farm = import('./Farm.lua')
local highLevelCommands = import('../highLevelCommands.lua')
local Project = import('./Project.lua')
local time = import('../_time.lua')
local resourceCollection = import('./_resourceCollection.lua')
local serializer = import('../_serializer.lua')
local sprintCoordinator = import('./_sprintCoordinator.lua')

local static = {}
local prototype = {}
serializer.registerValue('class-prototype:Plan', prototype)

--[[
Inputs:
    opts.initialTurtlePos
    opts.projectList: <Project instance>[]
]]
function static.new(opts)
    Project.__validateProjectList(opts.projectList)
    local state = State.newInitialState({
        startingPos = opts.initialTurtlePos,
        projectList = opts.projectList,
    })
    
    return util.attachPrototype(prototype, { _state = state })
end

-- It's valid to have multiple plan instances wrapping and mutating the same state instance.
-- Though it's encouraged to pass around the pre-existing plan instance instead of creating new ones, where possible.
function static.fromState(state)
    return util.attachPrototype(prototype, { _state = state })
end

function prototype:serialize()
    return serializer.serialize(self)
end

function static.deserialize(text)
    return serializer.deserialize(text)
end

-- Is there nothing else for this plan to do?
function prototype:isExhausted()
    return sprintCoordinator.noSprintsRemaining(self._state)
end

function prototype:runNextSprint()
    sprintCoordinator.runNextSprint(self._state)
end

-- Used for introspection purposes.
function prototype:displayInProgressTasks()
    planExecutor.displayInProgressTasks(self._state)
end

return static