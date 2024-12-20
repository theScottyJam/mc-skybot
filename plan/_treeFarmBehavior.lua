local util = import('util.lua')
local act = import('act/init.lua')

local module = {}

local navigate = act.navigate
local navigationPatterns = act.navigationPatterns
local space = act.space
local highLevelCommands = act.highLevelCommands
local curves = act.curves

-- Above a tree is typically a floating block, then an optional torch.
-- This function expects you to to be right above where the torch would be.
function module.harvestTreeFromAbove(commands, state, opts)
    local bottomLogPos = opts.bottomLogPos
    local bottomLogCmps = space.createCompass(bottomLogPos)

    navigate.assertAtCoord(state, bottomLogCmps.coordAt({ up=10 }))
    navigate.face(commands, state, bottomLogCmps.facingAt({ face='forward' }))
    commands.turtle.forward(state)

    -- Move down until you hit leaves
    while true do
        commands.turtle.down(state)
        local isThereABlockBelow, blockBelowInfo = commands.turtle.inspectDown(state)
        if isThereABlockBelow and blockBelowInfo.name == 'minecraft:leaves' then
            break
        end
    end

    -- Harvest top-half of leaves
    local topLeafCmps = state.turtleCmps().compassAt({ forward=-1, up=-1 })
    local cornerPos = topLeafCmps.posAt({ forward = 1, right = 1, face='backward' })
    navigate.moveToPos(commands, state, cornerPos, { 'right', 'forward', 'up' })
    navigationPatterns.spiralInwards(commands, state, {
        sideLength = 3,
        onVisit = function(commands, state)
            commands.turtle.dig(state)
            commands.turtle.digDown(state)
        end
    })

    -- Harvest bottom-half of leaves
    local aboveCornerPos = topLeafCmps.posAt({ forward = 2, right = 2, up = -1, face='backward' })
    navigate.moveToPos(commands, state, aboveCornerPos, { 'right', 'forward', 'up' })
    commands.turtle.digDown(state)
    commands.turtle.down(state)
    navigationPatterns.spiralInwards(commands, state, {
        sideLength = 5,
        onVisit = function(commands, state)
            commands.turtle.dig(state)
            commands.turtle.digDown(state)
        end
    })
    navigate.face(commands, state, topLeafCmps.facingAt({ face='forward' }))

    -- Harvest trunk
    while true do
        commands.turtle.digDown(state)
        commands.turtle.down(state)
        local isThereABlockBelow, blockBelowInfo = commands.turtle.inspectDown(state)
        if not isThereABlockBelow or blockBelowInfo.name ~= 'minecraft:log' then
            break
        end
    end

    navigate.assertAtPos(state, bottomLogCmps.pos)
end

-- You must be standing at the inFrontOfTreeCmps position before calling this.
-- This will check if the tree has grown, and if so, harvest it.
function module.tryHarvestTree(commands, state, inFrontOfTreeCmps)
    local success, blockInfo = commands.turtle.inspect(state)

    local blockIsLog = success and blockInfo.name == 'minecraft:log'
    if blockIsLog then
        local bottomLogCmps = inFrontOfTreeCmps.compassAt({ forward=1 })
        navigate.moveToCoord(commands, state, inFrontOfTreeCmps.coordAt({ forward=-2 }))
        navigate.moveToPos(commands, state, bottomLogCmps.posAt({ up=10 }), { 'up', 'forward', 'right' })
        module.harvestTreeFromAbove(commands, state, { bottomLogPos = bottomLogCmps.pos })
        navigate.moveToPos(commands, state, inFrontOfTreeCmps.pos)
        highLevelCommands.placeItem(commands, state, 'minecraft:sapling', { allowMissing = true })
    end
end

module.stats = {
    supplies = {
        'minecraft:log',
        'minecraft:sapling',
        'minecraft:apple',
        -- 'minecraft:stick',
    },
    calcExpectedYield = function(timeSpan)
        local checkTime = 20
        local treeHarvestTime = 140

        local logsPerTree = 7
        local leavesOnTree = 50
        local chanceOfAppleDrop = 1/200
        local chanceOfSaplingDrop = 1/50
        local chanceOfStickDrop = 1.5/50
        local saplingsDroppedPerTree = 2.75
        local createCurve = curves.sigmoidFactory({ minX = 0.3, maxX = 3 })
        return {
            work = createCurve({ minY = checkTime, maxY = checkTime + treeHarvestTime * 2 })(timeSpan),
            yield = {
                ['minecraft:log'] = createCurve({ maxY = 2 * logsPerTree })(timeSpan),
                ['minecraft:sapling'] = createCurve({ maxY = 2 * leavesOnTree * chanceOfSaplingDrop })(timeSpan),
                ['minecraft:apple'] = createCurve({ maxY = 2 * leavesOnTree * chanceOfAppleDrop })(timeSpan),
                -- Commenting this out, because I don't want the turtle to ever purposely try waiting
                -- for tree to grow in order to get sticks, when the turtle might have wood on hand
                -- and could just craft them.
                -- ['minecraft:stick'] = createCurve({ maxY = 2 * leavesOnTree * chanceOfStickDrop })(timeSpan),
            },
        }
    end,
}

return module
