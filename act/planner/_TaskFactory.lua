local util = import('util.lua')
local commands = import('../_commands.lua')
local highLevelCommands = import('../highLevelCommands.lua')
local Task = import('./_Task.lua')
local serializer = import('../_serializer.lua')

local static = {}
local prototype = {}
serializer.registerValue('class-prototype:TaskFactory', prototype)

--[[
inputs:
    id: string
    opts?.init(self, state, args): void
        Called when a new task instance is created.
        This gives you a chance to initialize arbitrary state on the instance.
        `args` can be anything the caller wishes to supply the init function,
        and may be omitted.
    opts?.before(self, commands): void
        Called before the task has started.
        You can, for example, register a new location path that you will need to use within the task.
    opts?.enter(self, commands): void
        It will run before the task starts and whenever the task continues after an
        interruption, and is supposed to bring the turtle from any registered location
        in the world to a desired position.
    opts?.exit(self, commands): void
        This function will run after the task finishes and whenever the task needs to pause
        for an interruption, and is supposed to bring the turtle to a registered location.
    opts?.after(self, commands): void
        Called after the task has been fully completed.
        You can, for example, activate a mill or farm in this function.
    opts.nextSprint(self, commands): boolean
        Returns a "exhausted" boolean, which, when true,
        indicates that the task has finished. (i.e. it is not at an interruption point).
        After `true` is returned, `exit()` then `after()` will be called.

All functions provided above will be passed along as the "behaviors" to any
new tasks being created. Any optional behavior will be passed along as a no-op function.
See §HzRxB for where it gets used.
]]
function static.register(opts)
    local id = opts.id
    local taskBehaviors = {
        init = opts.init or function() end,
        before = opts.before or function() end,
        enter = opts.enter or function() end,
        exit = opts.exit or function() end,
        after = opts.after or function() end,
        nextSprint = opts.nextSprint,
    }

    serializer.registerValue('Task-behavior:'..id, taskBehaviors)

    local factory = util.attachPrototype(prototype, {
        _taskDisplayName = id,
        _taskBehaviors = taskBehaviors,
    })

    return factory
end

-- args is optional
function prototype:createTask(state, args)
    return Task.new(self._taskDisplayName, state, self._taskBehaviors, args)
end

return static