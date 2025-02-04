local util = import('util.lua')
local navigate = import('./navigate.lua')
local commands = import('./commands.lua')
local space = import('./space.lua')
local state = import('./state.lua')

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

function module.findAndSelectSlotWithItem(itemIdToFind, opts)
    if opts == nil then opts = {} end
    local allowMissing = opts.allowMissing or false
    for i = 1, 16 do
        local slotInfo = commands.turtle.getItemDetail(i)
        if slotInfo ~= nil then
            local itemIdInSlot = slotInfo.name
            if itemIdInSlot == itemIdToFind then
                commands.turtle.select(i)
                return true
            end
        end
    end
    if allowMissing then
        return false
    end
    error('Failed to find the item '..itemIdToFind..' in the inventory')
end

function module.findAndSelectEmptySlot(opts)
    -- A potential option I could add, is to auto-reorganize the inventory if an empty slot can't be found.
    if opts == nil then opts = {} end
    local allowMissing = opts.allowMissing or false
    for i = 1, 16 do
        local slotInfo = commands.turtle.getItemDetail(i)
        if slotInfo == nil then
            commands.turtle.select(i)
            return true
        end
    end
    if allowMissing then
        return false
    end
    error('Failed to find an empty slot in the inventory')
end

local placeItemUsing

function module.placeItem(itemId, opts)
    placeItemUsing(itemId, opts, commands.turtle.tryPlace)
end

function module.placeItemUp(itemId, opts)
    placeItemUsing(itemId, opts, commands.turtle.tryPlaceUp)
end

function module.placeItemDown(itemId, opts)
    placeItemUsing(itemId, opts, commands.turtle.tryPlaceDown)
end

placeItemUsing = function(itemId, opts, placeFn)
    opts = opts or {}
    local allowMissing = opts.allowMissing or false

    local foundItem = module.findAndSelectSlotWithItem(itemId, { allowMissing = allowMissing })
    if foundItem then
        local success = placeFn()
        util.assert(success, 'Failed to place "'..itemId..' (maybe there is already something at that location?)')
        commands.turtle.select(1)
    end
end

local dropItemUsing
function module.dropItem(itemId, amount)
    dropItemUsing(itemId, amount, commands.turtle.drop)
end

function module.dropItemUp(itemId, amount)
    dropItemUsing(itemId, amount, commands.turtle.dropUp)
end

function module.dropItemDown(itemId, amount)
    dropItemUsing(itemId, amount, commands.turtle.dropDown)
end

dropItemUsing = function(itemId, amount, dropFn)
    while amount > 0 do
        module.findAndSelectSlotWithItem(itemId)
        local quantityInSlot = commands.turtle.getItemCount()
        local amountToDrop = util.minNumber(quantityInSlot, amount)

        if amountToDrop == 0 then
            error('Internal error when using dropItemAt command.')
        end

        dropFn(amountToDrop)

        amount = amount - amountToDrop
    end
    commands.turtle.select(1)
end

-- recipe is a 3x3 grid of itemIds.
-- `maxQuantity` is optional, and default to the max,
-- which is a stack per item the recipe produces. (e.g. reeds
-- produce multiple paper with a single craft)
-- pre-condition: There must be an empty space above the turtle
function module.craft(recipe, maxQuantity)
    maxQuantity = maxQuantity or 99999
    if util.tableSize(recipe.from) == 0 then error('Empty recipe') end

    local numOfItemsInChest = 0

    local flattenedRecipe = {}
    for i, row in pairs(recipe.from) do
        for j, itemId in pairs(row) do
            local slotId = (i - 1)*4 + j
            flattenedRecipe[slotId] = itemId -- might be nil
        end
    end

    if commands.turtle.detectUp() then
        error('Can not craft unless there is room above the turtle')
    end

    module.findAndSelectSlotWithItem('minecraft:chest')
    commands.turtle.placeUpAndAssert()
    -- Put any remaining chests into the chest, to make sure we have at least one empty inventory slot
    commands.turtle.dropUp(64)
    module.findAndSelectSlotWithItem('minecraft:crafting_table')
    commands.turtle.equipRight()
    commands.turtle.select(1)

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
    local startingInventory = module.takeInventory()
    -- emptySlot and whereItemsAre will be updated in the following for loop
    -- to stay up-to-date as things shift around.
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
        commands.turtle.select(i)
        commands.turtle.transferTo(emptySlot)
        whereItemsAre[emptySlot] = whereItemsAre[i]
        whereItemsAre[i] = nil
        emptySlot = i

        local locationsOfThisResource = findLocationsOfItems(whereItemsAre, flattenedRecipe[i])
        locationsOfThisResource = util.subtractArrayTables(locationsOfThisResource, usedRecipeCells)

        if #locationsOfThisResource > 0 then
            table.insert(usedRecipeCells, i)
        end
        for _, resourceLocation in ipairs(locationsOfThisResource) do
            commands.turtle.select(resourceLocation)
            commands.turtle.transferTo(i)
            if emptySlot == i then
                emptySlot = resourceLocation
            end
            whereItemsAre[i] = whereItemsAre[resourceLocation]
            if commands.turtle.getItemCount(resourceLocation) == 0 then
                whereItemsAre[resourceLocation] = nil
            end
            if commands.turtle.getItemSpace(i) == 0 then
                break
            end
        end
    end
    commands.turtle.select(1)

    -- Drop everything in the 3x3 grid into the chest above that isn't part of the recipe
    -- Also drop everything into the chest outside of the 3x3 grid
    for i = 1, 16 do
        if not util.tableContains(usedRecipeCells, i) then
            commands.turtle.select(i)
            commands.turtle.dropUp(64)
            numOfItemsInChest = numOfItemsInChest + 1
        end
    end
    commands.turtle.select(1)

    -- Evenly spread the recipe resources
    local updatedInventory = module.takeInventory()
    local resourcesInInventory = module.countResourcesInInventory(updatedInventory, craftSlotIds)
    local recipeResourcessToSlotCount = util.countOccurrencesOfValuesInTable(flattenedRecipe)
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
            local amountToRemove = commands.turtle.getItemCount(slotId) - amountPerSlot
            util.assert(amountToRemove >= 0)
            -- If it fails to find another slot afterwards, then it'll just
            -- keep any remainder in the current slot
            for j = i + 1, #craftSlotIds do
                if amountToRemove == 0 then break end
                local iterSlotId = craftSlotIds[j]
                if flattenedRecipe[slotId] == flattenedRecipe[iterSlotId] then
                    commands.turtle.select(slotId)
                    commands.turtle.transferTo(iterSlotId, amountToRemove)
                    amountToRemove = commands.turtle.getItemCount(slotId) - amountPerSlot
                end
            end
        end
    end
    commands.turtle.select(1)

    commands.turtle.select(4)
    local quantityUsing = util.minNumber(minStackSize, math.ceil(maxQuantity / recipe.yields))
    while quantityUsing > 0 do
        commands.turtle.craft(util.minNumber(64, quantityUsing * recipe.yields))
        quantityUsing = quantityUsing - commands.turtle.getItemCount() / recipe.yields
        commands.turtle.dropUp(64)
        numOfItemsInChest = numOfItemsInChest + 1
    end
    commands.turtle.select(1)

    for i = 1, numOfItemsInChest do
        commands.turtle.suckUp(64)
    end

    module.findAndSelectSlotWithItem('minecraft:diamond_pickaxe')
    commands.turtle.equipRight()
    commands.turtle.select(1)
    commands.turtle.digUp()
end

-- Move everything to the earlier slots in the inventory
-- and combines split stacks.
function module.organizeInventory()
    local lastStackLocations = {}
    local emptySpaces = {}
    for i = 1, 16 do
        local itemDetails = commands.turtle.getItemDetail(i)

        -- First, try to transfer to an existing stack
        if itemDetails ~= nil and lastStackLocations[itemDetails.name] ~= nil then
            commands.turtle.select(i)
            commands.turtle.transferTo(lastStackLocations[itemDetails.name])
            itemDetails = commands.turtle.getItemDetail(i)
        end

        -- Then, try to transfer it to an earlier empty slot
        if itemDetails ~= nil and #emptySpaces > 0 then
            local emptySpace = table.remove(emptySpaces, 1)
            commands.turtle.select(i)
            commands.turtle.transferTo(emptySpace)
            lastStackLocations[itemDetails.name] = emptySpace
            itemDetails = commands.turtle.getItemDetail(i)
        end
        
        -- If you were able to get it moved, then note the empty cell
        -- otherwise, note down this ptoentially partial stack left behind.
        if itemDetails == nil then
            table.insert(emptySpaces, i)
        else
            lastStackLocations[itemDetails.name] = i
        end
    end
    commands.turtle.select(1)
end

function module.takeInventory()
    local inventory = {}
    for i = 1, 16 do
        local itemDetails = commands.turtle.getItemDetail(i)
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
function module.busyWait()
    commands.turtle.turnRight()
    commands.turtle.turnRight()
    commands.turtle.turnRight()
    commands.turtle.turnRight()
end

-- opts.expectedBlockId is the blockId you're waiting for
-- opts.direction is 'up' or 'down' ('front' is not yet supported).
-- opts.endFacing. Can be a facing or 'ANY', or 'CURRENT' (the default)
function module.waitUntilDetectBlock(opts)
    local expectedBlockId = opts.expectedBlockId
    local direction = opts.direction
    local endFacing = opts.endFacing

    if endFacing == 'CURRENT' or endFacing == nil then
        endFacing = state.getTurtleCmps().facing
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
        local success, blockInfo = inspectFn()
        local blockId = blockInfo.name
        if not success then
            minecraftBlockId = 'minecraft:air'
        end

        if blockId == expectedBlockId then
            if endFacing ~= 'ANY' then
                navigate.face(endFacing)
            end
            break
        end

        commands.turtle.turnRight() -- Wait for a bit
    end
end

-- Starting from a corner of a square (of size sideLength), touch every cell in it by following
-- a clockwise spiral to the center. You must start facing in a direction such that
-- no turning is required before movement.
-- The `onVisit` function is called at each cell visited.
function module.spiralInwards(opts)
    -- This function is used to harvest the leaves on trees.
    -- We could probably use the snake function instead, but this one
    -- is more fine-tuned to allow the turtle to harvest both in front and below
    -- at the same time, thus being able to harvest the tree in two sweeps instead of four.
    -- If needed, in the future, it might be possible to fine-tune the snake function
    -- in the same fashion so that either could be used.
    local sideLength = opts.sideLength
    local onVisit = opts.onVisit

    for segmentLength = sideLength - 1, 1, -1 do
        local firstIter = segmentLength == sideLength - 1
        for i = 1, (firstIter and 3 or 2) do
            for j = 1, segmentLength do
                onVisit()
                commands.turtle.forward()
            end
            commands.turtle.turnRight()
        end
    end
    onVisit()
end

--[[
Causes the turtle to make large back-and-forth horizontal movements as it slowly progresses across the region,
thus visiting every spot in the region (that you ask it to visit) in a relatively efficient manner.
The turtle may end anywhere in the region.

inputs:
    boundingBoxCoords = {<coord 1>, <coord 2>} -- Your turtle must be inside of this bounding box,
        and this bounding box must only be 1 block high.
    shouldVisit (optional) = a function that takes a coordinate as a parameter,
        and returns true if the turtle should travel there.
    onVisit = a function that is called each time the turtle visits a designated spot.
]]
function module.snake(opts)
    local boundingBoxCoords = opts.boundingBoxCoords
    local shouldVisit = opts.shouldVisit or function(x, y) return true end
    local onVisit = opts.onVisit

    util.assert(boundingBoxCoords[1].up == boundingBoxCoords[2].up)

    local boundingBox = {
        mostForward = util.maxNumber(boundingBoxCoords[1].forward, boundingBoxCoords[2].forward),
        leastForward = util.minNumber(boundingBoxCoords[1].forward, boundingBoxCoords[2].forward),
        mostRight = util.maxNumber(boundingBoxCoords[1].right, boundingBoxCoords[2].right),
        leastRight = util.minNumber(boundingBoxCoords[1].right, boundingBoxCoords[2].right),
        up = boundingBoxCoords[1].up,
    }

    local inBounds = function (coord)
        return (
            coord.forward >= boundingBox.leastForward and coord.forward <= boundingBox.mostForward and
            coord.right >= boundingBox.leastRight and coord.right <= boundingBox.mostRight and
            coord.up == boundingBox.up
        )
    end

    util.assert(
        inBounds(state.getTurtlePos()),
        'The turtle is not inside of the provided bounding box.'
    )

    local firstCoord = { up = boundingBox.up }
    local verDelta
    local hozDelta
    -- if you're more forwards than backwards within the box
    if boundingBox.mostForward - state.getTurtlePos().forward < state.getTurtlePos().forward - boundingBox.leastForward then
        firstCoord.forward = boundingBox.mostForward
        verDelta = { forward = -1 }
    else
        firstCoord.forward = boundingBox.leastForward
        verDelta = { forward = 1 }
    end
    -- if you're more right than left within the box
    if boundingBox.mostRight - state.getTurtlePos().right < state.getTurtlePos().right - boundingBox.leastRight then
        firstCoord.right = boundingBox.mostRight
        hozDelta = { right = -1 }
    else
        firstCoord.right = boundingBox.leastRight
        hozDelta = { right = 1 }
    end

    local curCmps = space.createCompass(util.mergeTables(firstCoord, { face = 'forward' }))
    while inBounds(curCmps.coord) do
        if shouldVisit(curCmps.coord) then
            navigate.moveToCoord(curCmps.coord)
            onVisit()
        end
        
        local nextCmps = curCmps.compassAt(hozDelta)
        if not inBounds(nextCmps.coord) then
            nextCmps = curCmps.compassAt(verDelta)
            hozDelta.right = -hozDelta.right
        end

        curCmps = nextCmps
    end
end

return module
