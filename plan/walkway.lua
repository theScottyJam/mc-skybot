local act = import('act/init.lua')

local location = act.location
local navigate = act.navigate

local module = {}

local leftRightWalkway = act.blueprint.create({
    key = {
        ['minecraft:smoothStone'] = 's',
        ['minecraft:stoneBricks'] = 's',
        ['minecraft:torch'] = '*',
    },
    labeledPositions = {
        entrance = {
            behavior = 'buildStartCoord',
            char = '!',
        },
    },
    layers = {
        {
            ',     .',
            'WWWWWWW',
            '   *   ',
            '       ',
            '!      ',
            '       ',
            '   *   ',
            'WWWWWWW',
        },
        {
            ',     .',
            'sssssss',
            'XXXXXXX',
            'XXsssXX',
            'ss   ss',
            'XXsssXX',
            'XXXXXXX',
            'sssssss',
        },
    }
})

local leftDownWalkway = act.blueprint.create({
    key = {
        ['minecraft:smoothStone'] = 's',
        ['minecraft:stoneBricks'] = 's',
        ['minecraft:torch'] = '*',
    },
    labeledPositions = {
        entrance = {
            behavior = 'buildStartCoord',
            char = '!',
        },
    },
    layers = {
        {
            ',     .',
            'WWWWWWW',
            '   *  W',
            '      W',
            '!    *W',
            '      W',
            '      W',
            '      W',
        },
        {
            ',     .',
            'sssssss',
            'XXXXXXs',
            'XXssXXs',
            'ss  sXs',
            'XXs sXs',
            'XXXsXXs',
            'XXXsXXs',
        },
    }
})

local leftDownRightWalkway = act.blueprint.create({
    key = {
        ['minecraft:smoothStone'] = 's',
        ['minecraft:stoneBricks'] = 's',
        ['minecraft:torch'] = '*',
    },
    labeledPositions = {
        entrance = {
            behavior = 'buildStartCoord',
            char = '!',
        },
    },
    layers = {
        {
            ',     .',
            'WWWWWWW',
            '   *   ',
            '       ',
            '!      ',
            '       ',
            '       ',
            'W      W',
        },
        {
            ',     .',
            'sssssss',
            'XXXXXXX',
            'XXsssXX',
            'ss   ss',
            'XXs sXX',
            'XXXsXXX',
            'sXXsXXs',
        },
    }
})

-- function createFunctionalScaffoldingProject(opts)
--     local treeFarmEntranceLoc = opts.treeFarmEntranceLoc

--     local taskRunnerId = 'project:basicTreeFarm:createFunctionalScaffolding'
--     act.task.registerTaskRunner(taskRunnerId, {
--         createTaskState = function()
--             return createFunctionalScaffoldingBlueprint.createTaskState(treeFarmEntranceLoc.cmps)
--         end,
--         enter = function(commands, state, taskState)
--             location.travelToLocation(commands, state, treeFarmEntranceLoc)
--             createFunctionalScaffoldingBlueprint.enter(commands, state, taskState)
--         end,
--         exit = function(commands, state, taskState, info)
--             createFunctionalScaffoldingBlueprint.exit(commands, state, taskState, info)
--             navigate.assertAtPos(state, treeFarmEntranceLoc.cmps.pos)
--         end,
--         nextSprint = function(commands, state, taskState)
--             return createFunctionalScaffoldingBlueprint.nextSprint(commands, state, taskState)
--         end,
--     })
--     return act.project.create(taskRunnerId, {
--         requiredResources = createFunctionalScaffoldingBlueprint.requiredResources,
--     })
-- end

-- function module.init(opts)
--     local homeLoc = opts.homeLoc
--     local treeFarmEntranceLoc = location.register(homeLoc.cmps.posAt({ forward=2 }))
--     location.registerPath(homeLoc, treeFarmEntranceLoc)

--     return {
--         createFunctionalScaffolding = createFunctionalScaffoldingProject({ treeFarmEntranceLoc = treeFarmEntranceLoc }),
--     }
-- end

return module
