local module = {}

function module.init(registerCommand)
    local highLevelCommands = {}

    highLevelCommands.transferToFirstEmptySlot = registerCommand('turtle:transferToFirstEmptySlot', function(state)
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
    end)

    return highLevelCommands
end

return module
