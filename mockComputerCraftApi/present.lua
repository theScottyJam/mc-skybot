--[[
    Used to display information about the a mock world
]]

local util = import('util.lua')
local osModule = import('./os.lua')
local time = import('./_time.lua')

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
    ['minecraft:cobblestone'] = 'c',
    ['minecraft:stone'] = 'S',
    ['minecraft:leaves'] = 'l',
    ['minecraft:sapling'] = 's',
    ['minecraft:log'] = 'L',
    ['minecraft:water'] = '~',
    ['minecraft:lava'] = '=',
    ['minecraft:ice'] = 'I',
    ['minecraft:furnace'] = 'F',
    ['minecraft:torch'] = '*',
}

-- bounds is of the shape { minX = ..., maxX = ..., minY? = ..., maxY? = ..., minZ = ..., maxZ = ...}
-- This will render a top-down view of the world, cropped at the provided bounds.
-- opts is optional. You can provide `opts.showKey` to also render the map's key.
function module.displayMap(bounds, opts)
    local showKey = (opts or {}).showKey
    if showKey == nil then showKey = false end

    local world = _G.mockComputerCraftApi.world

    local map = world.map
    local view = {}

    local minY = bounds.minY
    if minY == nil then minY = -9999 end
    local maxY = bounds.maxY
    if maxY == nil then maxY = 9999 end

    local insertCellIntoViewIfAble = function(x, y, z, view, cell)
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

function module.displayCentered(opts)
    local world = _G.mockComputerCraftApi.world
    opts = opts or {}
    local coord = opts.coord or world.turtle.pos
    local width = opts.width or 20
    local height = opts.height or 8
    local minY = opts.minY -- may be nil
    local maxY = opts.maxY -- may be nil
    local showKey = opts.showKey -- may be nil

    module.displayMap({
        minX = coord.x - math.floor(width / 2),
        maxX = coord.x + math.ceil(width / 2),
        minY = minY,
        maxY = maxY,
        minZ = coord.z - math.floor(height / 2),
        maxZ = coord.z + math.ceil(height / 2),
    }, { showKey = showKey })
end

function module.displayLayers(bounds, opts)
    local world = _G.mockComputerCraftApi.world
    for i = bounds.maxY, bounds.minY, -1 do
        local boundsCopy = util.copyTable(bounds)
        boundsCopy.minY = i
        boundsCopy.maxY = i
        print('y='..i)
        module.displayMap(boundsCopy, opts)
    end
end

function module.inventory()
    local world = _G.mockComputerCraftApi.world

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

function module.turtlePosition()
    local world = _G.mockComputerCraftApi.world
    local turtlePos = world.turtle.pos
    print('Turtle pos: ('..turtlePos.x..','..turtlePos.y..','..turtlePos.z..') '..turtlePos.face)
end

function module.now()
    print('ticks: '..time.getTicks())
end

return module