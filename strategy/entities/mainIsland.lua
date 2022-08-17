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

            local shortTermPlaner = _G.act.shortTermPlaner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlaner, homeLoc)
            local startPos = util.copyTable(shortTermPlaner.turtlePos)

            local bottomLogCmps = bedrockCmps.compassAt({ forward=-4, right=-1, up=3 })
            local aboveTreeCoord = bottomLogCmps.coordAt({ up=7 })

            navigate.moveToCoord(shortTermPlaner, aboveTreeCoord, { 'up', 'forward', 'right' })
            navigate.assertFace(shortTermPlaner, 'left')

            -- Harvest plus-sign shape of leaves on top
            for i = 1, 2 do
                commands.turtle.digDown(shortTermPlaner, 'left')
                commands.turtle.down(shortTermPlaner)
                for j = 1, 4 do
                    commands.turtle.dig(shortTermPlaner, 'left')
                    commands.turtle.turnRight(shortTermPlaner)
                end
            end

            -- Get a stray leaf block
            navigate.face(shortTermPlaner, bottomLogCmps.facingAt({ face='forward' }))
            local levelTwoCenterCmps = bottomLogCmps.compassAt({ up=5 })
            navigate.assertCoord(shortTermPlaner, levelTwoCenterCmps.coord)
            navigate.moveToPos(shortTermPlaner, levelTwoCenterCmps.posAt({ forward=1, face='right' }))
            commands.turtle.dig(shortTermPlaner, 'left')
            
            -- Harvest bottom-half of leaves
            for y = 5, 4, -1 do
                local cornerPos = bottomLogCmps.posAt({ forward = 2, right = 2, up = y, face='backward' })
                navigate.moveToPos(shortTermPlaner, cornerPos, { 'right', 'forward', 'up' })
                spiralInwards(shortTermPlaner, {
                    sideLength = 5,
                    onVisit = function()
                        commands.turtle.digDown(shortTermPlaner, 'left')
                    end
                })
            end

            -- Harvest trunk
            navigate.assertCoord(shortTermPlaner, bottomLogCmps.coordAt({ up=4 }))
            for i = 1, 4 do
                commands.turtle.digDown(shortTermPlaner, 'left')
                commands.turtle.down(shortTermPlaner)
            end

            navigate.moveToPos(shortTermPlaner, startPos, { 'up', 'forward', 'right' })

            return { done = true }, shortTermPlaner.shortTermPlan
        end
    })
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

            local shortTermPlaner = _G.act.shortTermPlaner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlaner, homeLoc)
            local startPos = util.copyTable(shortTermPlaner.turtlePos)

            -- Dig out east branch
            navigate.face(shortTermPlaner, homeCmps.facingAt({ face='right' }))
            for i = 1, 2 do
                commands.turtle.forward(shortTermPlaner)
                commands.turtle.digDown(shortTermPlaner, 'left')
            end

            -- Grab stuff from chest
            local LAVA_BUCKET_SLOT = 16
            local ICE_SLOT = 15
            commands.turtle.forward(shortTermPlaner)
            commands.turtle.select(shortTermPlaner, LAVA_BUCKET_SLOT)
            commands.turtle.suck(shortTermPlaner, 1)
            commands.turtle.select(shortTermPlaner, ICE_SLOT)
            commands.turtle.suck(shortTermPlaner, 1)

            -- Place lava down
            navigate.moveToCoord(shortTermPlaner, homeCmps.coordAt({ right=2 }))
            commands.turtle.select(shortTermPlaner, LAVA_BUCKET_SLOT)
            commands.turtle.placeDown(shortTermPlaner)
            -- Move the empty bucket to an earlier cell.
            highLevelCommands.transferToFirstEmptySlot(shortTermPlaner)
            commands.turtle.select(shortTermPlaner, 1)

            -- Dig out west branch
            navigate.moveToPos(shortTermPlaner, homeCmps.posAt({ face='backward' }))
            commands.turtle.forward(shortTermPlaner)
            commands.turtle.digDown(shortTermPlaner, 'left')
            commands.turtle.down(shortTermPlaner)
            commands.turtle.digDown(shortTermPlaner, 'left')
            commands.turtle.dig(shortTermPlaner, 'left')
            commands.turtle.up(shortTermPlaner)

            -- Place ice down
            -- (We're placing ice here, instead of in it's final spot, so it can be closer to the lava
            -- so the lava can melt it)
            commands.turtle.select(shortTermPlaner, ICE_SLOT)
            commands.turtle.placeDown(shortTermPlaner)
            commands.turtle.select(shortTermPlaner, 1)

            -- Dig out place for player to stand
            navigate.moveToCoord(shortTermPlaner, homeCmps.coordAt({ x=-1, y=0, z=0 }))
            commands.turtle.digDown(shortTermPlaner, 'left')

            navigate.moveToPos(shortTermPlaner, startPos)

            return { done = true }, shortTermPlaner.shortTermPlan
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

            local shortTermPlaner = _G.act.shortTermPlaner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlaner, homeLoc)

            local startPos = util.copyTable(shortTermPlaner.turtlePos)

            -- Wait for ice to melt
            navigate.moveToCoord(shortTermPlaner, homeCmps.coordAt({ forward=-1 }))
            highLevelCommands.waitUntilDetectBlock(shortTermPlaner, {
                expectedBlockId = 'WATER',
                direction = 'down',
                endFacing = homeCmps.facingAt({ face='backward' }),
            })
            
            -- Move water
            highLevelCommands.findAndSelectSlotWithItem(shortTermPlaner, 'BUCKET')
            commands.turtle.placeDown(shortTermPlaner, 'left')
            commands.turtle.forward(shortTermPlaner)
            commands.turtle.placeDown(shortTermPlaner)
            commands.turtle.select(shortTermPlaner, 1)

            navigate.moveToPos(shortTermPlaner, startPos)
            commands.turtle.digDown(shortTermPlaner, 'left')
            commands.mockHooks.registerCobblestoneRegenerationBlock(shortTermPlaner, homeCmps.coordAt({ up=-1 }))

            return { done = true }, shortTermPlaner.shortTermPlan
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

            local shortTermPlaner = _G.act.shortTermPlaner.create({ turtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlaner, homeLoc)

            local startPos = util.copyTable(shortTermPlaner.turtlePos)

            for i = 1, 32 do
                highLevelCommands.waitUntilDetectBlock(shortTermPlaner, {
                    expectedBlockId = 'COBBLESTONE',
                    direction = 'down',
                    endFacing = 'ANY',
                })
                commands.turtle.digDown(shortTermPlaner, 'left')
            end
            highLevelCommands.reorient(shortTermPlaner, space.posToFacing(startPos))

            return { done = true }, shortTermPlaner.shortTermPlan
        end
    })
end

-- Starting from a corner of a square (of size sideLength), touch every cell in it by following
-- a clockwise spiral to the center. You must start facing in a direction such that
-- no turning is required before movement.
-- The `onVisit` function is called at each cell visited.
function spiralInwards(shortTermPlaner, opts)
    local commands = _G.act.commands

    local sideLength = opts.sideLength
    local onVisit = opts.onVisit

    for segmentLength = sideLength - 1, 1, -1 do
        local firstIter = segmentLength == sideLength - 1
        for i = 1, (firstIter and 3 or 2) do
            for j = 1, segmentLength do
                onVisit(shortTermPlaner)
                commands.turtle.forward(shortTermPlaner)
            end
            commands.turtle.turnRight(shortTermPlaner)
        end
    end
    onVisit(shortTermPlaner)
end

return module