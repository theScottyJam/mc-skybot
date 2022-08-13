local module = {}

function module.mergeTablesInPlace(table, ...)
    for _, tableToMerge in ipairs({ ... }) do
        for key, value in pairs(tableToMerge) do
            table[key] = value
        end
    end
    return table
end

function module.mergeTables(...)
    return module.mergeTablesInPlace({}, table.unpack({...}))
end

function module.copyTable(table)
    local newTable = {}
    for key, value in pairs(table) do
        newTable[key] = value
    end
    return newTable
end

function module.tableContains(table, entry)
    for key, value in pairs(table) do
        if entry == value then
            return true
        end
    end
    return false
end

-- You can't use `#table` syntax to get the size of a table
-- if the table contains key-value pairs. (The result is undefined).
function module.tableSize(table)
    local count = 0
    for key, value in pairs(table) do
        count = count + 1
    end
    return count
end

return module