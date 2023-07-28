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

function module.extendsArrayTableInPlace(curTable, entriesToAdd)
    for i, value in ipairs(entriesToAdd) do
        table.insert(curTable, value)
    end
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

function module.flatArrayTable(curTable)
    local newTable = {}
    for i, array in ipairs(curTable) do
        for j, entry in ipairs(array) do
            table.insert(newTable, entry)
        end
    end
    return newTable
end

function module.findInArrayTable(curTable, predicate)
    for i, value in ipairs(curTable) do
        local isFound = predicate(value, i)
        if isFound then
            return value
        end
    end
    return nil
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

-- Converts {1, 2, 3, 4} to iterator<(1, 2), (3, 4)>
-- Meant to be used while iterating
function module.paired(curTable)
    local i = -1
    return function()
        i = i + 2
        if i > #curTable then return nil end
        return curTable[i], curTable[i + 1]
    end
end

-- Iterates over the table and returns the first key/value pair found.
function module.getAnEntry(table)
    for key, value in pairs(table) do
        return key, value
    end
    error('Failed to find a key in a provided object')
end

function module.countOccurancesOfValuesInTable(curTable)
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

function module.joinArrayTable(curTable, sep)
    if sep == nil then sep = ', ' end

    local result = ''
    for i, str in ipairs(curTable) do
        result = result..str
        if i ~= #curTable then
            result = result..sep
        end
    end
    return result
end

function module.indexOfMinNumber(first, ...)
    local min = first
    local minIndex = 1
    for i, value in ipairs({ ... }) do
        if min > value then
            min = value
            minIndex = i + 1
        end
    end
    return minIndex
end

function module.minNumber(...)
    local values = { ... }
    local minIndex = module.indexOfMinNumber(table.unpack(values))
    return values[minIndex]
end

function module.maxNumber(first, ...)
    local max = first
    local maxIndex = 1
    for i, value in ipairs({ ... }) do
        if max < value then
            max = value
            maxIndex = i + 1
        end
    end
    return max, maxIndex
end

function module.sum(curTable)
    local total = 0
    for _, value in ipairs(curTable) do
        total = total + value
    end
    return total
end

function module.assert(condition, message)
    local message = message or 'Assertion failed'
    if not condition then error(message) end
    return condition
end

return module