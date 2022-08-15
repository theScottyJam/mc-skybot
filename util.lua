local module = {}

function module.mergeTablesInPlace(curTable, ...)
    for _, tableToMerge in ipairs({ ... }) do
        for key, value in pairs(tableToMerge) do
            curTable[key] = value
        end
    end
    return curTable
end

function module.mergeTables(...)
    return module.mergeTablesInPlace({}, table.unpack({...}))
end

function module.copyTable(curTable)
    local newTable = {}
    for key, value in pairs(curTable) do
        newTable[key] = value
    end
    return newTable
end

function module.tableContains(curTable, entry)
    for key, value in pairs(curTable) do
        if entry == value then
            return true
        end
    end
    return false
end

function module.reverseTable(curTable)
    local newTable = {}
    for i = #curTable, 1, -1 do
        table.insert(newTable, curTable[i])
    end
    return newTable
end

function module.filterArrayTable(curTable, filterFn)
    local newTable = {}
    for _, value in ipairs(curTable) do
        local keep = filterFn(value, key)
        if keep then
            table.insert(newTable, value)
        end
    end
    return newTable
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

-- Splits a string. Uses regular-expression matching to work, so not all separators will be valid.
function module.splitString (inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local newTable = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(newTable, str)
    end
    return newTable
end

return module