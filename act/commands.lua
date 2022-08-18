local util = import('util.lua')

local turtleActions = {}
local futuresActions = {}
local generalActions = {}
local mockHooksActions = {}
local module = {
    turtle = turtleActions,
    futures = futuresActions,
    general = generalActions,
    mockHooks = mockHooksActions,
}

local commandListeners = {}

-- Note, if you ever choose to add a command directly (as a table literal) into the shortTermPlan list
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
    return function(shortTermPlanner, ...)
        -- A sanity check, because I mess this up a lot.
        if shortTermPlanner == nil or shortTermPlanner.shortTermPlan == nil then
            error('Forgot to pass in a proper shortTermPlanner object into a command')
        end
        local returnValue = nil
        if onSetup ~= nil then returnValue = onSetup(shortTermPlanner, table.unpack({...})) end
        table.insert(shortTermPlanner.shortTermPlan, { command = id, args = {...} })
        return returnValue
    end
end
local registerCommand = module.registerCommand

-- A convinient shorthand function to remove boilerplate related to updating movement information.
function registerMovementCommand(id, execute, updatePos)
    return registerCommand(id, execute, {
        onSetup = function(shortTermPlanner)
            updatePos(shortTermPlanner.turtlePos)
        end,
        onExec = function(state)
            updatePos(state.turtlePos)
        end
    })
end

-- A convinient shorthand to cause the command to return a future
function module.registerCommandWithFuture(id, execute_, extractFutureId)
    function execute(state, ...)
        local futureId = extractFutureId(table.unpack({ ... }))
        local result = execute_(state, table.unpack({ ... }))
        if futureId ~= nil then
            state.primaryTask.projectVars[futureId] = result
        end
    end
    return registerCommand(id, execute, {
        onSetup = function(shortTermPlanner, ...)
            local futureId = extractFutureId(table.unpack({ ... }))
            if futureId ~= nil and type(futureId) ~= 'string' then
                error('Expected id to be a string or nil')
            end
            return futureId
        end
    })
end
local registerCommandWithFuture = module.registerCommandWithFuture

-- Convinient function to bulk-register lots of transformers at once.
function module.registerFutureTransformers(baseId, transformers)
    local processedTransformers = {}
    for key, transformer in pairs(transformers) do
        fullId = 'futureTransformer:'..baseId..':'..key
        processedTransformers[key] = registerCommandWithFuture(fullId, function(state, opts)
            local inId = opts.in_
            local outId = opts.out

            local inValue = state.primaryTask.projectVars[inId]
            return transformer(inValue)
        end, function(opts) return opts.out end)
    end
    return processedTransformers
end

-- Convinient helper tool, as unique IDs are needed for some commands
function module.createIdGenerator(baseId)
    local lastId = 0
    return function(name)
        lastId = lastId + 1
        return 'id:'..baseId..':'..name..':'..lastId
    end
end

function module.execCommand(state, cmd)
    local type = cmd.command
    local args = cmd.args or {}

    commandListeners[type](state, table.unpack(args))
end

turtleActions.up = registerMovementCommand('turtle:up', function(state)
    turtle.up()
end, function(turtlePos)
    turtlePos.up = turtlePos.up + 1
end)

turtleActions.down = registerMovementCommand('turtle:down', function(state)
    turtle.down()
end, function(turtlePos)
    turtlePos.up = turtlePos.up - 1
end)

turtleActions.forward = registerMovementCommand('turtle:forward', function(state)
    turtle.forward()
end, function(turtlePos)
    if turtlePos.face == 'forward' then turtlePos.forward = turtlePos.forward + 1
    elseif turtlePos.face == 'backward' then turtlePos.forward = turtlePos.forward - 1
    elseif turtlePos.face == 'right' then turtlePos.right = turtlePos.right + 1
    elseif turtlePos.face == 'left' then turtlePos.right = turtlePos.right - 1
    else error('Invalid face')
    end
end)

turtleActions.backward = registerMovementCommand('turtle:backward', function(state)
    turtle.backward()
end, function(turtlePos)
    if turtlePos.face == 'forward' then turtlePos.forward = turtlePos.forward - 1
    elseif turtlePos.face == 'backward' then turtlePos.forward = turtlePos.forward + 1
    elseif turtlePos.face == 'right' then turtlePos.right = turtlePos.right - 1
    elseif turtlePos.face == 'left' then turtlePos.right = turtlePos.right + 1
    else error('Invalid face')
    end
end)

turtleActions.turnLeft = registerMovementCommand('turtle:turnLeft', function(state)
    turtle.turnLeft()
end, function(turtlePos)
    turtlePos.face = _G.act.space.rotateFaceCounterClockwise(turtlePos.face)
end)

turtleActions.turnRight = registerMovementCommand('turtle:turnRight', function(state)
    turtle.turnRight()
end, function(turtlePos)
    turtlePos.face = _G.act.space.rotateFaceClockwise(turtlePos.face)
end)

turtleActions.select = registerCommand('turtle:select', function(state, slotNum)
    turtle.select(slotNum)
end)

-- signText is optional
turtleActions.place = registerCommand('turtle:place', function(state, signText)
    turtle.place(signText)
end)

turtleActions.placeUp = registerCommand('turtle:placeUp', function(state)
    turtle.placeUp()
end)

turtleActions.placeDown = registerCommand('turtle:placeDown', function(state)
    turtle.placeDown()
end)

-- opts looks like { out=... }
turtleActions.inspect = registerCommandWithFuture('turtle:inspect', function(state, opts)
    local success, blockInfo = turtle.inspect()
    return { success, blockInfo }
end, function (opts) return opts.out end)

-- opts looks like { out=... }
turtleActions.inspectUp = registerCommandWithFuture('turtle:inspectUp', function(state, opts)
    local success, blockInfo = turtle.inspectUp()
    return { success, blockInfo }
end, function (opts) return opts.out end)

-- opts looks like { out=... }
turtleActions.inspectDown = registerCommandWithFuture('turtle:inspectDown', function(state, opts)
    local success, blockInfo = turtle.inspectDown()
    return { success, blockInfo }
end, function (opts) return opts.out end)

turtleActions.dig = registerCommand('turtle:dig', function(state, toolSide)
    turtle.dig(toolSide)
end)

turtleActions.digUp = registerCommand('turtle:digUp', function(state, toolSide)
    turtle.digUp(toolSide)
end)

turtleActions.digDown = registerCommand('turtle:digDown', function(state, toolSide)
    turtle.digDown(toolSide)
end)

turtleActions.suck = registerCommand('turtle:suck', function(state, amount)
    turtle.suck(amount)
end)

turtleActions.suckUp = registerCommand('turtle:suckUp', function(state, amount)
    turtle.suckUp(amount)
end)

turtleActions.suckDown = registerCommand('turtle:suckDown', function(state, amount)
    turtle.suckDown(amount)
end)

-- quantity is optional
turtleActions.transferTo = registerCommand('turtle:transferTo', function(state, destinationSlot, quantity)
    turtle.transferTo(destinationSlot, quantity)
end)

-- opts looks like { value=..., out=... }
futuresActions.set = registerCommandWithFuture('futures:set', function(state, opts)
    return opts.value
end, function(opts) return opts.out end)

futuresActions.delete = registerCommand('futures:delete', function(state, opts)
    local inId = opts.in_
    -- The variable might not exist if it is only registered during a branch that never runs
    local allowMissing = opts.allowMissing

    if not allowMissing and state.primaryTask.projectVars[inId] == nil then
        error('Failed to find variable with future-id to delete')
    end
    state.primaryTask.projectVars[inId] = nil
end)

local while_ = registerCommand('futures:while', function(state, opts)
    local subCommands = opts.subCommands
    local continueIfFuture = opts.continueIfFuture
    local runIndex = opts.runIndex or 1

    if #subCommands == 0 then error('The block must register at least one command') end

    if runIndex == 1 then
        if not state.primaryTask.projectVars[continueIfFuture] then
            return -- break the loop
        end
    end

    local nextRunIndex = runIndex + 1
    if nextRunIndex > #subCommands then
        nextRunIndex = 1
    end

    local newOpts = { subCommands = subCommands, runIndex = nextRunIndex, continueIfFuture = continueIfFuture }
    table.insert(state.shortTermPlan, 1, { command = 'futures:while', args = {newOpts} })
    table.insert(state.shortTermPlan, 1, subCommands[runIndex])
end)

-- Don't do branching logic and what-not inside the passed-in block.
-- it needs to be possible to run the block in advance to learn about the behavior of the block.
futuresActions.while_ = function(shortTermPlanner, opts, block)
    local continueIfFuture = opts.continueIf

    -- First run of block() is used to determin how the turtle moves
    local originalShortTermPlanLength = #shortTermPlanner.shortTermPlan
    local innerPlanner = _G.act.shortTermPlanner.copy(shortTermPlanner)
    block(innerPlanner)

    if originalShortTermPlanLength < #shortTermPlanner.shortTermPlan then
        error('The outer shortTermPlan got updated during a block. Only the passed-in shortTermPlan should be modified. ')
    end

    shortTermPlanner.turtlePos = createPosInterprettingDifferencesAsUnknowns(shortTermPlanner.turtlePos, innerPlanner.turtlePos)

    -- Second run of block() is used to determin the actual list of block commands to record.
    -- This time around, the turtlePos has been updated to have UNKNOWN positions where appropriate.
    local innerPlanner2 = _G.act.shortTermPlanner.copy(shortTermPlanner)
    innerPlanner2.shortTermPlan = {}
    block(innerPlanner2)

    return while_(shortTermPlanner, {
        subCommands = innerPlanner2.shortTermPlan,
        continueIfFuture = continueIfFuture,
    })
end

local if_ = registerCommand('futures:if', function(state, opts)
    local subCommands = opts.subCommands
    local enterIfFuture = opts.enterIfFuture

    if #subCommands == 0 then error('The block must register at least one command') end

    if state.primaryTask.projectVars[enterIfFuture] then
        for i = #subCommands, 1, -1 do
            table.insert(state.shortTermPlan, 1, subCommands[i])
        end
    end
end)

-- Don't do branching logic and what-not inside the passed-in block.
-- it needs to be possible to run the block in advance to learn about the behavior of the block.
futuresActions.if_ = function(shortTermPlanner, enterIfFuture, block)
    -- First run of block() is used to determin how the turtle moves
    local originalShortTermPlanLength = #shortTermPlanner.shortTermPlan
    local innerPlanner = _G.act.shortTermPlanner.copy(shortTermPlanner)
    innerPlanner.shortTermPlan = {}
    block(innerPlanner)

    if originalShortTermPlanLength < #shortTermPlanner.shortTermPlan then
        error('The outer shortTermPlan got updated during a block. Only the passed-in shortTermPlan should be modified. ')
    end

    shortTermPlanner.turtlePos = createPosInterprettingDifferencesAsUnknowns(shortTermPlanner.turtlePos, innerPlanner.turtlePos)

    return if_(shortTermPlanner, {
        subCommands = innerPlanner.shortTermPlan,
        enterIfFuture = enterIfFuture,
    })
end

function createPosInterprettingDifferencesAsUnknowns(pos1, pos2)
    local space = _G.act.space
    if space.comparePos(pos1, pos2) then
        return pos1
    end

    local commonFromField = space.findCommonFromField(pos1, pos2)
    local pos1Squashed = space.squashFromFields(pos1, { limit = commonFromField })
    local pos2Squashed = space.squashFromFields(pos2, { limit = commonFromField })

    local newStemPos = { from = commonFromField }
    for _, field in ipairs({ 'forward', 'right', 'up', 'face' }) do
        if pos1Squashed[field] == pos2Squashed[field] then
            newStemPos[field] = pos1Squashed[field]
        else
            newStemPos[field] = 'UNKNOWN'
        end
    end

    return { forward = 0, right = 0, up = 0, face = 'forward', from = newStemPos }
end

mockHooksActions.registerCobblestoneRegenerationBlock = registerCommand(
    'mockHooks:registerCobblestoneRegenerationBlock',
    function(state, coord)
        local mockHooks = _G.act.mockHooks
        local space = _G.act.space
        mockHooks.registerCobblestoneRegenerationBlock(coord)
    end
)

generalActions.setState = registerCommand('general:setState', function(state, updates)
    util.mergeTablesInPlace(state, updates)
end)

generalActions.debug = registerCommand('general:debug', function(state, opts)
    debug.onDebugCommand(state, opts)
end)

return module
