-- Helpers for interacting with the mock world

local module = {}

-- coord is an {x, y, z} coordinate
function module.lookupInMap(coord)
    local map = _G.mockComputerCraftApi.world.map
    if map[coord.x] and map[coord.x][coord.y] and map[coord.x][coord.y][coord.z] then
        return map[coord.x][coord.y][coord.z]
    end
    return nil
end

-- value should at least be { id = ... }
function module.setInMap(coord, value)
    local map = _G.mockComputerCraftApi.world.map
    if map[coord.x] == nil then map[coord.x] = {} end
    if map[coord.x][coord.y] == nil then map[coord.x][coord.y] = {} end
    map[coord.x][coord.y][coord.z] = value
end

-- `amount` must be the size of a stack or less. Defaults to 1.
-- Returns the quantity added successfully.
function module.addToInventory(itemId, amount)
    local turtle = _G.mockComputerCraftApi.world.turtle
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
function module.removeFromInventory(amount)
    local turtle = _G.mockComputerCraftApi.world.turtle
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

return module
