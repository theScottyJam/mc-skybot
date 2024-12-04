local location = _G.act.location
local navigate = _G.act.navigate

local module = {}

local createFunctionalScaffoldingBlueprint = _G.act.blueprint.create({
    key = {
        ['minecraft:stone'] = 'X',
        ['minecraft:dirt'] = 'D',
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
            '               ',
            '       *       ',
        },
        {
            '  .    ,    .  ',
            '               ',
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
            '  *    *    *  ',
        },
        {
            '               ',
            '  .    ,    .  ',
            '  X    X    X  ',
            '  DXXXXDXXXXD  ',
            '       X       ',
            '       X       ',
            '       !       ',
        },
        {
            '  .    ,    .  ',
            '               ',
            '  X    X    X  ',
        },
    }
})

function createFunctionalScaffoldingProject(opts)
    local treeFarmEntranceLoc = opts.treeFarmEntranceLoc

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
        end,
        nextPlan = function(commands, state, taskState)
            return createFunctionalScaffoldingBlueprint.nextPlan(commands, state, taskState)
        end,
    })
    return _G.act.project.create(taskRunnerId, {
        requiredResources = createFunctionalScaffoldingBlueprint.requiredResources,
    })
end

function module.initEntity(opts)
    local homeLoc = opts.homeLoc
    local treeFarmEntranceLoc = location.register(homeLoc.cmps.posAt({ forward=2 }))
    location.registerPath(homeLoc, treeFarmEntranceLoc)

    return {
        createFunctionalScaffolding = createFunctionalScaffoldingProject({ treeFarmEntranceLoc = treeFarmEntranceLoc }),
    }
end

return module
