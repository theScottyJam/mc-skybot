local util = import('util.lua')
local recipes = import('shared/recipes.lua')

local module = {}

local location = _G.act.location
local navigate = _G.act.navigate
local commands = _G.act.commands
local highLevelCommands = _G.act.highLevelCommands
local curves = _G.act.curves
local space = _G.act.space

local moduleId = 'entity:mainIsland'
local genId = commands.createIdGenerator(moduleId)

-- Starting from a corner of a square (of size sideLength), touch every cell in it by following
-- a clockwise spiral to the center. You must start facing in a direction such that
-- no turning is required before movement.
-- The `onVisit` function is called at each cell visited.
local spiralInwards = function(planner, opts)
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

local harvestTreeFromAbove
-- Pre-condition: Must have two dirt in inventory
local harvestInitialTreeAndPrepareTreeFarmProject = function(opts)
    local bedrockPos = opts.bedrockPos
    local homeLoc = opts.homeLoc
    local startingIslandTreeFarm = opts.startingIslandTreeFarm

    local bedrockCmps = space.createCompass(bedrockPos)
    local taskRunnerId = 'project:mainIsland:harvestInitialTreeAndPrepareTreeFarm'
    _G.act.task.registerTaskRunner(taskRunnerId, {
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
            local prepareSaplingDirtArm = function(planner, direction)
                navigate.face(planner, bottomTreeLogCmps.facingAt({ face=direction }))
                for i = 1, 2 do
                    commands.turtle.forward(planner)
                    highLevelCommands.placeItemDown(planner, 'minecraft:dirt', { allowMissing = true })
                end
                commands.turtle.up(planner)
                highLevelCommands.placeItemDown(planner, 'minecraft:sapling', { allowMissing = true })
            end

            navigate.assertPos(planner, bottomTreeLogCmps.pos)
            prepareSaplingDirtArm(planner, 'left')
            navigate.moveToCoord(planner, bottomTreeLogCmps.coordAt({ right=2 }), { 'forward', 'right', 'up' })
            prepareSaplingDirtArm(planner, 'right')

            navigate.moveToPos(planner, startPos, { 'forward', 'right', 'up' })

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        requiredResources = {
            -- 2 for each "sappling-arm", and 2 for the dirt that hovers above the trees
            ['minecraft:dirt'] = { quantity=6, at='INVENTORY' }
        }
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

harvestTreeFromAbove = function(planner, opts)
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

local startBuildingCobblestoneGeneratorProject = function(opts)
    local homeLoc = opts.homeLoc
    local craftingMills = opts.craftingMills

    local homeCmps = space.createCompass(homeLoc.pos)
    local taskRunnerId = 'project:mainIsland:startBuildingCobblestoneGenerator'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(planner, taskState)
            location.travelToLocation(planner, homeLoc)
        end,
        exit = function(planner, taskState, info)
            navigate.assertPos(planner, homeLoc.pos)
            if info.complete then
                for _, mill in ipairs(craftingMills) do
                    mill.activate(planner)
                end
            end
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
            commands.turtle.forward(planner)
            commands.turtle.suck(planner, 1)
            commands.turtle.suck(planner, 1)

            -- Pick up chest
            commands.turtle.dig(planner)

            -- Place lava down
            navigate.moveToCoord(planner, homeCmps.coordAt({ right=2 }))
            highLevelCommands.placeItemDown(planner, 'minecraft:lava_bucket')

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
            highLevelCommands.placeItemDown(planner, 'minecraft:ice')

            -- Dig out place for player to stand
            navigate.moveToCoord(planner, homeCmps.coordAt({ right=-1 }))
            commands.turtle.digDown(planner)

            navigate.moveToPos(planner, startPos)

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        postConditions = function(currentConditions)
            currentConditions.mainIsland.startedCobblestoneGeneratorConstruction = true
        end,
    })
end

local waitForIceToMeltAndfinishCobblestoneGeneratorProject = function(opts)
    local homeLoc = opts.homeLoc
    local cobblestoneGeneratorMill = opts.cobblestoneGeneratorMill

    local homeCmps = space.createCompass(homeLoc.pos)
    local taskRunnerId = 'project:mainIsland:waitForIceToMeltAndfinishCobblestoneGenerator'
    _G.act.task.registerTaskRunner(taskRunnerId, {
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
            highLevelCommands.placeItemDown(planner, 'minecraft:bucket')
            commands.turtle.forward(planner)
            highLevelCommands.placeItemDown(planner, 'minecraft:water_bucket')

            navigate.moveToPos(planner, startPos)
            commands.turtle.digDown(planner)

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        requiredResources = {
            ['minecraft:bucket'] = { quantity=1, at='INVENTORY' }
        },
        preConditions = function(currentConditions)
            return currentConditions.mainIsland.startedCobblestoneGeneratorConstruction
        end,
    })
end

local buildFurnacesProject = function(opts)
    local inFrontOfChestLoc = opts.inFrontOfChestLoc
    local furnaceMill = opts.furnaceMill

    local inFrontOfChestCmps = space.createCompass(inFrontOfChestLoc.pos)
    local taskRunnerId = 'project:mainIsland:buildFurnaces'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(planner, taskState)
            location.travelToLocation(planner, inFrontOfChestLoc)
        end,
        exit = function(planner, taskState, info)
            navigate.assertPos(planner, inFrontOfChestLoc.pos)
            if info.complete then
                furnaceMill.activate(planner)
            end
        end,
        nextPlan = function(planner, taskState)
            local startPos = util.copyTable(planner.turtlePos)

            local aboveFirstFurnaceCmps = inFrontOfChestCmps.compassAt({ forward=1, right=2, up=2, face='right' })
            for i = 0, 2 do
                navigate.moveToPos(planner, aboveFirstFurnaceCmps.posAt({ right = i }), { 'up', 'forward', 'right'})
                highLevelCommands.placeItemDown(planner, 'minecraft:furnace')
            end

            navigate.moveToPos(planner, startPos, { 'right', 'forward', 'up' })

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        requiredResources = {
            ['minecraft:furnace'] = { quantity=3, at='INVENTORY' }
        },
    })
end

local createFurnaceMill = function(opts)
    local inFrontOfChestLoc = opts.inFrontOfChestLoc

    local inFrontOfChestCmps = space.createCompass(inFrontOfChestLoc.pos)
    local inFrontOfFirstFurnaceCmps = inFrontOfChestCmps.compassAt({ forward=1, right=1, up=1, face='right' })
    local inFrontOfFirstFurnaceLoc = location.register(inFrontOfFirstFurnaceCmps.pos) -- faces the furnace
    local taskRunnerId = 'mill:mainIsland:furnace'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        createTaskState = function()
            return {
                currentlyInFurnaces = { 0, 0, 0 },
                collected = 0,
            }
        end,
        enter = function(planner, taskState)
            location.travelToLocation(planner, inFrontOfFirstFurnaceLoc)
        end,
        exit = function(planner, taskState)
            navigate.moveToPos(planner, inFrontOfFirstFurnaceLoc.pos, { 'right', 'forward', 'up' })
        end,
        nextPlan = function(planner, taskState, resourceRequests)
            local newTaskState = util.copyTable(taskState)

            if util.tableSize(resourceRequests) ~= 1 then
                error('Only supports smelting one item type at a time')
            end

            local targetResource
            local quantity
            for targetResource_, quantity_ in pairs(resourceRequests) do
                targetResource = targetResource_
                quantity = quantity_
            end

            targetRecipe = util.findInArrayTable(recipes.smelting, function(recipe)
                return recipe.to == targetResource
            end)
            sourceResource = targetRecipe.from

            -- I don't have inventory management techniques in place to handle a larger quantity
            if quantity > 64 * 8 then error('Can not handle that large of a quantity yet') end

            -- Index of first furnace that has 32 or more items being smelted, or nil if there is no such furnace.
            -- Alternatively, if there isn't a need to restock, this is the index of the furnace with the most content.
            local furnaceIndexToWaitOn = nil
            local restockRequired = taskState.collected + util.sum(taskState.currentlyInFurnaces) < quantity
            if restockRequired then
                for i = 1, 3 do
                    if taskState.currentlyInFurnaces[i] > 32 then
                        furnaceIndexToWaitOn = i
                        break
                    end
                end
            else
                _, furnaceIndexToWaitOn = util.maxNumber(table.unpack(taskState.currentlyInFurnaces))
            end

            -- Insert raw materials and fuel
            if furnaceIndexToWaitOn == nil then
                -- Calculate items to place
                local willBeInFurnaces = util.copyTable(taskState.currentlyInFurnaces)
                local willBeRemaining = quantity - newTaskState.collected - util.sum(willBeInFurnaces)
                while true do
                    local minStackValue, minStackIndex = util.minNumber(table.unpack(willBeInFurnaces))
                    if minStackValue > 64 - 8 then break end
                    if willBeRemaining == 0 then break end
                    local adding = util.minNumber(willBeRemaining, 8)
                    willBeInFurnaces[minStackIndex] = willBeInFurnaces[minStackIndex] + adding
                    willBeRemaining = willBeRemaining - adding
                end

                local willBeAdded = {}
                for i = 1, 3 do
                    willBeAdded[i] = willBeInFurnaces[i] - taskState.currentlyInFurnaces[i]
                end

                -- Fill fuel from the bottom
                local belowFirstFurnaceCmps = inFrontOfFirstFurnaceCmps.compassAt({ forward=1, up=-1 })
                -- This movement will correctly move the turtle from any of its possible starting positions.
                navigate.moveToPos(planner, belowFirstFurnaceCmps.posAt({ face='right' }), { 'up', 'forward', 'right' })
                for i = 1, 2 do
                    highLevelCommands.dropItemUp(planner, 'minecraft:charcoal', math.ceil(willBeAdded[i] / 8))
                    commands.turtle.forward(planner)
                end
                highLevelCommands.dropItemUp(planner, 'minecraft:charcoal', math.ceil(willBeAdded[3] / 8))

                navigate.moveToCoord(planner, belowFirstFurnaceCmps.coord)
                navigate.moveToCoord(planner, inFrontOfFirstFurnaceCmps.pos, { 'forward', 'right', 'up' })

                -- Fill raw materials from the top
                local aboveFirstFurnaceCmps = inFrontOfFirstFurnaceCmps.compassAt({ forward=1, up=1 })
                navigate.moveToPos(planner, aboveFirstFurnaceCmps.posAt({ face='right' }), { 'up', 'right' })
                for i = 1, 2 do
                    highLevelCommands.dropItemDown(planner, sourceResource, willBeAdded[i])
                    commands.turtle.forward(planner)
                end
                highLevelCommands.dropItemDown(planner, sourceResource, willBeAdded[3])

                navigate.moveToCoord(planner, aboveFirstFurnaceCmps.coord)
                navigate.moveToPos(planner, inFrontOfFirstFurnaceCmps.pos, { 'forward', 'right', 'up' })

                newTaskState.currentlyInFurnaces = willBeInFurnaces

            -- Wait and collect results from a furnace
            else
                -- Move into position if needed
                local belowFirstFurnaceCmps = inFrontOfFirstFurnaceCmps.compassAt({ forward=1, up=-1 })
                local targetFurnaceCmps = belowFirstFurnaceCmps.compassAt({ right = furnaceIndexToWaitOn - 1 })
                if space.comparePos(planner.turtlePos, inFrontOfFirstFurnaceCmps.pos) then
                    navigate.moveToPos(planner, belowFirstFurnaceCmps.posAt({ face='right' }), { 'up', 'forward' })
                end
                navigate.moveToCoord(planner, targetFurnaceCmps.coord)

                highLevelCommands.findAndSelectEmptpySlot(planner)
                local collectionSuccess = commands.turtle.suckUp(planner, 64, { out=genId('collectionSuccess') })

                commands.futures.if_(planner, collectionSuccess, function(planner)
                    local amountSucked = commands.turtle.getItemCount(planner, { out=genId('amountSucked') })

                    -- Inventory organization is a bit overkill - attempting to stack the just-found item
                    -- would have been sufficient. I just didn't want to make a function for that yet.
                    highLevelCommands.organizeInventory(planner)

                    commands.futures.updateTaskState(planner, amountSucked, function (amountSuckedValue, currentTaskState)
                        local updatedTaskState = util.copyTable(currentTaskState)
                        updatedTaskState.currentlyInFurnaces = util.copyTable(taskState.currentlyInFurnaces)
                        updatedTaskState.currentlyInFurnaces[furnaceIndexToWaitOn] = (
                            updatedTaskState.currentlyInFurnaces[furnaceIndexToWaitOn] - amountSuckedValue
                        )
                        updatedTaskState.collected = updatedTaskState.collected + amountSuckedValue
                        return updatedTaskState
                    end)
                end).else_(function(planner)
                    highLevelCommands.busyWait(planner)
                end)
            end

            return newTaskState, newTaskState.collected == quantity
        end,
    })

    local requiredResourcesPerUnit = {}
    for _, recipe in ipairs(recipes.smelting) do
        requiredResourcesPerUnit[recipe.to] = {
            [recipe.from] = { quantity=1, at='INVENTORY' },
            ['minecraft:charcoal'] = { quantity=1/8, at='INVENTORY' },
        }
    end

    return _G.act.mill.create(taskRunnerId, {
        requiredResourcesPerUnit = requiredResourcesPerUnit,
        supplies = util.mapArrayTable(recipes.smelting, function(recipe)
            return recipe.to
        end),
        onActivated = function()
            location.registerPath(inFrontOfChestLoc, inFrontOfFirstFurnaceLoc, {
                inFrontOfChestCmps.coordAt({ right=1 }),
                inFrontOfChestCmps.coordAt({ right=1, up=1 }),
            })
        end
    })
end

local createCobblestoneGeneratorMill = function(opts)
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


local createStartingIslandTreeFarm = function(opts)
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
            commands.turtle.select(planner, 1)
            location.travelToLocation(planner, homeLoc)
            local startPos = util.copyTable(planner.turtlePos)

            local mainCmps = homeCmps.compassAt({ forward=-5 })
            navigate.moveToCoord(planner, mainCmps.coord)

            local tryHarvestTree = function(planner, inFrontOfTreeCmps)
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

local createCraftingMills = function()
    local millList = {}
    for i, recipe in pairs(recipes.crafting) do
        local taskRunnerId = 'mill:mainIsland:crafting:'..recipe.to..':'..i
        _G.act.task.registerTaskRunner(taskRunnerId, {
            createTaskState = function()
                return { produced = 0 }
            end,
            nextPlan = function(planner, taskState, resourceRequests)
                local newTaskState = util.copyTable(taskState)
                local quantity = resourceRequests[recipe.to]
                if quantity == nil then error('Must supply a request for '..recipe.to..' to use this mill') end
                -- I don't have inventory management techniques in place to handle a larger quantity
                if quantity > 64 * 8 then error('Can not handle that large of a quantity yet') end
    
                local amountNeeded = quantity - taskState.produced
                local craftAmount = util.minNumber(64 * recipe.yields, amountNeeded)
                highLevelCommands.craft(planner, recipe, craftAmount)
                
                newTaskState.produced = newTaskState.produced + craftAmount
                return newTaskState, newTaskState.produced == quantity
            end,
        })
        local mill = _G.act.mill.create(taskRunnerId, {
            requiredResourcesPerUnit = (function ()
                local craftQuantity = 1 / recipe.yields

                local requirements = {}
                for _, row in pairs(recipe.from) do
                    for _, itemId in pairs(row) do
                        if requirements[itemId] == nil then
                            requirements[itemId] = { quantity=0, at='INVENTORY' }
                        end
                        requirements[itemId].quantity = requirements[itemId].quantity + craftQuantity
                    end
                end
                return { [recipe.to] = requirements }
            end)(),
            supplies = { recipe.to },
        })
        table.insert(millList, mill)
    end
    return millList
end

local createTowerProject = function(opts)
    local homeLoc = opts.homeLoc
    local towerNumber = opts.towerNumber

    local homeCmps = space.createCompass(homeLoc.pos)
    local taskRunnerId = _G.act.task.registerTaskRunner('project:mainIsland:createTower:'..towerNumber, {
        enter = function(planner, taskState)
            location.travelToLocation(planner, homeLoc)
        end,
        exit = function(planner, taskState)
            navigate.assertPos(planner, homeLoc.pos)
        end,
        nextPlan = function(planner, taskState)
            local startPos = util.copyTable(planner.turtlePos)

            local nextToTowers = homeCmps.compassAt({ right = -5 })
            local towerBaseCmps = homeCmps.compassAt({ right = -6 - (towerNumber*2) })
            
            navigate.moveToCoord(planner, nextToTowers.coord, { 'forward', 'right', 'up' })
            for x = 0, 1 do
                for z = 0, 3 do
                    navigate.moveToCoord(
                        planner,
                        towerBaseCmps.coordAt({ forward = -z, right = -x }),
                        { 'forward', 'right', 'up' }
                    )
                    -- for i = 1, 32 do
                    for i = 1, 4 do
                        -- highLevelCommands.findAndSelectSlotWithItem(planner, 'minecraft:cobblestone')
                        -- highLevelCommands.findAndSelectSlotWithItem(planner, 'minecraft:furnace')
                        highLevelCommands.findAndSelectSlotWithItem(planner, 'minecraft:stone')
                        commands.turtle.placeDown(planner)
                        commands.turtle.up(planner)
                    end
                end
            end
            commands.turtle.select(planner, 1)

            navigate.moveToCoord(planner, nextToTowers.coord, { 'forward', 'right', 'up' })
            navigate.moveToPos(planner, startPos, { 'right', 'forward', 'up' })

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        requiredResources = {
            -- ['minecraft:cobblestone'] = { quantity=64 * 4, at='INVENTORY' }
            -- ['minecraft:furnace'] = { quantity=32, at='INVENTORY' }
            ['minecraft:stone'] = { quantity=32, at='INVENTORY' }
        },
    })
end

function module.initEntity()
    local bedrockPos = util.mergeTables({ forward = 3, right = 0, up = 64, from = 'ORIGIN' }, { face = 'forward' })

    -- homeLoc is right above the bedrock
    local homeLoc = location.register(space.resolveRelPos({ up=3 }, bedrockPos))
    local inFrontOfChestLoc = location.register(space.resolveRelPos({ right=3 }, homeLoc.pos))
    local initialLoc = location.register(space.resolveRelPos({ face='left' }, inFrontOfChestLoc.pos))
    location.registerPath(inFrontOfChestLoc, homeLoc)
    location.registerPath(inFrontOfChestLoc, initialLoc)

    local cobblestoneGeneratorMill = createCobblestoneGeneratorMill({ homeLoc = homeLoc })
    local startingIslandTreeFarm = createStartingIslandTreeFarm({ bedrockPos = bedrockPos, homeLoc = homeLoc })
    local furnaceMill = createFurnaceMill({ inFrontOfChestLoc = inFrontOfChestLoc })
    local craftingMills = createCraftingMills()

    return {
        -- locations
        inFrontOfChestLoc = inFrontOfChestLoc,
        initialLoc = initialLoc,
        homeLoc = homeLoc,

        -- projects
        startBuildingCobblestoneGenerator = startBuildingCobblestoneGeneratorProject({ homeLoc = homeLoc, craftingMills = craftingMills }),
        harvestInitialTreeAndPrepareTreeFarm = harvestInitialTreeAndPrepareTreeFarmProject({ bedrockPos = bedrockPos, homeLoc = homeLoc, startingIslandTreeFarm = startingIslandTreeFarm }),
        waitForIceToMeltAndfinishCobblestoneGenerator = waitForIceToMeltAndfinishCobblestoneGeneratorProject({ homeLoc = homeLoc, cobblestoneGeneratorMill = cobblestoneGeneratorMill }),
        buildFurnaces = buildFurnacesProject({ inFrontOfChestLoc = inFrontOfChestLoc, furnaceMill = furnaceMill }),
        createTower1 = createTowerProject({ homeLoc = homeLoc, towerNumber = 1 }),
        createTower2 = createTowerProject({ homeLoc = homeLoc, towerNumber = 2 }),
        createTower3 = createTowerProject({ homeLoc = homeLoc, towerNumber = 3 }),
        createTower4 = createTowerProject({ homeLoc = homeLoc, towerNumber = 4 }),
    }
end

_G.act.project.registerStartingConditionInitializer(function(startingConditions)
    startingConditions.mainIsland = {
        startedCobblestoneGeneratorConstruction = false,
    }
end)

return module