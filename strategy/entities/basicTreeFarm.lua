local util = import('util.lua')
local treeFarmBehavior = import('./_treeFarmBehavior.lua')

local location = _G.act.location
local navigate = _G.act.navigate

local module = {}

local createFunctionalScaffoldingBlueprint = _G.act.blueprint.create({
    key = {
        ['minecraft:stone'] = 'X',
        ['minecraft:dirt'] = 'D',
        ['minecraft:sapling'] = 's',
        ['minecraft:torch'] = '*',
    },
    labeledPositions = {
        entrance = {
            behavior = 'buildStartCoord',
            char = '!',
            targetOffset = { forward = 1, up = 1 },
        },
    },
    layers = {
        {
            '  .    ,    .  ',
            '       *       ',
        },
        {
            '  .    ,    .  ',
            '  X    X    X  ',
        },
        {','},
        {','},
        {','},
        {','},
        {','},
        {','},
        {','},
        {
            '  .    ,    .  ',
            '  s  * s *  s  ',
        },
        {
            '               ',
            '  .    ,    .  ',
            '  D  X D X  D  ',
            '  XXXXXXXXXXX  ',
            '       X       ', -- Leaves shouldn't go farther than here
            '       X       ', -- This row needs to remain empty so there's room for the turtle to travel upwards.
            '       !       ',
        },
        {
            '  .    ,    .  ',
            '  X    X    X  ',
        },
    }
})

function createFunctionalScaffoldingProject(opts)
    local treeFarmEntranceLoc = opts.treeFarmEntranceLoc
    local treeFarm = opts.treeFarm

    local taskRunnerId = 'project:basicTreeFarm:createFunctionalScaffolding'
    _G.act.task.registerTaskRunner(taskRunnerId, {
        createTaskState = function()
            return createFunctionalScaffoldingBlueprint.createTaskState(treeFarmEntranceLoc.cmps)
        end,
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, treeFarmEntranceLoc)
            createFunctionalScaffoldingBlueprint.enter(commands, state, taskState)
        end,
        exit = function(commands, state, taskState, info)
            createFunctionalScaffoldingBlueprint.exit(commands, state, taskState, info)
            navigate.assertPos(state, treeFarmEntranceLoc.cmps.pos)
            if info.complete then
                treeFarm.activate(commands, state)
            end
        end,
        nextPlan = function(commands, state, taskState)
            return createFunctionalScaffoldingBlueprint.nextPlan(commands, state, taskState)
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        requiredResources = createFunctionalScaffoldingBlueprint.requiredResources,
    })
end

local createTreeFarm = function(opts)
    local treeFarmEntranceLoc = opts.treeFarmEntranceLoc

    local taskRunnerId = _G.act.task.registerTaskRunner('farm:treeFarm', {
        enter = function(commands, state, taskState)
            location.travelToLocation(commands, state, treeFarmEntranceLoc)
        end,
        exit = function(commands, state, taskState)
            navigate.assertPos(state, treeFarmEntranceLoc.cmps.pos)
        end,
        nextPlan = function(commands, state, taskState)
            commands.turtle.select(state, 1)
            local startPos = util.copyTable(state.turtlePos)

            local inFrontOfEachTreeCmps = {
                treeFarmEntranceLoc.cmps.compassAt({ forward=2, right=-5 }),
                treeFarmEntranceLoc.cmps.compassAt({ forward=2 }),
                treeFarmEntranceLoc.cmps.compassAt({ forward=2, right=5 }),
            }

            for i, inFrontOfTreeCmps in ipairs(inFrontOfEachTreeCmps) do
                navigate.moveToPos(commands, state, inFrontOfTreeCmps.pos, { 'forward', 'right' })
                treeFarmBehavior.tryHarvestTree(commands, state, inFrontOfTreeCmps)
            end

            navigate.moveToPos(commands, state, startPos, { 'up', 'right', 'forward' })

            return taskState, true
        end,
    })
    return _G.act.farm.register(taskRunnerId, {
        supplies = treeFarmBehavior.stats.supplies,
        calcExpectedYield = treeFarmBehavior.stats.calcExpectedYield,
    })
end

function module.initEntity(opts)
    local homeLoc = opts.homeLoc
    local treeFarmEntranceLoc = location.register(homeLoc.cmps.posAt({ forward=2 }))
    location.registerPath(homeLoc, treeFarmEntranceLoc)

    local treeFarm = createTreeFarm({ treeFarmEntranceLoc = treeFarmEntranceLoc })

    return {
        createFunctionalScaffolding = createFunctionalScaffoldingProject({ treeFarmEntranceLoc = treeFarmEntranceLoc, treeFarm = treeFarm }),
    }
end

return module
