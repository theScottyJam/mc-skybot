local util = import('util.lua')
local act = import('act/init.lua')
local treeFarmBehavior = import('./_treeFarmBehavior.lua')

local Location = act.Location
local navigate = act.navigate

local module = {}

local functionalScaffoldingBlueprint = act.blueprint.create({
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

function registerFunctionalScaffoldingProject(opts)
    local homeLoc = opts.homeLoc
    local treeFarmEntranceLoc = opts.treeFarmEntranceLoc
    local treeFarm = opts.treeFarm

    return act.Project.register({
        id = 'basicTreeFarm:createFunctionalScaffolding',
        init = function(self, state)
            self.state = state
            -- mutable state
            self.taskState = functionalScaffoldingBlueprint.createTaskState(treeFarmEntranceLoc.cmps)
        end,
        before = function(self, commands)
            Location.addPath(self.state, homeLoc, treeFarmEntranceLoc)
        end,
        enter = function(self, commands)
            treeFarmEntranceLoc:travelHere(commands, self.state)
            functionalScaffoldingBlueprint.enter(commands, self.state, self.taskState)
        end,
        exit = function(self, commands)
            functionalScaffoldingBlueprint.exit(commands, self.state, self.taskState)
            navigate.assertAtPos(self.state, treeFarmEntranceLoc.cmps.pos)
        end,
        after = function(self, commands)
            treeFarm:activate(commands, self.state)
        end,
        nextSprint = function(self, commands)
            return functionalScaffoldingBlueprint.nextSprint(commands, self.state, self.taskState)
        end,
        requiredResources = functionalScaffoldingBlueprint.requiredResources,
    })
end

local registerTreeFarm = function(opts)
    local treeFarmEntranceLoc = opts.treeFarmEntranceLoc

    return act.Farm.register({
        id = 'basicTreeFarm:treeFarm',
        init = function(self, state)
            self.state = state
        end,
        enter = function(self, commands)
            treeFarmEntranceLoc:travelHere(commands, self.state)
        end,
        exit = function(self, commands)
            navigate.assertAtPos(self.state, treeFarmEntranceLoc.cmps.pos)
        end,
        nextSprint = function(self, commands)
            local state = self.state

            commands.turtle.select(state, 1)
            local startPos = state.turtlePos

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

            return true
        end,
        supplies = treeFarmBehavior.stats.supplies,
        calcExpectedYield = treeFarmBehavior.stats.calcExpectedYield,
    })
end

function module.register(opts)
    local homeLoc = opts.homeLoc
    local treeFarmEntranceLoc = Location.register(homeLoc.cmps.posAt({ forward=2 }))

    local treeFarm = registerTreeFarm({ treeFarmEntranceLoc = treeFarmEntranceLoc })

    return {
        functionalScaffolding = registerFunctionalScaffoldingProject({ homeLoc = homeLoc, treeFarmEntranceLoc = treeFarmEntranceLoc, treeFarm = treeFarm }),
    }
end

return module
