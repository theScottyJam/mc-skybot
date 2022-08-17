--[[
    Used to display information about the a mock world
--]]

local util = import('util.lua')

local module = {}

local completeMapKey = {
    ['computercraft:turtle_n'] = '^',
    ['computercraft:turtle_e'] = '>',
    ['computercraft:turtle_s'] = 'V',
    ['computercraft:turtle_w'] = '<',
    ['computercraft:disk_drive'] = '&',
    ['minecraft:dirt'] = 'd',
    ['minecraft:grass'] = 'D',
    ['minecraft:chest'] = 'C',
    ['minecraft:leaves'] = 'l',
    ['minecraft:log'] = 'L',
    ['minecraft:water'] = '~',
    ['minecraft:lava'] = '=',
    ['minecraft:ice'] = 'I',
}

-- bounds is of the shape { minX = ..., maxX = ..., minY? = ..., maxY? = ..., minZ = ..., maxZ = ...}
-- This will render a top-down view of the world, cropped at the provided bounds.
-- opts is optional
function module.displayMap(world, bounds, opts)
    local showKey = (opts or {}).showKey
    if showKey == nil then showKey = true end

    local map = world.map
    local view = {}

    local minY = bounds.minY
    if minY == nil then minY = -9999 end
    local maxY = bounds.maxY
    if maxY == nil then maxY = 9999 end

    function insertCellIntoViewIfAble(x, y, z, view, cell)
        if view[x] == nil then view[x] = {} end
        local inVerticalBounds = minY <= y and maxY >= y
        local higherThanLastFoundValue = view[x][z] == nil or view[x][z].y < y
        if inVerticalBounds and higherThanLastFoundValue then
            view[x][z] = { y = y, cell = cell }
        end
    end

    -- Calculates a 2d view from the 3d map
    for x, plane in pairs(map) do
        for y, row in pairs(plane) do
            for z, cell in pairs(row) do
                insertCellIntoViewIfAble(x, y, z, view, cell)
            end
        end
    end

    local turtlePos = world.turtle.pos
    local turtleId = 'computercraft:turtle_'..string.lower(turtlePos.face)
    insertCellIntoViewIfAble(turtlePos.x, turtlePos.y, turtlePos.z, view, { id = turtleId })

    -- Turns the 2d view into a string
    local result = ''
    local neededInKey = {}
    for z = bounds.minZ, bounds.maxZ do
        for x = bounds.minX, bounds.maxX do
            if view[x] == nil or view[x][z] == nil then
                result = result..'.'
            else
                local cell = view[x][z].cell
                local char = completeMapKey[cell.id]
                if char == nil then char = '?' end
                neededInKey[cell.id] = char
                result = result..char
            end
        end
        result = result..'\n'
    end

    if showKey then
        -- Tacks on a key onto the end of the string
        result = result .. '\n' .. '-- key --\n'
        for id, char in pairs(neededInKey) do
            local parts = util.splitString(id, ':')
            result = result .. char .. ': ' .. parts[2] .. '\n'
        end
    end

    print(result)
end

function module.inventory(world)
    print('Inventory:')
    local found = false
    for i = 1, 16 do
        local slot = world.turtle.inventory[i]
        if slot ~= nil then
            found = true
            local parts = util.splitString(slot.id, ':')
            print('  '..i..': '..parts[2]..' ('..slot.quantity..')')
        end
    end
    if found == false then
        print('  <empty>')
    end
end

function module.showTurtlePosition(world)
    local turtlePos = world.turtle.pos
    print('Turtle pos: ('..turtlePos.x..','..turtlePos.y..','..turtlePos.z..') '..turtlePos.face)
end

return module