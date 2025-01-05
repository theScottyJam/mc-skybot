local util = import('util.lua')
local inspect = moduleLoader.tryImport('inspect.lua')
local State = import('./_State.lua')
local commands = import('./_commands.lua')
local Farm = import('./Farm.lua')
local highLevelCommands = import('./highLevelCommands.lua')
local Project = import('./Project.lua')
local resourceCollection = import('./_resourceCollection.lua')
local serializer = import('./_serializer.lua')
local interruptionHandler = import('./_interruptionHandler.lua')

local static = {}
local prototype = {}
serializer.registerValue('class-prototype:Plan', prototype)

local planStateManager = State.registerModuleState('module:Plan', function()
    return {
        -- List of projects that still need to be tackled
        projectList = nil,
        -- The project currently being worked on, or that we're currently gathering resources for
        primaryTask = nil,
        -- A task, like a farm-tending task, that's interrupting the active one
        interruptTask = nil,
    }
end)

-- HELPER FUNCTIONS --

local countNonReservedResourcesInInventory = function(state)
    local resourcesInInventory = util.copyTable(
        highLevelCommands.countResourcesInInventory(highLevelCommands.takeInventory(commands, state))
    )

    -- At least one charcoal is reserved so if you need to smelt something, you can get more charcoal to do so.
    if resourcesInInventory['minecraft:charcoal'] ~= nil then
        resourcesInInventory['minecraft:charcoal'] = resourcesInInventory['minecraft:charcoal'] - 1 or nil
        if resourcesInInventory['minecraft:charcoal'] == 0 then
            resourcesInInventory['minecraft:charcoal'] = nil
        end
    end

    return resourcesInInventory
end

-- PUBLIC FUNCTIONS --

--[[
Inputs:
    opts.initialTurtlePos
    opts.projectList: <Project instance>[]
]]
function static.new(opts)
    local state = State.newInitialState({ startingPos = opts.initialTurtlePos })
    
    Project.__validateProjectList(opts.projectList)
    state:getAndModify(planStateManager).projectList = opts.projectList

    return util.attachPrototype(prototype, { _state = state })
end

-- It's valid to have multiple plan instances wrapping and mutating the same state instance.
-- Though it's encouraged to pass around the pre-existing plan instance instead of creating new ones, where possible.
function static.fromState(state)
    return util.attachPrototype(prototype, { _state = state })
end

function prototype:serialize()
    return serializer.serialize(self)
end

function static.deserialize(text)
    return serializer.deserialize(text)
end

-- Is there nothing else for this plan to do?
function prototype:isExhausted()
    local planState = self._state:get(planStateManager)
    return planState.primaryTask == nil and #planState.projectList == 0
end

-- The state parameter gets mutated
function prototype:runNextSprint()
    local state = self._state
    local planState = state:getAndModify(planStateManager)
    -- Prepare the next project task, or resource-fetching task
    -- planState.primaryTask should be set to a value after this.
    local resourcesInInventory = nil
    if planState.primaryTask == nil then
        util.assert(#planState.projectList >= 1)
        resourcesInInventory = countNonReservedResourcesInInventory(state)
        local nextProject = planState.projectList[1]
        local resourceCollectionTask, isIdleTask = resourceCollection.collectResources(state, nextProject, resourcesInInventory)
        if resourceCollectionTask ~= nil then
            if inspect.isIdling then
                inspect.isIdling(isIdleTask)
            end
            planState.primaryTask = resourceCollectionTask
        else
            table.remove(planState.projectList, 1)
            planState.primaryTask = nextProject:__createTask(state)
        end
    end

    -- If there is not a current interrupt task, check if an interruption needs to
    -- happen, and if so, assign one.
    if planState.interruptTask == nil then
        -- If we haven't inspected our inventory yet, do so now.
        if resourcesInInventory == nil then
            resourcesInInventory = countNonReservedResourcesInInventory(state)
        end
        local interruptTask = interruptionHandler.checkForInterruptions(state, resourcesInInventory)
        if interruptTask ~= nil then
            planState.interruptTask = interruptTask
            if planState.primaryTask ~= nil then
                planState.primaryTask:prepareForInterrupt()
            end
        end
    end

    -- If there is an interrupt task currently active, handle the next sprint for it.
    if planState.interruptTask ~= nil then
        local taskExhausted = planState.interruptTask:nextSprint()
        if taskExhausted then
            planState.interruptTask = nil
        end
        return
    end

    local taskExhausted = planState.primaryTask:nextSprint()
    if taskExhausted then
        planState.primaryTask = nil
    end
end

-- Used for introspection purposes.
function prototype:displayTaskNames()
    local planState = self._state:get(planStateManager)
    print('primary task: '..(planState.primaryTask and planState.primaryTask.displayName or 'nil'))
    print('interrupt task: '..(planState.interruptTask and planState.interruptTask.displayName or 'nil'))
    print()
end

return static