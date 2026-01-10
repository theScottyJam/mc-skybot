--[[
    A task can, at any moment, ask for a routine to be executed.
    A routine is really just another task-factory that's capable of being embedded.
]]

local util = import('util.lua')
local TaskFactory = import('./_TaskFactory.lua')
local serializer = import('../_serializer.lua')

local static = {}
local prototype = {}

-- Inputs: Same as taskFactory's inputs
function static.register(opts)
    opts = util.copyTable(opts)
    opts.id = 'routine:'..opts.id

    local routine = util.attachPrototype(prototype, {
        -- Used for introspection, so if others want to display this routine, they have a name to display it by.
        displayName = opts.id,
        _taskFactory = TaskFactory.register(opts),
    })
    serializer.registerValue(opts.id, routine)

    return routine
end

function static.__isInstance(instance)
    return util.hasPrototype(instance, prototype)
end

function prototype:__createTask()
    return self._taskFactory:createTask()
end

return static