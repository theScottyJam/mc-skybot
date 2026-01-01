local util = import('util.lua')
local serializer = import('../_serializer.lua')
local PositionModule = moduleLoader.lazyImport('./Position.lua')

local static = {}
local prototype = {}
-- You're only allowed to serialize absolute coordinates.
serializer.registerValue('class-prototype:Coord', prototype)

local absoluteCoordinatePlaneId = 'absolute'

function prototype:at(opts)
    return static._new({
        forward = self.forward + (opts.forward or 0),
        right = self.right + (opts.right or 0),
        up = self.up + (opts.up or 0),
        coordSystemId = self._coordSystemId,
    })
end

function prototype:face(facing)
    local Position = PositionModule.load()
    return Position.new({
        coord = self,
        facing = facing,
    })
end

function prototype:isCompatible(coord)
    return self._coordSystemId == coord._coordSystemId
end

function prototype:assertCompatible(coord)
    util.assert(
        self._coordSystemId == coord._coordSystemId,
        'The coordinates are from incompatible coordinate planes. Left:'..self._coordSystemId..' Right:'..coord._coordSystemId
    )
end

function prototype:assertAbsolute()
    util.assert(
        self._coordSystemId == absoluteCoordinatePlaneId,
        'The coordinate is not absolute. Coordinate system id:'..self._coordSystemId
    )
end

function prototype:origin()
    return static._new({ coordSystemId = self._coordSystemId })
end

-- "looseEquals" will return `false` if the coordinates are from different coordinate planes,
-- while the regular "equals" function will throw an error.
function prototype:looseEquals(otherCoord)
    return (
        self.forward == otherCoord.forward and
        self.right == otherCoord.right and
        self.up == otherCoord.up and
        self._coordSystemId == otherCoord._coordSystemId
    )
end

function prototype:equals(otherCoord)
    self:assertCompatible(otherCoord)
    return self:looseEquals(otherCoord)
end

function prototype:toXYZCoord()
    return {
        x = self.right,
        y = self.up,
        z = -self.forward,
    }
end

-- Rotates the coordData table around the anchor coordinate, `count` times.
-- coordData is a table containing "forward" and "right" fields.
local rotateClockwise = function(coordData, anchor, count)
    while count > 3 do
        count = count - 4
    end

    for i = 0, count - 1 do -- -1 because Lua's loops are inclusive.
        local forwardFromAnchor = coordData.forward - anchor.forward
        local rightFromAnchor = coordData.right - anchor.right

        coordData = {
            forward = coordData.forward - forwardFromAnchor - rightFromAnchor,
            right = coordData.right - rightFromAnchor + forwardFromAnchor,
        }        
    end

    return coordData
end

-- Translates the coordinate into the bridged coordinate system
function prototype:convertIn(bridge)
    self:assertCompatible(bridge.outCoord)
    
    local coordData = rotateClockwise({
        forward = self.forward + bridge.delta.forward,
        right = self.right + bridge.delta.right,
    }, bridge.inCoord, bridge.delta.clockwiseTurns)

    return static._new({
        forward = coordData.forward,
        right = coordData.right,
        up = self.up + bridge.delta.up,
        coordSystemId = bridge.inCoord._coordSystemId,
    })
end

-- Translates the coordinate out of the bridged coordinate system
function prototype:convertOut(bridge)
    self:assertCompatible(bridge.inCoord)

    local coordData = rotateClockwise({
        forward = self.forward,
        right = self.right,
    }, bridge.inCoord, 4 - bridge.delta.clockwiseTurns)

    return static._new({
        forward = coordData.forward - bridge.delta.forward,
        right = coordData.right - bridge.delta.right,
        up = self.up - bridge.delta.up,
        coordSystemId = bridge.outCoord._coordSystemId,
    })
end

local nextId = 0
function static.newCoordSystem(name)
    local coordSystemId = name .. ':' .. nextId
    nextId = nextId + 1
    return {
        origin = static._new({ coordSystemId = coordSystemId })
    }
end

-- All fields are optional
function static.absolute(opts)
    return static._new({
        forward = opts.forward,
        right = opts.right,
        up = opts.up,
    })
end

function static._new(fields)
    fields = fields or {}
    local coordSystemId = fields.coordSystemId or absoluteCoordinatePlaneId

    local forbidSerialization = nil
    if coordSystemId ~= absoluteCoordinatePlaneId then
        forbidSerialization = true
    end

    return util.attachPrototype(prototype, {
        forward = fields.forward or 0,
        right = fields.right or 0,
        up = fields.up or 0,
        _coordSystemId = coordSystemId,
        -- Set to true when the coordinate is not absolute to instruct the serializer to throw an error
        -- if an attempt is made to serialize a non-absolute coordinate.
        -- This is done because there's no deterministic way to restore the coordinate system id correctly
        -- (whatever id was generated in one execution of the program likely won't match another).
        __forbidSerialization = forbidSerialization,
    })
end

return static
