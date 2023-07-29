local util = import('util.lua')
local time = import('./_time.lua')
local recipes = import('shared/recipes.lua')

local module = {}

local hookListeners = {}

math.randomseed(0)
-- math.randomseed(os.time())

-- HELPER FUNCTIONS --

local posToCoord = function(pos)
    return { x = pos.x, y = pos.y, z = pos.z }
end

-- coord is an {x, y, z} coordinate
local lookupInMap = function(map, coord)
    if map[coord.x] and map[coord.x][coord.y] and map[coord.x][coord.y][coord.z] then
        return map[coord.x][coord.y][coord.z]
    end
    return nil
end

-- `amount` must be the size of a stack or less. Defaults to 1.
-- Returns the quantity added successfuly.
local addToInventory = function(turtle, itemId, amount)
    if amount == nil then amount = 1 end
    local addedSuccessfully = 0
    for i = 0, 15 do
        local slot = (i + turtle.selectedSlot - 1)%16 + 1
        if turtle.inventory[slot] == nil then
            turtle.inventory[slot] = { id = itemId, quantity = 0 }
        end
        if turtle.inventory[slot].id == itemId then
            local availableSpaceInStack = 64 - turtle.inventory[slot].quantity
            local stillNeedToAdd = amount - addedSuccessfully
            if stillNeedToAdd > availableSpaceInStack then
                addedSuccessfully = addedSuccessfully + availableSpaceInStack
                turtle.inventory[slot].quantity = 64
            else
                turtle.inventory[slot].quantity = turtle.inventory[slot].quantity + stillNeedToAdd
                return amount
            end
        end
    end
    return addedSuccessfully
end

-- removes `amount` of items from the selected inventory slot.
-- Returns <item id>, <amount removed> or nil, 0 if nothing was removed.
local removeFrominventory = function(turtle, amount)
    local slot = turtle.inventory[turtle.selectedSlot]
    if slot == nil then
        return nil, 0
    elseif slot.quantity > amount then
        slot.quantity = slot.quantity - amount
        return slot.id, amount
    else
        turtle.inventory[turtle.selectedSlot] = nil
        return slot.id, slot.quantity
    end
end

local getPosInFront = function(pos)
    local newPos = util.copyTable(pos)
    if pos.face == 'N' then
        newPos.z = newPos.z - 1
    elseif pos.face == 'S' then
        newPos.z = newPos.z + 1
    elseif pos.face == 'W' then
        newPos.x = newPos.x - 1
    elseif pos.face == 'E' then
        newPos.x = newPos.x + 1
    end
    return newPos
end

local getPosBehind = function(pos)
    local newPos = util.copyTable(pos)
    if pos.face == 'N' then
        newPos.z = newPos.z + 1
    elseif pos.face == 'S' then
        newPos.z = newPos.z - 1
    elseif pos.face == 'W' then
        newPos.x = newPos.x + 1
    elseif pos.face == 'E' then
        newPos.x = newPos.x - 1
    end
    return newPos
end

local assertNotInsideBlock = function(world, movementDirectionForError)
    local cell = lookupInMap(world.map, posToCoord(world.turtle.pos))
    if cell ~= nil then
        local pos = world.turtle.pos
        error('Ran into a block of '..cell.id..' at ('..pos.x..', '..pos.y..', '..pos.z..') while moving '..movementDirectionForError)
    end
end

local assertEquiped = function(world, itemId)
    local isOnLeft = world.turtle.equipedLeft ~= nil and world.turtle.equipedLeft.id == itemId
    local isOnRight = world.turtle.equipedRight ~= nil and world.turtle.equipedRight.id == itemId
    if not isOnLeft and not isOnRight then
        error('Must have '..itemId..' equipped before doing this task')
    end
end

-- value should at least be { id = ... }
local setInMap = function(map, coord, value)
    if map[coord.x] == nil then map[coord.x] = {} end
    if map[coord.x][coord.y] == nil then map[coord.x][coord.y] = {} end
    map[coord.x][coord.y][coord.z] = value
end

local spawnTreeAt = function(currentWorld, absCoord)
    local trySetInMap = function(x, y, z, id)
        local coord = { x = absCoord.x + x, y = absCoord.y + y, z = absCoord.z + z }
        local existingCell = lookupInMap(currentWorld.map, coord)
        if existingCell == nil then
            setInMap(currentWorld.map, coord, { id = id })
        end
    end

    local trunkLength = math.random(3, 5)

    -- Remove existing sapling
    setInMap(currentWorld.map, absCoord, nil)

    for i = 0, trunkLength - 1 do
        trySetInMap(0, i, 0, 'minecraft:log')
    end

    -- Creating 5x5 block of leaves with logs down the center
    for x = -2, 2 do
        for z = -2, 2 do
            for y = 0, 1 do
                if x == 0 and z == 0 then
                    trySetInMap(x, trunkLength + y - 1, z, 'minecraft:log')
                elseif y == 0 and math.abs(x) == 2 and math.abs(z) == 2 then
                    -- do nothing
                elseif y == 1 and math.abs(x) == 2 and math.abs(z) == 2 and math.random(0, 1) == 0 then
                    -- do nothing
                else
                    trySetInMap(x, trunkLength + y - 1, z, 'minecraft:leaves')
                end
            end
        end
    end

    -- Creating the top two layers
    for x = -1, 1 do
        for z = -1, 1 do
            for y = 2, 3 do
                if y == 2 and x == 0 and z == 0 then
                    trySetInMap(x, trunkLength + y - 1, z, 'minecraft:log')
                elseif y == 2 and math.abs(x) == 1 and math.abs(z) == 1 and math.random(0, 1) == 0 then
                    -- do nothing
                elseif y == 3 and math.abs(x) == 1 and math.abs(z) == 1 then
                    -- do nothing
                else
                    trySetInMap(x, trunkLength + y - 1, z, 'minecraft:leaves')
                end
            end
        end
    end
end

-- PUBLIC FUNCTIONS --

-- quantity is optional
function module.craft(quantity)
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    assertEquiped(currentWorld, 'minecraft:crafting_table')
    local inventory = currentWorld.turtle.inventory

    local flattenRecipe = function(recipe)
        local flattenedRecipe = {}
        for i, row in pairs(recipe.from) do
            for j, itemId in pairs(row) do
                local slotId = (i - 1)*4 + j
                flattenedRecipe[slotId] = itemId -- might be nil
            end
        end
        return flattenedRecipe
    end

    local matchingRecipe = nil
    for _, recipe in pairs(recipes.crafting) do
        local flattenedRecipe = flattenRecipe(recipe)
        matchingRecipe = recipe
        -- Does it line up with the recipe?
        for slotId, itemId in pairs(flattenedRecipe) do
            if inventory[slotId] == nil or inventory[slotId].id ~= itemId then
                matchingRecipe = nil
                break
            end
        end
        -- Are there any slots outside of the recipe that also contain items?
        if matchingRecipe == nil then
            for i = 1, 16 do
                if flattenedRecipe[i] == nil and inventory[i] ~= nil then
                    matchingRecipe = nil
                    break
                end
            end
        end
        if matchingRecipe ~= nil then break end
    end

    if matchingRecipe == nil then
        error('Attempted to craft with an inventory that does not follow a valid recipe.')
    end

    local minStackSize = 999
    for i = 1, 16 do
        if inventory[i] ~= nil then
            minStackSize = util.minNumber(inventory[i].quantity, minStackSize)
        end
    end

    local amountToUse = util.minNumber(minStackSize, math.floor(64 / matchingRecipe.yields))
    if quantity ~= nil then
        amountToUse = util.minNumber(amountToUse, math.floor(quantity / matchingRecipe.yields))
    end

    for i = 1, 16 do
        if inventory[i] ~= nil then
            inventory[i].quantity = inventory[i].quantity - amountToUse
            if inventory[i].quantity == 0 then
                inventory[i] = nil
            end
        end
    end

    if inventory[currentWorld.turtle.selectedSlot] ~= nil then
        error('Currently only supports crafting into an empty slot')
    end

    inventory[currentWorld.turtle.selectedSlot] = {
        id = matchingRecipe.to,
        quantity = amountToUse * matchingRecipe.yields,
    }
end

function module.up()
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    currentWorld.turtle.pos.y = currentWorld.turtle.pos.y + 1
    assertNotInsideBlock(currentWorld, 'up')
    return true
end

function module.down()
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    currentWorld.turtle.pos.y = currentWorld.turtle.pos.y - 1
    assertNotInsideBlock(currentWorld, 'down')
    return true
end

function module.forward()
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    currentWorld.turtle.pos = getPosInFront(currentWorld.turtle.pos)
    assertNotInsideBlock(currentWorld, 'forwards')
    return true
end

function module.back()
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    currentWorld.turtle.pos = getPosBehind(currentWorld.turtle.pos)
    assertNotInsideBlock(currentWorld, 'backwards')
    return true
end

function module.turnLeft()
    time.tick()
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle
    if turtle.pos.face == 'N' then
        turtle.pos.face = 'W'
    elseif turtle.pos.face == 'W' then
        turtle.pos.face = 'S'
    elseif turtle.pos.face == 'S' then
        turtle.pos.face = 'E'
    elseif turtle.pos.face == 'E' then
        turtle.pos.face = 'N'
    end
    return true
end

function module.turnRight()
    time.tick()
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle
    if turtle.pos.face == 'N' then
        turtle.pos.face = 'E'
    elseif turtle.pos.face == 'E' then
        turtle.pos.face = 'S'
    elseif turtle.pos.face == 'S' then
        turtle.pos.face = 'W'
    elseif turtle.pos.face == 'W' then
        turtle.pos.face = 'N'
    end
    return true
end

function module.select(slotNum)
    if slotNum < 1 or slotNum > 16 then error('slotNum out of range') end
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle
    turtle.selectedSlot = slotNum
    return true
end

function module.getSelectedSlot(slotNum)
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle
    return turtle.selectedSlot
end

-- slotNum is optional
function module.getItemCount(slotNum)
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle

    if slotNum == nil then slotNum = turtle.selectedSlot end
    
    if turtle.inventory[slotNum] == nil then
        return 0
    else
        return turtle.inventory[slotNum].quantity
    end
end

-- slotNum is optional
function module.getItemSpace(slotNum)
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle

    if slotNum == nil then slotNum = turtle.selectedSlot end
    
    if turtle.inventory[slotNum] == nil then
        return 64
    else
        return 64 - turtle.inventory[slotNum].quantity
    end
end

-- slotNum defaults to the selected slot
function module.getItemDetail(slotNum)
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle
    if slotNum == nil then slotNum = turtle.selectedSlot end
    local slot = turtle.inventory[slotNum]
    if slot == nil then
        return nil
    end
    return {
        name = slot.id,
        count = slot.quantity,
        damage = 0
    }
end

function module.equipLeft()
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle
    local inventoryItem = turtle.inventory[turtle.selectedSlot] -- possibly nil
    util.assert(inventoryItem == nil or inventoryItem.quantity == 1, 'Currently unable to equip from a slot with multiple items')
    turtle.inventory[turtle.selectedSlot] = turtle.equipedLeft
    turtle.equipedLeft = inventoryItem
end

function module.equipRight()
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle
    local inventoryItem = turtle.inventory[turtle.selectedSlot] -- possibly nil
    util.assert(inventoryItem == nil or inventoryItem.quantity == 1, 'Currently unable to equip from a slot with multiple items')
    turtle.inventory[turtle.selectedSlot] = turtle.equipedRight
    turtle.equipedRight = inventoryItem
end

local placeAt
-- signText is optional
function module.place(signText)
    time.tick()
    if signText ~= nil then error('signText arg not supported') end
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local placeCoord = posToCoord(getPosInFront(currentWorld.turtle.pos))
    return placeAt(currentWorld, placeCoord)
end

function module.placeUp()
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local placeCoord = { x = turtle.pos.x, y = turtle.pos.y + 1, z = turtle.pos.z }
    return placeAt(currentWorld, placeCoord)
end

function module.placeDown()
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local placeCoord = { x = turtle.pos.x, y = turtle.pos.y - 1, z = turtle.pos.z }
    return placeAt(currentWorld, placeCoord)
end

local canPlace = {
    'minecraft:dirt',
    'minecraft:lava_bucket',
    'minecraft:water_bucket',
    'minecraft:bucket',
    'minecraft:ice',
    'minecraft:sapling',
    'minecraft:cobblestone',
    'minecraft:stone',
    'minecraft:chest',
    'minecraft:furnace',
    'minecraft:torch'
}

placeAt = function(currentWorld, placeCoord)
    local targetCell = lookupInMap(currentWorld.map, placeCoord) -- may be nil
    local belowTargetCell = lookupInMap(currentWorld.map, util.mergeTables(placeCoord, { y = placeCoord.y - 1 }))

    local itemIdBeingPlaced, quantity = removeFrominventory(currentWorld.turtle, 1)
    if quantity == 0 then return false end

    if not util.tableContains(canPlace, itemIdBeingPlaced) then
        error('Can not place block '..itemIdBeingPlaced..' yet.')
    end

    if targetCell ~= nil then
        if targetCell.id == 'minecraft:water' and itemIdBeingPlaced == 'minecraft:bucket' then
            setInMap(currentWorld.map, placeCoord, nil)
            local success = addToInventory(currentWorld.turtle, 'minecraft:water_bucket') == 1
            if not success then error('UNREACHABLE') end
            return true
        elseif targetCell.id == 'minecraft:lava' and itemIdBeingPlaced == 'minecraft:bucket' then
            setInMap(currentWorld.map, placeCoord, nil)
            local success = addToInventory(currentWorld.turtle, 'minecraft:lava_bucket') == 1
            if not success then error('UNREACHABLE') end
            return true
        end
        return false
    end

    if itemIdBeingPlaced == 'minecraft:lava_bucket' then
        itemIdBeingPlaced = 'minecraft:lava'
        local success = addToInventory(currentWorld.turtle, 'minecraft:bucket') == 1
        if not success then error('UNREACHABLE') end
    elseif itemIdBeingPlaced == 'minecraft:water_bucket' then
        itemIdBeingPlaced = 'minecraft:water'
        local success = addToInventory(currentWorld.turtle, 'minecraft:bucket') == 1
        if not success then error('UNREACHABLE') end
    elseif itemIdBeingPlaced == 'minecraft:ice' then
        time.addTickListener(math.random(200, 250), function()
            local cell = lookupInMap(currentWorld.map, placeCoord)
            if cell ~= nil and cell.id == 'minecraft:ice' then
                setInMap(currentWorld.map, placeCoord, { id = 'minecraft:water' })
            end
        end)
    elseif itemIdBeingPlaced == 'minecraft:sapling' then
        if belowTargetCell == nil or (belowTargetCell.id ~= 'minecraft:dirt' and belowTargetCell.id ~= 'minecraft:grass') then
            error('Saplings must be placed on dirt or grass')
        end
        time.addTickListener(math.random(600, 1600), function()
            local cell = lookupInMap(currentWorld.map, placeCoord)
            if cell ~= nil and cell.id == 'minecraft:sapling' then
                spawnTreeAt(currentWorld, placeCoord)
            end
        end)
    elseif itemIdBeingPlaced == 'minecraft:torch' then
        if belowTargetCell == nil then
            error('Torches must be placed on a block')
        end
    end

    local itemBeingPlaced = { id = itemIdBeingPlaced }
    if itemIdBeingPlaced == 'minecraft:chest' then
        itemBeingPlaced.contents = { size = 9 * 3, slots = {} } -- Only small chests are supported right now
    end
    if itemIdBeingPlaced == 'minecraft:furnace' then
        itemBeingPlaced.inputSlot = { size = 1, slots = {} }
        itemBeingPlaced.outputSlot = { size = 1, slots = {} }
        itemBeingPlaced.fuelSlot = { size = 1, slots = {} }
        -- The number of items that will be smelted, with the fuel that was just consumed.
        -- Decreses by 1 every time the item gets smelted.
        itemBeingPlaced.activelySmelting = 0
    end

    setInMap(currentWorld.map, placeCoord, itemBeingPlaced)
    return true
end

function module.detect()
    local blockFound, _ = module.inspect()
    return blockFound
end

function module.detectUp()
    local blockFound, _ = module.inspectUp()
    return blockFound
end

function module.detectDown()
    local blockFound, _ = module.inspectDown()
    return blockFound
end

local inspectAt
function module.inspect()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local inspectCoord = posToCoord(getPosInFront(currentWorld.turtle.pos))
    return inspectAt(currentWorld, inspectCoord)
end

function module.inspectUp()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local inspectCoord = { x = turtle.pos.x, y = turtle.pos.y + 1, z = turtle.pos.z }
    return inspectAt(currentWorld, inspectCoord)
end

function module.inspectDown()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local inspectCoord = { x = turtle.pos.x, y = turtle.pos.y - 1, z = turtle.pos.z }
    return inspectAt(currentWorld, inspectCoord)
end

inspectAt = function(currentWorld, inspectCoord)
    local targetCell = lookupInMap(currentWorld.map, inspectCoord)

    if targetCell == nil then
        return false, 'no block to inspect'
    end

    local blockInfo = {
        name = targetCell.id,
        state = {},
        metadata = 0
    }

    return true, blockInfo
end

local digAt
function module.dig(toolSide)
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local coordBeingDug = posToCoord(getPosInFront(currentWorld.turtle.pos))
    return digAt(currentWorld, coordBeingDug, toolSide)
end

function module.digUp(toolSide)
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local coordBeingDug = { x = turtle.pos.x, y = turtle.pos.y + 1, z = turtle.pos.z }
    return digAt(currentWorld, coordBeingDug, toolSide)
end

function module.digDown(toolSide)
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local coordBeingDug = { x = turtle.pos.x, y = turtle.pos.y - 1, z = turtle.pos.z }
    return digAt(currentWorld, coordBeingDug, toolSide)
end

local canDig = {
    'minecraft:dirt',
    'minecraft:cobblestone',
    'minecraft:grass',
    'minecraft:log',
    'minecraft:leaves',
    'minecraft:ice',
    'minecraft:chest',
}

digAt = function(currentWorld, coordBeingDug, toolSide)
    assertEquiped(currentWorld, 'minecraft:diamond_pickaxe')
    local dugCell = lookupInMap(currentWorld.map, coordBeingDug)
    if dugCell == nil then
        return false
    end
    if dugCell.id == 'minecraft:chest' and util.tableSize(dugCell.contents.slots) > 0 then
        error('Can not pick up a chest filled with items')
    end
    if dugCell.id == 'minecraft:furnace' and (
        util.tableSize(dugCell.inputSlot.slots) > 0 or
        util.tableSize(dugCell.fuelSlot.slots) > 0 or
        util.tableSize(dugCell.outputSlot.slots) > 0 or
        dugCell.activelySmelting > 0
    ) then
        error('Can not pick up a furnace filled with items, or that is actively running')
    end
    if not util.tableContains(canDig, dugCell.id) then
        error('Can not dig block '..dugCell.id..' yet. Perhaps this requires using a tool, which is not supported.')
    end

    setInMap(currentWorld.map, coordBeingDug, nil)
    local success
    if dugCell.id == 'minecraft:leaves' then
        if math.random(0, 10) == 0 then
            success = addToInventory(currentWorld.turtle, 'minecraft:sapling') == 1
        elseif math.random(0, 20) == 0 then
            success = addToInventory(currentWorld.turtle, 'minecraft:stick') == 1
        elseif math.random(0, 30) == 0 then
            success = addToInventory(currentWorld.turtle, 'minecraft:apple') == 1
        else
            success = true
        end
    elseif dugCell.id == 'minecraft:ice' then
        -- The turtle breaks ice without turning it into water
        success = true
    elseif dugCell.id == 'minecraft:grass' then
        success = addToInventory(currentWorld.turtle, 'minecraft:dirt') == 1
    else
        success = addToInventory(currentWorld.turtle, dugCell.id) == 1
    end
    if not success then error('Failed to dig - Inventory full.') end
    return true
end

local dropAt
function module.drop(amount)
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local coordDroppingTo = posToCoord(getPosInFront(turtle.pos))
    return dropAt(currentWorld, coordDroppingTo, amount, 'front')
end

function module.dropUp(amount)
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local coordDroppingTo = { x = turtle.pos.x, y = turtle.pos.y + 1, z = turtle.pos.z }
    return dropAt(currentWorld, coordDroppingTo, amount, 'up')
end

function module.dropDown(amount)
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local coordDroppingTo = { x = turtle.pos.x, y = turtle.pos.y - 1, z = turtle.pos.z }
    return dropAt(currentWorld, coordDroppingTo, amount, 'down')
end

local attemptToSmelt
dropAt = function(currentWorld, coordDroppingTo, amount, dropDirection)
    if amount == nil then
        -- According to the docs, the `amount` param used to not be a thing.
        -- Apparently now that it is a thing, it's also required.
        error('`amount` param is required')
    end

    local selectedSlot = currentWorld.turtle.selectedSlot

    local targetCell = lookupInMap(currentWorld.map, coordDroppingTo)
    if targetCell == nil then
        error('Expected to find a block with an inventory')
    end
    if currentWorld.turtle.inventory[selectedSlot] == nil then
        return true
    end

    if amount > currentWorld.turtle.inventory[selectedSlot].quantity then
        amount = currentWorld.turtle.inventory[selectedSlot].quantity
    end

    local targetInventory
    if targetCell.id == 'minecraft:chest' then
        targetInventory = targetCell.contents
    elseif targetCell.id == 'minecraft:furnace' then
        if dropDirection == 'up' or dropDirection == 'front' then
            targetInventory = targetCell.fuelSlot
        elseif dropDirection == 'down' then
            targetInventory = targetCell.inputSlot
        else
            error()
        end
    else
        error('Can not drop item into block '..targetCell.id..' yet.')
    end

    local somethingMoved = false
    for i = 1, targetInventory.size do
        local inventory = currentWorld.turtle.inventory
        if targetInventory.slots[i] == nil then
            targetInventory.slots[i] = {
                id = inventory[selectedSlot].id,
                quantity = 0
            }
        end

        if targetInventory.slots[i].id == inventory[selectedSlot].id then
            local maxThatCanBeMoved = 64 - targetInventory.slots[i].quantity
            local amountBeingMoved = util.minNumber(maxThatCanBeMoved, amount)
            if amountBeingMoved > 0 then
                somethingMoved = true
            end

            amount = amount - amountBeingMoved
            targetInventory.slots[i].quantity = targetInventory.slots[i].quantity + amountBeingMoved
            inventory[selectedSlot].quantity = inventory[selectedSlot].quantity - amountBeingMoved
            if inventory[selectedSlot].quantity == 0 then
                inventory[selectedSlot] = nil
            end
            if amount == 0 then
                break
            end
        end
    end

    if targetCell.id == 'minecraft:furnace' and somethingMoved then
        attemptToSmelt(currentWorld, coordDroppingTo)
    end

    return somethingMoved
end

attemptToSmelt = function(currentWorld, furnaceCoord)
    local furnaceCell = lookupInMap(currentWorld.map, furnaceCoord)
    local SMELT_TIME = 20

    if furnaceCell.activelySmelting > 0 then
        return
    end

    local input = furnaceCell.inputSlot.slots[1]
    local fuel = furnaceCell.fuelSlot.slots[1]
    if input == nil or fuel == nil then
        return
    end

    if fuel.id == 'minecraft:charcoal' then
        furnaceCell.activelySmelting = 8
        fuel.quantity = fuel.quantity - 1
    elseif fuel.id == 'minecraft:planks' then
        furnaceCell.activelySmelting = 3
        if fuel.quantity < 2 then
            error('Must have a multiple of 2 planks in the fuel slot. Any other number is currently not supported')
        end
        fuel.quantity = fuel.quantity - 2
    else
        error(
            'Invalid fuel type ' .. fuel.id .. ' found in fuel slot. ' ..
            'This fuel type is either currently not supported, or can not be used as fuel.'
        )
    end

    if fuel.quantity == 0 then
        furnaceCell.fuelSlot.slots[1] = nil
    end

    local finishSmelt
    finishSmelt = function()
        local furnaceCell = lookupInMap(currentWorld.map, furnaceCoord)
        if furnaceCell == nil or furnaceCell.id ~= 'minecraft:furnace' then
            error('Finished smelting, but the target furnace was gone.')
        end

        local input = furnaceCell.inputSlot.slots[1]
        if input == nil then
            return
        end
        local recipe = util.findInArrayTable(recipes.smelting, function (recipe) return recipe.from == input.id end)
        if recipe == nil then
            error('Attempted to smelt ' .. input.id .. ' which currently does not have a smelting recipe')
        end

        if furnaceCell.outputSlot.slots[1] == nil then
            furnaceCell.outputSlot.slots[1] = { id = recipe.to, quantity = 0 }
        end
        if furnaceCell.outputSlot.slots[1].id ~= recipe.to then
            furnaceCell.activelySmelting = 0
            return
        end
        if furnaceCell.outputSlot.slots[1].quantity == 64 then
            furnaceCell.activelySmelting = 0
            return
        end
        furnaceCell.outputSlot.slots[1].quantity = furnaceCell.outputSlot.slots[1].quantity + 1
        furnaceCell.inputSlot.slots[1].quantity = furnaceCell.inputSlot.slots[1].quantity - 1

        local moreToSmelt = true
        if furnaceCell.inputSlot.slots[1].quantity == 0 then
            furnaceCell.inputSlot.slots[1] = nil
            moreToSmelt = false
        end

        furnaceCell.activelySmelting = furnaceCell.activelySmelting - 1
        if furnaceCell.activelySmelting > 0 then
            if moreToSmelt then
                time.addTickListener(SMELT_TIME, finishSmelt)
            end
        else
            attemptToSmelt(currentWorld, furnaceCoord)
        end
    end

    time.addTickListener(SMELT_TIME, finishSmelt)
end

local suckAt
function module.suck(amount)
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local coordSuckingFrom = posToCoord(getPosInFront(turtle.pos))
    return suckAt(currentWorld, coordSuckingFrom, amount, 'front')
end

function module.suckUp(amount)
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local coordSuckingFrom = { x = turtle.pos.x, y = turtle.pos.y + 1, z = turtle.pos.z }
    return suckAt(currentWorld, coordSuckingFrom, amount, 'up')
end

function module.suckDown(amount)
    time.tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local coordSuckingFrom = { x = turtle.pos.x, y = turtle.pos.y - 1, z = turtle.pos.z }
    return suckAt(currentWorld, coordSuckingFrom, amount, 'down')
end

suckAt = function(currentWorld, coordSuckingFrom, amount, suckDirection)
    if amount == nil then
        -- According to the docs, the `amount` param used to not be a thing.
        -- Apparently now that it is a thing, it's also required.
        error('`amount` param is required')
    end

    local cellSuckingFrom = lookupInMap(currentWorld.map, coordSuckingFrom)
    if cellSuckingFrom == nil then
        return false
    end

    local targetInventory
    if cellSuckingFrom.id == 'minecraft:chest' then
        targetInventory = cellSuckingFrom.contents
    elseif cellSuckingFrom.id == 'minecraft:furnace' then
        if suckDirection == 'up' then
            targetInventory = cellSuckingFrom.outputSlot
        elseif suckDirection == 'front' then
            targetInventory = cellSuckingFrom.fuelSlot
        elseif suckDirection == 'down' then
            targetInventory = cellSuckingFrom.inputSlot
        else
            error()
        end
    else
        error('Can not suck from block '..cellSuckingFrom.id..' yet.')
    end

    if amount > 64 or amount <= 0 then
        error('amount argument out of range')
    end

    local findItemsToRemove = function(applyChanges, limit)
        if limit == nil then limit = 64 end
        local suckingItemId = nil
        local quantity = 0
        for i = 1, targetInventory.size do
            local item = targetInventory.slots[i]
            if item ~= nil and suckingItemId == nil then
                suckingItemId = item.id
            end
            if item ~= nil and item.id == suckingItemId then
                if quantity + item.quantity > limit then
                    if applyChanges then item.quantity = item.quantity - (limit - quantity) end
                    quantity = limit
                else
                    quantity = quantity + item.quantity
                    if applyChanges then targetInventory.slots[i] = nil end
                end
                if quantity == limit then break end
            end
        end
        return suckingItemId, quantity -- suckingItemId may be nil
    end

    local suckingItemId, quantityCanBePulled = findItemsToRemove(false)
    if suckingItemId == nil then return false end
    local quantityAdded = addToInventory(currentWorld.turtle, suckingItemId, quantityCanBePulled)
    findItemsToRemove(true, quantityAdded)

    return quantityAdded > 0
end

-- quantity is optional
function module.refuel(quantity)
    -- TODO
end

-- quantity is optional
function module.transferTo(destinationSlot, quantity)
    if quantity == nil then quantity = 64 end
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle

    if turtle.selectedSlot == destinationSlot then
        return true
    end
    if turtle.inventory[turtle.selectedSlot] == nil then
        return false
    end

    if turtle.inventory[destinationSlot] == nil then
        turtle.inventory[destinationSlot] = {
            id = turtle.inventory[turtle.selectedSlot].id,
            quantity = 0,
        }
    end

    if turtle.inventory[destinationSlot].id ~= turtle.inventory[turtle.selectedSlot].id then
        return false
    end

    local spaceAvailable = 64 - turtle.inventory[destinationSlot].quantity
    local amountBeingMoved = util.minNumber(
        util.minNumber(spaceAvailable, quantity),
        turtle.inventory[turtle.selectedSlot].quantity
    )

    turtle.inventory[turtle.selectedSlot].quantity = turtle.inventory[turtle.selectedSlot].quantity - amountBeingMoved
    turtle.inventory[destinationSlot].quantity = turtle.inventory[destinationSlot].quantity + amountBeingMoved
    if turtle.inventory[turtle.selectedSlot].quantity == 0 then
        turtle.inventory[turtle.selectedSlot] = nil
    end

    return true
end

---- HOOKS ----

function hookListeners.registerCobblestoneRegenerationBlock(deltaCoord)
    local coord = {
        x = deltaCoord.right,
        y = deltaCoord.up,
        z = -deltaCoord.forward
    }
    local regenerateCobblestone
    regenerateCobblestone = function()
        time.addTickListener(4, regenerateCobblestone)
        local currentWorld = _G.mockComputerCraftApi._currentWorld
        local cell = lookupInMap(currentWorld.map, coord)
        if cell ~= nil then return end
        setInMap(currentWorld.map, coord, { id = 'minecraft:cobblestone' })
    end

    time.addTickListener(4, regenerateCobblestone)
end

return { module, hookListeners }
