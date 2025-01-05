--[[
    This module is in charge of managing persistent state.
    The state object is intended to be mutable - anyone with a reference can update it.
]]

local util = import('util.lua')
local space = import('./space.lua')
local Task = moduleLoader.lazyImport('./Task.lua')
local serializer = import('./_serializer.lua')
local time = import('./_time.lua')

local static = {}
local prototype = {}
serializer.registerValue('class-prototype:State', prototype)

function prototype:turtleCmps()
    return space.createCompass(self.turtlePos)
end

function static.newInitialState(opts)
    local startingPos = opts.startingPos
    local projectList = opts.projectList

    return util.attachPrototype(prototype, {
        -- Where the turtle is currently at.
        -- The contents of this table should not be mutated, as others may hold references to it,
        -- but it can be reassigned with a new position table.
        turtlePos = opts.startingPos,
        -- List of projects that still need to be tackled
        projectList = util.copyTable(projectList),
        -- The project currently being worked on, or that we're currently gathering resources for
        primaryTask = nil,
        -- A task, like a farm-tending task, that's interrupting the active one
        interruptTask = nil,
        -- A mapping that lets us know where resources can be found.
        resourceSuppliers = {},
        -- A list of info objects related to enabled farms that require occasional attention.
        activeFarms = {},
        -- A mapping of paths the turtle can travel to move from one location to the next.
        availablePaths = {},
        -- What time did this program start executing?
        initialTime = time.getRawTimestamp(),
    })
end

return static