local module = {}

local commandListeners = {}

local moduleId = 'act:commands:publicHelpers'

function module.execCommand(state, cmd)
    local type = cmd.command
    local args = cmd.args or {}

    commandListeners[type](state, table.unpack(args))
end

-- Convinient helper tool, as unique IDs are needed for some commands
function module.createIdGenerator(baseId)
    local lastId = 0
    return function(name)
        lastId = lastId + 1
        return 'id:'..baseId..':'..name..':'..lastId
    end
end

-- Note, if you ever choose to add a command directly (as a table literal) into the plan list
-- (something that higher-level commands might do), take care to handle the onSetup
-- stuff yourself, as that won't run if you bypass the command-initialization function.
function module.registerCommand(id, execute, opts)
    if opts == nil then opts = {} end
    local onSetup = opts.onSetup or nil
    local onExec = opts.onExec or nil

    commandListeners[id] = function(state, ...)
        if onExec ~= nil then onExec(state, table.unpack({...})) end
        execute(state, table.unpack({ ... }))
    end
    return function(planner, ...)
        -- A sanity check, because I mess this up a lot.
        if planner == nil or planner.plan == nil then
            error('Forgot to pass in a proper planner object into a command')
        end
        local returnValue = nil
        if onSetup ~= nil then returnValue = onSetup(planner, table.unpack({...})) end
        table.insert(planner.plan, { command = id, args = {...} })
        return returnValue
    end
end

-- A convinient shorthand function to remove boilerplate related to updating movement information.
function module.registerMovementCommand(id, execute, updatePos)
    return module.registerCommand(id, execute, {
        onSetup = function(planner)
            updatePos(planner.turtlePos)
        end,
        onExec = function(state)
            updatePos(state.turtlePos)
        end
    })
end

-- A convinient shorthand to cause the command to return a future
function module.registerCommandWithFuture(id, execute_, extractFutureId)
    local execute = function(state, ...)
        local futureId = extractFutureId(table.unpack({ ... }))
        local result = execute_(state, table.unpack({ ... }))
        if futureId ~= nil then
            state.getActiveTaskVars()[futureId] = result
        end
    end
    return module.registerCommand(id, execute, {
        onSetup = function(planner, ...)
            local futureId = extractFutureId(table.unpack({ ... }))
            if futureId ~= nil and type(futureId) ~= 'string' then
                error('Expected id to be a string or nil')
            end
            return futureId
        end
    })
end

-- Convinient function to bulk-register lots of transformers at once.
function module.registerFutureTransformers(baseId, transformers)
    local processedTransformers = {}
    for key, transformer in pairs(transformers) do
        fullId = 'futureTransformer:'..baseId..':'..key
        processedTransformers[key] = module.registerCommandWithFuture(fullId, function(state, opts)
            local inId = opts.in_
            local outId = opts.out

            local inValue = state.getActiveTaskVars()[inId]
            return transformer(inValue)
        end, function(opts) return opts.out end)
    end
    return processedTransformers
end

module.commonTransformers = module.registerFutureTransformers(
    moduleId..':commonTransformers',
    {
        not_ = function(value)
            return not value
        end,
    }
)

return module
