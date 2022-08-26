local publicHelpers = import('./_publicHelpers.lua')

local module = {}

local registerCommand = publicHelpers.registerCommand
local registerCommandWithFuture = publicHelpers.registerCommandWithFuture

-- opts looks like { value=..., out=... }
module.set = registerCommandWithFuture('futures:set', function(state, opts)
    return opts.value
end, function(opts) return opts.out end)

module.delete = registerCommand('futures:delete', function(state, opts)
    local inId = opts.in_
    -- The variable might not exist if it is only registered during a branch that never runs
    local allowMissing = opts.allowMissing

    if not allowMissing and state.getActiveTask().taskVars[inId] == nil then
        error('Failed to find variable with future-id to delete')
    end
    state.getActiveTask().taskVars[inId] = nil
end)

local while_ = registerCommand('futures:while', function(state, opts)
    local subCommands = opts.subCommands
    local continueIfFuture = opts.continueIfFuture
    local runIndex = opts.runIndex or 1

    if #subCommands == 0 then error('The block must register at least one command') end

    if runIndex == 1 then
        if not state.getActiveTask().taskVars[continueIfFuture] then
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

    return while_(planner, {
        subCommands = innerPlanner2.plan,
        continueIfFuture = continueIfFuture,
    })
end

local if_ = registerCommand('futures:if', function(state, opts)
    local subCommands = opts.subCommands
    local enterIfFuture = opts.enterIfFuture

    if #subCommands == 0 then error('The block must register at least one command') end

    if state.getActiveTask().taskVars[enterIfFuture] then
        for i = #subCommands, 1, -1 do
            table.insert(state.plan, 1, subCommands[i])
        end
    end
end)

-- Don't do branching logic and what-not inside the passed-in block.
-- it needs to be possible to run the block in advance to learn about the behavior of the block.
module.if_ = function(planner, enterIfFuture, block)
    -- First run of block() is used to determin how the turtle moves
    local originalPlanLength = #planner.plan
    local innerPlanner = _G.act.planner.copy(planner)
    innerPlanner.plan = {}
    block(innerPlanner)

    if originalPlanLength < #planner.plan then
        error('The outer plan got updated during a block. Only the passed-in plan should be modified. ')
    end

    planner.turtlePos = createPosInterprettingDifferencesAsUnknowns(planner.turtlePos, innerPlanner.turtlePos)

    return if_(planner, {
        subCommands = innerPlanner.plan,
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

return module
