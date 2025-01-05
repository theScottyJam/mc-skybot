local util = import('util.lua')
local recipes = import('shared/recipes.lua')
local act = import('act/init.lua')
local treeFarmBehavior = import('./_treeFarmBehavior.lua')

local module = {}

local commands = act.commands
local Location = act.Location
local navigate = act.navigate
local navigationPatterns = act.navigationPatterns
local highLevelCommands = act.highLevelCommands
local curves = act.curves
local space = act.space

-- This should be the first project that runs
local registerInitializationProject = function(opts)
    local initialLoc = opts.initialLoc
    local homeLoc = opts.homeLoc
    local inFrontOfChestLoc = opts.inFrontOfChestLoc

    return act.Project.register({
        id = 'mainIsland:initialization',
        init = function(self, state)
            self.state = state
        end,
        after = function(self, commands)
            Location.addPath(self.state, inFrontOfChestLoc, homeLoc)
            Location.addPath(self.state, inFrontOfChestLoc, initialLoc)
        end,
        nextSprint = function(self, commands)
            return true
        end,
    })
end

-- Pre-condition: Must have two dirt in inventory
local registerHarvestInitialTreeAndPrepareTreeFarmProject = function(opts)
    local bedrockPos = opts.bedrockPos
    local homeLoc = opts.homeLoc
    local startingIslandTreeFarm = opts.startingIslandTreeFarm

    local bedrockCmps = space.createCompass(bedrockPos)
    return act.Project.register({
        id = 'mainIsland:harvestInitialTreeAndPrepareTreeFarm',
        init = function(self, state)
            self.state = state
        end,
        enter = function(self, commands)
            homeLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.assertAtPos(self.state, homeLoc.cmps.pos)
        end,
        after = function(self, commands)
            startingIslandTreeFarm:activate(commands, self.state)
        end,
        nextSprint = function(self, commands)
            local state = self.state
            local startPos = state.turtlePos

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
            treeFarmBehavior.harvestTreeFromAbove(commands, state, { bottomLogPos = bottomTreeLogCmps.pos })

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

            navigate.assertAtPos(state, bottomTreeLogCmps.pos)
            prepareSaplingDirtArm(state, 'left')
            navigate.moveToCoord(commands, state, bottomTreeLogCmps.coordAt({ right=2 }), { 'forward', 'right', 'up' })
            prepareSaplingDirtArm(state, 'right')

            navigate.moveToPos(commands, state, startPos, { 'forward', 'right', 'up' })

            return true
        end,
        requiredResources = {
            -- 2 for each "sappling-arm", and 2 for the dirt that hovers above the trees
            ['minecraft:dirt'] = { quantity=6, at='INVENTORY' }
        }
    })
end

local registerStartBuildingCobblestoneGeneratorProject = function(opts)
    local homeLoc = opts.homeLoc
    local craftingMills = opts.craftingMills

    return act.Project.register({
        id = 'mainIsland:startBuildingCobblestoneGenerator',
        init = function(self, state)
            self.state = state
        end,
        enter = function(self, commands)
            homeLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.assertAtPos(self.state, homeLoc.cmps.pos)
        end,
        after = function(self, commands)
            -- Crafting mills are activated here, because the way crafting was
            -- designed, it requires the turtle to have a chest in its inventory,
            -- and the turtle picks up a chest here.
            for _, mill in ipairs(craftingMills) do
                mill:activate(commands, self.state)
            end
        end,
        nextSprint = function(self, commands)
            local state = self.state
            local startPos = state.turtlePos

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

            -- Dig out west branch
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

            return true
        end,
        postConditions = function(currentConditions)
            currentConditions.mainIsland.startedCobblestoneGeneratorConstruction = true
        end,
    })
end

local registerWaitForIceToMeltAndfinishCobblestoneGeneratorProject = function(opts)
    local homeLoc = opts.homeLoc
    local cobblestoneGeneratorMill = opts.cobblestoneGeneratorMill

    return act.Project.register({
        id = 'mainIsland:waitForIceToMeltAndfinishCobblestoneGenerator',
        init = function(self, state)
            self.state = state
        end,
        enter = function(self, commands)
            homeLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.assertAtPos(self.state, homeLoc.cmps.pos)
        end,
        after = function(self, commands)
            if _G.mockComputerCraftApi ~= nil then
                _G.mockComputerCraftApi.hooks.registerCobblestoneRegenerationBlock(homeLoc.cmps.coordAt({ up=-1 }))
            end
            cobblestoneGeneratorMill:activate(commands, self.state)
        end,
        nextSprint = function(self, commands)
            local state = self.state
            local startPos = state.turtlePos

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

            return true
        end,
        preConditions = function(currentConditions)
            return currentConditions.mainIsland.startedCobblestoneGeneratorConstruction
        end,
        requiredResources = {
            ['minecraft:bucket'] = { quantity=1, at='INVENTORY' }
        },
    })
end

local registerBuildFurnacesProject = function(opts)
    local inFrontOfChestLoc = opts.inFrontOfChestLoc
    local inFrontOfFirstFurnaceLoc = opts.inFrontOfFirstFurnaceLoc

    return act.Project.register({
        id = 'mainIsland:buildFurnaces',
        init = function(self, state)
            self.state = state
        end,
        enter = function(self, commands)
            inFrontOfChestLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.assertAtPos(self.state, inFrontOfChestLoc.cmps.pos)
        end,
        after = function(self, commands)
            Location.addPath(self.state, inFrontOfChestLoc, inFrontOfFirstFurnaceLoc, {
                inFrontOfChestLoc.cmps.coordAt({ right=1 }),
                inFrontOfChestLoc.cmps.coordAt({ right=1, up=1 }),
            })
        end,
        nextSprint = function(self, commands)
            local state = self.state
            local startPos = state.turtlePos

            local aboveFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=1, face='forward' })
            for i = 0, 2 do
                navigate.moveToPos(commands, state, aboveFirstFurnaceCmps.posAt({ right = i }), { 'up', 'forward', 'right'})
                highLevelCommands.placeItemDown(commands, state, 'minecraft:furnace')
            end

            navigate.moveToPos(commands, state, startPos, { 'right', 'forward', 'up' })

            return true
        end,
        requiredResources = {
            ['minecraft:furnace'] = { quantity=3, at='INVENTORY' }
        },
    })
end

local registerSmeltInitialCharcoalProject = function(opts)
    local inFrontOfFirstFurnaceLoc = opts.inFrontOfFirstFurnaceLoc
    local furnaceMill = opts.furnaceMill
    local simpleCharcoalSmeltingMill = opts.simpleCharcoalSmeltingMill

    return act.Project.register({
        id = 'mainIsland:smeltInitialCharcoal',
        init = function(self, state)
            self.state = state
        end,
        enter = function(self, commands)
            inFrontOfFirstFurnaceLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.assertAtPos(self.state, inFrontOfFirstFurnaceLoc.cmps.pos)
        end,
        after = function(self, commands)
            furnaceMill:activate(commands, self.state)
            simpleCharcoalSmeltingMill:activate(commands, self.state)
        end,
        nextSprint = function(self, commands)
            local state = self.state
            local startPos = state.turtlePos

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
            highLevelCommands.findAndSelectEmptySlot(commands, state)
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

            return true
        end,
        requiredResources = {
            -- Uses a total of four logs. One as planks for fuel to smelt 3 charcoal.
            -- Some of that charcoal will be used as future fuel, other will be used for torches.
            ['minecraft:log'] = { quantity=3, at='INVENTORY' },
            ['minecraft:planks'] = { quantity=2, at='INVENTORY' },
        },
    })
end

local registerTorchUpIslandProject = function(opts)
    local inFrontOfChestLoc = opts.inFrontOfChestLoc

    return act.Project.register({
        id = 'mainIsland:torchUpIsland',
        init = function(self, state)
            self.state = state
        end,
        enter = function(self, commands)
            inFrontOfChestLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.assertAtPos(self.state, inFrontOfChestLoc.cmps.pos)
        end,
        nextSprint = function(self, commands)
            local state = self.state
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

            return true
        end,
        requiredResources = {
            ['minecraft:torch'] = { quantity=4, at='INVENTORY' },
        },
    })
end

local registerFurnaceMill = function(opts)
    local inFrontOfFirstFurnaceLoc = opts.inFrontOfFirstFurnaceLoc

    local whatIsSmeltedFromWhat = {}
    for _, recipe in ipairs(recipes.smelting) do
        whatIsSmeltedFromWhat[recipe.to] = recipe.from
    end

    return act.Mill.register({
        id = 'mainIsland:furnace',
        init = function(self, state, resourceRequests)
            self.state = state
            -- mutable state
            self.taskState = {
                currentlyInFurnaces = { 0, 0, 0 },
                collected = 0,
            }

            if util.tableSize(resourceRequests) ~= 1 then
                error('Only supports smelting one item type at a time')
            end
            local targetResource, requestedQuantity = util.getASortedEntry(resourceRequests)

            local targetRecipe = util.findInArrayTable(recipes.smelting, function(recipe)
                return recipe.to == targetResource
            end)

            -- I don't have inventory management techniques in place to handle a larger quantity
            util.assert(requestedQuantity <= 64 * 8, 'Can not handle that large of a quantity yet')

            self.sourceResource = targetRecipe.from
            self.requestedQuantity = requestedQuantity
        end,
        enter = function(self, commands)
            inFrontOfFirstFurnaceLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.moveToPos(commands, self.state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'right', 'forward', 'up' })
        end,
        nextSprint = function(self, commands)
            local state = self.state
            local newTaskState = util.copyTable(self.taskState)

            -- Index of first furnace that has 32 or more items being smelted, or nil if there is no such furnace.
            -- Alternatively, if there isn't a need to restock, this is the index of the furnace with the most content.
            local furnaceIndexToWaitOn = nil
            local restockRequired = self.taskState.collected + util.sum(self.taskState.currentlyInFurnaces) < self.requestedQuantity
            if restockRequired then
                for i = 1, 3 do
                    if self.taskState.currentlyInFurnaces[i] > 32 then
                        furnaceIndexToWaitOn = i
                        break
                    end
                end
            else
                _, furnaceIndexToWaitOn = util.maxNumber(table.unpack(self.taskState.currentlyInFurnaces))
            end

            -- Insert raw materials and fuel
            if furnaceIndexToWaitOn == nil then
                -- Calculate items to place
                local willBeInFurnaces = util.copyTable(self.taskState.currentlyInFurnaces)
                local willBeRemaining = self.requestedQuantity - self.taskState.collected - util.sum(willBeInFurnaces)
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
                    willBeAdded[i] = willBeInFurnaces[i] - self.taskState.currentlyInFurnaces[i]
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
                    highLevelCommands.dropItemDown(commands, state, self.sourceResource, willBeAdded[i])
                    commands.turtle.forward(state)
                end
                highLevelCommands.dropItemDown(commands, state, self.sourceResource, willBeAdded[3])

                navigate.moveToCoord(commands, state, aboveFirstFurnaceCmps.coord)
                navigate.moveToPos(commands, state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'forward', 'right', 'up' })

                newTaskState.currentlyInFurnaces = willBeInFurnaces

            -- Wait and collect results from a furnace
            else
                -- Move into position if needed
                local belowFirstFurnaceCmps = inFrontOfFirstFurnaceLoc.cmps.compassAt({ forward=1, up=-1 })
                local targetFurnaceCmps = belowFirstFurnaceCmps.compassAt({ right = furnaceIndexToWaitOn - 1 })
                if inFrontOfFirstFurnaceLoc.cmps.compareCmps(state:turtleCmps()) then
                    navigate.moveToPos(commands, state, belowFirstFurnaceCmps.posAt({ face='right' }), { 'up', 'forward' })
                end
                navigate.moveToCoord(commands, state, targetFurnaceCmps.coord)

                highLevelCommands.findAndSelectEmptySlot(commands, state)
                local collectionSuccess = commands.turtle.suckUp(state, 64)

                if collectionSuccess then
                    local amountSucked = commands.turtle.getItemCount(state)

                    -- Inventory organization is a bit overkill - attempting to stack the just-found item
                    -- would have been sufficient. I just didn't want to make a function for that yet.
                    highLevelCommands.organizeInventory(commands, state)

                    newTaskState.currentlyInFurnaces = util.copyTable(self.taskState.currentlyInFurnaces)
                    newTaskState.currentlyInFurnaces[furnaceIndexToWaitOn] = (
                        newTaskState.currentlyInFurnaces[furnaceIndexToWaitOn] - amountSucked
                    )
                    newTaskState.collected = newTaskState.collected + amountSucked
                else
                    highLevelCommands.busyWait(commands, state)
                end
            end

            self.taskState = newTaskState
            return newTaskState.collected == self.requestedQuantity
        end,
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

local registerSimpleCharcoalSmeltingMill = function(opts)
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

    return act.Mill.register({
        id = 'mainIsland:simpleCharcoalSmeltingMill',
        init = function(self, state, resourceRequests)
            self.state = state
            -- mutable state
            self.taskState = {
                quantityInFirstFurnace = 0,
                collected = 0,
            }

            local requestedQuantity = resourceRequests['minecraft:charcoal']

            util.assert(requestedQuantity ~= nil, 'Must supply a request for cobblestone to use this mill')
            -- I don't have inventory management techniques in place to handle a larger quantity
            util.assert(requestedQuantity <= 64 * 8, 'Can not handle that large of a quantity yet')

            self.logsBeingSmelted = calcAmountToSmelt(requestedQuantity)
        end,
        enter = function(self, commands)
            inFrontOfFirstFurnaceLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.moveToPos(commands, self.state, inFrontOfFirstFurnaceLoc.cmps.pos, { 'right', 'forward', 'up' })
        end,
        nextSprint = function(self, commands)
            local state = self.state
            local newTaskState = util.copyTable(self.taskState)

            -- Insert raw materials and fuel
            if self.taskState.quantityInFirstFurnace == 0 then
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

                highLevelCommands.findAndSelectEmptySlot(commands, state)
                local collectionSuccess = commands.turtle.suckUp(state, 64)

                if collectionSuccess then
                    local amountSucked = commands.turtle.getItemCount(state)

                    -- Inventory organization is a bit overkill - attempting to stack the just-found item
                    -- would have been sufficient. I just didn't want to make a function for that yet.
                    highLevelCommands.organizeInventory(commands, state)

                    newTaskState.quantityInFirstFurnace = self.taskState.quantityInFirstFurnace - amountSucked
                    newTaskState.collected = self.taskState.collected + amountSucked
                else
                    highLevelCommands.busyWait(commands, state)
                end
            end

            self.taskState = newTaskState
            return newTaskState.collected >= self.logsBeingSmelted
        end,
        getRequiredResources = function (resourceRequest)
            if resourceRequest.resourceName ~= 'minecraft:charcoal' then
                error('Only charcoal is supported')
            end
            return {
                ['minecraft:log'] = calcAmountToSmelt(resourceRequest.quantity),
            }
        end,
        supplies = { 'minecraft:charcoal' },
    })
end

local registerCobblestoneGeneratorMill = function(opts)
    local homeLoc = opts.homeLoc

    return act.Mill.register({
        id = 'mainIsland:cobblestoneGenerator',
        init = function(self, state, resourceRequests)
            self.state = state

            -- mutable state
            self.harvested = 0

            local requestedQuantity = resourceRequests['minecraft:cobblestone']
            util.assert(requestedQuantity ~= nil, 'Must supply a request for cobblestone to use this mill')
            -- I don't have inventory management techniques in place to handle a larger quantity
            util.assert(requestedQuantity <= 64 * 8, 'Can not handle that large of a quantity yet')

            self.quantityRequested = requestedQuantity
        end,
        enter = function(self, commands)
            homeLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.face(commands, self.state, homeLoc.cmps.facing)
            navigate.assertAtPos(self.state, homeLoc.cmps.pos)
        end,
        nextSprint = function(self, commands)
            local state = self.state

            highLevelCommands.waitUntilDetectBlock(commands, state, {
                expectedBlockId = 'minecraft:cobblestone',
                direction = 'down',
                endFacing = 'ANY',
            })
            commands.turtle.digDown(state)
            self.harvested = self.harvested + 1
            
            return self.harvested == self.quantityRequested
        end,
        supplies = { 'minecraft:cobblestone' },
    })
end

local registerStartingIslandTreeFarm = function(opts)
    local homeLoc = opts.homeLoc
    local bedrockPos = opts.bedrockPos

    return act.Farm.register({
        id = 'mainIsland:startingIslandTreeFarm',
        init = function(self, state)
            self.state = state
        end,
        enter = function(self, commands)
            homeLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.assertAtPos(self.state, homeLoc.cmps.pos)
        end,
        nextSprint = function(self, commands)
            local state = self.state

            commands.turtle.select(state, 1)
            local startPos = state.turtlePos

            local mainCmps = homeLoc.cmps.compassAt({ forward=-5 })
            navigate.moveToCoord(commands, state, mainCmps.coord)

            local inFrontOfEachTreeCmps = {
                mainCmps.compassAt({ right=-3 }),
                mainCmps.compassAt({ right=3 }),
            }

            for i, inFrontOfTreeCmps in ipairs(inFrontOfEachTreeCmps) do
                navigate.moveToPos(commands, state, inFrontOfTreeCmps.pos)
                treeFarmBehavior.tryHarvestTree(commands, state, inFrontOfTreeCmps)
            end

            navigate.moveToPos(commands, state, startPos, { 'up', 'right', 'forward' })

            return true
        end,
        supplies = treeFarmBehavior.stats.supplies,
        calcExpectedYield = treeFarmBehavior.stats.calcExpectedYield,
    })
end

local registerCraftingMills = function()
    local millList = {}
    for i, recipe in pairs(recipes.crafting) do
        local mill = act.Mill.register({
            id = 'mainIsland:crafting:'..recipe.to..':'..i,
            init = function(self, state, resourceRequests)
                self.state = state

                -- mutable state
                self.produced = 0

                local requestedQuantity = resourceRequests[recipe.to]
                util.assert(requestedQuantity ~= nil, 'Must supply a request for '..recipe.to..' to use this mill')
                -- I don't have inventory management techniques in place to handle a larger quantity
                util.assert(requestedQuantity <= 64 * 8, 'Can not handle that large of a quantity yet')
                self.requestedQuantity = requestedQuantity
            end,
            nextSprint = function(self, commands)
                local state = self.state

                local amountNeeded = self.requestedQuantity - self.produced
                local craftAmount = util.minNumber(64 * recipe.yields, amountNeeded)
                highLevelCommands.craft(commands, state, recipe, craftAmount)
                
                self.produced = self.produced + craftAmount
                return self.produced == self.requestedQuantity
            end,
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

local registerHarvestExcessDirtProject = function(opts)
    local bedrockPos = opts.bedrockPos
    local homeLoc = opts.homeLoc
    local bedrockCmps = space.createCompass(bedrockPos)

    return act.Project.register({
        id = 'mainIsland:harvestExcessDirt',
        init = function(self, state)
            self.state = state
        end,
        enter = function(self, commands)
            homeLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.assertAtPos(self.state, homeLoc.cmps.pos)
        end,
        nextSprint = function(self, commands)
            local state = self.state
            local startPos = state.turtlePos
            local digStartCmps = bedrockCmps.compassAt({ forward=2, up=-1 })

            navigate.moveToCoord(commands, state, digStartCmps.coord, { 'forward', 'up' })

            local dirtPlaneToDig = navigationPatterns.compilePlane({
                -- "d" marks the dirt to dig
                -- "D" marks dirt we don't want to dig
                -- "B" marks bedrock
                ' ,    ',
                'dddddd',
                'dBdddd',
                'dDdddd',
                'ddd   ',
                'ddd   ',
                'ddd   ',
            }, { referencePointCmps = digStartCmps })

            navigationPatterns.snake(commands, state, {
                boundingBoxCoords = { dirtPlaneToDig.topLeftCmps.coord, dirtPlaneToDig.bottomRightCmps.coord },
                shouldVisit = function(coord)
                    return dirtPlaneToDig.getCharAt(coord) == 'd'
                end,
                onVisit = function()
                    commands.turtle.digUp(state)
                end,
            })

            navigate.moveToCoord(commands, state, digStartCmps.coord)
            navigate.moveToPos(commands, state, startPos, { 'up', 'forward' })

            return true
        end,
    })
end

local registerTowerProject = function(opts)
    local homeLoc = opts.homeLoc
    local towerNumber = opts.towerNumber

    return act.Project.register({
        id = 'mainIsland:tower:'..towerNumber,
        init = function(self, state)
            self.state = state
        end,
        enter = function(self, commands)
            homeLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.assertAtPos(self.state, homeLoc.cmps.pos)
        end,
        nextSprint = function(self, commands)
            local state = self.state
            local startPos = state.turtlePos

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

            return true
        end,
        requiredResources = {
            -- ['minecraft:cobblestone'] = { quantity=64 * 4, at='INVENTORY' }
            -- ['minecraft:furnace'] = { quantity=32, at='INVENTORY' }
            ['minecraft:stone'] = { quantity=32, at='INVENTORY' }
        },
    })
end

function module.register()
    local bedrockCmps = space.createCompass({ forward = 3, right = 0, up = 64, face = 'forward' })

    -- homeLoc is right above the bedrock
    local homeLoc = Location.register(bedrockCmps.posAt({ up=3 }))
    -- in front of chest, but facing north
    local inFrontOfChestLoc = Location.register(homeLoc.cmps.posAt({ right=3 }))
    -- facing away from the chest, with the disk drive to the right
    local initialLoc = Location.register(inFrontOfChestLoc.cmps.posAt({ face='left' }))
    local inFrontOfFirstFurnaceLoc = Location.register(
        -- faces the furnace
        inFrontOfChestLoc.cmps.posAt({ forward=1, right=1, up=1, face='right' })
    )

    local cobblestoneGeneratorMill = registerCobblestoneGeneratorMill({ homeLoc = homeLoc })
    local startingIslandTreeFarm = registerStartingIslandTreeFarm({ bedrockPos = bedrockCmps.pos, homeLoc = homeLoc })
    local furnaceMill = registerFurnaceMill({ inFrontOfFirstFurnaceLoc = inFrontOfFirstFurnaceLoc })
    local simpleCharcoalSmeltingMill = registerSimpleCharcoalSmeltingMill({ inFrontOfFirstFurnaceLoc = inFrontOfFirstFurnaceLoc })
    local craftingMills = registerCraftingMills()

    return {
        -- locations
        inFrontOfChestLoc = inFrontOfChestLoc,
        initialLoc = initialLoc,
        homeLoc = homeLoc,

        -- projects
        initialization = registerInitializationProject({ initialLoc = initialLoc, homeLoc = homeLoc, inFrontOfChestLoc = inFrontOfChestLoc }),
        startBuildingCobblestoneGenerator = registerStartBuildingCobblestoneGeneratorProject({ homeLoc = homeLoc, craftingMills = craftingMills }),
        harvestInitialTreeAndPrepareTreeFarm = registerHarvestInitialTreeAndPrepareTreeFarmProject({ bedrockPos = bedrockCmps.pos, homeLoc = homeLoc, startingIslandTreeFarm = startingIslandTreeFarm }),
        waitForIceToMeltAndfinishCobblestoneGenerator = registerWaitForIceToMeltAndfinishCobblestoneGeneratorProject({ homeLoc = homeLoc, cobblestoneGeneratorMill = cobblestoneGeneratorMill }),
        buildFurnaces = registerBuildFurnacesProject({ inFrontOfChestLoc = inFrontOfChestLoc, inFrontOfFirstFurnaceLoc = inFrontOfFirstFurnaceLoc }),
        smeltInitialCharcoal = registerSmeltInitialCharcoalProject({ inFrontOfFirstFurnaceLoc = inFrontOfFirstFurnaceLoc, furnaceMill = furnaceMill, simpleCharcoalSmeltingMill = simpleCharcoalSmeltingMill }),
        torchUpIsland = registerTorchUpIslandProject({ inFrontOfChestLoc = inFrontOfChestLoc }),
        harvestExcessDirt = registerHarvestExcessDirtProject({ bedrockPos = bedrockCmps.pos, homeLoc = homeLoc }),
        tower1 = registerTowerProject({ homeLoc = homeLoc, towerNumber = 1 }),
        tower2 = registerTowerProject({ homeLoc = homeLoc, towerNumber = 2 }),
        tower3 = registerTowerProject({ homeLoc = homeLoc, towerNumber = 3 }),
        tower4 = registerTowerProject({ homeLoc = homeLoc, towerNumber = 4 }),
    }
end

act.Project.registerStartingConditionInitializer(function(startingConditions)
    startingConditions.mainIsland = {
        startedCobblestoneGeneratorConstruction = false,
    }
end)

return module
