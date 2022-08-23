local util = import('util.lua')

local module = {}

function module.init(commands)
    local registerCommand = commands.registerCommand
    local registerCommandWithFuture = commands.registerCommandWithFuture

    local highLevelCommands = {}

    highLevelCommands.transferToFirstEmptySlot = registerCommand(
        'highLevelCommands:transferToFirstEmptySlot',
        function(state)
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

    highLevelCommands.findAndSelectSlotWithItem = registerCommandWithFuture(
        'highLevelCommands:findAndSelectSlotWithItem',
        function(state, itemIdToFind, opts)
            if opts == nil then opts = {} end
            local allowMissing = opts.allowMissing or false
            for i = 1, 16 do
                local slotInfo = turtle.getItemDetail(i)
                if slotInfo ~= nil then
                    local itemIdInSlot = slotInfo.name
                    if itemIdInSlot == itemIdToFind then
                        turtle.select(i)
                        return true
                    end
                end
            end
            if allowMissing then
                return false
            end
            error('Failed to find the specific item.')
        end,
        function(itemIdToFind, opts)
            return opts and opts.out
        end
    )

    -- opts.expectedBlockId is the blockId you're waiting for
    -- opts.direction is 'up' or 'down' ('front' is not yet supported).
    -- opts.endFacing. Can be a facing or 'ANY', or 'CURRENT' (the default)
    --   If set to 'ANY', you MUST use highLevelCommands.reorient() to fix your facing
    --   when you're ready to depend on it again. (The exception is if you let the
    --   current plan end while in an unknown position then try to fix the position
    --   in a new plan, as the turtle's real position becomes known between plans)
    highLevelCommands.waitUntilDetectBlock = registerCommand(
        'highLevelCommands:waitUntilDetectBlock',
        function(state, opts)
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
            local blockId = blockInfo.name
            if not success then
                minecraftBlockId = 'minecraft:air'
            end

            if blockId ~= expectedBlockId then
                turtle.turnRight() -- Wait for a bit
                state.turtlePos.face = space.rotateFaceClockwise(state.turtlePos.face)
                -- If endFacing is 'CURRENT' (or nil), we need to swap it for a calculated direction,
                -- so the next command that runs knows the original facing.
                local newOpts = util.mergeTables(opts, { endFacing = endFacing })
                table.insert(state.plan, 1, { command = 'highLevelCommands:waitUntilDetectBlock', args = {newOpts} })
            elseif endFacing ~= 'ANY' then
                table.insert(state.plan, 1, { command = 'highLevelCommands:reorient', args = {endFacing} })
            end
        end,
        {
            onSetup = function(planner, opts)
                local endFacing = opts.endFacing

                local turtlePos = planner.turtlePos
                if endFacing == 'CURRENT' or endFacing == nil then
                    -- Do nothing
                elseif endFacing == 'ANY' then
                    planner.turtlePos = {
                        forward=0,
                        right=0,
                        up=0,
                        face='forward',
                        from=util.mergeTables(
                            planner.turtlePos,
                            { face='UNKNOWN' }
                        )
                    }
                else
                    turtlePos.face = endFacing.face
                end
            end
        }
    )

    -- Uses runtime facing information instead of the ahead-of-time planned facing to orient yourself a certain direction
    -- relative to the origin.
    -- This is important after doing a high-level command that could put you facing a random direction, and there's no way
    -- to plan a specific number of turn-lefts/rights to fix it in advance.
    highLevelCommands.reorient = registerCommand(
        'highLevelCommands:reorient',
        function(state, targetFacing)
            if state.turtlePos.from ~= 'ORIGIN' then
                error('UNREACHABLE: A state.turtlePos.from value should always be "ORIGIN"')
            end
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
            onSetup = function(planner, targetFacing)
                local space = _G.act.space
                if targetFacing.from ~= 'ORIGIN' then
                    error('The targetFacing "from" field must be set to "ORIGIN"')
                end
                if planner.turtlePos.from == 'ORIGIN' then
                    error("There is no need to use reorient(), if the turtle's positition is completely known.")
                end

                local squashedPos = space.squashFromFields(planner.turtlePos)
                local unsupportedMovement = (
                    squashedPos.forward == 'UNKNOWN' or
                    squashedPos.right == 'UNKNOWN' or
                    squashedPos.up == 'UNKNOWN'
                )
                if unsupportedMovement then
                    error('The reoirient command currently only knows how to fix the "from" field when "face" is the only field set to "UNKNOWN" in the "from" chain.')
                end
                squashedPos.face = targetFacing.face
                planner.turtlePos = squashedPos
            end
        }
    )

    return highLevelCommands
end

return module
