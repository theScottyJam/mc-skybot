--[[
    This module is in charge of managing persistent state.
    The state object is intended to be mutable - anyone with a reference can update it.
]]

local util = import('util.lua')
local space = import('./space.lua')
local serializer = import('./_serializer.lua')

local static = {}
local prototype = {}
serializer.registerValue('class-prototype:State', prototype)

local stateInitializers = {}

function prototype:turtleCmps()
    return space.createCompass(self.turtlePos)
end

function prototype:get(moduleState)
    return self[moduleState._key]
end

-- Same as get(). This should be used if you plan on mutating the return value.
-- The function name reminds readers that the result is being mutated.
function prototype:getAndModify(moduleState)
    return self[moduleState._key]
end

function static.newInitialState(opts)
    local startingPos = opts.startingPos
    local projectList = opts.projectList

    local state = util.attachPrototype(prototype, {
        -- Where the turtle is currently at.
        -- The contents of this table should not be mutated, as others may hold references to it,
        -- but it can be reassigned with a new position table.
        turtlePos = opts.startingPos,
        -- A mapping that lets us know where resources can be found.
        resourceSuppliers = {},
        -- A list of info objects related to enabled farms that require occasional attention.
        activeFarms = {},
    })

    for key, initializer in util.sortedMapTablePairs(stateInitializers) do
        state[key] = initializer({ projectList = projectList })
    end

    return state
end

function static.__isInstance(self)
    return util.hasPrototype(self, prototype)
end

function static.registerModuleState(moduleId, initializer)
    local moduleKey = '_'..moduleId

    stateInitializers[moduleKey] = initializer
    return { _key = moduleKey }
end

return static