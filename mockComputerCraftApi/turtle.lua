local util = import('util.lua')

local module = {}

local hookListeners = {}

local MAX_INVENTORY_SIZE = 100

function module.up()
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    currentWorld.turtle.pos.y = currentWorld.turtle.pos.y + 1
    assertNotInsideBlock(currentWorld)
    return true
end

function module.down()
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    currentWorld.turtle.pos.y = currentWorld.turtle.pos.y - 1
    assertNotInsideBlock(currentWorld)
    return true
end

function module.forward()
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    currentWorld.turtle.pos = getPosInFront(currentWorld.turtle.pos)
    assertNotInsideBlock(currentWorld)
    return true
end

function module.back()
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    currentWorld.turtle.pos = getPosBehind(currentWorld.turtle.pos)
    assertNotInsideBlock(currentWorld)
    return true
end

function module.turnLeft()
    tick()
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
    tick()
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

-- slotNum defaults to the selected slot
function module.getItemDetail(slotNum)
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle
    if slotNum == nil then slotNum = turtle.selectedSlot end
    local slot = turtle.inventory[slotNum]
    if slot == nil then
        return nil
    end
    return {
        name = 'minecraft:'..string.lower(slot.id),
        count = slot.quantity,
        damage = 0
    }
end

function module.equipLeft()
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle
    local inventoryItem = turtle.inventory[turtle.selectedSlot] -- possibly nil
    turtle.inventory[turtle.selectedSlot] = turtle.equipedLeft
    turtle.equipedLeft = inventoryItem
end

function module.equipRight()
    local turtle = _G.mockComputerCraftApi._currentWorld.turtle
    local inventoryItem = turtle.inventory[turtle.selectedSlot] -- possibly nil
    turtle.inventory[turtle.selectedSlot] = turtle.equipedRight
    turtle.equipedRight = inventoryItem
end

-- signText is optional
function module.place(signText)
    tick()
    if signText ~= nil then error('signText arg not supported') end
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local placePos = getPosInFront(currentWorld.turtle.pos)
    return placeAt(currentWorld, placePos)
end

function module.placeUp()
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local placePos = { x = turtle.pos.x, y = turtle.pos.y + 1, z = turtle.pos.z }
    return placeAt(currentWorld, placePos)
end

function module.placeDown()
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local placePos = { x = turtle.pos.x, y = turtle.pos.y - 1, z = turtle.pos.z }
    return placeAt(currentWorld, placePos)
end

local canPlace = { 'DIRT', 'LAVA_BUCKET', 'WATER_BUCKET', 'BUCKET', 'ICE' }
function placeAt(currentWorld, placePos)
    local targetCell = lookupInMap(currentWorld.map, placePos) -- may be nil

    itemIdBeingPlaced, quantity = removeFrominventory(currentWorld.turtle, 1)
    if quantity == 0 then return false end

    if not util.tableContains(canPlace, itemIdBeingPlaced) then
        error('Can not place block '..itemIdBeingPlaced..' yet.')
    end

    if targetCell ~= nil then
        if targetCell.id == 'WATER' and itemIdBeingPlaced == 'BUCKET' then
            setInMap(currentWorld.map, placePos, nil)
            local success = addToInventory(currentWorld.turtle, 'WATER_BUCKET') == 1
            if not success then error('UNREACHABLE') end
            return true
        elseif targetCell.id == 'LAVA' and itemIdBeingPlaced == 'BUCKET' then
            setInMap(currentWorld.map, placePos, nil)
            local success = addToInventory(currentWorld.turtle, 'LAVA_BUCKET') == 1
            if not success then error('UNREACHABLE') end
            return true
        end
        return false
    end

    if itemIdBeingPlaced == 'LAVA_BUCKET' then
        itemIdBeingPlaced = 'LAVA'
        local success = addToInventory(currentWorld.turtle, 'BUCKET') == 1
        if not success then error('UNREACHABLE') end
    elseif itemIdBeingPlaced == 'WATER_BUCKET' then
        itemIdBeingPlaced = 'WATER'
        local success = addToInventory(currentWorld.turtle, 'BUCKET') == 1
        if not success then error('UNREACHABLE') end
    elseif itemIdBeingPlaced == 'ICE' then
        addTickListener(200, function()
            local cell = lookupInMap(currentWorld.map, placePos)
            if cell ~= nil and cell.id == 'ICE' then
                setInMap(currentWorld.map, placePos, { id = 'WATER' })
            end
        end)
    end
    setInMap(currentWorld.map, placePos, { id = itemIdBeingPlaced })
    return true
end

function module.inspect()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local inspectPos = getPosInFront(currentWorld.turtle.pos)
    return inspectAt(currentWorld, inspectPos)
end

function module.inspectUp()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local inspectPos = { x = turtle.pos.x, y = turtle.pos.y + 1, z = turtle.pos.z }
    return inspectAt(currentWorld, inspectPos)
end

function module.inspectDown()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local inspectPos = { x = turtle.pos.x, y = turtle.pos.y - 1, z = turtle.pos.z }
    return inspectAt(currentWorld, inspectPos)
end

function inspectAt(currentWorld, inspectPos)
    local targetCell = lookupInMap(currentWorld.map, inspectPos)

    if targetCell == nil then
        return false, 'no block to inspect'
    end

    local blockInfo = {
        name = 'minecraft:'..string.lower(targetCell.id),
        state = {},
        metadata = 0
    }

    return true, blockInfo
end

function module.dig(toolSide)
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local posBeingDug = getPosInFront(currentWorld.turtle.pos)
    return digAt(currentWorld, posBeingDug, toolSide)
end

function module.digUp(toolSide)
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local posBeingDug = { x = turtle.pos.x, y = turtle.pos.y + 1, z = turtle.pos.z }
    return digAt(currentWorld, posBeingDug, toolSide)
end

function module.digDown(toolSide)
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local posBeingDug = { x = turtle.pos.x, y = turtle.pos.y - 1, z = turtle.pos.z }
    return digAt(currentWorld, posBeingDug, toolSide)
end

local canDig = { 'DIRT', 'COBBLESTONE', 'GRASS', 'LOG', 'LEAVES', 'ICE' }

local leavesDug = 0
function digAt(currentWorld, posBeingDug, toolSide)
    local dugCell = lookupInMap(currentWorld.map, posBeingDug)
    if dugCell == nil then
        return false
    end
    if not util.tableContains(canDig, dugCell.id) then
        error('Can not dig block '..dugCell.id..' yet. Perhaps this requires using a tool, which is not supported.')
    end

    setInMap(currentWorld.map, posBeingDug, nil)
    local success
    if dugCell.id == 'LEAVES' then
        leavesDug = leavesDug + 1
        if leavesDug % 4 == 0 then
            success = addToInventory(currentWorld.turtle, 'STICK') == 1
        elseif leavesDug % 7 == 0 then
            success = addToInventory(currentWorld.turtle, 'SAPLING') == 1
        elseif leavesDug % 15 == 0 then
            success = addToInventory(currentWorld.turtle, 'APPLE') == 1
        else
            success = true
        end
    elseif dugCell.id == 'ICE' then
        -- The turtle breaks ice without turning it into water
        success = true
    elseif dugCell.id == 'GRASS' then
        success = addToInventory(currentWorld.turtle, 'DIRT') == 1
    else
        success = addToInventory(currentWorld.turtle, dugCell.id) == 1
    end
    if not success then error('Failed to dig - Inventory full.') end
    return true
end

-- amount is optional
function module.suck(amount)
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local posSuckingFrom = getPosInFront(turtle.pos)
    return suckAt(currentWorld, posSuckingFrom, amount)
end

function module.suckUp(amount)
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local posSuckingFrom = { x = turtle.pos.x, y = turtle.pos.y + 1, z = turtle.pos.z, face = turtle.pos.face }
    return suckAt(currentWorld, posSuckingFrom, amount)
end

function module.suckDown(amount)
    tick()
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    local posSuckingFrom = { x = turtle.pos.x, y = turtle.pos.y - 1, z = turtle.pos.z, face = turtle.pos.face }
    return suckAt(currentWorld, posSuckingFrom, amount)
end

local canSuckFrom = { 'CHEST' }

function suckAt(currentWorld, posSuckingFrom, amount)
    if amount == nil then
        -- According to the docs, the `amount` param used to not be a thing.
        -- Apparently now that it is a thing, it's also required.
        error('`amount` param is required')
    end

    local cellSuckingFrom = lookupInMap(currentWorld.map, posSuckingFrom)
    if cellSuckingFrom == nil then
        return false
    end

    if not util.tableContains(canSuckFrom, cellSuckingFrom.id) then
        error('Can not suck from block '..cellSuckingFrom.id..' yet.')
    end
    if amount > 64 or amount <= 0 then
        error('amount argument out of range')
    end

    function findItemsToRemove(applyChanges, limit)
        if limit == nil then limit = 64 end
        local suckingItemId = nil
        local quantity = 0
        for i = 0, MAX_INVENTORY_SIZE do
            local item = cellSuckingFrom.contents[i]
            if item ~= nil and suckingItemId == nil then
                suckingItemId = item.id
            end
            if item ~= nil and item.id == suckingItemId then
                if quantity + item.quantity > limit then
                    if applyChanges then item.quantity = item.quantity - (limit - quantity) end
                    quantity = limit
                else
                    quantity = quantity + item.quantity
                    if applyChanges then cellSuckingFrom.contents[i] = nil end
                end
                if quantity == limit then break end
            end
        end
        return suckingItemId, quantity
    end

    local suckingItemId, quantityCanBePulled = findItemsToRemove(false)
    local quantityAdded = addToInventory(currentWorld.turtle, suckingItemId, quantityCanBePulled)
    findItemsToRemove(true, quantityAdded)

    return quantityAdded == 0
end

-- quantity is optional
function module.transferTo(destinationSlot, quantity)
    if quantity == nil then quantity = 64 end
    local currentWorld = _G.mockComputerCraftApi._currentWorld
    local turtle = currentWorld.turtle
    
    if turtle.inventory[turtle.selectedSlot] == nil then
        return false
    end
    if turtle.inventory[destinationSlot] ~= nil then
        if turtle.inventory[destinationSlot].id == turtle.inventory[turtle.selectedSlot].id then
            error('The ability to transfer items to a partially-filled slot of the same type is not yet implemented.')
        end
        return false
    end

    turtle.inventory[destinationSlot] = turtle.inventory[turtle.selectedSlot]
    turtle.inventory[turtle.selectedSlot] = nil
    return true
end

---- HOOKS ----

function hookListeners.registerCobblestoneRegenerationBlock(deltaCoord)
    if deltaCoord.from ~= 'ORIGIN' then
        error('Cobblestone generators can only be registered with coordinates who\'s from value is set to "ORIGIN"')
    end
    local coord = {
        x = deltaCoord.right,
        y = deltaCoord.up,
        z = -deltaCoord.forward
    }
    function regenerateCobblestone()
        local currentWorld = _G.mockComputerCraftApi._currentWorld
        local cell = lookupInMap(currentWorld.map, coord)
        if cell ~= nil then return end
        setInMap(currentWorld.map, coord, { id = 'COBBLESTONE' })

        addTickListener(5, regenerateCobblestone)  
    end

    addTickListener(5, regenerateCobblestone)
end

---- HELPERS ----

local tickListeners = {}
local currentTick = 0
function tick()
    currentTick = currentTick + 1
    for i, entry in ipairs(tickListeners) do
        if entry.at == currentTick then
            entry.listener()
        end
    end
    tickListeners = util.filterArrayTable(tickListeners, function(value) return value.at > currentTick end)
end

function addTickListener(ticksLater, listener)
    table.insert(tickListeners, {
        at = currentTick + ticksLater,
        listener = listener
    })
end

-- quantity must be the size of a stack or less. Defaults to 1.
-- Returns the quantity added successfuly.
function addToInventory(turtle, itemId, amount)
    if amount == nil then amount = 1 end
    local addedSuccessfully = 0
    for i = 0,15 do
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
function removeFrominventory(turtle, amount)
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

function getPosInFront(pos)
    newPos = util.copyTable(pos)
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

function getPosBehind(pos)
    newPos = util.copyTable(pos)
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

function assertNotInsideBlock(world)
    local cell = lookupInMap(world.map, posToCoord(world.turtle.pos))
    if cell ~= nil then
        local pos = world.turtle.pos
        error('Ran into a block of '..cell.id..' at ('..pos.x..', '..pos.y..', '..pos.z..')')
    end
end

-- coord is an {x, y, z} coordinate
function lookupInMap(map, coord)
    if map[coord.x] and map[coord.x][coord.y] and map[coord.x][coord.y][coord.z] then
        return map[coord.x][coord.y][coord.z]
    end
    return nil
end

-- value should at least be { id = ... }
function setInMap(map, coord, value)
    if map[coord.x] == nil then map[coord.x] = {} end
    if map[coord.x][coord.y] == nil then map[coord.x][coord.y] = {} end
    map[coord.x][coord.y][coord.z] = value
end

function posToCoord(pos)
    return { x = pos.x, y = pos.y, z = pos.z }
end

return module, hookListeners
