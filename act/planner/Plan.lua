--[[
    The overall plan the turtle will follow, describing its first actions to its last.
]]

local util = import('util.lua')
local state = import('../state.lua')
local Project = import('./Project.lua')
local Farm = import('./Farm.lua')
local serializer = import('../_serializer.lua')
local sprintCoordinator = import('./_sprintCoordinator.lua')
local inspect = moduleLoader.tryImport('inspect.lua') 

local static = {}
local prototype = {}

local INITIAL_CHARCOAL_REQUIRED = 16

-- Sets this plan as the active plan to run.
function static.register(opts)
    local initialTurtlePos = opts.initialTurtlePos
    local projectList = opts.projectList
    local valueOfFarmableResources = opts.valueOfFarmableResources
    Project.__validateProjectList(projectList)
    
    Farm.registerValueOfFarmableResources(valueOfFarmableResources)

    return util.attachPrototype(prototype, {
        _initialTurtlePos = initialTurtlePos,
        _projectList = projectList,
    })
end

-- Any functions with "register" in the name should be called before this function is called.
function prototype:startFromBeginning()
    state.init({ startingPos = self._initialTurtlePos })
    sprintCoordinator.useProjectList(self._projectList)

    if inspect.onPlanStart then
        inspect.onPlanStart()
    end

    turtle.refuel(INITIAL_CHARCOAL_REQUIRED)
end

-- Is there nothing else for this plan to do?
function prototype:isPlanExhausted()
    return sprintCoordinator.noSprintsRemaining()
end

function prototype:runNextSprint()
    sprintCoordinator.runNextSprint()
end

-- Used for introspection purposes.
function static.displayInProgressTasks()
    sprintCoordinator.displayInProgressTasks()
end

return static