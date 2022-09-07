local commands = import('./commands/init.lua')
local util = import('util.lua')

local registerCommand = commands.registerCommand
local registerCommandWithFuture = commands.registerCommandWithFuture

local module = {}

local moduleId = 'act:highLevelCommands'
local genId = commands.createIdGenerator(moduleId)

module.transferToFirstEmptySlot = registerCommand(
    'highLevelCommands:transferToFirstEmptySlot',
    function(state, opts)
        opts = opts or {}
        local allowEmpty = opts.allowEmpty or false

        local firstEmptySlot = nil
        for i = 1, 16 do
            local count = turtle.getItemCount(i)
            if count == 0 then
                firstEmptySlot = i
                break
            end
        end
        if firstEmptySlot == nil then
            error('Failed to find an empty slot.')
        end
        local success = turtle.transferTo(firstEmptySlot)
        if not success then
            if allowEmpty then return end
            error('Failed to transfer to the first empty slot (was the source empty?)')
        end
    end
)

module.findAndSelectSlotWithItem = registerCommandWithFuture(
    'highLevelCommands:findAndSelectSlotWithItem',
    function(state, itemIdToFind, opts)
        if opts == nil then opts = {} end
        local allowMissing = opts.allowMissing or false
        for i = 1, 16 do
            local slotInfo = turtle.getItemDetail(i)
            if slotInfo ~= nil then
                local itemIdInSlot = slotInfo.name
                if itemIdInSlot == itemIdToFind then
                    turtle.select(i)
                    return true
                end
            end
        end
        if allowMissing then
            return false
        end
        error('Failed to find the item '..itemIdToFind..' in the inventory')
    end,
    function(itemIdToFind, opts)
        return opts and opts.out
    end
)

function module.placeItem(planner, itemId, opts)
    placeItemUsing(planner, itemId, opts, commands.turtle.place)
end

function module.placeItemUp(planner, itemId, opts)
    placeItemUsing(planner, itemId, opts, commands.turtle.placeUp)
end

function module.placeItemDown(planner, itemId, opts)
    placeItemUsing(planner, itemId, opts, commands.turtle.placeDown)
end

function placeItemUsing(planner, itemId, opts, placeFn)
    opts = opts or {}
    local allowMissing = opts.allowMissing or false
    local out = opts.out or genId('foundItem')

    local foundItem = module.findAndSelectSlotWithItem(planner, itemId, {
        out = out,
        allowMissing = allowMissing,
    })
    commands.futures.if_(planner, foundItem, function(planner)
        placeFn(planner)
        commands.turtle.select(planner, 1)
    end)
end

-- recipe is a 3x3 grid of itemIds.
-- `maxQuantity` is optional, and default to the max,
-- which is a stack per item the recipe produces. (e.g. reeds
-- produce multiple paper with a single craft)
-- pre-condition: There must be an empty space above the turtle
module.craft = registerCommand(
    'highLevelCommands:craft',
    function(state, recipe, maxQuantity)
        local strategy = _G.act.strategy

        maxQuantity = maxQuantity or 999
        if util.tableSize(recipe.from) == 0 then error('Empty recipe') end

        local numOfItemsInChest = 0

        local flattenedRecipe = {}
        for i, row in pairs(recipe.from) do
            for j, itemId in pairs(row) do
                local slotId = (i - 1)*4 + j
                flattenedRecipe[slotId] = itemId -- might be nil
            end
        end
    
        if turtle.detectUp() then
            error('Can not craft unless there is room above the turtle')
        end

        strategy.atomicallyExecuteSubplan(state, function(planner)
            module.findAndSelectSlotWithItem(planner, 'minecraft:chest')
            commands.turtle.placeUp(planner)
            -- Put any remaining chests into the chest, to make sure we have at least one empty inventory slot
            commands.turtle.dropUp(planner, 64)
            module.findAndSelectSlotWithItem(planner, 'minecraft:crafting_table')
            commands.turtle.equipRight(planner)
            commands.turtle.select(planner, 1)
        end)

        function findLocationsOfItems(whereItemsAre, itemId)
            local itemLocations = {}
            for slotId, iterItemId in pairs(whereItemsAre) do
                if itemId == iterItemId then
                    table.insert(itemLocations, slotId)
                end
            end
            return itemLocations
        end

        local craftSlotIds = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }
        local startingInventory = module.takeInventoryNow()
        -- emptySlot and whereItemsAre will be updated in the following for
        -- loop to state up-to-date as things shift around.
        local emptySlot = findEmptyInventorySlots(startingInventory)[1]
        local whereItemsAre = util.mapMapTable(startingInventory, function(entry) return entry.name end)
        local usedRecipeCells = {}
        if emptySlot == nil then
            -- For this to happen, you have to, for example, have multiple chests in your inventory
            -- so when one gets placed down, you're still completely full. Additional logic could be
            -- added to support these edge cases, but right now we just throw an error.
            error('Failed to craft - inventory is too full')
        end

        -- Shuffle around items in the 3x3 grid, so that the correct recipe items will be
        -- found in the correct slots, or the slot will be left empty (after the next loop runs
        -- that throws the garbage stuff into the chest above)
        for _, i in ipairs(craftSlotIds) do
            turtle.select(i)
            turtle.transferTo(emptySlot)
            whereItemsAre[emptySlot] = whereItemsAre[i]
            whereItemsAre[i] = nil
            emptySlot = i

            local locationsOfThisResource = findLocationsOfItems(whereItemsAre, flattenedRecipe[i])
            locationsOfThisResource = util.subtractArrayTables(locationsOfThisResource, usedRecipeCells)

            if #locationsOfThisResource > 0 then
                table.insert(usedRecipeCells, i)
            end
            for _, resourceLocation in ipairs(locationsOfThisResource) do
                turtle.select(resourceLocation)
                turtle.transferTo(i)
                if emptySlot == i then
                    emptySlot = resourceLocation
                end
                whereItemsAre[i] = whereItemsAre[resourceLocation]
                if turtle.getItemCount(resourceLocation) == 0 then
                    whereItemsAre[resourceLocation] = nil
                end
                if turtle.getItemSpace(i) == 0 then
                    break
                end
            end
        end
        turtle.select(1)

        -- Drop everything in the 3x3 grid into the chest above that isn't part of the recipe
        -- Also drop everything into the chest outside of the 3x3 grid
        for i = 1, 16 do
            if not util.tableContains(usedRecipeCells, i) then
                turtle.select(i)
                turtle.dropUp(64)
                numOfItemsInChest = numOfItemsInChest + 1
            end
        end
        turtle.select(1)

        -- Evently spread the recipe resources
        local updatedInventory = module.takeInventoryNow()
        local resourcesInInventory = module.countResourcesInInventory(updatedInventory, craftSlotIds)
        local recipeResourcessToSlotCount = util.coundOccurancesOfValuesInTable(flattenedRecipe)
        local minStackSize = 999
        for i, slotId in ipairs(craftSlotIds) do
            local resourceName = flattenedRecipe[slotId]
            if resourceName ~= nil then
                local totalOfResource = resourcesInInventory[resourceName]
                local numberOfSlots = recipeResourcessToSlotCount[resourceName]
                local amountPerSlot = math.floor(totalOfResource / numberOfSlots)
                minStackSize = util.minNumber(amountPerSlot, minStackSize)
                if amountPerSlot == 0 then
                    error("There isn't enough items in the inventory to craft the requested item.")
                end
                local amountToRemove = turtle.getItemCount(slotId) - amountPerSlot
                util.assert(amountToRemove >= 0)
                -- If it fails to find another slot afterwards, then it'll just
                -- keep any remainder in the current slot
                for j = i + 1, #craftSlotIds do
                    if amountToRemove == 0 then break end
                    local iterSlotId = craftSlotIds[j]
                    if flattenedRecipe[slotId] == flattenedRecipe[iterSlotId] then
                        turtle.select(slotId)
                        turtle.transferTo(iterSlotId, amountToRemove)
                        amountToRemove = turtle.getItemCount(slotId) - amountPerSlot
                    end
                end
            end
        end
        turtle.select(1)

        turtle.select(4)
        local quantityUsing = minStackSize
        while quantityUsing > 0 do
            turtle.craft(util.minNumber(64, quantityUsing * recipe.yields))
            quantityUsing = quantityUsing - turtle.getItemCount() / recipe.yields
            turtle.dropUp(64)
            numOfItemsInChest = numOfItemsInChest + 1
        end
        turtle.select(1)

        for i = 1, numOfItemsInChest do
            turtle.suckUp(64)
        end

        strategy.atomicallyExecuteSubplan(state, function(planner)
            module.findAndSelectSlotWithItem(planner, 'minecraft:diamond_pickaxe')
            commands.turtle.equipRight(planner)
            commands.turtle.select(planner, 1)
            commands.turtle.digUp(planner)
        end)
    end
)

-- Move everything to the earlier slots in the inventory
-- and combines split stacks.
module.organizeInventory = registerCommand(
    'highLevelCommands:organizeInventory',
    function (state)
        local lastStackLocations = {}
        local emptySpaces = {}
        for i = 1, 16 do
            local itemDetails = turtle.getItemDetail(i)

            -- First, try to transfer to an existing stack
            if itemDetails ~= nil and lastStackLocations[itemDetails.name] ~= nil then
                turtle.select(i)
                turtle.transferTo(lastStackLocations[itemDetails.name])
                itemDetails = turtle.getItemDetail(i)
            end

            -- Then, try to transfer it to an earlier empty slot
            if itemDetails ~= nil and #emptySpaces > 0 then
                local emptySpace = table.delete(emptySpace, 1)
                turtle.select(i)
                turtle.transferTo(emptySpace)
                lastStackLocations[itemDetails.name] = emptySpace
                itemDetails = turtle.getItemDetail(i)
            end
            
            -- If you were able to get it moved, then note the empty cell
            -- otherwise, not down this ptoentially partial stack left behind.
            if itemDetails == nil then
                table.insert(emptySpaces, i)
            else
                lastStackLocations[itemDetails.name] = i
            end
        end
        turtle.select(1)
    end
)

function module.takeInventoryNow()
    local inventory = {}
    for i = 1, 16 do
        local itemDetails = turtle.getItemDetail(i)
        if itemDetails ~= nil then
            inventory[i] = {
                name = itemDetails.name,
                count = itemDetails.count,
            }
        end
    end
    return inventory
end

-- targetSlotIds can optionally be a list of slot IDs to look at (ignoring all other slots)
function module.countResourcesInInventory(inventory, targetSlotIds)
    local resourcesInInventory = {}
    for slotId, itemDetails in pairs(inventory) do
        if itemDetails ~= nil and (targetSlotIds == nil or util.tableContains(targetSlotIds, slotId)) then
            if resourcesInInventory[itemDetails.name] == nil then
                resourcesInInventory[itemDetails.name] = 0
            end
            resourcesInInventory[itemDetails.name] = resourcesInInventory[itemDetails.name] + itemDetails.count
        end
    end
    return resourcesInInventory
end

function findEmptyInventorySlots(inventory)
    local emptySlots = {}
    for i = 1, 16 do
        if inventory[i] == nil then
            table.insert(emptySlots, i)
        end
    end
    return emptySlots
end

-- opts.expectedBlockId is the blockId you're waiting for
-- opts.direction is 'up' or 'down' ('front' is not yet supported).
-- opts.endFacing. Can be a facing or 'ANY', or 'CURRENT' (the default)
--   If set to 'ANY', you MUST use highLevelCommands.reorient() to fix your facing
--   when you're ready to depend on it again. (The exception is if you let the
--   current plan end while in an unknown position then try to fix the position
--   in a new plan, as the turtle's real position becomes known between plans)
module.waitUntilDetectBlock = registerCommand(
    'highLevelCommands:waitUntilDetectBlock',
    function(state, opts)
        local space = _G.act.space

        local expectedBlockId = opts.expectedBlockId
        local direction = opts.direction
        local endFacing = opts.endFacing

        if endFacing == 'CURRENT' or endFacing == nil then
            endFacing = space.posToFace(state.turtlePos)
        end

        local inspectFn
        if direction == 'up' then
            inspectFn = turtle.inspectUp
        elseif direction == 'down' then
            inspectFn = turtle.inspectDown
        else
            error('Invalid direction')
        end

        local success, blockInfo = inspectFn()
        local blockId = blockInfo.name
        if not success then
            minecraftBlockId = 'minecraft:air'
        end

        if blockId ~= expectedBlockId then
            turtle.turnRight() -- Wait for a bit
            state.turtlePos.face = space.rotateFaceClockwise(state.turtlePos.face)
            -- If endFacing is 'CURRENT' (or nil), we need to swap it for a calculated direction,
            -- so the next command that runs knows the original facing.
            local newOpts = util.mergeTables(opts, { endFacing = endFacing })
            table.insert(state.plan, 1, { command = 'highLevelCommands:waitUntilDetectBlock', args = {newOpts} })
        elseif endFacing ~= 'ANY' then
            table.insert(state.plan, 1, { command = 'highLevelCommands:reorient', args = {endFacing} })
        end
    end,
    {
        onSetup = function(planner, opts)
            local endFacing = opts.endFacing

            local turtlePos = planner.turtlePos
            if endFacing == 'CURRENT' or endFacing == nil then
                -- Do nothing
            elseif endFacing == 'ANY' then
                planner.turtlePos = {
                    forward=0,
                    right=0,
                    up=0,
                    face='forward',
                    from=util.mergeTables(
                        planner.turtlePos,
                        { face='UNKNOWN' }
                    )
                }
            else
                turtlePos.face = endFacing.face
            end
        end
    }
)

-- Uses runtime facing information instead of the ahead-of-time planned facing to orient yourself a certain direction
-- relative to the origin.
-- This is important after doing a high-level command that could put you facing a random direction, and there's no way
-- to plan a specific number of turn-lefts/rights to fix it in advance.
module.reorient = registerCommand(
    'highLevelCommands:reorient',
    function(state, targetFacing)
        if state.turtlePos.from ~= 'ORIGIN' then
            error('UNREACHABLE: A state.turtlePos.from value should always be "ORIGIN"')
        end
        local space = _G.act.space
    
        local beforeFace = state.turtlePos.face
        local rotations = space.countClockwiseRotations(beforeFace, targetFacing.face)
    
        if rotations == 1 then
            turtle.turnRight()
        elseif rotations == 2 then
            turtle.turnRight()
            turtle.turnRight()
        elseif rotations == 3 then
            turtle.turnLeft()
        end
        state.turtlePos.face = targetFacing.face
    end, {
        onSetup = function(planner, targetFacing)
            local space = _G.act.space
            if targetFacing.from ~= 'ORIGIN' then
                error('The targetFacing "from" field must be set to "ORIGIN"')
            end
            if planner.turtlePos.from == 'ORIGIN' then
                error("There is no need to use reorient(), if the turtle's positition is completely known.")
            end

            local squashedPos = space.squashFromFields(planner.turtlePos)
            local unsupportedMovement = (
                squashedPos.forward == 'UNKNOWN' or
                squashedPos.right == 'UNKNOWN' or
                squashedPos.up == 'UNKNOWN'
            )
            if unsupportedMovement then
                error('The reoirient command currently only knows how to fix the "from" field when "face" is the only field set to "UNKNOWN" in the "from" chain.')
            end
            squashedPos.face = targetFacing.face
            planner.turtlePos = squashedPos
        end
    }
)

return module
