local Coord = import('./Coord.lua')
local util = import('util.lua')

local static = {}
local prototype = {}

function prototype:contains(coord)
    self.origin:assertCompatible(coord)
    return (
        coord.forward >= self.leastForward and
        coord.forward <= self.mostForward and
        coord.right >= self.leastRight and
        coord.right <= self.mostRight and
        coord.up >= self.leastUp and
        coord.up <= self.mostUp
    )
end

function prototype:convertIn(bridge)
    return static.new(
        self.origin:at({
            forward = self.leastForward,
            right = self.leastRight,
            up = self.leastUp,
        }):convertIn(bridge),
        self.origin:at({
            forward = self.mostForward,
            right = self.mostRight,
            up = self.mostUp,
        }):convertIn(bridge)
    )
end

function prototype:convertOut(bridge)
    return static.new(
        self.origin:at({
            forward = self.leastForward,
            right = self.leastRight,
            up = self.leastUp,
        }):convertOut(bridge),
        self.origin:at({
            forward = self.mostForward,
            right = self.mostRight,
            up = self.mostUp,
        }):convertOut(bridge)
    )
end

function static.new(coord1, coord2)
    coord1:assertCompatible(coord2)

    local fields = {
        origin = coord1:origin(),
        -- All inclusive
        mostForward = util.maxNumber(coord1.forward, coord2.forward),
        leastForward = util.minNumber(coord1.forward, coord2.forward),
        mostRight = util.maxNumber(coord1.right, coord2.right),
        leastRight = util.minNumber(coord1.right, coord2.right),
        mostUp = util.maxNumber(coord1.up, coord2.up),
        leastUp = util.minNumber(coord1.up, coord2.up),
    }
    fields.width = fields.mostRight - fields.leastRight + 1
    fields.depth = fields.mostForward - fields.leastForward + 1
    fields.height = fields.mostUp - fields.leastUp + 1

    return util.attachPrototype(prototype, fields)
end

return static
