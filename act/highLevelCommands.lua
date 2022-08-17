local util = import('util.lua')

local module = {}

function module.init(registerCommand)
    local highLevelCommands = {}

    highLevelCommands.transferToFirstEmptySlot = registerCommand(
        'highLevelCommands:transferToFirstEmptySlot',
        function(state, setupState)
            local firstEmptySlot = nil
            for i = 1, 16 do
                local count = turtle.getItemCount(i)
                if count == 0 then
                    firstEmptySlot = i
                    break
                end
            end
            if firstEmptySlot == nil then
                error('Failed to find an empty slot.')
            end
            local success = turtle.transferTo(firstEmptySlot)
            if not success then
                error('Failed to transfer to the first empty slot (was the source empty?)')
            end
        end
    )

    highLevelCommands.findAndSelectSlotWithItem = registerCommand(
        'highLevelCommands:findAndSelectSlotWithItem',
        function(state, setupState, itemIdToFind)
            for i = 1, 16 do
                local slotInfo = turtle.getItemDetail(i)
                if slotInfo ~= nil then
                    local itemIdInSlot = string.upper(util.splitString(slotInfo.name, ':')[2])
                    if itemIdInSlot == itemIdToFind then
                        turtle.select(i)
                        return
                    end
                end
            end
            error('Failed to find the specific item.')
        end
    )

    -- opts.expectedBlockId is the blockId you're waiting for
    -- opts.direction is 'up' or 'down' ('front' is not yet supported).
    -- opts.endFacing. Can be a facing or 'ANY', or 'CURRENT' (the default)
    --   If set to 'ANY', you MUST use highLevelCommands.reorient() to fix your facing
    --   when you're ready to depend on it again.
    highLevelCommands.waitUntilDetectBlock = registerCommand(
        'highLevelCommands:waitUntilDetectBlock',
        function(state, setupState, opts)
            local space = _G.act.space

            local expectedBlockId = opts.expectedBlockId
            local direction = opts.direction
            local endFacing = opts.endFacing

            if endFacing == 'CURRENT' or endFacing == nil then
                endFacing = space.posToFace(state.turtlePos)
            end

            local inspectFn
            if direction == 'up' then
                inspectFn = turtle.inspectUp
            elseif direction == 'down' then
                inspectFn = turtle.inspectDown
            else
                error('Invalid direction')
            end

            local success, blockInfo = inspectFn()
            local minecraftBlockId = blockInfo.name
            if not success then
                minecraftBlockId = 'minecraft:air'
            end

            local blockId = string.upper(util.splitString(minecraftBlockId, ':')[2])
            if blockId ~= expectedBlockId then
                turtle.turnRight() -- Wait for a bit
                state.turtlePos.face = space.rotateFaceClockwise(state.turtlePos.face)
                -- If endFacing is 'CURRENT' (or nil), we need to swap it for a calculated direction,
                -- so the next command that runs knows the original facing.
                local newOpts = util.mergeTables(opts, { endFacing = endFacing })
                table.insert(state.shortTermPlan, 1, { command = 'highLevelCommands:waitUntilDetectBlock', args = {newOpts} })
            elseif endFacing ~= 'ANY' then
                table.insert(state.shortTermPlan, 1, { command = 'highLevelCommands:reorient', args = {endFacing} })
            end
        end,
        {
            onSetup = function(shortTermPlanner, opts)
                local endFacing = opts.endFacing

                local turtlePos = shortTermPlanner.turtlePos
                if endFacing == 'CURRENT' or endFacing == nil then
                    -- Do nothing
                elseif endFacing == 'ANY' then
                    turtlePos.face = 'left' -- 'left' is the "random" direction you end up facing
                else
                    turtlePos.face = endFacing.face
                end
            end
        }
    )

    -- Uses runtime facing information instead of the ahead-of-time planned facing to orient yourself a certain direction.
    -- This is important after doing a high-level command that could put you facing a random direction, and there's no way
    -- to plan a specific number of turn-lefts/rights to fix it in advance.
    highLevelCommands.reorient = registerCommand(
        'highLevelCommands:reorient',
        function(state, setupState, targetFacing)
            if state.turtlePos.from ~= targetFacing.from then error('incompatible "from" fields') end
            local space = _G.act.space
        
            local beforeFace = state.turtlePos.face
            local rotations = space.countClockwiseRotations(beforeFace, targetFacing.face)
        
            if rotations == 1 then
                turtle.turnRight()
            elseif rotations == 2 then
                turtle.turnRight()
                turtle.turnRight()
            elseif rotations == 3 then
                turtle.turnLeft()
            end
            state.turtlePos.face = targetFacing.face
        end, {
            onSetup = function(shortTermPlanner, targetFacing)
                if shortTermPlanner.turtlePos.from ~= targetFacing.from then error('incompatible "from" fields') end
                shortTermPlanner.turtlePos.face = targetFacing.face
            end
        }
    )

    return highLevelCommands
end

return module
