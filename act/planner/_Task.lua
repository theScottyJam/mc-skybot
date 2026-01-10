local util = import('util.lua')
local highLevelCommands = import('../highLevelCommands.lua')
local serializer = import('../_serializer.lua')
local RoutineModule = moduleLoader.lazyImport('./Routine.lua')

local static = {}
local prototype = {}
serializer.registerValue('class-prototype:Task', prototype)

-- Get the task that's currently being used.
function prototype:_liveTask()
    local parent = nil
    local task = self
    while task._delegate ~= nil do
        parent = task
        task = task._delegate
    end
    return task, parent
end

-- Called to fetch the next sprint.
--
-- If this is the first sprint, or if the turtle had previously left (with leave()),
-- then this function should expect the turtle to be found at any arbitrary registered
-- location, and it will need to navigate the turtle to a desired spot.
--
-- If this was the last sprint, leave the turtle at a registered location,
-- then return true.
function prototype:nextSprint()
    local Routine = RoutineModule.load()
    local task, taskParent = self:_liveTask()
    task._justExecutedDelegate = false

    if not task._started then
        task._behaviors.before(task._taskState)
        task._started = true
    end

    if task._exhausted then
        error('This task is already finished')
    end

    if not task._entered then
        task._behaviors.enter(task._taskState)
        task._entered = true
    end

    local sprintResult = task._behaviors.nextSprint(task._taskState)
    util.assert(type(sprintResult) == 'boolean' or Routine.__isInstance(sprintResult), 'nextSprint() must return a boolean or a routine.')
    task._exhausted = sprintResult == true

    if sprintResult == true then
        task._behaviors.exit(task._taskState)
        task._entered = false
        task._behaviors.after(task._taskState)
        if taskParent ~= nil then
            taskParent._delegate = nil
            taskParent._justExecutedDelegate = true
        end
    end

    if Routine.__isInstance(sprintResult) then
        task._behaviors.exit(task._taskState)
        task._entered = false
        task._delegate = sprintResult:__createTask()
    end

    return self._exhausted
end

-- Called when an interruption is happening. This should navigate the turtle
-- to a registered location.
function prototype:prepareForInterrupt()
    local task = self:_liveTask()
    if task._entered then
        task._behaviors.exit(task._taskState)
        task._entered = false
    end
end

-- Called to learn what would happen if an interruption were to be triggered
-- Returns: { location = ..., work = ... }
function prototype:ifInterrupted()
    local task = self:_liveTask()
    util.assert(task._entered, 'This can only be called when you are actively performing the task.')
    util.assert(task._behaviors.ifExits ~= nil, 'This task does not support interruptions.')
    return task._behaviors.ifExits(task._taskState)
end

function prototype:entered()
    return self:_liveTask()._entered
end

-- Returns a list of display names, starting with this task then moving through its delegates.
function prototype:displayNameList()
    local displayNameList = {}
    local task = self
    while task ~= nil do
        table.insert(displayNameList, task.displayName)
        task = task._delegate
    end
    return displayNameList
end

--[[
Inputs:
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
function static.new(displayName, behaviors, args)
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
        -- If this task asked for another routine to run, then that other routine's
        -- task will be stored here.
        _delegate = nil,
        _behaviors = behaviors,
    })

    behaviors.init(instance._taskState, args)

    return instance
end

return static