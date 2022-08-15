local util = import('util.lua')

local module = {}

function module.init()
    return _G.act.entity.createEntityFactory(entityBuilder)
end

function entityBuilder(opts)
    local space = _G.act.space
    -- The bedrockCoord should always be set to { x = 0, y = 64, z = -3 }
    local bedrockCoord = opts.bedrockCoord

    local bedrockPos = util.mergeTables(bedrockCoord, { face = 'N' })

    -- homeLoc is right above the bedrock
    local homeLoc = _G.act.location.register(space.resolveRelPos({ x=0, y=3, z=0, face='N' }, bedrockPos))
    -- initialLoc is in front of the chest
    local initialLoc = _G.act.location.register(space.resolveRelPos({ x=3, face='W' }, homeLoc))

    local harvestInitialTree = harvestInitialTreeProject({ bedrockPos = bedrockPos, homeLoc = homeLoc })
    local prepareCobblestoneGenerator = prepareCobblestoneGeneratorProject({ homeLoc = homeLoc })
    local waitForIceToMeltAndfinishCobblestoneGenerator = waitForIceToMeltAndfinishCobblestoneGeneratorProject({ homeLoc = homeLoc })
    local harvestCobblestone = harvestCobblestoneProject({ homeLoc = homeLoc })

    return {
        init = function()
            _G.act.location.registerPath(initialLoc, homeLoc)
        end,
        entity = {
            initialLoc = initialLoc,
            homeLoc = homeLoc,
            harvestInitialTree = harvestInitialTree,
            prepareCobblestoneGenerator = prepareCobblestoneGenerator,
            waitForIceToMeltAndfinishCobblestoneGenerator = waitForIceToMeltAndfinishCobblestoneGenerator,
            harvestCobblestone = harvestCobblestone
        }
    }
end

function harvestInitialTreeProject(opts)
    local absoluteBedrockPos = opts.bedrockPos
    local absoluteHomeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local space = _G.act.space

    return _G.act.project.register('mainIsland:harvestInitialTree', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local absoluteBottomLogPos = space.resolveRelPos({ x=-1, y=3, z=4, face='N' }, absoluteBedrockPos)
            local aboveTreeCoord = { x=0, y=7, z=0 }

            local shortTermPlaner = _G.act.shortTermPlaner.create({ absTurtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlaner, absoluteHomeLoc)
            local shortTermPlaner = _G.act.shortTermPlaner.withRelativePos(shortTermPlaner, absoluteBottomLogPos)

            local startPos = util.copyTable(shortTermPlaner.turtlePos)
            navigate.moveTo(shortTermPlaner, aboveTreeCoord, { 'y', 'z', 'x' })

            -- Harvest plus-sign shape of leaves on top
            navigate.assertFace(shortTermPlaner, 'W')
            for i = 1, 2 do
                commands.turtle.digDown(shortTermPlaner, 'left')
                commands.turtle.down(shortTermPlaner)
                for j = 1, 4 do
                    commands.turtle.dig(shortTermPlaner, 'left')
                    commands.turtle.turnRight(shortTermPlaner)
                end
            end

            -- Get a stray leaf block
            navigate.moveTo(shortTermPlaner, { z = -1, face = 'E' })
            commands.turtle.dig(shortTermPlaner, 'left')
            
            -- Harvest bottom-half of leaves
            for y = 5, 4, -1 do
                navigate.moveTo(shortTermPlaner, { x = 2, y = y, z = -2 }, { 'x', 'z', 'y' })
                navigate.face(shortTermPlaner, 'S')
                spiralInwards(shortTermPlaner, {
                    sideLength = 5,
                    onVisit = function()
                        commands.turtle.digDown(shortTermPlaner, 'left')
                    end
                })
            end

            -- Harvest trunk
            for y = 3, 0, -1 do
                commands.turtle.digDown(shortTermPlaner, 'left')
                navigate.moveTo(shortTermPlaner, { y = y })
            end

            navigate.moveTo(shortTermPlaner, startPos, { 'y', 'z', 'x' })

            return { done = true }, shortTermPlaner.shortTermPlan
        end
    })
end

-- End condition: An empty bucket will be left in your inventory
function prepareCobblestoneGeneratorProject(opts)
    local absoluteHomeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    return _G.act.project.register('mainIsland:prepareCobblestoneGenerator', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlaner = _G.act.shortTermPlaner.create({ absTurtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlaner, absoluteHomeLoc)
            local shortTermPlaner = _G.act.shortTermPlaner.withRelativePos(shortTermPlaner, space.locToPos(absoluteHomeLoc))

            local startPos = util.copyTable(shortTermPlaner.turtlePos)

            -- Dig out east branch
            navigate.face(shortTermPlaner, 'E')
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
            navigate.moveTo(shortTermPlaner, { x=2, y=0, z=0 })
            commands.turtle.select(shortTermPlaner, LAVA_BUCKET_SLOT)
            commands.turtle.placeDown(shortTermPlaner)
            -- Move the empty bucket to an earlier cell.
            highLevelCommands.transferToFirstEmptySlot(shortTermPlaner)
            commands.turtle.select(shortTermPlaner, 1)

            -- Dig out west branch
            navigate.moveTo(shortTermPlaner, { x=0, y=0, z=0, face='S' })
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
            navigate.moveTo(shortTermPlaner, { x=-1, y=0, z=0 })
            commands.turtle.digDown(shortTermPlaner, 'left')

            navigate.moveTo(shortTermPlaner, startPos)

            return { done = true }, shortTermPlaner.shortTermPlan
        end
    })
end

-- Start condition: An empty bucket must be in your inventory.
function waitForIceToMeltAndfinishCobblestoneGeneratorProject(opts)
    local absoluteHomeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    return _G.act.project.register('mainIsland:waitForIceToMeltAndfinishCobblestoneGenerator', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlaner = _G.act.shortTermPlaner.create({ absTurtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlaner, absoluteHomeLoc)
            local shortTermPlaner = _G.act.shortTermPlaner.withRelativePos(shortTermPlaner, space.locToPos(absoluteHomeLoc))

            local startPos = util.copyTable(shortTermPlaner.turtlePos)

            -- Wait for ice to melt
            navigate.moveTo(shortTermPlaner, { x=0, y=0, z=1 })
            highLevelCommands.waitUntilDetectBlock(shortTermPlaner, {
                expectedBlockId = 'WATER',
                direction = 'down',
                endFacing = 'S'
            })

            -- Move water
            highLevelCommands.findAndSelectSlotWithItem(shortTermPlaner, 'BUCKET')
            commands.turtle.placeDown(shortTermPlaner, 'left')
            commands.turtle.forward(shortTermPlaner)
            commands.turtle.placeDown(shortTermPlaner)
            commands.turtle.select(shortTermPlaner, 1)

            navigate.moveTo(shortTermPlaner, startPos)
            commands.turtle.digDown(shortTermPlaner, 'left')
            commands.mockHooks.registerCobblestoneRegenerationBlock(shortTermPlaner, { x=0, y=-1, z=0 })

            return { done = true }, shortTermPlaner.shortTermPlan
        end
    })
end

function harvestCobblestoneProject(opts)
    local absoluteHomeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    return _G.act.project.register('mainIsland:harvestCobblestoneProject', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlaner = _G.act.shortTermPlaner.create({ absTurtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlaner, absoluteHomeLoc)
            local shortTermPlaner = _G.act.shortTermPlaner.withRelativePos(shortTermPlaner, space.locToPos(absoluteHomeLoc))

            local startPos = util.copyTable(shortTermPlaner.turtlePos)

            for i = 1, 32 do
                highLevelCommands.waitUntilDetectBlock(shortTermPlaner, {
                    expectedBlockId = 'COBBLESTONE',
                    direction = 'down',
                    endFacing = 'ANY'
                })
                commands.turtle.digDown(shortTermPlaner, 'left')
            end
            highLevelCommands.reorient(shortTermPlaner, startPos.face)

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