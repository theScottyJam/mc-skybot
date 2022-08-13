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
    -- local nowhereInParticularLoc = _G.act.location.register(space.resolveRelPos({ x=5, y=8, z=5, face='E' }, bedrockPos))

    local harvestInitialTree = harvestInitialTreeProject({ bedrockPos = bedrockPos, homeLoc = homeLoc })
    local buildBasicCobblestoneGenerator = buildBasicCobblestoneGeneratorProject({ bedrockPos = bedrockPos, homeLoc = homeLoc })

    return {
        init = function()
            -- _G.act.location.registerPath(homeLoc, nowhereInParticularLoc, {
            --     space.resolveRelCoord({ x=0, y=8, z=0 }, bedrockPos),
            --     space.resolveRelCoord({ x=5, y=8, z=0 }, bedrockPos)
            -- })
        end,
        entity = {
            homeLoc = homeLoc,
            harvestInitialTree = harvestInitialTree,
            buildBasicCobblestoneGenerator = buildBasicCobblestoneGenerator
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

function buildBasicCobblestoneGeneratorProject(opts)
    local absoluteBedrockPos = opts.bedrockPos
    local absoluteHomeLoc = opts.homeLoc

    local location = _G.act.location
    local navigate = _G.act.navigate
    local commands = _G.act.commands
    local highLevelCommands = _G.act.highLevelCommands
    local space = _G.act.space

    return _G.act.project.register('mainIsland:buildBasicCobblestoneGenerator', {
        createProjectState = function()
            return { done = false }
        end,
        nextShortTermPlan = function(state, projectState)
            if projectState.done == true then
                return nil, nil
            end

            local shortTermPlaner = _G.act.shortTermPlaner.create({ absTurtlePos = state.turtlePos })
            location.travelToLocation(shortTermPlaner, absoluteHomeLoc)
            local shortTermPlaner = _G.act.shortTermPlaner.withRelativePos(shortTermPlaner, absoluteHomeLoc)

            local startPos = util.copyTable(shortTermPlaner.turtlePos)

            -- Dig cobblestone mining spot
            navigate.face(shortTermPlaner, 'W')
            commands.turtle.digDown(shortTermPlaner, 'left')
            commands.turtle.down(shortTermPlaner)
            commands.turtle.dig(shortTermPlaner, 'left')
            commands.turtle.digDown(shortTermPlaner, 'left')
            
            -- Dig out east branch
            navigate.moveTo(shortTermPlaner, { x=0, y=0, z=0, face='E' })
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
            highLevelCommands.transferToFirstEmptySlot(shortTermPlaner, firstEmptySlot)
            commands.turtle.select(shortTermPlaner, 1)

            -- Dig out west branch
            navigate.moveTo(shortTermPlaner, { x=0, y=0, z=0, face='S' })
            for i = 1, 2 do
                commands.turtle.forward(shortTermPlaner)
                commands.turtle.digDown(shortTermPlaner, 'left')
            end

            -- Place water down
            commands.turtle.select(shortTermPlaner, ICE_SLOT)
            commands.turtle.placeDown(shortTermPlaner)
            commands.turtle.select(shortTermPlaner, 1)

            navigate.moveTo(shortTermPlaner, startPos)

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