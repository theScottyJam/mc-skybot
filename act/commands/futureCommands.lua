local publicHelpers = import('./_publicHelpers.lua')

local module = {}

local registerCommand = publicHelpers.registerCommand
local registerCommandWithFuture = publicHelpers.registerCommandWithFuture

local moduleId = 'act:commands:futureCommands'
local genId = publicHelpers.createIdGenerator(moduleId)

local createPosInterprettingDifferencesAsUnknowns = function(pos1, pos2)
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

-- opts looks like { value=..., out=... }
module.set = registerCommandWithFuture('futures:set', function(state, opts)
    return opts.value
end, function(opts) return opts.out end)

module.delete = registerCommand('futures:delete', function(state, opts)
    local inId = opts.in_
    -- The variable might not exist if it is only registered during a branch that never runs
    local allowMissing = opts.allowMissing

    if not allowMissing and state.getActiveTaskVars()[inId] == nil then
        error('Failed to find variable with future-id to delete')
    end
    state.getActiveTaskVars()[inId] = nil
end)

module.updateTaskState = registerCommand('futures:updateTaskState', function(state, in_, taskStateUpdater)
    local activeTask = state.getActiveTask()
    if activeTask == nil then
        error('updateTaskState() can only be used when there is currently a task in progress')
    end

    local inValue = activeTask.taskVars[in_]
    activeTask.taskState = taskStateUpdater(inValue, activeTask.taskState)
end)

local while_ = registerCommand('futures:while', function(state, opts)
    local subCommands = opts.subCommands
    local continueIfFuture = opts.continueIfFuture
    local runIndex = opts.runIndex or 1

    if #subCommands == 0 then error('The block must register at least one command') end

    if runIndex == 1 then
        if not state.getActiveTaskVars()[continueIfFuture] then
            return -- break the loop
        end
    end

    local nextRunIndex = runIndex + 1
    if nextRunIndex > #subCommands then
        nextRunIndex = 1
    end

    local newOpts = { subCommands = subCommands, runIndex = nextRunIndex, continueIfFuture = continueIfFuture }
    table.insert(state.plan, 1, { command = 'futures:while', args = {newOpts} })
    table.insert(state.plan, 1, subCommands[runIndex])
end)

-- IMPORTANT: If you create new futures inside the while loop,
-- be sure to call delete() on them afterwards to clean them up.
--
-- Don't do branching logic and what-not inside the passed-in block.
-- it needs to be possible to run the block in advance to learn about the behavior of the block.
module.while_ = function(planner, opts, block)
    local continueIfFuture = opts.continueIf

    -- First run of block() is used to determin how the turtle moves
    local originalPlanLength = #planner.plan
    local innerPlanner = _G.act.planner.copy(planner)
    block(innerPlanner)

    if originalPlanLength < #planner.plan then
        error('The outer plan got updated during a block. Only the passed-in plan should be modified. ')
    end

    planner.turtlePos = createPosInterprettingDifferencesAsUnknowns(planner.turtlePos, innerPlanner.turtlePos)

    -- Second run of block() is used to determin the actual list of block commands to record.
    -- This time around, the turtlePos has been updated to have UNKNOWN positions where appropriate.
    local innerPlanner2 = _G.act.planner.copy(planner)
    innerPlanner2.plan = {}
    block(innerPlanner2)

    while_(planner, {
        subCommands = innerPlanner2.plan,
        continueIfFuture = continueIfFuture,
    })
end

local if_ = registerCommand('futures:if', function(state, opts)
    local subCommands = opts.subCommands
    local enterIfFuture = opts.enterIfFuture

    if #subCommands == 0 then error('The block must register at least one command') end

    if state.getActiveTaskVars()[enterIfFuture] then
        for i = #subCommands, 1, -1 do
            table.insert(state.plan, 1, subCommands[i])
        end
    end
end)

-- Don't do branching logic and what-not inside the passed-in block (e.g. using lua's if-else).
-- it needs to be possible to run the block in advance to learn about the behavior of the block.
module.if_ = function(planner, enterIfFuture, block)
    -- First run of block() is used to determin how the turtle moves
    local originalPlanLength = #planner.plan
    local innerPlanner = _G.act.planner.copy(planner)
    local commonTransformers = _G.act.commands.commonTransformers
    innerPlanner.plan = {}
    block(innerPlanner)

    if originalPlanLength < #planner.plan then
        error('The outer plan got updated during a block. Only the passed-in plan should be modified. ')
    end

    planner.turtlePos = createPosInterprettingDifferencesAsUnknowns(planner.turtlePos, innerPlanner.turtlePos)

    if_(planner, {
        subCommands = innerPlanner.plan,
        enterIfFuture = enterIfFuture,
    })

    return {
        else_ = function(block)
            local enterIfNotFuture = commonTransformers.not_(planner, { in_=enterIfFuture, out=genId('enterIfNotFuture') })
            module.if_(planner, enterIfNotFuture, block)
        end
    }
end

return module
