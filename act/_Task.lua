local util = import('util.lua')
local commands = import('./_commands.lua')
local highLevelCommands = import('./highLevelCommands.lua')
local serializer = import('./_serializer.lua')

local static = {}
local prototype = {}
serializer.registerValue('class-prototype:Task', prototype)

-- Called to fetch the next sprint.
--
-- If this is the first sprint, or if the turtle had previously left (with leave()),
-- then this function should expect the turtle to be found at any arbitrary registered
-- location, and it will need to navigate the turtle to a desired spot.
--
-- If this was the last sprint, leave the turtle at a registered location,
-- then return true.
function prototype:nextSprint()
    if not self._started then
        self._behaviors.before(self._taskState, commands)
        self._started = true
    end

    if self._exhausted then
        error('This task is already finished')
    end

    if not self._entered then
        self._behaviors.enter(self._taskState, commands)
        self._entered = true
    end

    local complete = self._behaviors.nextSprint(self._taskState, commands)
    util.assert(type(complete) == 'boolean', 'nextSprint() must return a boolean.')
    self._exhausted = complete

    if complete then
        self._behaviors.exit(self._taskState, commands)
        self._entered = false
        self._behaviors.after(self._taskState, commands)
    end

    return self._exhausted
end

-- Called when an interruption is happening. This should navigate the turtle
-- to a registered location.
function prototype:prepareForInterrupt()
    if self._entered then
        self._behaviors.exit(self._taskState, commands)
        self._entered = false
    end
end

--[[
Select inputs:
    displayName:
        This isn't tied to any behaviors, it's only used for display purposes.
    behaviors:
        A table of behaviors.
        See §HzRxB for documentation on the available behaviors.
        This behaviors table should be registered with the serializer
        so it can be serialized and deserialized properly.
    args:
        Optional. This is an arbitrary value that will be passed along to behaviors.init().
]]
function static.new(displayName, state, behaviors, args)
    local instance = util.attachPrototype(prototype, {
        -- Used for introspection, so if others want to display this task, they have a name to display it by.
        displayName = displayName,
        -- Set to true after nextSprint() has been called at least once.
        _started = false,
        -- Set to true when all available sprints have been returned
        _exhausted = false,
        -- true when enter() gets called. false when exit() gets called.
        _entered = false,
        -- This is the "self" argument given to the various callbacks.
        -- The callbacks can choose to attach and modify data on this
        -- table however they please.
        _taskState = {},
        _behaviors = behaviors,
    })

    behaviors.init(instance._taskState, state, args)

    return instance
end

return static