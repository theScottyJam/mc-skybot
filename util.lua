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
    for i, value in ipairs(curTable) do
        local keep = filterFn(value, i)
        if keep then
            table.insert(newTable, value)
        end
    end
    return newTable
end

function module.mapArrayTable(curTable, mapFn)
    local newTable = {}
    for i, value in ipairs(curTable) do
        table.insert(newTable, mapFn(value, i))
    end
    return newTable
end

function module.mapMapTable(curTable, mapFn)
    local newTable = {}
    for key, value in pairs(curTable) do
        newTable[key] = mapFn(value, key)
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

function module.subtractArrayTables(table1, table2)
    local resultTable = {}
    for _, value in pairs(table1) do
        if not module.tableContains(table2, value) then
            table.insert(resultTable, value)
        end
    end
    return resultTable
end

function module.coundOccurancesOfValuesInTable(curTable)
    local occurancesOfValues = {}
    for key, value in pairs(curTable) do
        if value ~= nil then
            if occurancesOfValues[value] == nil then
                occurancesOfValues[value] = 0
            end
            occurancesOfValues[value] = occurancesOfValues[value] + 1
        end
    end
    return occurancesOfValues
end

-- Splits a string. Uses regular-expression matching to work, so not all separators will be valid.
function module.splitString(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local newTable = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(newTable, str)
    end
    return newTable
end

function module.minNumber(first, ...)
    local min = first
    for _, value in pairs({ ... }) do
        if min > value then min = value end
    end
    return min
end

function module.maxNumber(first, ...)
    local max = first
    for _, value in pairs({ ... }) do
        if max < value then max = value end
    end
    return max
end

function module.assert(condition, message)
    local message = message or 'Assertion failed'
    if not condition then error(message) end
    return condition
end

return module