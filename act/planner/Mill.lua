--[[
    A mill is something that requires active attention to produce a resource.
    The more attention you give it, the more it produces.
]]

local util = import('util.lua')
local TaskFactory = import('./_TaskFactory.lua')
local serializer = import('../_serializer.lua')
local resourceCollection = import('./_resourceCollection.lua')

local static = {}
local prototype = {}

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
    opts?.onActivated()
        This gets called when the mill is first activated
    ...taskFactoryOpts
        Any options accepted by the generate-task-factory function
        can also be used here.
]]
function static.register(opts)
    opts = util.copyTable(opts)
    local id = 'mill:'..opts.id
    local getRequiredResources = opts.getRequiredResources or function() return {} end
    local supplies = opts.supplies
    local onActivated = opts.onActivated or function() end
    opts.id = nil
    opts.getRequiredResources = nil
    opts.supplies = nil
    opts.onActivated = nil

    local taskFactory = TaskFactory.register(
        util.mergeTables(opts, { id = id })
    )

    local mill = util.attachPrototype(prototype, {
        _id = id,
        _taskFactory = taskFactory,
        _getRequiredResources = getRequiredResources,
        _supplies = supplies,
        _onActivated = onActivated,
    })
    serializer.registerValue(id, mill)

    return mill
end

function static.__isInstance(instance)
    return util.hasPrototype(instance, prototype)
end

function prototype:activate()
    resourceCollection.markSupplierAsAvailable(self)
    self._onActivated()
end

function prototype:__resourcesSupplied()
    return self._supplies
end

function prototype:__getRequiredResources(resourceRequest)
    return self._getRequiredResources(resourceRequest)
end

function prototype:__createTask(resourceRequests)
    return self._taskFactory:createTask(resourceRequests)
end

return static