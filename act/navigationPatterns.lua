--[[
    High-level navigation tools, for building up complex movement patterns.
]]

local util = import('util.lua')
local commands = import('./commands.lua')
local space = import('./space.lua')
local navigate = import('./navigate.lua')
local state = import('./state.lua')

local module = {}

-- Starting from a corner of a square (of size sideLength), touch every cell in it by following
-- a clockwise spiral to the center. You must start facing in a direction such that
-- no turning is required before movement.
-- The `onVisit` function is called at each cell visited.
function module.spiralInwards(opts)
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
                onVisit()
                commands.turtle.forward()
            end
            commands.turtle.turnRight()
        end
    end
    onVisit()
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
function module.snake(opts)
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
        inBounds(state.getTurtlePos()),
        'The turtle is not inside of the provided bounding box.'
    )

    local firstCoord = { up = boundingBox.up }
    local verDelta
    local hozDelta
    -- if you're more forwards than backwards within the box
    if boundingBox.mostForward - state.getTurtlePos().forward < state.getTurtlePos().forward - boundingBox.leastForward then
        firstCoord.forward = boundingBox.mostForward
        verDelta = { forward = -1 }
    else
        firstCoord.forward = boundingBox.leastForward
        verDelta = { forward = 1 }
    end
    -- if you're more right than left within the box
    if boundingBox.mostRight - state.getTurtlePos().right < state.getTurtlePos().right - boundingBox.leastRight then
        firstCoord.right = boundingBox.mostRight
        hozDelta = { right = -1 }
    else
        firstCoord.right = boundingBox.leastRight
        hozDelta = { right = 1 }
    end

    local curCmps = space.createCompass(util.mergeTables(firstCoord, { face = 'forward' }))
    while inBounds(curCmps.coord) do
        if shouldVisit(curCmps.coord) then
            navigate.moveToCoord(curCmps.coord)
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

local planePrototype = {}

function planePrototype:getTopLeftCmps()
    return self._topLeftCmps
end

function planePrototype:getBottomRightCmps()
    return self._topLeftCmps.compassAt({
        forward = -(#self._plane - 1),
        right = #self._plane[1] - 1,
    })
end

function planePrototype:_getSize()
    return {
        width = #self._plane[1],
        height = #self._plane,
    }
end

function planePrototype:getCmpsAtMarker(markerId)
    local relCoordFromTopLeft = self._markerIdToMetadata[markerId].relCoordFromTopLeft
    return self._topLeftCmps.compassAt({
        forward = -relCoordFromTopLeft.y,
        right = relCoordFromTopLeft.x,
    })
end

function planePrototype:cmpsListFromMarkerSet(markerSetId)
    local metadataList = self._markerSetIdToMetadataList[markerSetId]
    return util.mapArrayTable(metadataList, function(metadata)
        local relCoordFromTopLeft = metadata.relCoordFromTopLeft
        return self._topLeftCmps.compassAt({
            forward = -relCoordFromTopLeft.y,
            right = relCoordFromTopLeft.x,
        })
    end)
end

-- Returns a table containing left/forward/right/backward fields, saying how many steps
-- you have to move to reach (and not cross) a boundary.
-- For example, A 1x1 grid containing the marker would have all values set to 0.
function planePrototype:getBoundsAtMarker(markerId)
    local relCoordFromTopLeft = self._markerIdToMetadata[markerId].relCoordFromTopLeft
    local dimensions = self:_getSize()

    return {
        left = relCoordFromTopLeft.x,
        forward = relCoordFromTopLeft.y,
        right = dimensions.width - relCoordFromTopLeft.x - 1,
        backward = dimensions.height - relCoordFromTopLeft.y - 1,
    }
end

function planePrototype:getCharAt(coord)
    local deltaCoord = self._topLeftCmps.distanceTo(coord)
    assert(deltaCoord.up == 0)
    local char = self._plane[-deltaCoord.forward + 1] and util.charAt(self._plane[-deltaCoord.forward + 1], deltaCoord.right + 1)
    assert(char ~= nil)
    return char
end

function planePrototype:anchorMarker(markerId, coord)
    return util.attachPrototype(planePrototype, util.mergeTables(
        self,
        {
            _topLeftCmps = space.createCompass({
                forward = coord.forward - self._markerIdToMetadata[markerId].relCoordFromTopLeft.y,
                right = coord.right - self._markerIdToMetadata[markerId].relCoordFromTopLeft.x,
                up = coord.up,
                face = 'forward',
            }),
        }
    ))
end

function planePrototype:anchorTopLeft(coord)
    return util.attachPrototype(planePrototype, util.mergeTables(
        self,
        {
            _topLeftCmps = space.createCompass({
                forward = coord.forward,
                right = coord.right,
                up = coord.up,
                face = 'forward',
            }),
        }
    ))
end

--[[
Inputs:
    plane: A list of strings containing a 2d map of tiles and markers.
    markers?: This is used to mark interesting areas in the plane.
        A mapping is expected which maps marker names to info tables with the shape of:
            { char = <char>, targetOffset ?= <x/y coord> }

    markerSets?: Similar to markers, but lets you mark zero or more spots with the same character.
        A mapping is expected which maps marker names to info tables with the shape of:
            { char = <char> }
]]
function module.compilePlane(opts)
    local plane = opts.plane
    local markerConfs = opts.markers or {}
    local markerSetConfs = opts.markerSets or {}

    -- The plane must contain something
    util.assert(#plane > 0)
    util.assert(#plane[1] > 0)

    local charToIntermediateMarkerData = {} -- Intermediate mapping to help us populate markerIdToMetadata and markerSetIdToMetadataList
    local markerIdToMetadata = {}
    local markerSetIdToMetadataList = {}
    for markerId, markerConf in util.sortedMapTablePairs(markerConfs or {}) do
        charToIntermediateMarkerData[markerConf.char] = { type = 'marker', id = markerId, conf = markerConf }
    end
    for markerSetId, markerSetConf in util.sortedMapTablePairs(markerSetConfs or {}) do
        charToIntermediateMarkerData[markerSetConf.char] = { type = 'markerSet', id = markerSetId, conf = markerSetConf }
        markerSetIdToMetadataList[markerSetId] = {}
    end

    for y, row in ipairs(plane) do
        util.assert(#row == #plane[1], 'All rows must be of the same length')
        for x, cell in util.stringPairs(row) do
            local intermediateMarkerData = charToIntermediateMarkerData[cell]
            if intermediateMarkerData ~= nil and intermediateMarkerData.type == 'marker' then
                local markerId = intermediateMarkerData.id
                local markerConf = intermediateMarkerData.conf
                util.assert(markerIdToMetadata[markerId] == nil, 'Marker "'..markerConf.char..'" was found multiple times')

                local targetOffset = markerConf.targetOffset or {}
                markerIdToMetadata[markerId] = {
                    relCoordFromTopLeft = {
                        x = x - 1 + (targetOffset.x or 0),
                        y = y - 1 + (targetOffset.y or 0),
                    }
                }
            elseif intermediateMarkerData ~= nil and intermediateMarkerData.type == 'markerSet' then
                local markerId = intermediateMarkerData.id
                local markerConf = intermediateMarkerData.conf
                util.assert(markerConf.targetOffset == nil, 'targetOffset is currently not supported with marker sets')
                table.insert(markerSetIdToMetadataList[markerId], {
                    relCoordFromTopLeft = {
                        x = x - 1,
                        y = y - 1,
                    }
                })
            end
        end
    end

    for markerId, markerConf in util.sortedMapTablePairs(markerConfs) do
        util.assert(markerIdToMetadata[markerId] ~= nil, 'Marker "'..markerConf.char..'" was not found')
    end

    return util.attachPrototype(planePrototype, {
        _plane = plane,
        _markerIdToMetadata = markerIdToMetadata,
        _markerSetIdToMetadataList = markerSetIdToMetadataList,
        -- The top-left corner is, by default, set to (0,0,0). To change it, call an anchor function.
        _topLeftCmps = space.createCompass({
            forward = 0,
            right = 0,
            up = 0,
            face = 'forward',
        })
    })
end

return module
