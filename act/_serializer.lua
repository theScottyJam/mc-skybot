local util = import('util.lua')
local json = import('./_json.lua')

local module = {}

local idsToRegisteredValues = {}
local registeredValuesToIds = {}

-- Registers a value with a unique id.
-- If a reference to this same value is seen during serialization, it will instead be serialized to a special
-- id-holding table. When this table gets deserialized, it'll be swapped back with the registered value.
function module.registerValue(id, value)
    -- The same value is technically allowed to be registered multiple times under different IDs.
    -- If this happens, the idsToRegisteredValues table will map all these different ids to the same value,
    -- while registeredValuesToIds will map the value to one of the valid ids (which, with this implementation, will
    -- be the last id registered)
    --
    -- It might not be strictly necessary to support this kind of duplication with the
    -- way the code is currently written, but it's still good to have support for it
    -- in case it's needed in the future, to remove potential suprises when using this function.
    util.assert(idsToRegisteredValues[id] == nil, 'Duplicate id '..id..' found.')
    idsToRegisteredValues[id] = value
    registeredValuesToIds[value] = id
end

-- refCount will be mutated.
-- It maps tables to the number of times the table was seen in the data structure.
local countReferences
countReferences = function(data, refCount)
    -- Don't examine registered values - we only want to check circular references
    -- for data we're trying to JSON-encode.
    if registeredValuesToIds[data] ~= nil then
        return
    end

    if type(data) ~= 'table' then
        return
    end

    if refCount[data] == nil then
        refCount[data] = 0
    end
    refCount[data] = refCount[data] + 1

    -- If a circular reference is detected, return early to break the cycle
    if refCount[data] > 1 then
        return
    end

    for key, value in pairs(data) do
        countReferences(value, refCount)
    end

    local metatable = getmetatable(data)
    if metatable ~= nil then
        countReferences(metatable, refCount)
    end
end

-- isRootTable is either true or omitted (nil).
local toJsonData
toJsonData = function(data, context, isRootTable)
    if registeredValuesToIds[data] ~= nil then
        return { __externalRef = registeredValuesToIds[data] }
    end

    if type(data) ~= 'table' then
        return data
    end

    -- Check if this table has already been converted to JSON. If so,
    -- return a reference to it.
    if context.seenTablesToRefId[data] ~= nil then
        return { __internalRef = context.seenTablesToRefId[data] }
    end
    
    util.assert(
        data.__internalRef == nil and data.__externalRef == nil or data.__metatable == nil,
        'Can not serialize data with a "__internalRef", "__externalRef", or "__metatable" field - these field are given special meaning by the serializer.'
    )

    local jsonData = {}
    if context.refCount[data] > 1 or isRootTable then
        local refId = context.nextRefId
        context.nextRefId = context.nextRefId + 1
        context.seenTablesToRefId[data] = refId
    end

    -- We recurse inwards (below) after we've marked this value as seen in the context table (which is done above).

    for key, value in pairs(data) do
        jsonData[key] = toJsonData(value, context)
    end

    local metatable = getmetatable(data)
    if metatable ~= nil then
        jsonData.__metatable = toJsonData(metatable, context)
    end

    -- Did we just finish converting a table that's referenced in multiple places, or the root table?
    -- Then add it to context.refs instead of returning it.
    if context.seenTablesToRefId[data] ~= nil then
        local refId = context.seenTablesToRefId[data]
        context.refs[refId] = jsonData
        if isRootTable then
            -- If this is the root table, then we want to return context.refs, as that's
            -- what we actually want to JSON-encode, as it holds all of the references.
            -- The first reference in context.refs should be the root table.
            return context.refs
        end
        -- Note that the way this function is coded, these refIds point to an actual table,
        -- not another special __internalRef table, __externalRef table,
        -- or a primitive. The JSON-decoding logic depends on this assumption. See §IHR7f.
        return { __internalRef = context.seenTablesToRefId[data] }
    end

    return jsonData
end

local fromJsonData
fromJsonData = function(jsonData, context)
    if type(jsonData) ~= 'table' then
        return jsonData
    end

    -- addNewTableDataHere will be mutated to receive the new table's contents.
    -- This is needed to help handle circular references, where you might need
    -- to insert your parent table as your child, but your parent table isn't
    -- fully built yet, because your table isn't built.
    local tableFromJsonData
    tableFromJsonData = function(jsonData, context, addNewTableDataHere)
        for key, value in pairs(jsonData) do
            if key ~= '__metatable' then
                addNewTableDataHere[key] = fromJsonData(value, context)
            end
        end

        if jsonData.__metatable ~= nil then
            local metatable = fromJsonData(jsonData.__metatable)
            setmetatable(addNewTableDataHere, metatable)
        end
    end

    if jsonData.__externalRef ~= nil then
        local value = idsToRegisteredValues[jsonData.__externalRef]
        util.assert(value ~= nil)
        return value
    elseif jsonData.__internalRef ~= nil then
        if context.refIdToTable[jsonData.__internalRef] ~= nil then
            return context.refIdToTable[jsonData.__internalRef]
        else
            local data = {}

            -- Insert a reference to data, then mutate data to contain the appropriate contents.
            -- This is done so that we can recurse inwards and assign the partially-complete data table
            -- to other areas in the JSON tree.
            context.refIdToTable[jsonData.__internalRef] = data

            -- Note that refIds point to an actual table, not another special __internalRef table, __externalRef table,
            -- or a primitive. See §IHR7f.
            tableFromJsonData(context.refs[jsonData.__internalRef], context, data)

            return data
        end
    else
        local data = {}
        tableFromJsonData(jsonData, context, data)
        return data
    end
end

function module.serialize(data)
    local refCount = {} -- This will be mutated.
    countReferences(data, refCount)

    local context = {
        refCount = refCount,
        -- This will be mutated
        nextRefId = 1,
        -- This will be mutated
        seenTablesToRefId = {},
        -- This will be mutated.
        refs = {}
    }

    return json.encode(toJsonData(data, context, true))
end

function module.deserialize(text)
    local refs = json.decode(text)
    local context = {
        refs = refs,
        -- This will be mutated
        refIdToTable = {},
    }
    return fromJsonData({ __internalRef = 1 }, context)
end

return module