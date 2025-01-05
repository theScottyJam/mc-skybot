-- This module returns a number of functions that the rest of the project will look for and call at specific times.
-- This module will also register various globals to make it easier to debug the project from anywhere.

local util = import('util.lua')
local actModule = moduleLoader.lazyImport('act/init.lua')

local act = function()
    return actModule.load()
end

-- A shorthand to get worldTool functions, which allows you to, e.g., spawn items
-- into the turtle's inventory.
local worldTools = function()
    return _G.mockComputerCraftApi.worldTools
end

local module = {}

-- Set this to true to cause the program to pause after each sprint, shut itself mostly down,
-- then bring itself back up and unpause. This helps test the pause/unpause feature,
-- but it may make it run slower.
module.pauseUnpauseAfterEachSprint = true

-- Methods will be attached in addition to the properties defined immediately below.
local debugGlobal = {
    -- Shows the current step we're on
    step = 0,
    -- Set this to true to start displaying each step
    showStepByStep = false,
}

local busySleep = function(seconds)
    -- The os module gets overwritten to act more like computerCraft's version of `os`.
    -- The original os module is still needed to count real time passing, if it's available.
    -- (When mocking, the original is backed-up to _G.originalOs)
    local osModule = _G.originalOs or _G.os
    local sec = tonumber(osModule.clock() + seconds);
    while (osModule.clock() < sec) do 
    end
end

local idling = false
local lastIdleStartAt = nil
local lastIdleEndAt = nil

-- Called with `true` when the turtle doesn't have anything in particular to do,
-- This happens when the only remaining dependencies for a project are those that require waiting.
-- This may be called multiple times with the same value.
function module.isIdling(idling_)
    if not idling and idling_ then
        lastIdleStartAt = debugGlobal.step
    end
    if idling and not idling_ then
        lastIdleEndAt = debugGlobal.step
    end
    idling = idling_
end

-- Called after imports have happened and the main code is about to start running
function module.onStart()
    -- Only show debug info if we're in the mock environment.
    if _G.mockComputerCraftApi == nil then
        return
    end

    -- Printing this to make it easy to visually see how performant the code is.
    -- i.e. you can see how long it takes between the time it starts running and
    -- the time it finishes, excluding module-load time.
    print('Starting')
end

-- Called after each action the turtle takes
function module.onStep(state)
    -- Only show debug info if we're in the mock environment.
    if _G.mockComputerCraftApi == nil then
        return
    end

    local SLEEP_TIME = 0.05
    debugGlobal.step = debugGlobal.step + 1
    if debugGlobal.showStepByStep then
        if idling then return end
        if lastIdleEndAt == step - 1 then
            local skipCount = lastIdleEndAt - lastIdleStartAt
            print('Idled for '..skipCount..' steps (skipping '..(skipCount * SLEEP_TIME)..' secs)')
            busySleep(2)
        end

        -- _G.mockComputerCraftApi.present.displayMap({ minX = -8, maxX = 5, minY = 0, maxY = 999, minZ = -5, maxZ = 5 }, { showKey = false })
        _G.mockComputerCraftApi.present.displayCentered({ width = 20, height = 12 })
        print('step: '..step)
        -- _G.mockComputerCraftApi.present.taskNames(state)
        -- _G.mockComputerCraftApi.present.inventory()
        _G.mockComputerCraftApi.present.turtlePosition()

        busySleep(SLEEP_TIME)
    end
end

-- Called when the turtle has finished
function module.showFinalState(finalPlan)
    -- Only show debug info if we're in the mock environment.
    if _G.mockComputerCraftApi == nil then
        return
    end

    mockComputerCraftApi.present.displayMap({ minX = -18, maxX = 18, minY = 0, maxY = 79, minZ = -15, maxZ = 3 }, { showKey = false })
    mockComputerCraftApi.present.turtlePosition()
    mockComputerCraftApi.present.now()
    mockComputerCraftApi.present.inventory()
    -- print(finalPlan:serialize())
end

-- A special project you can register in your project list to let you run arbitrary code at a specific point in time.
function module.debugProject(homeLoc)
    local location = act().location
    local navigate = act().navigate
    local highLevelCommands = act().highLevelCommands

    return act().Project.register({
        id = 'inspect:debugProject',
        enter = function(commands, state, taskState)
            -- homeLoc:travelHere(commands, state)
        end,
        nextSprint = function(commands, state, taskState)
            -- local startPos = state.turtlePos
            -- local currentWorld = _G.mockComputerCraftApi.world
            -- worldTools().addToInventory('minecraft:charcoal', 64)
            debugGlobal.showStepByStep = true

            -- navigate.moveToPos(commands, state, startPos)
            return taskState, true
        end,
    })
end

function debugGlobal.printTable(table)
    if util.tableSize(table) == 0 then print('{}'); return end
    print('{')
    for k, v in pairs(table) do
        print('  ' .. tostring(k) .. ' = ' .. tostring(v))
    end
    print('}')
end

function module.registerGlobals()
    _G._debug = debugGlobal
end

return module
