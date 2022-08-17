local util = import('util.lua')

local module = {}

function module.init()
    return _G.act.entity.createEntityFactory(entityBuilder)
end

-- opts.bedrockCoord - the coordinate of the bedrock block
function entityBuilder(opts)
    local location = _G.act.location
    local space = _G.act.space

    -- The bedrockCoord should always be at (0, 64, -3}
    local bedrockPos = util.mergeTables(opts.bedrockCoord, { face = 'forward' })

    -- homeLoc is right above the bedrock
    local homeLoc = location.register(space.resolveRelPos({ up=3 }, bedrockPos))
    -- initialLoc is in front of the chest
    local initialLoc = location.register(space.resolveRelPos({ right=3, face='left' }, homeLoc.pos))

    local harvestInitialTree = harvestInitialTreeProject({ bedrockPos = bedrockPos, homeLoc = homeLoc })
    local prepareCobblestoneGenerator = prepareCobblestoneGeneratorProject({ homeLoc = homeLoc })
    local waitForIceToMeltAndfinishCobblestoneGenerator = waitForIceToMeltAndfinishCobblestoneGeneratorProject({ homeLoc = homeLoc })
    local harvestCobblestone = harvestCobblestoneProject({ homeLoc = homeLoc })

    return {
        init = function()
            location.registerPath(initialLoc, homeLoc)
        end,
        entity = {
            initialLoc = initialLoc,
            homeLoc = homeLoc,
            harvestInitialTree = harvestInitialTree,
            prepareCobblestoneGenerator = prepareCobblestoneGenerator,
            waitForIceToMeltAndfinishCobblestoneGenerator = waitForIceToMeltAndfinishCobblestoneGenerator,
            harvestCobblestone = harvestCobblestone,
        }
    }
end

function harvestInitialTreeProject(opts)
    local bedrockPos = opts.bedrockPos
    local homeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local space = _G.act.space

    local bedrockCmps = space.createCompass(bedrockPos)
    return _G.act.project.register('mainIsland:harvestInitialTree', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlanner = _G.act.shortTermPlanner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlanner, homeLoc)
            local startPos = util.copyTable(shortTermPlanner.turtlePos)

            local bottomLogCmps = bedrockCmps.compassAt({ forward=-4, right=-1, up=3 })
            local aboveTreeCoord = bottomLogCmps.coordAt({ up=9 })

            navigate.moveToCoord(shortTermPlanner, aboveTreeCoord, { 'up', 'forward', 'right' })

            harvestTreeFromAbove(shortTermPlanner, { bottomLogPos = bottomLogCmps.pos })

            navigate.moveToPos(shortTermPlanner, startPos, { 'up', 'forward', 'right' })

            return { done = true }, shortTermPlanner.shortTermPlan
        end
    })
end

function harvestTreeFromAbove(shortTermPlanner, opts)
    local bottomLogPos = opts.bottomLogPos

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local space = _G.act.space

    local bottomLogCmps = space.createCompass(bottomLogPos)

    -- Brings the turtle two blocks above the top leaf (the block right above will eventually have a dirt block)
    navigate.assertCoord(shortTermPlanner, bottomLogCmps.coordAt({ up=9 }))
    navigate.face(shortTermPlanner, bottomLogCmps.facingAt({ face='left' }))

    commands.turtle.down(shortTermPlanner)
    commands.turtle.down(shortTermPlanner)
    for i = 1, 2 do
        commands.turtle.digDown(shortTermPlanner, 'left')
        commands.turtle.down(shortTermPlanner)
        for j = 1, 4 do
            commands.turtle.dig(shortTermPlanner, 'left')
            commands.turtle.turnRight(shortTermPlanner)
        end
    end

    -- Get a stray leaf block
    navigate.face(shortTermPlanner, bottomLogCmps.facingAt({ face='forward' }))
    local levelTwoCenterCmps = bottomLogCmps.compassAt({ up=5 })
    navigate.assertCoord(shortTermPlanner, levelTwoCenterCmps.coord)
    navigate.moveToPos(shortTermPlanner, levelTwoCenterCmps.posAt({ forward=1, face='right' }))
    commands.turtle.dig(shortTermPlanner, 'left')
    
    -- Harvest bottom-half of leaves
    for y = 5, 4, -1 do
        local cornerPos = bottomLogCmps.posAt({ forward = 2, right = 2, up = y, face='backward' })
        navigate.moveToPos(shortTermPlanner, cornerPos, { 'right', 'forward', 'up' })
        spiralInwards(shortTermPlanner, {
            sideLength = 5,
            onVisit = function()
                commands.turtle.digDown(shortTermPlanner, 'left')
            end
        })
    end

    -- Harvest trunk
    navigate.assertCoord(shortTermPlanner, bottomLogCmps.coordAt({ up=4 }))
    for i = 1, 4 do
        commands.turtle.digDown(shortTermPlanner, 'left')
        commands.turtle.down(shortTermPlanner)
    end
end

-- End condition: An empty bucket will be left in your inventory
function prepareCobblestoneGeneratorProject(opts)
    local homeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    local homeCmps = space.createCompass(homeLoc.pos)
    return _G.act.project.register('mainIsland:prepareCobblestoneGenerator', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlanner = _G.act.shortTermPlanner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlanner, homeLoc)
            local startPos = util.copyTable(shortTermPlanner.turtlePos)

            -- Dig out east branch
            navigate.face(shortTermPlanner, homeCmps.facingAt({ face='right' }))
            for i = 1, 2 do
                commands.turtle.forward(shortTermPlanner)
                commands.turtle.digDown(shortTermPlanner, 'left')
            end

            -- Grab stuff from chest
            local LAVA_BUCKET_SLOT = 16
            local ICE_SLOT = 15
            commands.turtle.forward(shortTermPlanner)
            commands.turtle.select(shortTermPlanner, LAVA_BUCKET_SLOT)
            commands.turtle.suck(shortTermPlanner, 1)
            commands.turtle.select(shortTermPlanner, ICE_SLOT)
            commands.turtle.suck(shortTermPlanner, 1)

            -- Place lava down
            navigate.moveToCoord(shortTermPlanner, homeCmps.coordAt({ right=2 }))
            commands.turtle.select(shortTermPlanner, LAVA_BUCKET_SLOT)
            commands.turtle.placeDown(shortTermPlanner)
            -- Move the empty bucket to an earlier cell.
            highLevelCommands.transferToFirstEmptySlot(shortTermPlanner)
            commands.turtle.select(shortTermPlanner, 1)

            -- Dig out west branch
            navigate.moveToPos(shortTermPlanner, homeCmps.posAt({ face='backward' }))
            commands.turtle.forward(shortTermPlanner)
            commands.turtle.digDown(shortTermPlanner, 'left')
            commands.turtle.down(shortTermPlanner)
            commands.turtle.digDown(shortTermPlanner, 'left')
            commands.turtle.dig(shortTermPlanner, 'left')
            commands.turtle.up(shortTermPlanner)

            -- Place ice down
            -- (We're placing ice here, instead of in it's final spot, so it can be closer to the lava
            -- so the lava can melt it)
            commands.turtle.select(shortTermPlanner, ICE_SLOT)
            commands.turtle.placeDown(shortTermPlanner)
            commands.turtle.select(shortTermPlanner, 1)

            -- Dig out place for player to stand
            navigate.moveToCoord(shortTermPlanner, homeCmps.coordAt({ x=-1, y=0, z=0 }))
            commands.turtle.digDown(shortTermPlanner, 'left')

            navigate.moveToPos(shortTermPlanner, startPos)

            return { done = true }, shortTermPlanner.shortTermPlan
        end
    })
end

-- Start condition: An empty bucket must be in your inventory.
function waitForIceToMeltAndfinishCobblestoneGeneratorProject(opts)
    local homeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    local homeCmps = space.createCompass(homeLoc.pos)
    return _G.act.project.register('mainIsland:waitForIceToMeltAndfinishCobblestoneGenerator', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlanner = _G.act.shortTermPlanner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlanner, homeLoc)

            local startPos = util.copyTable(shortTermPlanner.turtlePos)

            -- Wait for ice to melt
            navigate.moveToCoord(shortTermPlanner, homeCmps.coordAt({ forward=-1 }))
            highLevelCommands.waitUntilDetectBlock(shortTermPlanner, {
                expectedBlockId = 'minecraft:water',
                direction = 'down',
                endFacing = homeCmps.facingAt({ face='backward' }),
            })
            
            -- Move water
            highLevelCommands.findAndSelectSlotWithItem(shortTermPlanner, 'minecraft:bucket')
            commands.turtle.placeDown(shortTermPlanner, 'left')
            commands.turtle.forward(shortTermPlanner)
            commands.turtle.placeDown(shortTermPlanner)
            commands.turtle.select(shortTermPlanner, 1)

            navigate.moveToPos(shortTermPlanner, startPos)
            commands.turtle.digDown(shortTermPlanner, 'left')
            commands.mockHooks.registerCobblestoneRegenerationBlock(shortTermPlanner, homeCmps.coordAt({ up=-1 }))

            return { done = true }, shortTermPlanner.shortTermPlan
        end
    })
end

function harvestCobblestoneProject(opts)
    local homeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    local homeCmps = space.createCompass(homeLoc.pos)
    return _G.act.project.register('mainIsland:harvestCobblestoneProject', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlanner = _G.act.shortTermPlanner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlanner, homeLoc)

            local startPos = util.copyTable(shortTermPlanner.turtlePos)

            for i = 1, 32 do
                highLevelCommands.waitUntilDetectBlock(shortTermPlanner, {
                    expectedBlockId = 'minecraft:cobblestone',
                    direction = 'down',
                    endFacing = 'ANY',
                })
                commands.turtle.digDown(shortTermPlanner, 'left')
            end
            highLevelCommands.reorient(shortTermPlanner, space.posToFacing(startPos))

            return { done = true }, shortTermPlanner.shortTermPlan
        end
    })
end

-- Starting from a corner of a square (of size sideLength), touch every cell in it by following
-- a clockwise spiral to the center. You must start facing in a direction such that
-- no turning is required before movement.
-- The `onVisit` function is called at each cell visited.
function spiralInwards(shortTermPlanner, opts)
    local commands = _G.act.commands

    local sideLength = opts.sideLength
    local onVisit = opts.onVisit

    for segmentLength = sideLength - 1, 1, -1 do
        local firstIter = segmentLength == sideLength - 1
        for i = 1, (firstIter and 3 or 2) do
            for j = 1, segmentLength do
                onVisit(shortTermPlanner)
                commands.turtle.forward(shortTermPlanner)
            end
            commands.turtle.turnRight(shortTermPlanner)
        end
    end
    onVisit(shortTermPlanner)
end

return module