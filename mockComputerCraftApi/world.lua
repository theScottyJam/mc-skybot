--[[
    The world object is a mutable object that anyone is allowed to tamper with.
--]]

local module = {}

function module.createDefault()
    local world = {
        turtle = {
            pos = { x=0, y=67, z=-3, face='N' },
            selectedSlot = 1, -- Selected inventory slot
            inventory = {},
            equipedLeft = nil,
            equipedRight = nil
        },
        map = createStartingMap()
    }
    return world
end

function createStartingMap()
    local map = {}

    local createLeaves = function() return { id = 'LEAVES' } end

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
                return { id = 'GRASS' }
            else
                return { id = 'DIRT' }
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

    map[ 0][64][-3] = { id = 'BEDROCK' } -- overriding previous dirt value
    map[ 4][67] = {}
    map[ 4][67][-3] = {
        id = 'CHEST',
        contents = {
            [1] = { id = 'LAVA_BUCKET' },
            [2] = { id = 'ICE' }
        }
    }

    map[-1][67] = {}
    map[-1][67][ 1] = { id = 'LOG' }
    map[-1][68] = {}
    map[-1][68][ 1] = { id = 'LOG' }
    map[-1][69] = {}
    map[-1][69][ 1] = { id = 'LOG' }

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
        map[-1][y][ 1] = { id = 'LOG' }
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
    map[-1][72][ 1] = { id = 'LOG' }
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

return module