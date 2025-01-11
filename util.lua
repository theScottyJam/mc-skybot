local module = {}

function module.attachPrototype(prototype, table)
    setmetatable(table, { __index = prototype })
    return table
end

function module.hasPrototype(table, prototype)
    local metatable = getmetatable(table)
    return metatable and metatable.__index == prototype
end

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

-- (NOTE: This function is currently unused)
-- Iterates over the table and returns the first key/value pair found.
-- WARNING: Because tables don't preserve order, plucking the first entry can lead to non-deterministic behavior.
--          Use getASortedEntry() instead if this is not desired (though be warned that the alternative is O(n))
function module.getAnEntry(table)
    for key, value in pairs(table) do
        return key, value
    end
    error('Failed to find a key in a provided object')
end

-- Returns the first entry who's key sorts the lowest.
-- This is like getAnEntry(), but deterministic.
function module.getASortedEntry(table)
    local lowestKey = nil
    for key, value in pairs(table) do
        if lowestKey == nil then
            lowestKey = key
        elseif lowestKey > key then
            lowestKey = key
        end
    end

    if lowestKey == nil then
        error('Failed to find a key in a provided object')
    end

    return lowestKey, table[lowestKey]
end

function module.countOccurrencesOfValuesInTable(curTable)
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

-- Like pairs(), but it will sort the keys to provide a deterministic iteration
-- order. This has O(n).
function module.sortedMapTablePairs(mapTable)
    local entries = {}
    for key, value in pairs(mapTable) do
        table.insert(entries, {key, value})
    end
    table.sort(entries, function (a, b) return a[1] < b[1] end)
    local i = 0
    return function()
        i = i + 1
        if i > #entries then return nil end
        return entries[i][1], entries[i][2]
    end
end

-- Like pairs() but works with strings
function module.stringPairs(str)
    local i = 0
    return function()
        i = i + 1
        if i > #str then return nil end
        return i, module.charAt(str, i)
    end
end

function module.charAt(str, index)
    return string.sub(str, index, index)
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

function module.createEventEmitter()
    local prototype = {}

    function prototype:subscribe(fn)
        table.insert(self._listeners, fn)
    end

    function prototype:trigger(...)
        for i, fn in ipairs(self._listeners) do
            fn(table.unpack({ ... }))
        end
    end

    return module.attachPrototype(prototype, {
        _listeners = {},
    })
end

return module