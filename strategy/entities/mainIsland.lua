local util = import('util.lua')

local module = {}

local location = _G.act.location
local navigate = _G.act.navigate
local commands = _G.act.commands
local highLevelCommands = _G.act.highLevelCommands
local curves = _G.act.curves
local space = _G.act.space

local moduleId = 'entity:mainIsland'
local genId = commands.createIdGenerator(moduleId)

function module.initEntity()
    local bedrockPos = util.mergeTables({ forward = 3, right = 0, up = 64, from = 'ORIGIN' }, { face = 'forward' })

    -- homeLoc is right above the bedrock
    local homeLoc = location.register(space.resolveRelPos({ up=3 }, bedrockPos))
    -- initialLoc is in front of the chest
    local initialLoc = location.register(space.resolveRelPos({ right=3, face='left' }, homeLoc.pos))
    _G.act.location.registerPath(initialLoc, homeLoc)

    local cobblestoneGeneratorMill = createCobblestoneGeneratorMill({ homeLoc = homeLoc })
    local startingIslandTreeFarm = createStartingIslandTreeFarm({ bedrockPos = bedrockPos, homeLoc = homeLoc })

    return {
        -- locations
        initialLoc = initialLoc,
        homeLoc = homeLoc,

        -- projects
        harvestInitialTreeAndPrepareTreeFarm = harvestInitialTreeAndPrepareTreeFarmProject({ bedrockPos = bedrockPos, homeLoc = homeLoc, startingIslandTreeFarm = startingIslandTreeFarm }),
        startBuildingCobblestoneGenerator = startBuildingCobblestoneGeneratorProject({ homeLoc = homeLoc }),
        waitForIceToMeltAndfinishCobblestoneGenerator = waitForIceToMeltAndfinishCobblestoneGeneratorProject({ homeLoc = homeLoc, cobblestoneGeneratorMill = cobblestoneGeneratorMill }),
        createCobbleTower1 = createCobbleTowerProject({ homeLoc = homeLoc, towerNumber = 1 }),
        createCobbleTower2 = createCobbleTowerProject({ homeLoc = homeLoc, towerNumber = 2 }),
        createCobbleTower3 = createCobbleTowerProject({ homeLoc = homeLoc, towerNumber = 3 }),
        createCobbleTower4 = createCobbleTowerProject({ homeLoc = homeLoc, towerNumber = 4 }),
    }
end

_G.act.project.registerStartingConditionInitializer(function(startingConditions)
    startingConditions.mainIsland = {
        startedCobblestoneGeneratorConstruction = false,
    }
end)

-- Pre-condition: Must have two dirt in inventory
function harvestInitialTreeAndPrepareTreeFarmProject(opts)
    local bedrockPos = opts.bedrockPos
    local homeLoc = opts.homeLoc
    local startingIslandTreeFarm = opts.startingIslandTreeFarm

    local bedrockCmps = space.createCompass(bedrockPos)
    local taskRunnerId = 'project:mainIsland:harvestInitialTreeAndPrepareTreeFarm'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        requiredResources = {
            -- 2 for each "sappling-arm", and 2 for the dirt that hovers above the trees
            ['minecraft:dirt'] = { quantity=6, at='INVENTORY' }
        },
        enter = function(planner, taskState)
            location.travelToLocation(planner, homeLoc)
        end,
        exit = function(planner, taskState, info)
            navigate.assertPos(planner, homeLoc.pos)
            if info.complete then
                startingIslandTreeFarm.activate(planner)
            end
        end,
        nextPlan = function(planner, taskState)
            local startPos = util.copyTable(planner.turtlePos)

            local bottomTreeLogCmps = bedrockCmps.compassAt({ forward=-4, right=-1, up=3 })
            local aboveTreeCmps = bottomTreeLogCmps.compassAt({ up=9 })
            local aboveFutureTree1Cmps = aboveTreeCmps.compassAt({ right=-2 })
            local aboveFutureTree2Cmps = aboveTreeCmps.compassAt({ right=4 })

            -- Place dirt up top
            highLevelCommands.findAndSelectSlotWithItem(planner, 'minecraft:dirt')
            navigate.moveToCoord(planner, aboveFutureTree2Cmps.coord, { 'up', 'forward', 'right' })
            commands.turtle.placeDown(planner)
            highLevelCommands.findAndSelectSlotWithItem(planner, 'minecraft:dirt')
            navigate.moveToCoord(planner, aboveFutureTree1Cmps.coord, { 'up', 'forward', 'right' })
            commands.turtle.placeDown(planner)
            commands.turtle.select(planner, 1)

            -- Harvest tree
            navigate.moveToCoord(planner, aboveTreeCmps.coord, { 'up', 'forward', 'right' })
            harvestTreeFromAbove(planner, { bottomLogPos = bottomTreeLogCmps.pos })

            -- Prepare sapling planting area
            function prepareSaplingDirtArm(planner, direction)
                navigate.face(planner, bottomTreeLogCmps.facingAt({ face=direction }))
                for i = 1, 2 do
                    commands.turtle.forward(planner)
                    highLevelCommands.placeItemDown(planner, 'minecraft:dirt')
                end
                commands.turtle.up(planner)
                highLevelCommands.placeItemDown(planner, 'minecraft:sapling')
            end

            navigate.assertPos(planner, bottomTreeLogCmps.pos)
            prepareSaplingDirtArm(planner, 'left')
            navigate.moveToPos(planner, bottomTreeLogCmps.posAt({ right=2 }), { 'forward', 'right', 'up' })
            prepareSaplingDirtArm(planner, 'right')

            navigate.moveToPos(planner, startPos, { 'forward', 'right', 'up' })

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        preConditions = function(currentConditions)
            return currentConditions.mainIsland
        end,
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

function harvestTreeFromAbove(planner, opts)
    local bottomLogPos = opts.bottomLogPos

    local transformers = harvestTreeFromAboveTransformers
    local bottomLogCmps = space.createCompass(bottomLogPos)

    navigate.assertCoord(planner, bottomLogCmps.coordAt({ up=9 }))
    navigate.face(planner, bottomLogCmps.facingAt({ face='forward' }))
    commands.turtle.forward(planner)

    -- Move down until you hit leaves
    local leavesNotFound = commands.futures.set(planner, { out=genId('leavesNotFound'), value=true })
    commands.futures.while_(planner, { continueIf = leavesNotFound }, function(planner)
        commands.turtle.down(planner)
        local blockBelow = commands.turtle.inspectDown(planner, { out = genId('blockBelow') })
        leavesNotFound = transformers.isNotBlockOfLeaves(planner, { in_=blockBelow, out=leavesNotFound })
        commands.futures.delete(planner, { in_ = blockBelow })
    end)

    -- Harvest top-half of leaves
    local topLeafCmps = space.createCompass(planner.turtlePos).compassAt({ forward=-1, up=-1 })
    local cornerPos = topLeafCmps.posAt({ forward = 1, right = 1, face='backward' })
    navigate.moveToPos(planner, cornerPos, { 'right', 'forward', 'up' })
    spiralInwards(planner, {
        sideLength = 3,
        onVisit = function()
            commands.turtle.dig(planner)
            commands.turtle.digDown(planner)
        end
    })

    -- Harvest bottom-half of leaves
    local aboveCornerPos = topLeafCmps.posAt({ forward = 2, right = 2, up = -1, face='backward' })
    navigate.moveToPos(planner, aboveCornerPos, { 'right', 'forward', 'up' })
    commands.turtle.digDown(planner)
    commands.turtle.down(planner)
    spiralInwards(planner, {
        sideLength = 5,
        onVisit = function()
            commands.turtle.dig(planner)
            commands.turtle.digDown(planner)
        end
    })
    navigate.face(planner, topLeafCmps.facingAt({ face='forward' }))

    -- Harvest trunk
    local logIsBelow = commands.futures.set(planner, { out=genId('logIsBelow'), value=true })
    commands.futures.while_(planner, { continueIf = logIsBelow }, function(planner)
        commands.turtle.digDown(planner)
        commands.turtle.down(planner)
        local blockBelow = commands.turtle.inspectDown(planner, { out = genId('blockBelow') })
        logIsBelow = harvestTreeFromAboveTransformers.isBlockALog(planner, { in_=blockBelow, out=logIsBelow })
        commands.futures.delete(planner, { in_ = blockBelow })
    end)

    planner.turtlePos = util.copyTable(bottomLogCmps.pos)
end

function startBuildingCobblestoneGeneratorProject(opts)
    local homeLoc = opts.homeLoc

    local homeCmps = space.createCompass(homeLoc.pos)
    local taskRunnerId = 'project:mainIsland:startBuildingCobblestoneGenerator'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(planner, taskState)
            location.travelToLocation(planner, homeLoc)
        end,
        exit = function(planner, taskState)
            navigate.assertPos(planner, homeLoc.pos)
        end,
        nextPlan = function(planner, taskState)
            local startPos = util.copyTable(planner.turtlePos)

            -- Dig out east branch
            navigate.face(planner, homeCmps.facingAt({ face='right' }))
            for i = 1, 2 do
                commands.turtle.forward(planner)
                commands.turtle.digDown(planner)
            end

            -- Grab stuff from chest
            local LAVA_BUCKET_SLOT = 16
            local ICE_SLOT = 15
            commands.turtle.forward(planner)
            commands.turtle.select(planner, LAVA_BUCKET_SLOT)
            commands.turtle.suck(planner, 1)
            commands.turtle.select(planner, ICE_SLOT)
            commands.turtle.suck(planner, 1)

            -- Place lava down
            navigate.moveToCoord(planner, homeCmps.coordAt({ right=2 }))
            commands.turtle.select(planner, LAVA_BUCKET_SLOT)
            commands.turtle.placeDown(planner)
            -- Move the empty bucket to an earlier cell.
            highLevelCommands.transferToFirstEmptySlot(planner)
            commands.turtle.select(planner, 1)

            -- Dig out west branch
            navigate.moveToPos(planner, homeCmps.posAt({ face='backward' }))
            commands.turtle.forward(planner)
            commands.turtle.digDown(planner)
            commands.turtle.down(planner)
            commands.turtle.digDown(planner)
            commands.turtle.dig(planner)
            commands.turtle.up(planner)

            -- Place ice down
            -- (We're placing ice here, instead of in it's final spot, so it can be closer to the lava
            -- so the lava can melt it)
            commands.turtle.select(planner, ICE_SLOT)
            commands.turtle.placeDown(planner)
            commands.turtle.select(planner, 1)

            -- Dig out place for player to stand
            navigate.moveToCoord(planner, homeCmps.coordAt({ right=-1 }))
            commands.turtle.digDown(planner)

            navigate.moveToPos(planner, startPos)

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        preConditions = function(currentConditions)
            return currentConditions.mainIsland
        end,
        postConditions = function(currentConditions)
            currentConditions.mainIsland.startedCobblestoneGeneratorConstruction = true
        end,
    })
end

function waitForIceToMeltAndfinishCobblestoneGeneratorProject(opts)
    local homeLoc = opts.homeLoc
    local cobblestoneGeneratorMill = opts.cobblestoneGeneratorMill

    local homeCmps = space.createCompass(homeLoc.pos)
    local taskRunnerId = 'project:mainIsland:waitForIceToMeltAndfinishCobblestoneGenerator'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        requiredResources = {
            ['minecraft:bucket'] = { quantity=1, at='INVENTORY' }
        },
        enter = function(planner, taskState)
            location.travelToLocation(planner, homeLoc)
        end,
        exit = function(planner, taskState, info)
            navigate.assertPos(planner, homeLoc.pos)
            if info.complete then
                commands.mockHooks.registerCobblestoneRegenerationBlock(planner, homeCmps.coordAt({ up=-1 }))
                cobblestoneGeneratorMill.activate(planner)
            end
        end,
        nextPlan = function(planner, taskState)
            local startPos = util.copyTable(planner.turtlePos)

            -- Wait for ice to melt
            navigate.moveToCoord(planner, homeCmps.coordAt({ forward=-1 }))
            highLevelCommands.waitUntilDetectBlock(planner, {
                expectedBlockId = 'minecraft:water',
                direction = 'down',
                endFacing = homeCmps.facingAt({ face='backward' }),
            })
            
            -- Move water
            highLevelCommands.findAndSelectSlotWithItem(planner, 'minecraft:bucket')
            commands.turtle.placeDown(planner)
            commands.turtle.forward(planner)
            commands.turtle.placeDown(planner)
            commands.turtle.select(planner, 1)

            navigate.moveToPos(planner, startPos)
            commands.turtle.digDown(planner)

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        preConditions = function(currentConditions)
            return (
                currentConditions.mainIsland and
                currentConditions.mainIsland.startedCobblestoneGeneratorConstruction
            )
        end,
    })
end

function createCobblestoneGeneratorMill(opts)
    local homeLoc = opts.homeLoc

    local homeCmps = space.createCompass(homeLoc.pos)
    local taskRunnerId = 'mill:mainIsland:cobblestoneGenerator'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        createTaskState = function()
            return { harvested = 0 }
        end,
        enter = function(planner, taskState)
            location.travelToLocation(planner, homeLoc)
        end,
        exit = function(planner, taskState)
            navigate.face(planner, space.posToFacing(homeLoc.pos))
            navigate.assertPos(planner, homeLoc.pos)
        end,
        nextPlan = function(planner, taskState, resourceRequests)
            local newTaskState = util.copyTable(taskState)
            local quantity = resourceRequests['minecraft:cobblestone']
            if quantity == nil then error('Must supply a request for cobblestone to use this mill') end
            -- I don't have inventory management techniques in place to handle a larger quantity
            if quantity > 64 * 8 then error('Can not handle that large of a quantity yet') end

            highLevelCommands.waitUntilDetectBlock(planner, {
                expectedBlockId = 'minecraft:cobblestone',
                direction = 'down',
                endFacing = 'ANY',
            })
            commands.turtle.digDown(planner)
            newTaskState.harvested = newTaskState.harvested + 1
            
            return newTaskState, newTaskState.harvested == quantity
        end,
    })
    return _G.act.mill.create(taskRunnerId, {
        supplies = { 'minecraft:cobblestone' },
    })
end

local startingIslandTreeFarmTransformers = _G.act.commands.registerFutureTransformers(
    moduleId..':startingIslandTreeFarm',
    {
        isBlockALog = function(blockInfoTuple)
            local success = blockInfoTuple[1]
            local blockInfo = blockInfoTuple[2]
            return success and blockInfo.name == 'minecraft:log'
        end,
    }
)


function createStartingIslandTreeFarm(opts)
    local homeLoc = opts.homeLoc
    local bedrockPos = opts.bedrockPos

    local transformers = startingIslandTreeFarmTransformers
    local homeCmps = space.createCompass(homeLoc.pos)
    local taskRunnerId = _G.act.task.registerTaskRunner('farm:mainIsland:startingIslandTreeFarm', {
        enter = function(planner, taskState)
            location.travelToLocation(planner, homeLoc)
        end,
        exit = function(planner, taskState)
            navigate.assertPos(planner, homeLoc.pos)
        end,
        nextPlan = function(planner, taskState)
            location.travelToLocation(planner, homeLoc)
            local startPos = util.copyTable(planner.turtlePos)

            local mainCmps = homeCmps.compassAt({ forward=-5 })
            navigate.moveToCoord(planner, mainCmps.coord)

            function tryHarvestTree(planner, inFrontOfTreeCmps)
                local blockInfo = commands.turtle.inspect(planner, { out=genId('blockInfo') })
                local blockIsLog = transformers.isBlockALog(planner, { in_=blockInfo, out=genId('blockIsLog') })
                commands.futures.if_(planner, blockIsLog, function(planner)
                    local bottomLogCmps = inFrontOfTreeCmps.compassAt({ forward=1 })
                    navigate.moveToCoord(planner, inFrontOfTreeCmps.coordAt({ forward=-2 }))
                    navigate.moveToPos(planner, bottomLogCmps.posAt({ up=9 }), { 'up', 'forward', 'right' })
                    harvestTreeFromAbove(planner, { bottomLogPos = bottomLogCmps.pos })
                    navigate.moveToPos(planner, inFrontOfTreeCmps.pos)
                    highLevelCommands.placeItem(planner, 'minecraft:sapling', { allowMissing = true })
                end)
            end

            local inFrontOfTree1Cmps = mainCmps.compassAt({ right=-3 })
            navigate.moveToPos(planner, inFrontOfTree1Cmps.pos)
            tryHarvestTree(planner, inFrontOfTree1Cmps)

            local inFrontOfTree2Cmps = mainCmps.compassAt({ right=3 })
            navigate.moveToPos(planner, inFrontOfTree2Cmps.pos)
            tryHarvestTree(planner, inFrontOfTree2Cmps)

            navigate.moveToPos(planner, startPos, { 'up', 'right', 'forward' })

            return taskState, true
        end,
    })

    return _G.act.farm.register(taskRunnerId, {
        supplies = { 'minecraft:log', 'minecraft:sapling', 'minecraft:apple', 'minecraft:stick' },
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
                    ['minecraft:stick'] = createCurve({ maxY = 2 * leavesOnTree * chanceOfStickDrop })(timeSpan),
                },
            }
        end,
    })
end

function createCobbleTowerProject(opts)
    local homeLoc = opts.homeLoc
    local towerNumber = opts.towerNumber

    local homeCmps = space.createCompass(homeLoc.pos)
    local taskRunnerId = _G.act.task.registerTaskRunner('project:mainIsland:createCobbleTower:'..towerNumber, {
        requiredResources = {
            ['minecraft:cobblestone'] = { quantity=64 * 4, at='INVENTORY' }
        },
        enter = function(planner, taskState)
            location.travelToLocation(planner, homeLoc)
        end,
        exit = function(planner, taskState)
            navigate.assertPos(planner, homeLoc.pos)
        end,
        nextPlan = function(planner, taskState)
            local startPos = util.copyTable(planner.turtlePos)

            local towerBaseCmps = homeCmps.compassAt({ right = -6 - (towerNumber*2) })
            
            for x = 0, 1 do
                for z = 0, 3 do
                    navigate.moveToCoord(
                        planner,
                        towerBaseCmps.coordAt({ forward = -z, right = -x }),
                        { 'forward', 'right', 'up' }
                    )
                    for i = 1, 32 do
                        highLevelCommands.findAndSelectSlotWithItem(planner, 'minecraft:cobblestone')
                        commands.turtle.placeDown(planner)
                        commands.turtle.up(planner)
                    end
                end
            end
            commands.turtle.select(planner, 1)

            navigate.moveToPos(planner, startPos, { 'right', 'forward', 'up' })

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        preConditions = function(currentConditions)
            return currentConditions.mainIsland
        end,
    })
end

-- Starting from a corner of a square (of size sideLength), touch every cell in it by following
-- a clockwise spiral to the center. You must start facing in a direction such that
-- no turning is required before movement.
-- The `onVisit` function is called at each cell visited.
function spiralInwards(planner, opts)
    local commands = _G.act.commands

    local sideLength = opts.sideLength
    local onVisit = opts.onVisit

    for segmentLength = sideLength - 1, 1, -1 do
        local firstIter = segmentLength == sideLength - 1
        for i = 1, (firstIter and 3 or 2) do
            for j = 1, segmentLength do
                onVisit(planner)
                commands.turtle.forward(planner)
            end
            commands.turtle.turnRight(planner)
        end
    end
    onVisit(planner)
end

return module