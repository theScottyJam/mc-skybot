local util = import('util.lua')
local inspect = tryImport('inspect.lua')
local stateModule = import('./_state.lua')
local commands = import('./_commands.lua')
local farm = import('./farm.lua')
local task = import('./task.lua')
local highLevelCommands = import('./highLevelCommands.lua')
local project = import('./project.lua')

local module = {}

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

--<-- Remove this indirection?
-- A plan is of the shape { initialTurtlePos=..., projectList=<list of taskRunnerIds> }
function module.createInitialState(plan)
    return stateModule.createInitialState({
        startingPos = plan.initialTurtlePos,
        projectList = plan.projectList,
    })
end

function module.isPlanComplete(state)
    return state.primaryTask == nil and #state.projectList == 0
end

-- The state parameter gets mutated
function module.runNextSprint(state)
    -- Prepare the next project task, or resource-fetching task
    -- state.primaryTask should be set to a value after this.
    local resourcesInInventory = nil
    if state.primaryTask == nil then
        util.assert(#state.projectList >= 1)
        resourcesInInventory = countNonReservedResourcesInInventory(state)
        local nextProject = project.lookup(state.projectList[1])
        local nextProjectTaskRunner = task.lookupTaskRunner(state.projectList[1])
        local resourceCollectionTask = task.collectResources(state, nextProject, resourcesInInventory)
        if resourceCollectionTask ~= nil then
            -- This "act:idle" id is defined elsewhere. §7kUI2
            if not isIdling and resourceCollectionTask.taskRunnerId == 'act:idle' then
                isIdling = true
                if inspect.onIdleStart ~= nil then
                    inspect.onIdleStart()
                end
            end
            if isIdling and resourceCollectionTask.taskRunnerId ~= 'act:idle' then
                isIdling = false
                if inspect.onIdleEnd ~= nil then
                    inspect.onIdleEnd()
                end
            end
            state.primaryTask = resourceCollectionTask
        else
            table.remove(state.projectList, 1)
            state.primaryTask = task.create(nextProjectTaskRunner.id)
        end
    end

    -- If there is not a current interrupt task, check if an interruption needs to
    -- happen, and if so, assign one.
    if state.interruptTask == nil then
        -- If we haven't inspected our inventory yet, do so now.
        if resourcesInInventory == nil then
            resourcesInInventory = countNonReservedResourcesInInventory(state)
        end
        local interruptTask = farm.checkForInterruptions(state, resourcesInInventory)
        if interruptTask ~= nil then
            state.interruptTask = interruptTask
            local taskRunnerBeingDone = state.interruptTask.getTaskRunner()
            if state.primaryTask ~= nil and state.primaryTask.entered then
                state.primaryTask.getTaskRunner().exit(state, state.primaryTask)
            end
            taskRunnerBeingDone.enter(state, state.interruptTask)
        end
    end

    -- If there is an interrupt task currently active, handle the next sprint for it.
    if state.interruptTask ~= nil then
        local taskRunnerBeingDone = state.interruptTask.getTaskRunner()
        if not state.interruptTask.exhausted then
            taskRunnerBeingDone.nextSprint(state, state.interruptTask)
        else
            taskRunnerBeingDone.exit(state, state.interruptTask)
            farm.markFarmTaskAsCompleted(state, state.interruptTask.taskRunnerId)
            state.interruptTask = nil
        end
        return
    end

    local taskRunnerBeingDone = state.primaryTask.getTaskRunner()
    -- Enter for the first time, or continuing after an interruption
    if not state.primaryTask.entered then
        taskRunnerBeingDone.enter(state, state.primaryTask)
    end
    taskRunnerBeingDone.nextSprint(state, state.primaryTask)

    if state.primaryTask.exhausted then
        taskRunnerBeingDone.exit(state, state.primaryTask)
        state.primaryTask = nil
        return
    end
end

return module