local util = import('util.lua')
local act = import('act/init.lua')
local treeFarmBehavior = import('./_treeFarmBehavior.lua')

local Location = act.Location
local navigate = act.navigate
local commands = act.commands
local state = act.state

local module = {}

local functionalScaffoldingBlueprint = act.blueprint.create({
    key = {
        ['minecraft:stone'] = 'X',
        ['minecraft:dirt'] = 'D',
        ['minecraft:sapling'] = 's',
        ['minecraft:torch'] = '*',
    },
    markers = {
        entrance = {
            char = '!',
            targetOffset = { forward = 1, up = 1 },
        },
    },
    buildStartMarker = 'entrance',
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

function registerFunctionalScaffoldingProject(opts)
    local homeLoc = opts.homeLoc
    local treeFarmEntranceLoc = opts.treeFarmEntranceLoc
    local treeFarm = opts.treeFarm

    local functionalScaffolding = functionalScaffoldingBlueprint(treeFarmEntranceLoc.pos)

    return act.Project.register({
        id = 'basicTreeFarm:createFunctionalScaffolding',
        init = function(self)
            -- mutable state
            self.taskState = functionalScaffolding.createTaskState()
        end,
        before = function(self)
            Location.addPath(homeLoc, treeFarmEntranceLoc)
        end,
        enter = function(self)
            treeFarmEntranceLoc:travelHere()
            functionalScaffolding.enter(self.taskState)
        end,
        exit = function(self)
            functionalScaffolding.exit(self.taskState)
            navigate.assertAtPos(treeFarmEntranceLoc.pos)
        end,
        after = function(self)
            treeFarm:activate()
        end,
        nextSprint = function(self)
            return functionalScaffolding.nextSprint(self.taskState)
        end,
        requiredResources = functionalScaffolding.requiredResources,
    })
end

local registerTreeFarm = function(opts)
    local treeFarmEntranceLoc = opts.treeFarmEntranceLoc

    return act.Farm.register({
        id = 'basicTreeFarm:treeFarm',
        enter = function(self)
            treeFarmEntranceLoc:travelHere()
        end,
        exit = function(self)
            navigate.assertAtPos(treeFarmEntranceLoc.pos)
        end,
        nextSprint = function(self)
            commands.turtle.select(1)
            local startPos = navigate.getTurtlePos()

            local inFrontOfEachTreePos = {
                treeFarmEntranceLoc.pos:at({ forward=2, right=-5 }),
                treeFarmEntranceLoc.pos:at({ forward=2 }),
                treeFarmEntranceLoc.pos:at({ forward=2, right=5 }),
            }

            for i, inFrontOfTreePos in ipairs(inFrontOfEachTreePos) do
                navigate.moveToPos(inFrontOfTreePos, { 'forward', 'right' })
                treeFarmBehavior.tryHarvestTree(inFrontOfTreePos)
            end

            navigate.moveToPos(startPos, { 'up', 'right', 'forward' })

            return true
        end,
        supplies = treeFarmBehavior.stats.supplies,
        calcExpectedYield = treeFarmBehavior.stats.calcExpectedYield,
    })
end

function module.register(opts)
    local homeLoc = opts.homeLoc
    local treeFarmEntranceLoc = Location.register(homeLoc.pos:at({ forward=2 }))

    local treeFarm = registerTreeFarm({ treeFarmEntranceLoc = treeFarmEntranceLoc })

    return {
        functionalScaffolding = registerFunctionalScaffoldingProject({ homeLoc = homeLoc, treeFarmEntranceLoc = treeFarmEntranceLoc, treeFarm = treeFarm }),
    }
end

return module
