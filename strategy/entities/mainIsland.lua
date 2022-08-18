local util = import('util.lua')

local module = {}

local moduleId = 'entity:mainIsland'
local genId = _G.act.commands.createIdGenerator(moduleId)

function module.init()
    return _G.act.entity.createEntityFactory(entityBuilder)
end

-- opts.bedrockCoord - the coordinate of the bedrock block
function entityBuilder(opts)
    local location = _G.act.location
    local space = _G.act.space

    -- The bedrockCoord should always be at (0, 64, -3}
    local bedrockPos = util.mergeTables(opts.bedrockCoord, { face = 'forward' })

    -- homeLoc is right above the bedrock
    local homeLoc = location.register(space.resolveRelPos({ up=3 }, bedrockPos))
    -- initialLoc is in front of the chest
    local initialLoc = location.register(space.resolveRelPos({ right=3, face='left' }, homeLoc.pos))

    local harvestInitialTreeAndPrepareTreeFarm = harvestInitialTreeAndPrepareTreeFarmProject({ bedrockPos = bedrockPos, homeLoc = homeLoc })
    local prepareCobblestoneGenerator = prepareCobblestoneGeneratorProject({ homeLoc = homeLoc })
    local waitForIceToMeltAndfinishCobblestoneGenerator = waitForIceToMeltAndfinishCobblestoneGeneratorProject({ homeLoc = homeLoc })
    local harvestCobblestone = harvestCobblestoneProject({ homeLoc = homeLoc })

    return {
        init = function()
            location.registerPath(initialLoc, homeLoc)
        end,
        entity = {
            initialLoc = initialLoc,
            homeLoc = homeLoc,
            harvestInitialTreeAndPrepareTreeFarm = harvestInitialTreeAndPrepareTreeFarm,
            prepareCobblestoneGenerator = prepareCobblestoneGenerator,
            waitForIceToMeltAndfinishCobblestoneGenerator = waitForIceToMeltAndfinishCobblestoneGenerator,
            harvestCobblestone = harvestCobblestone,
        }
    }
end

-- Pre-condition: Must have two dirt in inventory
function harvestInitialTreeAndPrepareTreeFarmProject(opts)
    local bedrockPos = opts.bedrockPos
    local homeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    local bedrockCmps = space.createCompass(bedrockPos)
    return _G.act.project.register('mainIsland:harvestInitialTreeAndPrepareTreeFarm', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlanner = _G.act.shortTermPlanner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlanner, homeLoc)
            local startPos = util.copyTable(shortTermPlanner.turtlePos)

            local bottomTree1LogCmps = bedrockCmps.compassAt({ forward=-4, right=-1, up=3 })
            local aboveTree1Cmps = bottomTree1LogCmps.compassAt({ up=9 })
            local aboveTree2Cmps = aboveTree1Cmps.compassAt({ right=2 })

            highLevelCommands.findAndSelectSlotWithItem(shortTermPlanner, 'minecraft:dirt')
            navigate.moveToCoord(shortTermPlanner, aboveTree2Cmps.coord, { 'up', 'forward', 'right' })
            commands.turtle.placeDown(shortTermPlanner)
            highLevelCommands.findAndSelectSlotWithItem(shortTermPlanner, 'minecraft:dirt')
            navigate.moveToCoord(shortTermPlanner, aboveTree1Cmps.coord, { 'up', 'forward', 'right' })
            commands.turtle.placeDown(shortTermPlanner)
            commands.turtle.select(shortTermPlanner, 1)

            harvestTreeFromAbove(shortTermPlanner, { bottomLogPos = bottomTree1LogCmps.pos })

            navigate.moveToPos(shortTermPlanner, bottomTree1LogCmps.posAt({ right=1 }))
            plantSaplingsFromBetweenTrees(shortTermPlanner, { bedrockCmps = bedrockCmps })

            navigate.moveToPos(shortTermPlanner, startPos, { 'up', 'forward', 'right' })

            return { done = true }, shortTermPlanner.shortTermPlan
        end
    })
end

local harvestTreeFromAboveTransformers = _G.act.commands.registerFutureTransformers(
    moduleId..':harvestTreeFromAbove',
    {
        isNotBlockOfLeaves = function(blockInfoTuple)
            local success = blockInfoTuple[1]
            local blockInfo = blockInfoTuple[2]
            return not success or blockInfo.name ~= 'minecraft:leaves'
        end,
        isBlockALog = function(blockInfoTuple)
            local success = blockInfoTuple[1]
            local blockInfo = blockInfoTuple[2]
            return success and blockInfo.name == 'minecraft:log'
        end,
    }
)

function harvestTreeFromAbove(shortTermPlanner, opts)
    local bottomLogPos = opts.bottomLogPos

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local space = _G.act.space

    local bottomLogCmps = space.createCompass(bottomLogPos)

    navigate.assertCoord(shortTermPlanner, bottomLogCmps.coordAt({ up=9 }))
    navigate.face(shortTermPlanner, bottomLogCmps.facingAt({ face='forward' }))
    commands.turtle.forward(shortTermPlanner)

    -- Move down until you hit leaves
    local leavesNotFound = commands.futures.set(shortTermPlanner, { out=genId('leavesNotFound'), value=true })
    commands.futures.while_(shortTermPlanner, { continueIf = leavesNotFound }, function(shortTermPlanner)
        commands.turtle.down(shortTermPlanner)
        local blockBelow = commands.turtle.inspectDown(shortTermPlanner, { out = genId('blockBelow') })
        leavesNotFound = harvestTreeFromAboveTransformers.isNotBlockOfLeaves(shortTermPlanner, { in_=blockBelow, out=leavesNotFound })
        commands.futures.delete(shortTermPlanner, { in_ = blockBelow })
    end)

    -- Harvest top-half of leaves
    local topLeafCmps = space.createCompass(shortTermPlanner.turtlePos).compassAt({ forward=-1, up=-1 })
    local cornerPos = topLeafCmps.posAt({ forward = 1, right = 1, face='backward' })
    navigate.moveToPos(shortTermPlanner, cornerPos, { 'right', 'forward', 'up' })
    spiralInwards(shortTermPlanner, {
        sideLength = 3,
        onVisit = function()
            commands.turtle.dig(shortTermPlanner)
            commands.turtle.digDown(shortTermPlanner)
        end
    })

    -- Harvest bottom-half of leaves
    local aboveCornerPos = topLeafCmps.posAt({ forward = 2, right = 2, up = -1, face='backward' })
    navigate.moveToPos(shortTermPlanner, aboveCornerPos, { 'right', 'forward', 'up' })
    commands.turtle.digDown(shortTermPlanner)
    commands.turtle.down(shortTermPlanner)
    spiralInwards(shortTermPlanner, {
        sideLength = 5,
        onVisit = function()
            commands.turtle.dig(shortTermPlanner)
            commands.turtle.digDown(shortTermPlanner)
        end
    })
    navigate.face(shortTermPlanner, topLeafCmps.facingAt({ face='forward' }))

    -- Harvest trunk
    local logIsBelow = commands.futures.set(shortTermPlanner, { out=genId('logIsBelow'), value=true })
    commands.futures.while_(shortTermPlanner, { continueIf = logIsBelow }, function(shortTermPlanner)
        commands.turtle.digDown(shortTermPlanner)
        commands.turtle.down(shortTermPlanner)
        local blockBelow = commands.turtle.inspectDown(shortTermPlanner, { out = genId('blockBelow') })
        logIsBelow = harvestTreeFromAboveTransformers.isBlockALog(shortTermPlanner, { in_=blockBelow, out=logIsBelow })
        commands.futures.delete(shortTermPlanner, { in_ = blockBelow })
    end)

    shortTermPlanner.turtlePos = util.copyTable(bottomLogCmps.pos)
end

function plantSaplingsFromBetweenTrees(shortTermPlanner, opts)
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands

    local bedrockCmps = opts.bedrockCmps

    local betweenTreesCmps = bedrockCmps.compassAt({ forward=-4, up=3 })
    navigate.assertPos(shortTermPlanner, betweenTreesCmps.pos)

    local saplingFound = highLevelCommands.findAndSelectSlotWithItem(shortTermPlanner, 'minecraft:sapling', {
        allowMissing = true,
        out=genId('saplingFound'),
    })
    commands.futures.if_(shortTermPlanner, saplingFound, function(shortTermPlanner)
        navigate.face(shortTermPlanner, betweenTreesCmps.facingAt({ face='left' }))
        commands.turtle.place(shortTermPlanner)

        saplingFound = highLevelCommands.findAndSelectSlotWithItem(shortTermPlanner, 'minecraft:sapling', {
            allowMissing = true,
            out=saplingFound,
        })
        commands.futures.if_(shortTermPlanner, saplingFound, function(shortTermPlanner)
            navigate.face(shortTermPlanner, betweenTreesCmps.facingAt({ face='right' }))
            commands.turtle.place(shortTermPlanner)
        end)
    end)

    highLevelCommands.reorient(shortTermPlanner, betweenTreesCmps.facingAt({ face='forward' }))
end

-- End condition: An empty bucket will be left in your inventory
function prepareCobblestoneGeneratorProject(opts)
    local homeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    local homeCmps = space.createCompass(homeLoc.pos)
    return _G.act.project.register('mainIsland:prepareCobblestoneGenerator', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlanner = _G.act.shortTermPlanner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlanner, homeLoc)
            local startPos = util.copyTable(shortTermPlanner.turtlePos)

            -- Dig out east branch
            navigate.face(shortTermPlanner, homeCmps.facingAt({ face='right' }))
            for i = 1, 2 do
                commands.turtle.forward(shortTermPlanner)
                commands.turtle.digDown(shortTermPlanner)
            end

            -- Grab stuff from chest
            local LAVA_BUCKET_SLOT = 16
            local ICE_SLOT = 15
            commands.turtle.forward(shortTermPlanner)
            commands.turtle.select(shortTermPlanner, LAVA_BUCKET_SLOT)
            commands.turtle.suck(shortTermPlanner, 1)
            commands.turtle.select(shortTermPlanner, ICE_SLOT)
            commands.turtle.suck(shortTermPlanner, 1)

            -- Place lava down
            navigate.moveToCoord(shortTermPlanner, homeCmps.coordAt({ right=2 }))
            commands.turtle.select(shortTermPlanner, LAVA_BUCKET_SLOT)
            commands.turtle.placeDown(shortTermPlanner)
            -- Move the empty bucket to an earlier cell.
            highLevelCommands.transferToFirstEmptySlot(shortTermPlanner)
            commands.turtle.select(shortTermPlanner, 1)

            -- Dig out west branch
            navigate.moveToPos(shortTermPlanner, homeCmps.posAt({ face='backward' }))
            commands.turtle.forward(shortTermPlanner)
            commands.turtle.digDown(shortTermPlanner)
            commands.turtle.down(shortTermPlanner)
            commands.turtle.digDown(shortTermPlanner)
            commands.turtle.dig(shortTermPlanner)
            commands.turtle.up(shortTermPlanner)

            -- Place ice down
            -- (We're placing ice here, instead of in it's final spot, so it can be closer to the lava
            -- so the lava can melt it)
            commands.turtle.select(shortTermPlanner, ICE_SLOT)
            commands.turtle.placeDown(shortTermPlanner)
            commands.turtle.select(shortTermPlanner, 1)

            -- Dig out place for player to stand
            navigate.moveToCoord(shortTermPlanner, homeCmps.coordAt({ right=-1 }))
            commands.turtle.digDown(shortTermPlanner)

            navigate.moveToPos(shortTermPlanner, startPos)

            return { done = true }, shortTermPlanner.shortTermPlan
        end
    })
end

-- Start condition: An empty bucket must be in your inventory.
function waitForIceToMeltAndfinishCobblestoneGeneratorProject(opts)
    local homeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    local homeCmps = space.createCompass(homeLoc.pos)
    return _G.act.project.register('mainIsland:waitForIceToMeltAndfinishCobblestoneGenerator', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlanner = _G.act.shortTermPlanner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlanner, homeLoc)

            local startPos = util.copyTable(shortTermPlanner.turtlePos)

            -- Wait for ice to melt
            navigate.moveToCoord(shortTermPlanner, homeCmps.coordAt({ forward=-1 }))
            highLevelCommands.waitUntilDetectBlock(shortTermPlanner, {
                expectedBlockId = 'minecraft:water',
                direction = 'down',
                endFacing = homeCmps.facingAt({ face='backward' }),
            })
            
            -- Move water
            highLevelCommands.findAndSelectSlotWithItem(shortTermPlanner, 'minecraft:bucket')
            commands.turtle.placeDown(shortTermPlanner)
            commands.turtle.forward(shortTermPlanner)
            commands.turtle.placeDown(shortTermPlanner)
            commands.turtle.select(shortTermPlanner, 1)

            navigate.moveToPos(shortTermPlanner, startPos)
            commands.turtle.digDown(shortTermPlanner)
            commands.mockHooks.registerCobblestoneRegenerationBlock(shortTermPlanner, homeCmps.coordAt({ up=-1 }))

            return { done = true }, shortTermPlanner.shortTermPlan
        end
    })
end

function harvestCobblestoneProject(opts)
    local homeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    local homeCmps = space.createCompass(homeLoc.pos)
    return _G.act.project.register('mainIsland:harvestCobblestoneProject', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlanner = _G.act.shortTermPlanner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlanner, homeLoc)

            local startPos = util.copyTable(shortTermPlanner.turtlePos)

            for i = 1, 32 do
                highLevelCommands.waitUntilDetectBlock(shortTermPlanner, {
                    expectedBlockId = 'minecraft:cobblestone',
                    direction = 'down',
                    endFacing = 'ANY',
                })
                commands.turtle.digDown(shortTermPlanner)
            end
            highLevelCommands.reorient(shortTermPlanner, space.posToFacing(startPos))

            return { done = true }, shortTermPlanner.shortTermPlan
        end
    })
end

-- Starting from a corner of a square (of size sideLength), touch every cell in it by following
-- a clockwise spiral to the center. You must start facing in a direction such that
-- no turning is required before movement.
-- The `onVisit` function is called at each cell visited.
function spiralInwards(shortTermPlanner, opts)
    local commands = _G.act.commands

    local sideLength = opts.sideLength
    local onVisit = opts.onVisit

    for segmentLength = sideLength - 1, 1, -1 do
        local firstIter = segmentLength == sideLength - 1
        for i = 1, (firstIter and 3 or 2) do
            for j = 1, segmentLength do
                onVisit(shortTermPlanner)
                commands.turtle.forward(shortTermPlanner)
            end
            commands.turtle.turnRight(shortTermPlanner)
        end
    end
    onVisit(shortTermPlanner)
end

return module