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
    -- opts.endFacing. Can be 'N', 'E', 'S', 'W', 'ANY', or 'CURRENT' (the default)
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
                endFacing = state.turtlePos.face
            end

            local inspectFn
            if direction == 'up' then
                inspectFn = turtle.inspectUp
            elseif direction == 'down' then
                inspectFn = turtle.inspectDown
            else
                error('Invalid direction')
            end

            -- TODO: Add detection logic
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
            onSetup = function(shortTermPlaner, opts)
                local endFacing = opts.endFacing

                local turtlePos = shortTermPlaner.turtlePos
                if endFacing == 'CURRENT' or endFacing == nil then
                    -- Do nothing
                elseif endFacing == 'ANY' then
                    turtlePos.face = 'W' -- 'W' is the "random" direction you end up facing
                else
                    turtlePos.face = endFacing
                end
            end
        }
    )

    -- Uses runtime facing information instead of the ahead-of-time planned facing to orient yourself a certain direction.
    -- This is important after doing a high-level command that could put you facing a random direction, and there's no way
    -- to plan a specific number of turn-lefts/rights to fix it in advance.
    highLevelCommands.reorient = registerCommand(
        'highLevelCommands:reorient',
        function(state, setupState, targetFace)
            local beforeFace = state.turtlePos.face

            turnCommands = ({
                N = {N={}, E={'R'}, S={'R','R'}, W={'L'}},
                E = {E={}, S={'R'}, W={'R','R'}, N={'L'}},
                S = {S={}, W={'R'}, N={'R','R'}, E={'L'}},
                W = {W={}, N={'R'}, E={'R','R'}, S={'L'}},
            })[beforeFace][targetFace]

            for _, command in ipairs(turnCommands) do
                if command == 'R' then turtle.turnRight() end
                if command == 'L' then turtle.turnLeft() end
            end
            state.turtlePos.face = targetFace
        end, {
            onSetup = function(shortTermPlaner, targetFace)
                shortTermPlaner.turtlePos.face = targetFace
            end
        }
    )

    return highLevelCommands
end

return module
