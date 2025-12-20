--[[
    This module is in charge of managing persistent state.
]]

local util = import('util.lua')
local serializer = import('./_serializer.lua')
local space = import('./space.lua')

local module = {}

local stateInitializers = {}
local currentState = nil

-- You can call this directly if you plan on using act/ without the plan/ component.
-- Otherwise, prepare a plan, and the plan will call this for you.
function module.init(opts)
    local startingPos = opts.startingPos

    currentState = {
        -- Where the turtle is currently at.
        -- The contents of this table should not be mutated, as others may hold references to it,
        -- but it can be reassigned with a new position table.
        turtlePos = opts.startingPos,
    }

    for statePieceId, initializer in util.sortedMapTablePairs(stateInitializers) do
        currentState[statePieceId] = initializer()
    end
end

function module.initFromSerializedSnapshot(text)
    currentState = serializer.deserialize(text)
end

function module.createSerializeSnapshot()
    return serializer.serialize(currentState)
end

function module.getTurtlePos()
    return currentState.turtlePos
end

function module.setTurtlePos(turtlePos)
    currentState.turtlePos = turtlePos
end

function module.getTurtleCmps()
    return space.createCompass(currentState.turtlePos)
end

function module.__registerPieceOfState(statePieceId, initializer)
    local prototype = {}

    stateInitializers[statePieceId] = initializer

    function prototype:get()
        return currentState[statePieceId]
    end
    
    -- Same as get(). This should be used if you plan on mutating the return value.
    -- The function name reminds readers that the result is being mutated.
    function prototype:getAndModify()
        return currentState[statePieceId]
    end

    return util.attachPrototype(prototype, {})
end

return module