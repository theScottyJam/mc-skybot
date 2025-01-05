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
    Project.__validateProjectList(opts.projectList)
    local state = State.newInitialState({
        startingPos = opts.initialTurtlePos,
        projectList = opts.projectList,
    })

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
    return self._state.primaryTask == nil and #self._state.projectList == 0
end

-- The state parameter gets mutated
function prototype:runNextSprint()
    local state = self._state
    -- Prepare the next project task, or resource-fetching task
    -- state.primaryTask should be set to a value after this.
    local resourcesInInventory = nil
    if state.primaryTask == nil then
        util.assert(#state.projectList >= 1)
        resourcesInInventory = countNonReservedResourcesInInventory(state)
        local nextProject = state.projectList[1]
        local resourceCollectionTask, isIdleTask = resourceCollection.collectResources(state, nextProject, resourcesInInventory)
        if resourceCollectionTask ~= nil then
            if inspect.isIdling then
                inspect.isIdling(isIdleTask)
            end
            state.primaryTask = resourceCollectionTask
        else
            table.remove(state.projectList, 1)
            state.primaryTask = nextProject:__createTask(state)
        end
    end

    -- If there is not a current interrupt task, check if an interruption needs to
    -- happen, and if so, assign one.
    if state.interruptTask == nil then
        -- If we haven't inspected our inventory yet, do so now.
        if resourcesInInventory == nil then
            resourcesInInventory = countNonReservedResourcesInInventory(state)
        end
        local interruptTask = interruptionHandler.checkForInterruptions(state, resourcesInInventory)
        if interruptTask ~= nil then
            state.interruptTask = interruptTask
            if state.primaryTask ~= nil then
                state.primaryTask:prepareForInterrupt()
            end
        end
    end

    -- If there is an interrupt task currently active, handle the next sprint for it.
    if state.interruptTask ~= nil then
        local taskExhausted = state.interruptTask:nextSprint()
        if taskExhausted then
            state.interruptTask = nil
        end
        return
    end

    local taskExhausted = state.primaryTask:nextSprint()
    if taskExhausted then
        state.primaryTask = nil
    end
end

return static