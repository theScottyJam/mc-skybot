local strategy = import('./strategy.lua')
local util = import('util.lua')

local module = {}

local findEmptyInventorySlots = function(inventory)
    local emptySlots = {}
    for i = 1, 16 do
        if inventory[i] == nil then
            table.insert(emptySlots, i)
        end
    end
    return emptySlots
end

-- Operation written in an old-style way, that might not even be needed anymore.
-- module.transferToFirstEmptySlot = registerCommand(
--     'highLevelCommands:transferToFirstEmptySlot',
--     function(state, opts)
--         opts = opts or {}
--         local allowEmpty = opts.allowEmpty or false

--         local firstEmptySlot = nil
--         for i = 1, 16 do
--             local count = turtle.getItemCount(i)
--             if count == 0 then
--                 firstEmptySlot = i
--                 break
--             end
--         end
--         if firstEmptySlot == nil then
--             error('Failed to find an empty slot.')
--         end
--         local success = turtle.transferTo(firstEmptySlot)
--         if not success then
--             if allowEmpty then return end
--             error('Failed to transfer to the first empty slot (was the source empty?)')
--         end
--     end
-- )

function module.findAndSelectSlotWithItem(commands, miniState, itemIdToFind, opts)
    if opts == nil then opts = {} end
    local allowMissing = opts.allowMissing or false
    for i = 1, 16 do
        local slotInfo = commands.turtle.getItemDetail(miniState, i)
        if slotInfo ~= nil then
            local itemIdInSlot = slotInfo.name
            if itemIdInSlot == itemIdToFind then
                commands.turtle.select(miniState, i)
                return true
            end
        end
    end
    if allowMissing then
        return false
    end
    error('Failed to find the item '..itemIdToFind..' in the inventory')
end

function module.findAndSelectEmptpySlot(commands, miniState, opts)
    -- A potential option I could add, is to auto-reorganize the inventory if an empty slot can't be found.
    if opts == nil then opts = {} end
    local allowMissing = opts.allowMissing or false
    for i = 1, 16 do
        local slotInfo = commands.turtle.getItemDetail(miniState, i)
        if slotInfo == nil then
            commands.turtle.select(miniState, i)
            return true
        end
    end
    if allowMissing then
        return false
    end
    error('Failed to find an empty slot in the inventory')
end

local placeItemUsing

function module.placeItem(commands, miniState, itemId, opts)
    placeItemUsing(commands, miniState, itemId, opts, commands.turtle.place)
end

function module.placeItemUp(commands, miniState, itemId, opts)
    placeItemUsing(commands, miniState, itemId, opts, commands.turtle.placeUp)
end

function module.placeItemDown(commands, miniState, itemId, opts)
    placeItemUsing(commands, miniState, itemId, opts, commands.turtle.placeDown)
end

placeItemUsing = function(commands, miniState, itemId, opts, placeFn)
    opts = opts or {}
    local allowMissing = opts.allowMissing or false

    local foundItem = module.findAndSelectSlotWithItem(commands, miniState, itemId, { allowMissing = allowMissing })
    if foundItem then
        placeFn(miniState)
        commands.turtle.select(miniState, 1)
    end
end

local dropItemAt
function module.dropItem(commands, miniState, itemId, amount)
    dropItemAt(commands, miniState, itemId, amount, 'forward')
end

function module.dropItemUp(commands, miniState, itemId, amount)
    dropItemAt(commands, miniState, itemId, amount, 'up')
end

function module.dropItemDown(commands, miniState, itemId, amount)
    dropItemAt(commands, miniState, itemId, amount, 'down')
end

dropItemAt = function(commands, miniState, itemId, amount, direction)
    local dropFn
    if direction == 'forward' then
        dropFn = commands.turtle.drop
    elseif direction == 'up' then
        dropFn = commands.turtle.dropUp
    elseif direction == 'down' then
        dropFn = commands.turtle.dropDown
    end

    while amount > 0 do
        module.findAndSelectSlotWithItem(commands, miniState, itemId)
        local quantityInSlot = commands.turtle.getItemCount(miniState)
        local amountToDrop = util.minNumber(quantityInSlot, amount)

        if amountToDrop == 0 then
            error('Internal error when using dropItemAt command.')
        end

        dropFn(miniState, amountToDrop)

        amount = amount - amountToDrop
    end
    commands.turtle.select(miniState, 1)
end

-- recipe is a 3x3 grid of itemIds.
-- `maxQuantity` is optional, and default to the max,
-- which is a stack per item the recipe produces. (e.g. reeds
-- produce multiple paper with a single craft)
-- pre-condition: There must be an empty space above the turtle
function module.craft(commands, miniState, recipe, maxQuantity)
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

    if commands.turtle.detectUp(miniState) then
        error('Can not craft unless there is room above the turtle')
    end

    module.findAndSelectSlotWithItem(commands, miniState, 'minecraft:chest')
    commands.turtle.placeUp(miniState)
    -- Put any remaining chests into the chest, to make sure we have at least one empty inventory slot
    commands.turtle.dropUp(miniState, 64)
    module.findAndSelectSlotWithItem(commands, miniState, 'minecraft:crafting_table')
    commands.turtle.equipRight(miniState)
    commands.turtle.select(miniState, 1)

    local findLocationsOfItems = function(whereItemsAre, itemId)
        local itemLocations = {}
        for slotId, iterItemId in pairs(whereItemsAre) do
            if itemId == iterItemId then
                table.insert(itemLocations, slotId)
            end
        end
        return itemLocations
    end

    local craftSlotIds = { 1, 2, 3, 5, 6, 7, 9, 10, 11 }
    local startingInventory = module.takeInventory(commands, miniState)
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
        commands.turtle.select(miniState, i)
        commands.turtle.transferTo(miniState, emptySlot)
        whereItemsAre[emptySlot] = whereItemsAre[i]
        whereItemsAre[i] = nil
        emptySlot = i

        local locationsOfThisResource = findLocationsOfItems(whereItemsAre, flattenedRecipe[i])
        locationsOfThisResource = util.subtractArrayTables(locationsOfThisResource, usedRecipeCells)

        if #locationsOfThisResource > 0 then
            table.insert(usedRecipeCells, i)
        end
        for _, resourceLocation in ipairs(locationsOfThisResource) do
            commands.turtle.select(miniState, resourceLocation)
            commands.turtle.transferTo(miniState, i)
            if emptySlot == i then
                emptySlot = resourceLocation
            end
            whereItemsAre[i] = whereItemsAre[resourceLocation]
            if commands.turtle.getItemCount(miniState, resourceLocation) == 0 then
                whereItemsAre[resourceLocation] = nil
            end
            if commands.turtle.getItemSpace(miniState, i) == 0 then
                break
            end
        end
    end
    commands.turtle.select(miniState, 1)

    -- Drop everything in the 3x3 grid into the chest above that isn't part of the recipe
    -- Also drop everything into the chest outside of the 3x3 grid
    for i = 1, 16 do
        if not util.tableContains(usedRecipeCells, i) then
            commands.turtle.select(miniState, i)
            commands.turtle.dropUp(miniState, 64)
            numOfItemsInChest = numOfItemsInChest + 1
        end
    end
    commands.turtle.select(miniState, 1)

    -- Evenly spread the recipe resources
    local updatedInventory = module.takeInventory(commands, miniState)
    local resourcesInInventory = module.countResourcesInInventory(updatedInventory, craftSlotIds)
    local recipeResourcessToSlotCount = util.countOccurancesOfValuesInTable(flattenedRecipe)
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
            local amountToRemove = commands.turtle.getItemCount(miniState, slotId) - amountPerSlot
            util.assert(amountToRemove >= 0)
            -- If it fails to find another slot afterwards, then it'll just
            -- keep any remainder in the current slot
            for j = i + 1, #craftSlotIds do
                if amountToRemove == 0 then break end
                local iterSlotId = craftSlotIds[j]
                if flattenedRecipe[slotId] == flattenedRecipe[iterSlotId] then
                    commands.turtle.select(miniState, slotId)
                    commands.turtle.transferTo(miniState, iterSlotId, amountToRemove)
                    amountToRemove = commands.turtle.getItemCount(miniState, slotId) - amountPerSlot
                end
            end
        end
    end
    commands.turtle.select(miniState, 1)

    commands.turtle.select(miniState, 4)
    local quantityUsing = minStackSize
    while quantityUsing > 0 do
        commands.turtle.craft(miniState, util.minNumber(64, quantityUsing * recipe.yields))
        quantityUsing = quantityUsing - commands.turtle.getItemCount(miniState) / recipe.yields
        commands.turtle.dropUp(miniState, 64)
        numOfItemsInChest = numOfItemsInChest + 1
    end
    commands.turtle.select(miniState, 1)

    for i = 1, numOfItemsInChest do
        commands.turtle.suckUp(miniState, 64)
    end

    module.findAndSelectSlotWithItem(commands, miniState, 'minecraft:diamond_pickaxe')
    commands.turtle.equipRight(miniState)
    commands.turtle.select(miniState, 1)
    commands.turtle.digUp(miniState)
end

-- Move everything to the earlier slots in the inventory
-- and combines split stacks.
function module.organizeInventory(commands, miniState)
    local lastStackLocations = {}
    local emptySpaces = {}
    for i = 1, 16 do
        local itemDetails = commands.turtle.getItemDetail(miniState, i)

        -- First, try to transfer to an existing stack
        if itemDetails ~= nil and lastStackLocations[itemDetails.name] ~= nil then
            commands.turtle.select(miniState, i)
            commands.turtle.transferTo(miniState, lastStackLocations[itemDetails.name])
            itemDetails = commands.turtle.getItemDetail(miniState, i)
        end

        -- Then, try to transfer it to an earlier empty slot
        if itemDetails ~= nil and #emptySpaces > 0 then
            local emptySpace = table.remove(emptySpaces, 1)
            commands.turtle.select(miniState, i)
            commands.turtle.transferTo(miniState, emptySpace)
            lastStackLocations[itemDetails.name] = emptySpace
            itemDetails = commands.turtle.getItemDetail(miniState, i)
        end
        
        -- If you were able to get it moved, then note the empty cell
        -- otherwise, note down this ptoentially partial stack left behind.
        if itemDetails == nil then
            table.insert(emptySpaces, i)
        else
            lastStackLocations[itemDetails.name] = i
        end
    end
    commands.turtle.select(miniState, 1)
end

function module.takeInventory(commands, miniState)
    local inventory = {}
    for i = 1, 16 do
        local itemDetails = commands.turtle.getItemDetail(miniState, i)
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

-- Do a 360. This causes a bit of time to pass,
-- and visually shows that the turtle is actively waiting for something.
function module.busyWait(commands, miniState)
    commands.turtle.turnRight(miniState)
    commands.turtle.turnRight(miniState)
    commands.turtle.turnRight(miniState)
    commands.turtle.turnRight(miniState)
end

-- opts.expectedBlockId is the blockId you're waiting for
-- opts.direction is 'up' or 'down' ('front' is not yet supported).
-- opts.endFacing. Can be a facing or 'ANY', or 'CURRENT' (the default)
function module.waitUntilDetectBlock(commands, miniState, opts)
    local navigate = _G.act.navigate

    local expectedBlockId = opts.expectedBlockId
    local direction = opts.direction
    local endFacing = opts.endFacing

    if endFacing == 'CURRENT' or endFacing == nil then
        endFacing = miniState.turtleCmps().facing
    end

    local inspectFn
    if direction == 'up' then
        inspectFn = commands.turtle.inspectUp
    elseif direction == 'down' then
        inspectFn = commands.turtle.inspectDown
    else
        error('Invalid direction')
    end

    while true do
        local success, blockInfo = inspectFn(miniState)
        local blockId = blockInfo.name
        if not success then
            minecraftBlockId = 'minecraft:air'
        end

        if blockId == expectedBlockId then
            if endFacing ~= 'ANY' then
                navigate.face(commands, miniState, endFacing)
            end
            break
        end

        turtle.turnRight() -- Wait for a bit
    end
end

return module
