--[[
    Figures out which sprint to run next, which may be the next sprint
    of the current primary task, or it may be an interruption.
]]

local util = import('util.lua')
local inspect = moduleLoader.tryImport('inspect.lua')
local State = import('./_State.lua')
local commands = import('./_commands.lua')
local Farm = import('./Farm.lua')
local highLevelCommands = import('./highLevelCommands.lua')
local Project = import('./Project.lua')
local time = import('./_time.lua')
local resourceCollection = import('./_resourceCollection.lua')
local serializer = import('./_serializer.lua')

local module = {}

local planStateManager = State.registerModuleState('module:planExecutor', function(opts)
    local projectList = opts.projectList
    return {
        -- List of projects that still need to be tackled
        projectList = projectList,
        -- The project currently being worked on, or that we're currently gathering resources for
        primaryTask = nil,
        -- A task, like a farm-tending task, that's interrupting the active one
        interruptTask = nil,
    }
end)

-- HELPER FUNCTIONS --

-- `expectedYieldInfo` is what gets returned by a farm's __calcExpectedYield() function.
local scoreFromExpectedYieldInfo = function(expectedYieldInfo, resourcesInInventory)
    local work = expectedYieldInfo.work
    local expectedResources = expectedYieldInfo.yield

    local score = 0
    for resourceName, quantity in pairs(expectedResources) do
        local getWorkToYieldThreshold = Farm.__getValueOfFarmableResource(resourceName)
        if getWorkToYieldThreshold ~= nil then
            local threshold = getWorkToYieldThreshold(resourcesInInventory[resourceName] or 0)
            local workToYield = work / quantity
            score = score + util.maxNumber(0, threshold - workToYield)
        end
    end
    return score
end

-- Should be called at each interruptible point during a project or mill,
-- and whenever an interruption has finished.
-- Returns an interrupt task, or nil if there
-- are no interruptions.
local checkForInterruptions = function(state, resourcesInInventory)
    local currentTime = time.get(state)
    local winningFarm = {
        farm = nil,
        score = 0,
    }

    for _, farmInfo in pairs(Farm.__getActiveFarms(state)) do
        local elapsedTime = currentTime - farmInfo.lastVisited

        local expectedYieldInfo = farmInfo.farm:__calcExpectedYield(elapsedTime)
        local score = scoreFromExpectedYieldInfo(expectedYieldInfo, resourcesInInventory)
        if score > winningFarm.score then
            winningFarm = {
                farm = farmInfo.farm,
                score = score,
            }
        end
    end

    if winningFarm.farm ~= nil then
        return winningFarm.farm:__createTask(state)
    else
        return nil
    end
end

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

function module.noSprintsRemaining(state)
    local planState = state:get(planStateManager)
    return planState.primaryTask == nil and #planState.projectList == 0
end

function module.runNextSprint(state)
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
        local interruptTask = checkForInterruptions(state, resourcesInInventory)
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
function module.displayInProgressTasks(state)
    local planState = state:get(planStateManager)
    print('primary task: '..(planState.primaryTask and planState.primaryTask.displayName or 'nil'))
    print('interrupt task: '..(planState.interruptTask and planState.interruptTask.displayName or 'nil'))
    print()
end

return module