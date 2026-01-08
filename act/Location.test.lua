-- Mostly focused on testing route costs, which if calculated
-- incorrectly would cause difficult-to-notice bugs.

local Coord = import('./space/Coord.lua')
local Location = import('./Location.lua')

testFramework.testGroup('Location')

local initialize = function()
    Location.__reset()
end

test('It can calculate the units of work between two locations', function()
    initialize()

    -- The path to travel is:
    -- Turtle starts facing right (total work=0)
    local loc1 = Location.register(Coord.absolute({ forward = 1, right = 1, up = 1 }):face('right'))
    -- Turtle turns right once to face backward (+1, total work = 1)
    -- Turtle moves straight twice to reach forward=-1 (+2*1.5, total work = 4)
    -- (Note that the turtle won't turn to face left, even though that's the direction this location faces - it
    -- doesn't need to face the direction of the location when the location is in the middle of the travel)
    local loc2 = Location.register(Coord.absolute({ forward = -1, right = 1, up = 1 }):face('left'))
    -- Turtle turns left to face right (+1, total work = 5)
    -- Turtle moves straight 4 (+4*1.5, total work = 11)
    -- Turtle moves up 1 (+1*1.5, total work = 12.5)
    -- Turtle turns left to face forward, the end location's direction (+1, total work = 13.5)
    local loc3 = Location.register(Coord.absolute({ forward = -1, right = 5, up = 2 }):face('forward'))
    Location.addPath(loc1, loc2)
    Location.addPath(loc2, loc3)

    assert.equal(Location.workToMove(loc1, loc3), 13.5)
end)

-- There's some special handling in the code for this scenario - where a given path between neighboring locations
-- won't record what facing is expected since any facing will work.
test('It can calculate the units of work between two locations where some locations only require rotations', function()
    initialize()

    -- The math should come out the same as the earlier test - the first and last facing are the same and the middle coordinates are the same,
    -- there's just more locations with different facings registered.
    local loc1 = Location.register(Coord.absolute({ forward = 1, right = 1, up = 1 }):face('right'))
    local loc1b = Location.register(Coord.absolute({ forward = 1, right = 1, up = 1 }):face('forward'))
    local loc2 = Location.register(Coord.absolute({ forward = -1, right = 1, up = 1 }):face('left'))
    local loc2b = Location.register(Coord.absolute({ forward = -1, right = 1, up = 1 }):face('backward'))
    local loc3 = Location.register(Coord.absolute({ forward = -1, right = 5, up = 2 }):face('left'))
    local loc3b = Location.register(Coord.absolute({ forward = -1, right = 5, up = 2 }):face('forward'))
    Location.addPath(loc1, loc1b)
    Location.addPath(loc1b, loc2)
    Location.addPath(loc2, loc2b)
    Location.addPath(loc2b, loc3)
    Location.addPath(loc3, loc3b)

    assert.equal(Location.workToMove(loc1, loc3b), 13.5)
end)

test('It can handle a path that only requires rotations', function()
    initialize()

    local loc1 = Location.register(Coord.absolute():face('right'))
    local loc2 = Location.register(Coord.absolute():face('forward'))
    Location.addPath(loc1, loc2)

    assert.equal(Location.workToMove(loc1, loc2), 1)
end)

test('It handles a path with multiple in-between coordinates', function()
    initialize()

    local loc1 = Location.register(Coord.absolute({ forward = 1, right = 1, up = 1 }):face('right'))
    local loc2 = Location.register(Coord.absolute({ forward = -1, right = 5, up = 2 }):face('forward'))
    Location.addPath(loc1, loc2, {
        -- Rotate right, facing backward, +1 total=1
        -- Move straight 2, +2*1.5 total=4
        Coord.absolute({ forward = -1, right = 1, up = 1 }),
        -- Rotate right, facing left, +1 total=5
        -- Move straight 1, +1*1.5 total=6.5
        Coord.absolute({ forward = -1, right = 0, up = 1 }),
        -- Move up 1, +1.5 total=8
        Coord.absolute({ forward = -1, right = 0, up = 2 }),
        -- Turn around, +2 total=10
        -- Move straight 5, +5*1.5 total=17.5
        -- Turn left, +1 total=18.5
    })

    assert.equal(Location.workToMove(loc1, loc2), 18.5)
end)

test('It takes the shortest path', function()
    initialize()

    local loc1 = Location.register(Coord.absolute({ forward = 0, right = 0, up = 0 }):face('forward'))
    local loc2a = Location.register(Coord.absolute({ forward = 5, right = 0, up = 0 }):face('forward'))
    local loc2b = Location.register(Coord.absolute({ forward = 5, right = 5, up = 0 }):face('forward'))
    local loc3 = Location.register(Coord.absolute({ forward = 10, right = 0, up = 0 }):face('forward'))
    Location.addPath(loc1, loc2a)
    Location.addPath(loc1, loc2b)
    Location.addPath(loc2a, loc3)
    Location.addPath(loc2b, loc3)

    -- It should move forward in a straight line, 10 movements. 10*1.5=15.
    assert.equal(Location.workToMove(loc1, loc3), 15)

    -- Going to also test moving backwards. +4 because we have to rotate backwards before we start moving, and rotate forwards at the end.
    assert.equal(Location.workToMove(loc3, loc1), 19)
end)
