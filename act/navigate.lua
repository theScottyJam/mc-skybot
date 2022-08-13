--[[
    Utilities that revolve around navigating 3d space.
    For traveling to a location, see location.lua.
--]]

local util = import('util.lua')

local module = {}

function module.assertFace(shortTermPlaner, expectedFace)
    local currentFace = shortTermPlaner.turtlePos.face
    if currentFace ~= expectedFace then
        error('Expected current face '..currentFace..' to be expected face '..expectedFace)
    end
end

function module.assertCoord(shortTermPlaner, expectedCoord)
    local currentCoord = module.posToCoord(shortTermPlaner.turtlePos)
    currentCoordStr = '('..currentCoord.x..','..currentCoord.y..','..currentCoord.z..')'
    expectedCoordStr = '('..expectedCoord.x..','..expectedCoord.y..','..expectedCoord.z..')'
    if currentCoordStr ~= expectedCoordStr then
        error('Expected current coord '..currentCoordStr..' to be expected coord '..expectedCoordStr)
    end
end

function module.assertPos(shortTermPlaner, expectedPos)
    local currentCoord = shortTermPlaner.turtlePos
    currentPosStr = '('..currentPos.x..','..currentPos.y..','..currentPos.z..','..currentPos.face..')'
    expectedPosStr = '('..expectedPos.x..','..expectedPos.y..','..expectedPos.z..','..expectedPos.face..')'
    if currentPosStr ~= expectedPosStr then
        error('Expected current pos '..currentPosStr..' to be expected pos '..expectedPosStr)
    end
end

-- deltaCoord is a coordinate containing movement instructions.
-- (e.g. move along x by -2)
-- x, y, and z are optional in deltaCoord.
-- dimensionOrder is optional, and indicates which dimensions to travel first. e.g. {'x', 'y'}.
-- It defaults to { 'x', 'z', 'y' }. Dimensions can be omited to prevent movement in that direction.
function module.move(shortTermPlaner, deltaCoord, dimensionOrder)
    local space = _G.act.space

    local destinationCoord = space.resolveRelCoord(deltaCoord, shortTermPlaner.turtlePos)
    module.moveTo(shortTermPlaner, destinationCoord, dimensionOrder)
end

-- x, y, z, and face are all optional in destinationPos,
-- and will default to not moving the turtle in those dimensions, or caring about where it ends up facing.
-- dimensionOrder is optional, and indicates which dimensions to travel first. e.g. {'x', 'y'}.
-- It defaults to { 'x', 'z', 'y' }. Dimensions can be omited to prevent movement in that direction.
function module.moveTo(shortTermPlaner, destinationPos_, dimensionOrder)
    local commands = _G.act.commands
    local space = _G.act.space
    local dimensionOrder = dimensionOrder or { 'x', 'z', 'y' }

    local destinationCoord = util.mergeTables(space.posToCoord(shortTermPlaner.turtlePos), destinationPos_)
    local destinationFace = destinationPos_.face or nil

    for _, dimension in ipairs(dimensionOrder) do
        while dimension == 'y' and shortTermPlaner.turtlePos.y < destinationCoord.y do
            commands.turtle.up(shortTermPlaner)
        end
        while dimension == 'y' and shortTermPlaner.turtlePos.y > destinationCoord.y do
            commands.turtle.down(shortTermPlaner)
        end
        while dimension == 'z' and shortTermPlaner.turtlePos.z < destinationCoord.z do
            module.face(shortTermPlaner, 'S')
            commands.turtle.forward(shortTermPlaner)
        end
        while dimension == 'z' and shortTermPlaner.turtlePos.z > destinationCoord.z do
            module.face(shortTermPlaner, 'N')
            commands.turtle.forward(shortTermPlaner)
        end
        while dimension == 'x' and shortTermPlaner.turtlePos.x < destinationCoord.x do
            module.face(shortTermPlaner, 'E')
            commands.turtle.forward(shortTermPlaner)
        end
        while dimension == 'x' and shortTermPlaner.turtlePos.x > destinationCoord.x do
            module.face(shortTermPlaner, 'W')
            commands.turtle.forward(shortTermPlaner)
        end
    end

    if destinationFace ~= nil then
        module.face(shortTermPlaner, destinationFace)
    end
end

-- targetFace should be a face direction (N/E/S/W)
function module.face(shortTermPlaner, targetFace)
    local beforeFace = shortTermPlaner.turtlePos.face

    commands = ({
        N = {N={}, E={'R'}, S={'R','R'}, W={'L'}},
        E = {E={}, S={'R'}, W={'R','R'}, N={'L'}},
        S = {S={}, W={'R'}, N={'R','R'}, E={'L'}},
        W = {W={}, N={'R'}, E={'R','R'}, S={'L'}},
    })[beforeFace][targetFace]

    for _, command in ipairs(commands) do
        if command == 'R' then _G.act.commands.turtle.turnRight(shortTermPlaner) end
        if command == 'L' then _G.act.commands.turtle.turnLeft(shortTermPlaner) end
    end
end

return module