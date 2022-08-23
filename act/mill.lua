--[[
    A mill is something that requires active attention to produce a resource.
    The more attention you give it, the more it produces.
--]]

local module = {}

-- opts.supplies is a list of resources the mill is capable of supplying.
-- Returns a mill instance
function module.create(taskRunnerId, opts)
    local commands = _G.act.commands

    local supplies = opts.supplies

    return {
        activate = function(planner)
            commands.general.activateMill(planner, {
                taskRunnerId = taskRunnerId,
                supplies = supplies,
            })
        end
    }
end

return module
