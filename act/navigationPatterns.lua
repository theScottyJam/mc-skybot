--[[
    High-level navigation tools, for building up complex movement patterns.
]]

local util = import('util.lua')
local commands = import('./_commands.lua')
local space = import('./space.lua')
local navigate = import('./navigate.lua')

local module = {}

-- Starting from a corner of a square (of size sideLength), touch every cell in it by following
-- a clockwise spiral to the center. You must start facing in a direction such that
-- no turning is required before movement.
-- The `onVisit` function is called at each cell visited.
function module.spiralInwards(commands, state, opts)
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
                onVisit(commands, state)
                commands.turtle.forward(state)
            end
            commands.turtle.turnRight(state)
        end
    end
    onVisit(commands, state)
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
function module.snake(commands, state, opts)
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
        inBounds(state.turtlePos),
        'The turtle is not inside of the provided bounding box.'
    )

    local firstCoord = { up = boundingBox.up }
    local verDelta
    local hozDelta
    -- if you're more forwards than backwards within the box
    if boundingBox.mostForward - state.turtlePos.forward < state.turtlePos.forward - boundingBox.leastForward then
        firstCoord.forward = boundingBox.mostForward
        verDelta = { forward = -1 }
    else
        firstCoord.forward = boundingBox.leastForward
        verDelta = { forward = 1 }
    end
    -- if you're more right than left within the box
    if boundingBox.mostRight - state.turtlePos.right < state.turtlePos.right - boundingBox.leastRight then
        firstCoord.right = boundingBox.mostRight
        hozDelta = { right = -1 }
    else
        firstCoord.right = boundingBox.leastRight
        hozDelta = { right = 1 }
    end

    local curCmps = space.createCompass(util.mergeTables(firstCoord, { face = 'forward' }))
    while inBounds(curCmps.coord) do
        if shouldVisit(curCmps.coord) then
            navigate.moveToCoord(commands, state, curCmps.coord)
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

function module.compilePlane(plane, opts)
    local referencePointCmps = opts.referencePointCmps -- Where the "," is located.

    local topLeftCmps
    for y, row in ipairs(plane) do
        for x, cell in util.stringPairs(row) do
            if cell == ',' then
                topLeftCmps = referencePointCmps.compassAt({ forward = y - 1, right = -(x - 1) })
            end
        end
    end
    local bottomRightCmps = topLeftCmps.compassAt({ forward = -(#plane - 1), right = #plane[1] - 1 })

    return {
        topLeftCmps = topLeftCmps,
        bottomRightCmps = bottomRightCmps,
        getCharAt = function(coord)
            local deltaCoord = topLeftCmps.distanceTo(coord)
            assert(deltaCoord.up == 0)
            local char = plane[-deltaCoord.forward + 1] and util.charAt(plane[-deltaCoord.forward + 1], deltaCoord.right + 1)
            assert(char ~= nil)
            return char
        end,
    }
end

return module
