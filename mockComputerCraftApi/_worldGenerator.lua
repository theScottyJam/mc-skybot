--[[
    The world object is a mutable object that anyone is allowed to tamper with.
--]]

local module = {}

local createStartingMap = function()
    local map = {}

    local createLeaves = function() return { id = 'minecraft:leaves' } end

    map[-3] = {}
    map[-2] = {}
    map[-1] = {}
    map[ 0] = {}
    map[ 1] = {}
    map[ 2] = {}
    map[ 3] = {}
    map[ 4] = {}

    -- Creating land mass
    for y = 64, 66 do
        local createGround = function()
            if y == 66 then
                return { id = 'minecraft:grass' }
            else
                return { id = 'minecraft:dirt' }
            end
        end
        map[-1][y] = {}
        map[-1][y][-4] = createGround()
        map[-1][y][-3] = createGround()
        map[-1][y][-2] = createGround()
        map[-1][y][-1] = createGround()
        map[-1][y][ 0] = createGround()
        map[-1][y][ 1] = createGround()
        map[ 0][y] = {}
        map[ 0][y][-4] = createGround()
        map[ 0][y][-3] = createGround() -- This is bedrock on the first layer
        map[ 0][y][-2] = createGround()
        map[ 0][y][-1] = createGround()
        map[ 0][y][ 0] = createGround()
        map[ 0][y][ 1] = createGround()
        map[ 1][y] = {}
        map[ 1][y][-4] = createGround()
        map[ 1][y][-3] = createGround()
        map[ 1][y][-2] = createGround()
        map[ 1][y][-1] = createGround()
        map[ 1][y][ 0] = createGround()
        map[ 1][y][ 1] = createGround()
        map[ 2][y] = {}
        map[ 2][y][-4] = createGround()
        map[ 2][y][-3] = createGround()
        map[ 2][y][-2] = createGround()
        map[ 3][y] = {}
        map[ 3][y][-4] = createGround()
        map[ 3][y][-3] = createGround()
        map[ 3][y][-2] = createGround()
        map[ 4][y] = {}
        map[ 4][y][-4] = createGround()
        map[ 4][y][-3] = createGround()
        map[ 4][y][-2] = createGround()
    end

    map[ 0][64][-3] = { id = 'minecraft:bedrock' } -- overriding previous dirt value
    map[ 4][67] = {}
    map[ 4][67][-3] = {
        id = 'minecraft:chest',
        contents = {
            size = 9 * 3,
            slots = {
                [1] = { id = 'minecraft:lava_bucket', quantity = 1 },
                [2] = { id = 'minecraft:ice', quantity = 1 }
            }
        }
    }
    map[ 3][67] = {}
    map[ 3][67][-4] = { id = 'computercraft:disk_drive' } -- Not sure what the real ID for this is.

    map[-1][67] = {}
    map[-1][67][ 1] = { id = 'minecraft:log' }
    map[-1][68] = {}
    map[-1][68][ 1] = { id = 'minecraft:log' }
    map[-1][69] = {}
    map[-1][69][ 1] = { id = 'minecraft:log' }

    -- Creating 5x5 block of leaves with logs down the center
    for y = 70, 71 do
        map[-3][y] = {}
        map[-3][y][-1] = createLeaves()
        map[-3][y][ 0] = createLeaves()
        map[-3][y][ 1] = createLeaves()
        map[-3][y][ 2] = createLeaves()
        map[-3][y][ 3] = createLeaves()
        map[-2][y] = {}
        map[-2][y][-1] = createLeaves()
        map[-2][y][ 0] = createLeaves()
        map[-2][y][ 1] = createLeaves()
        map[-2][y][ 2] = createLeaves()
        map[-2][y][ 3] = createLeaves()
        map[-1][y] = {}
        map[-1][y][-1] = createLeaves()
        map[-1][y][ 0] = createLeaves()
        map[-1][y][ 1] = { id = 'minecraft:log' }
        map[-1][y][ 2] = createLeaves()
        map[-1][y][ 3] = createLeaves()
        map[ 0][y] = {}
        map[ 0][y][-1] = createLeaves()
        map[ 0][y][ 0] = createLeaves()
        map[ 0][y][ 1] = createLeaves()
        map[ 0][y][ 2] = createLeaves()
        map[ 0][y][ 3] = createLeaves()
        map[ 1][y] = {}
        map[ 1][y][-1] = createLeaves()
        map[ 1][y][ 0] = createLeaves()
        map[ 1][y][ 1] = createLeaves()
        map[ 1][y][ 2] = createLeaves()
        map[ 1][y][ 3] = createLeaves()
    end

    -- Removing some leaves from corner of 5x5 block
    map[-3][70][-1] = nil
    map[-3][70][ 3] = nil
    map[-3][71][ 3] = nil
    map[ 1][70][-1] = nil
    map[ 1][71][-1] = nil
    map[ 1][70][ 3] = nil

    -- Creating plus sign shape
    map[-2][72] = {}
    map[-2][72][ 1] = createLeaves()
    map[-1][72] = {}
    map[-1][72][ 0] = createLeaves()
    map[-1][72][ 1] = { id = 'minecraft:log' }
    map[-1][72][ 2] = createLeaves()
    map[ 0][72] = {}
    map[ 0][72][ 1] = createLeaves()
    map[ 0][72][ 0] = createLeaves() -- extra leaf in the corner

    -- plus sign layer 2
    map[-2][73] = {}
    map[-2][73][ 1] = createLeaves()
    map[-1][73] = {}
    map[-1][73][ 0] = createLeaves()
    map[-1][73][ 1] = createLeaves()
    map[-1][73][ 2] = createLeaves()
    map[ 0][73] = {}
    map[ 0][73][ 1] = createLeaves()

    return map
end

function module.createWorld()
    return {
        turtle = {
            pos = { x=3, y=67, z=-3, face='W' },
            selectedSlot = 1, -- Selected inventory slot
            inventory = {
                [2] = { id = 'minecraft:crafting_table', quantity = 1 },
            },
            equippedLeft = nil,
            equippedRight = { id = 'minecraft:diamond_pickaxe', quantity = 1 },
        },
        map = createStartingMap()
    }
end

return module