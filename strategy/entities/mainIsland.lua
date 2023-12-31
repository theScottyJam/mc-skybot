local util = import('util.lua')
local recipes = import('shared/recipes.lua')

local module = {}

local location = _G.act.location
local navigate = _G.act.navigate
local highLevelCommands = _G.act.highLevelCommands
local curves = _G.act.curves
local space = _G.act.space

-- Starting from a corner of a square (of size sideLength), touch every cell in it by following
-- a clockwise spiral to the center. You must start facing in a direction such that
-- no turning is required before movement.
-- The `onVisit` function is called at each cell visited.
local spiralInwards = function(commands, state, opts)
    local sideLength = opts.sideLength
    local onVisit = opts.onVisit

    for segmentLength = sideLength - 1, 1, -1 do
        local firstIter = segmentLength == sideLength - 1
        for i = 1, (firstIter and 3 or 2) do
            for j = 1, segmentLength do
                onVisit(commands, state)
                commands.turtle.forward(state)
            end
            commands.turtle.turnRight(state)
        end
    end
    onVisit(commands, state)
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
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, homeLoc)
        end,
        exit = function(commands, state, taskState, info)
            navigate.assertPos(state, homeLoc.cmps.pos)
            if info.complete then
                startingIslandTreeFarm.activate(commands, state)
            end
        end,
        nextPlan = function(commands, state, taskState)
            local startPos = util.copyTable(state.turtlePos)

            local bottomTreeLogCmps = bedrockCmps.compassAt({ forward=-4, right=-1, up=3 })
            -- aboveTreeCmps is right above the floating dirt
            local aboveTreeCmps = bottomTreeLogCmps.compassAt({ up=9 })
            local aboveFutureTree1Cmps = aboveTreeCmps.compassAt({ right=-2 })
            local aboveFutureTree2Cmps = aboveTreeCmps.compassAt({ right=4 })

            -- Place dirt up top
            highLevelCommands.findAndSelectSlotWithItem(commands, state, 'minecraft:dirt')
            navigate.moveToCoord(commands, state, aboveFutureTree2Cmps.coord, { 'up', 'forward', 'right' })
            commands.turtle.placeDown(state)
            highLevelCommands.findAndSelectSlotWithItem(commands, state, 'minecraft:dirt')
            navigate.moveToCoord(commands, state, aboveFutureTree1Cmps.coord, { 'up', 'forward', 'right' })
            commands.turtle.placeDown(state)
            commands.turtle.select(state, 1)

            -- Harvest tree
            navigate.moveToCoord(commands, state, aboveTreeCmps.coord, { 'up', 'forward', 'right' })
            -- Move up one more, since harvestTreeFromAbove() expects you to have a space between the floating
            -- dirt and you, so a torch could be there if needed.
            commands.turtle.up(state)
            harvestTreeFromAbove(commands, state, { bottomLogPos = bottomTreeLogCmps.pos })

            -- Prepare sapling planting area
            local prepareSaplingDirtArm = function(state, direction)
                navigate.face(commands, state, bottomTreeLogCmps.facingAt({ face=direction }))
                for i = 1, 2 do
                    commands.turtle.forward(state)
                    highLevelCommands.placeItemDown(commands, state, 'minecraft:dirt', { allowMissing = true })
                end
                commands.turtle.up(state)
                highLevelCommands.placeItemDown(commands, state, 'minecraft:sapling', { allowMissing = true })
            end

            navigate.assertPos(state, bottomTreeLogCmps.pos)
            prepareSaplingDirtArm(state, 'left')
            navigate.moveToCoord(commands, state, bottomTreeLogCmps.coordAt({ right=2 }), { 'forward', 'right', 'up' })
            prepareSaplingDirtArm(state, 'right')

            navigate.moveToPos(commands, state, startPos, { 'forward', 'right', 'up' })

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

harvestTreeFromAbove = function(commands, state, opts)
    local bottomLogPos = opts.bottomLogPos
    local bottomLogCmps = space.createCompass(bottomLogPos)

    navigate.assertCoord(state, bottomLogCmps.coordAt({ up=10 }))
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
    spiralInwards(commands, state, {
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
    spiralInwards(commands, state, {
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

    navigate.assertPos(state, bottomLogCmps.pos)
end

local startBuildingCobblestoneGeneratorProject = function(opts)
    local homeLoc = opts.homeLoc
    local craftingMills = opts.craftingMills

    local taskRunnerId = 'project:mainIsland:startBuildingCobblestoneGenerator'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, homeLoc)
        end,
        exit = function(commands, state, taskState, info)
            navigate.assertPos(state, homeLoc.cmps.pos)
            if info.complete then
                for _, mill in ipairs(craftingMills) do
                    mill.activate(commands, state)
                end
            end
        end,
        nextPlan = function(commands, state, taskState)
            local startPos = util.copyTable(state.turtlePos)

            -- Dig out east branch
            navigate.face(commands, state, homeLoc.cmps.facingAt({ face='right' }))
            for i = 1, 2 do
                commands.turtle.forward(state)
                commands.turtle.digDown(state)
            end

            -- Grab stuff from chest
            commands.turtle.forward(state)
            commands.turtle.suck(state, 1)
            commands.turtle.suck(state, 1)

            -- Pick up chest
            commands.turtle.dig(state)

            -- Place lava down
            navigate.moveToCoord(commands, state, homeLoc.cmps.coordAt({ right=2 }))
            highLevelCommands.placeItemDown(commands, state, 'minecraft:lava_bucket')

            -- -- Dig out west branch
            navigate.moveToPos(commands, state, homeLoc.cmps.posAt({ face='backward' }))
            commands.turtle.forward(state)
            commands.turtle.digDown(state)
            commands.turtle.down(state)
            commands.turtle.digDown(state)
            commands.turtle.dig(state)
            commands.turtle.up(state)

            -- Place ice down
            -- (We're placing ice here, instead of in it's final spot, so it can be closer to the lava
            -- so the lava can melt it)
            highLevelCommands.placeItemDown(commands, state, 'minecraft:ice')

            -- Dig out place for player to stand
            navigate.moveToCoord(commands, state, homeLoc.cmps.coordAt({ right=-1 }))
            commands.turtle.digDown(state)

            navigate.moveToPos(commands, state, startPos)

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

    local taskRunnerId = 'project:mainIsland:waitForIceToMeltAndfinishCobblestoneGenerator'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, homeLoc)
        end,
        exit = function(commands, state, taskState, info)
            navigate.assertPos(state, homeLoc.cmps.pos)
            if info.complete then
                _G.act.mockHooks.registerCobblestoneRegenerationBlock(homeLoc.cmps.coordAt({ up=-1 }))
                cobblestoneGeneratorMill.activate(commands, state)
            end
        end,
        nextPlan = function(commands, state, taskState)
            local startPos = util.copyTable(state.turtlePos)

            -- Wait for ice to melt
            navigate.moveToCoord(commands, state, homeLoc.cmps.coordAt({ forward=-1 }))
            highLevelCommands.waitUntilDetectBlock(commands, state, {
                expectedBlockId = 'minecraft:water',
                direction = 'down',
                endFacing = homeLoc.cmps.facingAt({ face='backward' }),
            })
            
            -- Move water
            highLevelCommands.placeItemDown(commands, state, 'minecraft:bucket') -- pick up water
            commands.turtle.forward(state)
            highLevelCommands.placeItemDown(commands, state, 'minecraft:water_bucket')

            navigate.moveToPos(commands, state, startPos)
            commands.turtle.digDown(state)

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        requiredResources = {
            ['minecraft:bucket'] = { quantity=1, at='INVENTORY', consumed=false }
        },
        preConditions = function(currentConditions)
            return currentConditions.mainIsland.startedCobblestoneGeneratorConstruction
        end,
    })
end

local buildFurnacesProject = function(opts)
    local inFrontOfChestLoc = opts.inFrontOfChestLoc
    local inFrontOfFirstFurnaceLoc = opts.inFrontOfFirstFurnaceLoc

    local taskRunnerId = 'project:mainIsland:buildFurnaces'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, inFrontOfChestLoc)
        end,
        exit = function(commands, state, taskState, info)
            navigate.assertPos(state, inFrontOfChestLoc.cmps.pos)
            if info.complete then
                location.registerPath(inFrontOfChestLoc, inFrontOfFirstFurnaceLoc, {
                    inFrontOfChestLoc.cmps.coordAt({ right=1 }),
                    inFrontOfChestLoc.cmps.coordAt({ right=1, up=1 }),
                })
            end
        end,
        nextPlan = function(commands, state, taskState)
            local startPos = util.copyTable(state.turtlePos)

            local aboveFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=1, face='forward' })
            for i = 0, 2 do
                navigate.moveToPos(commands, state, aboveFirstFurnaceCmps.posAt({ right = i }), { 'up', 'forward', 'right'})
                highLevelCommands.placeItemDown(commands, state, 'minecraft:furnace')
            end

            navigate.moveToPos(commands, state, startPos, { 'right', 'forward', 'up' })

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        requiredResources = {
            ['minecraft:furnace'] = { quantity=3, at='INVENTORY' }
        },
    })
end

local smeltInitialCharcoalProject = function(opts)
    local inFrontOfFirstFurnaceLoc = opts.inFrontOfFirstFurnaceLoc
    local furnaceMill = opts.furnaceMill
    local simpleCharcoalSmeltingMill = opts.simpleCharcoalSmeltingMill

    local taskRunnerId = 'project:mainIsland:smeltInitialCharcoal'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, inFrontOfFirstFurnaceLoc)
        end,
        exit = function(commands, state, taskState, info)
            navigate.assertPos(state, inFrontOfFirstFurnaceLoc.cmps.pos)
            if info.complete then
                furnaceMill.activate(commands, state)
                simpleCharcoalSmeltingMill.activate(commands, state)
            end
        end,
        nextPlan = function(commands, state, taskState)
            local startPos = util.copyTable(state.turtlePos)

            -- Same values that were put in "requiredResources"
            local logCount = 3
            local plankCount = 2
            -- How much charcoal to reserve for future smelting needs
            local reserveCount = 1

            -- Fill raw materials from the top
            local aboveFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=1 })
            navigate.moveToPos(commands, state, aboveFirstFurnaceCmps.posAt({ face='right' }), { 'up', 'right' })
            highLevelCommands.dropItemDown(commands, state, 'minecraft:log', logCount)

            navigate.moveToPos(commands, state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'right', 'up' })

            -- Fill fuel from the bottom
            local belowFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=-1 })
            navigate.moveToPos(commands, state, belowFirstFurnaceCmps.posAt({ face='right' }), { 'up', 'right' })
            highLevelCommands.dropItemUp(commands, state, 'minecraft:planks', plankCount)

            -- Wait and collect results from a furnace
            highLevelCommands.findAndSelectEmptpySlot(commands, state)
            while true do
                commands.turtle.suckUp(state, 64)
                local collected = commands.turtle.getItemCount()
                if collected >= logCount then
                    break
                end
                highLevelCommands.busyWait(commands, state)
            end

            -- Reserve some charcoal in the furnace for future use
            highLevelCommands.dropItemUp(commands, state, 'minecraft:charcoal', reserveCount)

            navigate.moveToPos(commands, state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'right', 'up' })

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        requiredResources = {
            -- Uses four a total of four logs. One as planks for fuel to smelt 3 charcoal.
            -- Some of that charcoal will be used as future fuel, other will be used for torches.
            ['minecraft:log'] = { quantity=3, at='INVENTORY' },
            ['minecraft:planks'] = { quantity=2, at='INVENTORY' },
        },
    })
end

local torchUpIslandProject = function(opts)
    local inFrontOfChestLoc = opts.inFrontOfChestLoc

    local taskRunnerId = 'project:mainIsland:torchUpIsland'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, inFrontOfChestLoc)
        end,
        exit = function(commands, state, taskState, info)
            navigate.assertPos(state, inFrontOfChestLoc.cmps.pos)
        end,
        nextPlan = function(commands, state, taskState)
            -- torch 1 is directly left of the disk drive
            local torch1Cmps = inFrontOfChestLoc.cmps.compassAt({ forward=1, right=-1, up=1 })
            navigate.moveToPos(commands, state, torch1Cmps.pos, {'right', 'forward', 'up'})
            highLevelCommands.placeItemDown(commands, state, 'minecraft:torch')

            -- torch 2 is on the left side of the island
            local torch2Cmps = inFrontOfChestLoc.cmps.compassAt({ forward=-1, right=-4, up=1 })
            navigate.moveToPos(commands, state, torch2Cmps.pos, {'right', 'forward', 'up'})
            highLevelCommands.placeItemDown(commands, state, 'minecraft:torch')

            -- torch 3 is between the trees
            local torch3Cmps = inFrontOfChestLoc.cmps.compassAt({ forward=-3, right=-2, up=1 })
            navigate.moveToPos(commands, state, torch3Cmps.pos, {'right', 'forward', 'up'})
            highLevelCommands.placeItemDown(commands, state, 'minecraft:torch')

            -- torch 4 is on dirt above where the trees grow
            local betweenTreesCmps = inFrontOfChestLoc.cmps.compassAt({ forward=-4, right=-3, up=1 })
            navigate.moveToPos(commands, state, betweenTreesCmps.pos, {'right', 'forward', 'up'})
            local torch4Cmps = inFrontOfChestLoc.cmps.compassAt({ forward=-4, up=10 })
            navigate.moveToPos(commands, state, torch4Cmps.pos, {'up', 'forward', 'right'})
            highLevelCommands.placeItemDown(commands, state, 'minecraft:torch')

            navigate.moveToPos(commands, state, inFrontOfChestLoc.cmps.pos, {'forward', 'right', 'up'})

            return taskState, true
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        requiredResources = {
            ['minecraft:torch'] = { quantity=4, at='INVENTORY' },
        },
    })
end

local createFurnaceMill = function(opts)
    local inFrontOfFirstFurnaceLoc = opts.inFrontOfFirstFurnaceLoc

    local taskRunnerId = 'mill:mainIsland:furnace'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        createTaskState = function()
            return {
                currentlyInFurnaces = { 0, 0, 0 },
                collected = 0,
            }
        end,
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, inFrontOfFirstFurnaceLoc)
        end,
        exit = function(commands, state, taskState)
            navigate.moveToPos(commands, state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'right', 'forward', 'up' })
        end,
        nextPlan = function(commands, state, taskState, resourceRequests)
            local newTaskState = util.copyTable(taskState)

            if util.tableSize(resourceRequests) ~= 1 then
                error('Only supports smelting one item type at a time')
            end
            local targetResource, requestedQuantity = util.getAnEntry(resourceRequests)

            targetRecipe = util.findInArrayTable(recipes.smelting, function(recipe)
                return recipe.to == targetResource
            end)
            sourceResource = targetRecipe.from

            -- I don't have inventory management techniques in place to handle a larger quantity
            if requestedQuantity > 64 * 8 then error('Can not handle that large of a quantity yet') end

            -- Index of first furnace that has 32 or more items being smelted, or nil if there is no such furnace.
            -- Alternatively, if there isn't a need to restock, this is the index of the furnace with the most content.
            local furnaceIndexToWaitOn = nil
            local restockRequired = taskState.collected + util.sum(taskState.currentlyInFurnaces) < requestedQuantity
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
                local willBeRemaining = requestedQuantity - newTaskState.collected - util.sum(willBeInFurnaces)
                while true do
                    local minStackIndex = util.indexOfMinNumber(table.unpack(willBeInFurnaces))
                    if willBeInFurnaces[minStackIndex] > 64 - 8 then break end
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
                local belowFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=-1 })
                -- This movement will correctly move the turtle from any of its possible starting positions.
                navigate.moveToPos(commands, state, belowFirstFurnaceCmps.posAt({ face='right' }), { 'up', 'forward', 'right' })
                for i = 1, 2 do
                    highLevelCommands.dropItemUp(commands, state, 'minecraft:charcoal', math.ceil(willBeAdded[i] / 8))
                    commands.turtle.forward(state)
                end
                highLevelCommands.dropItemUp(commands, state, 'minecraft:charcoal', math.ceil(willBeAdded[3] / 8))

                navigate.moveToCoord(commands, state, belowFirstFurnaceCmps.coord)
                navigate.moveToCoord(commands, state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'forward', 'right', 'up' })

                -- Fill raw materials from the top
                local aboveFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=1 })
                navigate.moveToPos(commands, state, aboveFirstFurnaceCmps.posAt({ face='right' }), { 'up', 'right' })
                for i = 1, 2 do
                    highLevelCommands.dropItemDown(commands, state, sourceResource, willBeAdded[i])
                    commands.turtle.forward(state)
                end
                highLevelCommands.dropItemDown(commands, state, sourceResource, willBeAdded[3])

                navigate.moveToCoord(commands, state, aboveFirstFurnaceCmps.coord)
                navigate.moveToPos(commands, state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'forward', 'right', 'up' })

                newTaskState.currentlyInFurnaces = willBeInFurnaces

            -- Wait and collect results from a furnace
            else
                -- Move into position if needed
                local belowFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=-1 })
                local targetFurnaceCmps = belowFirstFurnaceCmps.compassAt({ right = furnaceIndexToWaitOn - 1 })
                if inFrontOfFirstFurnaceLoc.cmps.compareCmps(state.turtleCmps()) then
                    navigate.moveToPos(commands, state, belowFirstFurnaceCmps.posAt({ face='right' }), { 'up', 'forward' })
                end
                navigate.moveToCoord(commands, state, targetFurnaceCmps.coord)

                highLevelCommands.findAndSelectEmptpySlot(commands, state)
                local collectionSuccess = commands.turtle.suckUp(state, 64)

                if collectionSuccess then
                    local amountSucked = commands.turtle.getItemCount(state)

                    -- Inventory organization is a bit overkill - attempting to stack the just-found item
                    -- would have been sufficient. I just didn't want to make a function for that yet.
                    highLevelCommands.organizeInventory(commands, state)

                    newTaskState.currentlyInFurnaces = util.copyTable(taskState.currentlyInFurnaces)
                    newTaskState.currentlyInFurnaces[furnaceIndexToWaitOn] = (
                        newTaskState.currentlyInFurnaces[furnaceIndexToWaitOn] - amountSucked
                    )
                    newTaskState.collected = newTaskState.collected + amountSucked
                else
                    highLevelCommands.busyWait(commands, state)
                end
            end

            return newTaskState, newTaskState.collected == requestedQuantity
        end,
    })

    local whatIsSmeltedFromWhat = {}
    for _, recipe in ipairs(recipes.smelting) do
        whatIsSmeltedFromWhat[recipe.to] = recipe.from
    end

    return _G.act.mill.create(taskRunnerId, {
        getRequiredResources = function(resourceRequest)
            if whatIsSmeltedFromWhat[resourceRequest.resourceName] == nil then
                error('Unreachable: Requested an invalid resource')
            end

            local sourceResource = whatIsSmeltedFromWhat[resourceRequest.resourceName]
            local quantity = resourceRequest.quantity

            return {
                [sourceResource] = quantity,
                ['minecraft:charcoal'] = math.ceil(quantity / 8),
            }
        end,
        supplies = util.filterArrayTable(
            util.mapArrayTable(recipes.smelting, function(recipe)
                return recipe.to
            end),
            function(suppliedResource)
                return suppliedResource ~= 'minecraft:charcoal'
            end
        )
    })
end

createSimpleCharcoalSmeltingMill = function(opts)
    local inFrontOfFirstFurnaceLoc = opts.inFrontOfFirstFurnaceLoc

    -- Figures out the number of logs that will be used in
    -- order to produce the desired number of charcoal
    function calcAmountToSmelt(quantityRequested)
        -- For every 7 charcoal you want, an extra log will be needed
        -- to also convert into fuel and pay back the spent fuel.
        local quantityWithExtra = quantityRequested * 8 / 7
        -- Round to a multiple of 8
        local roundedQuantity = math.ceil(quantityWithExtra / 8) * 8
        return roundedQuantity
    end

    local taskRunnerId = 'mill:mainIsland:simpleCharcoalSmeltingMill'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        createTaskState = function()
            return {
                quantityInFirstFurnace = 0,
                collected = 0,
            }
        end,
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, inFrontOfFirstFurnaceLoc)
        end,
        exit = function(commands, state, taskState)
            navigate.moveToPos(commands, state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'right', 'forward', 'up' })
        end,
        nextPlan = function(commands, state, taskState, resourceRequests)
            local newTaskState = util.copyTable(taskState)
            local requestedQuantity = resourceRequests['minecraft:charcoal']

            -- I don't have inventory management techniques in place to handle a larger quantity
            if requestedQuantity > 64 * 8 then error('Can not handle that large of a quantity yet') end

            local logsBeingSmelted = calcAmountToSmelt(requestedQuantity)

            -- Insert raw materials and fuel
            if newTaskState.quantityInFirstFurnace == 0 then
                -- Fill fuel from the bottom
                local belowFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=-1 })
                navigate.moveToPos(commands, state, belowFirstFurnaceCmps.pos, { 'up', 'forward', 'right' })
                highLevelCommands.dropItemUp(commands, state, 'minecraft:charcoal', 1)

                navigate.moveToCoord(commands, state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'forward', 'right', 'up' })

                -- Fill raw materials from the top
                local aboveFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=1 })
                navigate.moveToPos(commands, state, aboveFirstFurnaceCmps.pos, { 'up', 'right' })
                highLevelCommands.dropItemDown(commands, state, 'minecraft:log', 8)

                navigate.moveToPos(commands, state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'forward', 'right', 'up' })

                newTaskState.quantityInFirstFurnace = 8

            -- Wait and collect results from a furnace
            else
                -- Move into position if needed
                local belowFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=-1 })
                navigate.moveToPos(commands, state, belowFirstFurnaceCmps.pos, { 'up', 'forward', 'right' })

                highLevelCommands.findAndSelectEmptpySlot(commands, state)
                local collectionSuccess = commands.turtle.suckUp(state, 64)

                if collectionSuccess then
                    local amountSucked = commands.turtle.getItemCount(state)

                    -- Inventory organization is a bit overkill - attempting to stack the just-found item
                    -- would have been sufficient. I just didn't want to make a function for that yet.
                    highLevelCommands.organizeInventory(commands, state)

                    newTaskState.quantityInFirstFurnace = newTaskState.quantityInFirstFurnace - amountSucked
                    newTaskState.collected = newTaskState.collected + amountSucked
                else
                    highLevelCommands.busyWait(commands, state)
                end
            end

            return newTaskState, newTaskState.collected >= logsBeingSmelted
        end,
    })

    return _G.act.mill.create(taskRunnerId, {
        getRequiredResources = function (resourceRequest)
            if resourceRequest.resourceName ~= 'minecraft:charcoal' then
                error('Only charcoal is supported')
            end
            return {
                ['minecraft:log'] = calcAmountToSmelt(resourceRequest.quantity),
            }
        end,
        supplies = {'minecraft:charcoal'},
    })
end

local createCobblestoneGeneratorMill = function(opts)
    local homeLoc = opts.homeLoc

    local taskRunnerId = 'mill:mainIsland:cobblestoneGenerator'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        createTaskState = function()
            return { harvested = 0 }
        end,
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, homeLoc)
        end,
        exit = function(commands, state, taskState)
            navigate.face(commands, state, homeLoc.cmps.facing)
            navigate.assertPos(state, homeLoc.cmps.pos)
        end,
        nextPlan = function(commands, state, taskState, resourceRequests)
            local newTaskState = util.copyTable(taskState)
            local quantity = resourceRequests['minecraft:cobblestone']
            if quantity == nil then error('Must supply a request for cobblestone to use this mill') end
            -- I don't have inventory management techniques in place to handle a larger quantity
            if quantity > 64 * 8 then error('Can not handle that large of a quantity yet') end

            highLevelCommands.waitUntilDetectBlock(commands, state, {
                expectedBlockId = 'minecraft:cobblestone',
                direction = 'down',
                endFacing = 'ANY',
            })
            commands.turtle.digDown(state)
            newTaskState.harvested = newTaskState.harvested + 1
            
            return newTaskState, newTaskState.harvested == quantity
        end,
    })
    return _G.act.mill.create(taskRunnerId, {
        supplies = { 'minecraft:cobblestone' },
    })
end

local createStartingIslandTreeFarm = function(opts)
    local homeLoc = opts.homeLoc
    local bedrockPos = opts.bedrockPos

    local taskRunnerId = _G.act.task.registerTaskRunner('farm:mainIsland:startingIslandTreeFarm', {
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, homeLoc)
        end,
        exit = function(commands, state, taskState)
            navigate.assertPos(state, homeLoc.cmps.pos)
        end,
        nextPlan = function(commands, state, taskState)
            commands.turtle.select(state, 1)
            location.travelToLocation(commands, state, homeLoc)
            local startPos = util.copyTable(state.turtlePos)

            local mainCmps = homeLoc.cmps.compassAt({ forward=-5 })
            navigate.moveToCoord(commands, state, mainCmps.coord)

            local tryHarvestTree = function(commands, state, inFrontOfTreeCmps)
                local success, blockInfo = commands.turtle.inspect(state)

                local blockIsLog = success and blockInfo.name == 'minecraft:log'
                if blockIsLog then
                    local bottomLogCmps = inFrontOfTreeCmps.compassAt({ forward=1 })
                    navigate.moveToCoord(commands, state, inFrontOfTreeCmps.coordAt({ forward=-2 }))
                    navigate.moveToPos(commands, state, bottomLogCmps.posAt({ up=10 }), { 'up', 'forward', 'right' })
                    harvestTreeFromAbove(commands, state, { bottomLogPos = bottomLogCmps.pos })
                    navigate.moveToPos(commands, state, inFrontOfTreeCmps.pos)
                    highLevelCommands.placeItem(commands, state, 'minecraft:sapling', { allowMissing = true })
                end
            end

            local inFrontOfTree1Cmps = mainCmps.compassAt({ right=-3 })
            navigate.moveToPos(commands, state, inFrontOfTree1Cmps.pos)
            tryHarvestTree(commands, state, inFrontOfTree1Cmps)

            local inFrontOfTree2Cmps = mainCmps.compassAt({ right=3 })
            navigate.moveToPos(commands, state, inFrontOfTree2Cmps.pos)
            tryHarvestTree(commands, state, inFrontOfTree2Cmps)

            navigate.moveToPos(commands, state, startPos, { 'up', 'right', 'forward' })

            return taskState, true
        end,
    })
    return _G.act.farm.register(taskRunnerId, {
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
            nextPlan = function(commands, state, taskState, resourceRequests)
                local newTaskState = util.copyTable(taskState)
                local quantity = resourceRequests[recipe.to]
                if quantity == nil then error('Must supply a request for '..recipe.to..' to use this mill') end
                -- I don't have inventory management techniques in place to handle a larger quantity
                if quantity > 64 * 8 then error('Can not handle that large of a quantity yet') end
    
                local amountNeeded = quantity - taskState.produced
                local craftAmount = util.minNumber(64 * recipe.yields, amountNeeded)
                highLevelCommands.craft(commands, state, recipe, craftAmount)
                
                newTaskState.produced = newTaskState.produced + craftAmount
                return newTaskState, newTaskState.produced == quantity
            end,
        })
        local mill = _G.act.mill.create(taskRunnerId, {
            getRequiredResources = function (resourceRequest)
                if resourceRequest.resourceName ~= recipe.to then
                    error('Unreachable: Requested an invalid resource')
                end

                local craftQuantity = math.ceil(resourceRequest.quantity / recipe.yields)

                local requirements = {}
                for _, row in pairs(recipe.from) do
                    for _, itemId in pairs(row) do
                        if requirements[itemId] == nil then
                            requirements[itemId] = 0
                        end
                        requirements[itemId] = requirements[itemId] + craftQuantity
                    end
                end
                return requirements
            end,
            supplies = { recipe.to },
        })
        table.insert(millList, mill)
    end
    return millList
end

local createTowerProject = function(opts)
    local homeLoc = opts.homeLoc
    local towerNumber = opts.towerNumber

    local taskRunnerId = _G.act.task.registerTaskRunner('project:mainIsland:createTower:'..towerNumber, {
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, homeLoc)
        end,
        exit = function(commands, state, taskState)
            navigate.assertPos(state, homeLoc.cmps.pos)
        end,
        nextPlan = function(commands, state, taskState)
            local startPos = util.copyTable(state.turtlePos)

            local nextToTowers = homeLoc.cmps.compassAt({ right = -5 })
            local towerBaseCmps = homeLoc.cmps.compassAt({ right = -6 - (towerNumber*2) })
            
            navigate.moveToCoord(commands, state, nextToTowers.coord, { 'forward', 'right', 'up' })
            for x = 0, 1 do
                for z = 0, 3 do
                    navigate.moveToCoord(
                        commands,
                        state,
                        towerBaseCmps.coordAt({ forward = -z, right = -x }),
                        { 'forward', 'right', 'up' }
                    )
                    -- for i = 1, 32 do
                    for i = 1, 4 do
                        -- highLevelCommands.findAndSelectSlotWithItem(commands, state, 'minecraft:cobblestone')
                        -- highLevelCommands.findAndSelectSlotWithItem(commands, state, 'minecraft:furnace')
                        highLevelCommands.findAndSelectSlotWithItem(commands, state, 'minecraft:stone')
                        commands.turtle.placeDown(state)
                        commands.turtle.up(state)
                    end
                end
            end
            commands.turtle.select(state, 1)

            navigate.moveToCoord(commands, state, nextToTowers.coord, { 'forward', 'right', 'up' })
            navigate.moveToPos(commands, state, startPos, { 'right', 'forward', 'up' })

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
    local bedrockCmps = space.createCompass({ forward = 3, right = 0, up = 64, face = 'forward' })

    -- homeLoc is right above the bedrock
    local homeLoc = location.register(bedrockCmps.posAt({ up=3 }))
    -- in front of chest, but facing north
    local inFrontOfChestLoc = location.register(homeLoc.cmps.posAt({ right=3 }))
    -- facing away from the chest, with the disk drive to the right
    local initialLoc = location.register(inFrontOfChestLoc.cmps.posAt({ face='left' }))
    local inFrontOfFirstFurnaceLoc = location.register(
        -- faces the furnace
        inFrontOfChestLoc.cmps.posAt({ forward=1, right=1, up=1, face='right' })
    )
    location.registerPath(inFrontOfChestLoc, homeLoc)
    location.registerPath(inFrontOfChestLoc, initialLoc)

    local cobblestoneGeneratorMill = createCobblestoneGeneratorMill({ homeLoc = homeLoc })
    local startingIslandTreeFarm = createStartingIslandTreeFarm({ bedrockPos = bedrockCmps.pos, homeLoc = homeLoc })
    local furnaceMill = createFurnaceMill({ inFrontOfFirstFurnaceLoc = inFrontOfFirstFurnaceLoc })
    local simpleCharcoalSmeltingMill = createSimpleCharcoalSmeltingMill({ inFrontOfFirstFurnaceLoc = inFrontOfFirstFurnaceLoc })
    local craftingMills = createCraftingMills()

    return {
        -- locations
        inFrontOfChestLoc = inFrontOfChestLoc,
        initialLoc = initialLoc,
        homeLoc = homeLoc,

        -- projects
        startBuildingCobblestoneGenerator = startBuildingCobblestoneGeneratorProject({ homeLoc = homeLoc, craftingMills = craftingMills }),
        harvestInitialTreeAndPrepareTreeFarm = harvestInitialTreeAndPrepareTreeFarmProject({ bedrockPos = bedrockCmps.pos, homeLoc = homeLoc, startingIslandTreeFarm = startingIslandTreeFarm }),
        waitForIceToMeltAndfinishCobblestoneGenerator = waitForIceToMeltAndfinishCobblestoneGeneratorProject({ homeLoc = homeLoc, cobblestoneGeneratorMill = cobblestoneGeneratorMill }),
        buildFurnaces = buildFurnacesProject({ inFrontOfChestLoc = inFrontOfChestLoc, inFrontOfFirstFurnaceLoc = inFrontOfFirstFurnaceLoc }),
        smeltInitialCharcoal = smeltInitialCharcoalProject({ inFrontOfFirstFurnaceLoc = inFrontOfFirstFurnaceLoc, furnaceMill = furnaceMill, simpleCharcoalSmeltingMill = simpleCharcoalSmeltingMill }),
        torchUpIsland = torchUpIslandProject({ inFrontOfChestLoc = inFrontOfChestLoc }),
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