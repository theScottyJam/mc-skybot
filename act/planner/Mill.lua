--[[
    A mill is something that requires active attention to produce a resource.
    The more attention you give it, the more it produces.
]]

local util = import('util.lua')
local TaskFactory = import('./_TaskFactory.lua')
local serializer = import('../_serializer.lua')

local static = {}
local prototype = {}

-- Triggered with a mill instance as an argument.
-- Outside modules can subscribe to it, but should not trigger it.
static.__onActivated = util.createEventEmitter()

--[[
inputs:
    id: string
    opts?.getRequiredResources(resourceRequest)
        resourceRequest is of the shape { resourceName = ..., quantity = ... }.
        this function should return what resources are required to fulfill this,
        request. The return value should be in
        the shape of { <name> = <quantity>, ... }.
    opts.supplies
        A list of resources the mill is capable of supplying.
    ...taskFactoryOpts
        Any options accepted by the generate-task-factory function
        can also be used here.
]]
function static.register(opts)
    opts = util.copyTable(opts)
    local id = 'mill:'..opts.id
    local getRequiredResources = opts.getRequiredResources or function() return {} end
    local supplies = opts.supplies
    opts.id = nil
    opts.getRequiredResources = nil
    opts.supplies = nil

    local taskFactory = TaskFactory.register(
        util.mergeTables(opts, { id = id })
    )

    local mill = util.attachPrototype(prototype, {
        _id = id,
        _taskFactory = taskFactory,
        __getRequiredResources = getRequiredResources,
        __supplies = supplies,
    })
    serializer.registerValue(id, mill)

    return mill
end

function static.__isInstance(instance)
    return util.hasPrototype(instance, prototype)
end

function prototype:activate()
    static.__onActivated:trigger(self)
end

function prototype:__createTask(args)
    return self._taskFactory:createTask(args)
end

return static