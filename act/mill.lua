--[[
    A mill is something that requires active attention to produce a resource.
    The more attention you give it, the more it produces.
--]]

local module = {}

local millRegistry = {}

-- opts.harvest() takes a state and a resource-request, and returns a short-term plan.
--   The resource-request is a mapping of desired resources to quantities desired.
-- opts.supplies is a list of resources the mill is capable of supplying.
-- Returns the mill id passed in.
function module.register(id, opts)
    millRegistry[id] = {
        supplies = opts.supplies,
        harvest = opts.harvest,
    }
    return id
end

function module.lookup(millId)
    return millRegistry[millId]
end

return module
