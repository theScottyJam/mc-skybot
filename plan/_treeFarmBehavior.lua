local util = import('util.lua')
local act = import('act/init.lua')

local module = {}

local navigate = act.navigate
local space = act.space
local highLevelCommands = act.highLevelCommands
local curves = act.curves
local commands = act.commands
local state = act.state

-- Above a tree is typically a floating block, then an optional torch.
-- This function expects you to to be right above where the torch would be.
--
-- You can start facing any direction you wish.
--
-- endFacing is required and must be set to 'ANY' to remind you that the turtle
-- could end facing any direction.
function module.harvestTreeFromAbove(opts)
    local bottomLogCoord = opts.bottomLogCoord
    util.assert(opts.endFacing == 'ANY')

    navigate.assertAtCoord(bottomLogCoord:at({ up=10 }))
    navigate.face('forward')
    commands.turtle.forward()

    -- Move down until you hit leaves
    while true do
        commands.turtle.down()
        local isThereABlockBelow, blockBelowInfo = commands.turtle.inspectDown()
        if isThereABlockBelow and blockBelowInfo.name == 'minecraft:leaves' then
            break
        end
    end

    -- Harvest top-half of leaves
    local topLeafCoord = navigate.getTurtlePos().coord:at({ forward=-1, up=-1 })
    local cornerPos = topLeafCoord:at({ forward = 1, right = 1 }):face('backward')
    navigate.moveToPos(cornerPos, { 'right', 'forward', 'up' })
    highLevelCommands.spiralInwards({
        sideLength = 3,
        onVisit = function()
            commands.turtle.dig()
            commands.turtle.digDown()
        end
    })

    -- Harvest bottom-half of leaves
    local aboveCornerPos = topLeafCoord:at({ forward = 2, right = 2, up = -1 }):face('backward')
    navigate.moveToPos(aboveCornerPos, { 'right', 'forward', 'up' })
    commands.turtle.digDown()
    commands.turtle.down()
    highLevelCommands.spiralInwards({
        sideLength = 5,
        onVisit = function()
            commands.turtle.dig()
            commands.turtle.digDown()
        end
    })
    navigate.face('forward')

    -- Harvest trunk
    while true do
        commands.turtle.digDown()
        commands.turtle.down()
        local isThereABlockBelow, blockBelowInfo = commands.turtle.inspectDown()
        if not isThereABlockBelow or blockBelowInfo.name ~= 'minecraft:log' then
            break
        end
    end

    navigate.assertAtCoord(bottomLogCoord)
end

-- You must be standing at the inFrontOfTreePos position (facing the tree) before calling this.
-- This will check if the tree has grown, and if so, harvest it.
function module.tryHarvestTree(inFrontOfTreePos)
    local success, blockInfo = commands.turtle.inspect()

    local blockIsLog = success and blockInfo.name == 'minecraft:log'
    if blockIsLog then
        local bottomLogCoord = inFrontOfTreePos.coord:at({ forward=1 })
        navigate.moveToCoord(inFrontOfTreePos.coord:at({ forward=-2 }))
        navigate.moveToCoord(bottomLogCoord:at({ up=10 }), { 'up', 'forward', 'right' })
        module.harvestTreeFromAbove({ bottomLogCoord = bottomLogCoord, endFacing = 'ANY' })
        navigate.moveToPos(inFrontOfTreePos)
        highLevelCommands.placeItem('minecraft:sapling', { allowMissing = true })
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
