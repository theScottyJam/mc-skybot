local module = {}

local util = import('util.lua')
local turtleScriptModule = lazyImport('./init.lua')

local nodeTypes = {}

local createWeakTable = function()
    return setmetatable({}, { __mode = "k" })
end

-- Values should be of the shape
-- {
--   paramNames = string[],
--   body = <ast>,
--   closedOverVars = <map of var names to { content= ... }>,
-- }
local functionToAst = createWeakTable()

local runtimeError = function(message, state)
    local nodeId = state.nodeStack[#state.nodeStack].nodeId
    local node = state.nodeLookup[nodeId]
    local pos = node.pos
    local posStr = pos.fileName .. ':' .. pos.lineNum
    error('Runtime error at ' .. posStr .. ': ' .. message)
end

local stateOps
stateOps = {
    init = function(rootNodeId, nodeLookup, opts)
        opts = opts or {}
        local initialLocalVars = util.copyTable(opts.initialLocalVars or {})

        return {
            -- `returnValue` is nil, until the program is finished and there's (maybe) something to return.
            returnValue = nil,
            nodeStack = {
                {
                    nodeId = rootNodeId,
                    subNodeValues = {},
                    -- Can either be `false` or `{ receivingValue = ... }`
                    assignmentTarget = false,
                    -- `true` if this is the first entry of a call stack
                    beginsCallStackFrame = false,
                }
            },
            -- When you enter a function, info about the current state is kept here,
            -- so it can be recovered when you leave the function.
            -- Has the shape { variables=... }[]
            callStack = {},
            -- Values are of the shape { content=... }
            -- Only contains variables that are currently in scope
            variables = initialLocalVars,
            -- Not actual state, just reference data
            nodeLookup = nodeLookup,
        }
    end,
    isDone = function(state)
        return #state.nodeStack == 0
    end,
    getActiveNodeId = function(state)
        return state.nodeStack[#state.nodeStack].nodeId
    end,
    isAssignmentTarget = function(state)
        return state.nodeStack[#state.nodeStack].assignmentTarget ~= false
    end,
    getAssignmentTargetReceivingValue = function(state)
        if state.nodeStack[#state.nodeStack].assignmentTarget == false then
            error('Can only call getAssignmentTargetReceivingValue() when the node is set as the assignment target')
        end
        return state.nodeStack[#state.nodeStack].assignmentTarget.receivingValue
    end,
    -- `opts` is optional. Available fields:
    --   assignmentTarget: Defaults to `false`. Can instead be set to `{ receivingValue = ... }`
    --     if this is a node on the left-hand side of an assignment, that's being assigned a value.
    --   newCallStackFrameInfo: Defaults to `nil`. Can be set to { localVars = <map var names to { content=... }> }.
    --     When true, existing state will be packed into a call stack
    --     frame, and a new "slate" will be provided as the descendant expression runs, initialized with the
    --     information provided.
    -- This will update the state to ask the program runner to, on the next step, execute the provided
    -- child nodes. When this returns true, it's expected that the caller will do an early return,
    -- to allow the program runner to start executing at a particular child node.
    updateStateToHandleDescendants = function(state, children, opts)
        local subNodeValues = state.nodeStack[#state.nodeStack].subNodeValues
        for _, childNode in ipairs(children) do
            if subNodeValues[childNode.nodeId] == nil then
                stateOps.forceUpdateStateToHandleDesendent(state, childNode, opts)
                return true
            end
        end
        return false
    end,
    -- Similar to updateStateToHandleDescendants(), except:
    -- * You can only update one child with this, not a list of children
    -- * Even if the desendent has already been evaluated, its previous completion
    --   value will be wiped out and it will be re-evaluated.
    -- * You must have your calling function return after calling this, so that
    --   the desendent can be handled. This is different from updateStateToHandleDescendants()
    --   which returns a boolean asking you return or not depending on the value of the bool.
    --   Control won't go back to the outer function until the desendent has been fully evaluated.
    --
    -- The `opts` parameter is the same as `updateStateToHandleDescendants()`
    forceUpdateStateToHandleDesendent = function(state, child, opts)
        if opts == nil then opts = {} end
        local assignmentTarget = opts.assignmentTarget or false
        local newCallStackFrameInfo = opts.newCallStackFrameInfo or nil

        if newCallStackFrameInfo ~= nil then
            table.insert(state.callStack, {
                variables = state.variables,
            })
            state.variables = util.copyTable(newCallStackFrameInfo.localVars)
        end

        table.insert(state.nodeStack, {
            nodeId = child.nodeId,
            subNodeValues = {},
            assignmentTarget = assignmentTarget,
            beginsCallStackFrame = newCallStackFrameInfo ~= nil,
        })
    end,
    -- After a sub-node has evaluated, you can use this to fetch its completion value.
    getSubExprValue = function(state, childNode)
        local valueEntry = state.nodeStack[#state.nodeStack].subNodeValues[childNode.nodeId]
        if valueEntry == nil then
            error('Value not found for '..childNode.nodeId)
        end
        return valueEntry.content
    end,
    declareVar = function(state, varName, newValue)
        if state.variables[varName] ~= nil then
            runtimeError('Variable "' .. varName .. '" got re-declared', state)
        end
        state.variables[varName] = { content = newValue }
    end,
    assignVar = function(state, varName, newValue)
        if state.variables[varName] == nil then
            runtimeError('Attempted to assign to an undeclared variable "' .. varName .. '".', state)
        end
        state.variables[varName].content = newValue
    end,
    -- Returns a { content = ... } object or nil if it is not found.
    -- Having a ref can be useful, because you'll always have your hands
    -- on an up-to-date value, and you can prevent it from
    -- being garbage collected by hanging onto it (closures use this to hold onto outside
    -- variables, long after they would have normally been cleaned up).
    lookupVarRef = function(state, varName)
        if state.variables[varName] ~= nil then
            return state.variables[varName]
        end
        if _G[varName] ~= nil then
            return { content = _G[varName] }
        end
        return nil
    end,
    lookupVar = function(state, varName)
        local ref = stateOps.lookupVarRef(state, varName)
        if ref == nil then
            runtimeError('Failed to find variable ' .. varName .. ' in the current scope', state)
        end
        return ref.content
    end,
    -- Calls `fn()`. If fn() throws, the error will be auto-converted
    -- to a proper runtime error with a helpful error location information.
    runUnsafeFn = function (state, fn)
        local success, errorOrValue = pcall(fn)
        if success then
            return errorOrValue
        else
            -- This will technically fail to properly remove the stacktrace if this test is
            -- ever running in a directory that has `: ` in one of the folder names.
            local errorMessage = string.gsub(errorOrValue, '^.-: ', '')
            runtimeError(errorMessage, state)
        end
    end,
    -- completionValue is optional, and defaults to `nil`
    completeExec = function (state, completionValue)
        -- If this is the end of a function
        if state.nodeStack[#state.nodeStack].beginsCallStackFrame then
            stateOps.returnFromFunctionOrModule(state)
            return
        else
            local topStackEntry = table.remove(state.nodeStack)
            -- Only set the completion value if there's a node stack frame
            -- able to receive it. Might not happen if we're at the root of an
            -- externally-called function call.
            if #state.nodeStack > 0 then
                local subNodeValues = state.nodeStack[#state.nodeStack].subNodeValues
                subNodeValues[topStackEntry.nodeId] = { content = completionValue }
            end
        end
    end,
    -- getCompletionValue should either return the completion value, or throw
    -- an error, which will be auto-converted into a proper runtime error (by using runUnsafeFn())
    safeCompleteExec = function(state, getCompletionValue)
        local completionValue = stateOps.runUnsafeFn(state, getCompletionValue)
        stateOps.completeExec(state, completionValue)
    end,
    -- returnValue is optional, and defaults to `nil`
    returnFromFunctionOrModule = function(state, returnValue)
        if #state.callStack == 0 then
            -- return from the module
            state.nodeStack = {}
            state.returnValue = returnValue
            return
        end

        -- Remove node stack entries until we're where we should be
        local topStackEntry
        while true do
            if #state.nodeStack == 0 then error('Unreachable state') end
            topStackEntry = table.remove(state.nodeStack)
            if topStackEntry.beginsCallStackFrame then
                break
            end
        end

        -- pop the call stack entry
        local callStackFrame = table.remove(state.callStack)
        state.variables = callStackFrame.variables
        local subNodeValues = state.nodeStack[#state.nodeStack].subNodeValues
        subNodeValues[topStackEntry.nodeId] = { content = returnValue }
    end
}

local registerNodeType = function(name, opts)
    if nodeTypes[name] then error('Node with name ' .. name .. ' already exists') end
    local canBeAssignmentTarget = false
    if opts.canBeAssignmentTarget ~= nil then canBeAssignmentTarget = opts.canBeAssignmentTarget end

    nodeTypes[name] = {
        canBeAssignmentTarget = canBeAssignmentTarget,
        init = opts.init,
        getVariablesNeeded = opts.getVariablesNeeded or nil,
        closureBoundary = opts.closureBoundary or false,
        children = opts.children,
        exec = opts.exec,
    }

    module[name] = function(pos, ...)
        local nodeType = nodeTypes[name]
        local nodeContent = nodeType.init(table.unpack({ ... }))

        local variablesNeeded = {}
        if nodeType.getVariablesNeeded ~= nil then
            variablesNeeded = nodeType.getVariablesNeeded(nodeContent)
        end

        local node
        node = {
            name = name,
            -- The `nodeId` doesn't get set until buildLookup() is called.
            nodeId = nil,
            pos = pos,
            -- The `varsToCapture` doesn't get set until buildLookup() is called,
            -- and only if `closureBoundary` is true.
            varsToCapture = nil,
            -- Builds both the lookup table, and calculates variables needed for closures.
            buildLookup = function(idPath)
                node.nodeId = idPath
                local lookup = { [idPath] = node }
                local currentVarsNeeded = util.copyTable(variablesNeeded)
                for i, childNode in ipairs(nodeType.children(nodeContent)) do
                    local subPath = idPath .. '.' .. i
                    local subLookup, subVarsNeeded = childNode.buildLookup(subPath)
                    util.mergeTablesInPlace(lookup, subLookup)
                    util.extendsArrayTableInPlace(currentVarsNeeded, subVarsNeeded)
                end
                if nodeType.closureBoundary then
                    node.varsToCapture = currentVarsNeeded
                end
                return lookup, currentVarsNeeded
            end,
            exec = function(state)
                local children = nodeType.children(nodeContent)
                nodeType.exec(state, nodeContent, children, {
                    -- `varsToCapture` is only set when `closureBoundary` is true.
                    varsToCapture = node.varsToCapture,
                })
            end,
            canBeAssignmentTarget = canBeAssignmentTarget,
        }
        return node
    end
end

local buildArgNameToValueMapping = function(paramNames, argValues)
    local argNamesToValueRefs = {}
    for i, paramName in ipairs(paramNames) do
        if i <= #argValues then
            argNamesToValueRefs[paramName] = { content = argValues[i] }
        else
            argNamesToValueRefs[paramName] = { content = nil }
        end
    end
    return argNamesToValueRefs
end

registerNodeType('root', {
    init = function(innerNode)
        return innerNode
    end,
    children = function(innerNode)
        return {innerNode}
    end,
    exec = function(state, exprNode, children)
        if stateOps.updateStateToHandleDescendants(state, children) then return end
        stateOps.returnFromFunctionOrModule(state)
    end,
})

registerNodeType('block', {
    init = function(statementNodes)
        return statementNodes
    end,
    children = function(statementNodes)
        return statementNodes
    end,
    exec = function(state, statementNodes, children)
        if stateOps.updateStateToHandleDescendants(state, children) then return end
        stateOps.completeExec(state)
    end,
})

registerNodeType('add', {
    init = function(left, right)
        return { left = left, right = right }
    end,
    children = function(innerNodes)
        return {innerNodes.left, innerNodes.right}
    end,
    exec = function(state, innerNodes, children)
        if stateOps.updateStateToHandleDescendants(state, children) then return end
        local leftValue = stateOps.getSubExprValue(state, innerNodes.left)
        local rightValue = stateOps.getSubExprValue(state, innerNodes.right)
        stateOps.safeCompleteExec(state, function()
            return leftValue + rightValue
        end)
    end,
})

registerNodeType('return_', {
    init = function(exprNode)
        return exprNode
    end,
    children = function(exprNode)
        return {exprNode}
    end,
    exec = function(state, exprNode, children)
        if stateOps.updateStateToHandleDescendants(state, children) then return end
        local innerValue = stateOps.getSubExprValue(state, exprNode)
        stateOps.returnFromFunctionOrModule(state, innerValue)
    end,
})

registerNodeType('nil_', {
    init = function()
        return nil
    end,
    children = function()
        return {}
    end,
    exec = function(state, value, children)
        stateOps.completeExec(state, nil)
    end,
})

registerNodeType('boolean', {
    init = function(value)
        return value
    end,
    children = function()
        return {}
    end,
    exec = function(state, value, children)
        stateOps.completeExec(state, value)
    end,
})

registerNodeType('number', {
    init = function(value)
        return value
    end,
    children = function(value)
        return {}
    end,
    exec = function(state, value, children)
        stateOps.completeExec(state, value)
    end,
})

registerNodeType('string', {
    init = function(value)
        return value
    end,
    children = function(value)
        return {}
    end,
    exec = function(state, value, children)
        stateOps.completeExec(state, value)
    end,
})

registerNodeType('table', {
    -- keyToNodeEntries is a list of entries of the shape
    -- [{ static = <string> } | { dynamic = <node> }, <node>]
    init = function(keyToNodeEntries)
        return keyToNodeEntries
    end,
    children = function(keyToNodeEntries)
        return util.flatArrayTable(util.mapArrayTable(keyToNodeEntries, function(entry)
            if entry[1].dynamic then
                return {entry[1].dynamic, entry[2]}
            else
                return {entry[2]}
            end
        end))
    end,
    exec = function(state, keyToNodeEntries, children)
        if stateOps.updateStateToHandleDescendants(state, children) then return end
        local newTable = {}
        for i, entry in ipairs(keyToNodeEntries) do
            newValue = stateOps.getSubExprValue(state, entry[2])
            local newKey
            if entry[1].static then
                newKey = entry[1].static
            else
                newKey = stateOps.getSubExprValue(state, entry[1].dynamic)
            end
            stateOps.runUnsafeFn(state, function()
                newTable[newKey] = newValue
            end)
        end
        stateOps.completeExec(state, newTable)
    end,
})

registerNodeType('function_', {
    init = function(paramNames, body)
        return { paramNames = paramNames, body = body }
    end,
    closureBoundary = true,
    children = function(innerNodes)
        return {innerNodes.body}
    end,
    exec = function(state, innerNodes, children, info)
        local varsToCapture = info.varsToCapture

        local closedOverVars = {}
        for i, varName in ipairs(varsToCapture) do
            local ref = stateOps.lookupVarRef(state, varName)
            closedOverVars[varName] = ref
        end

        -- When `fn` is called outside the script, this is what executed.
        -- This has the limitation that this function can not be paused while it runs.
        -- When `fn` is called inside the script, the AST assosiated with it
        -- is looked up and that is used instead.
        local fn = function(...)
            local argValues = {...}
            local argNamesToValueRefs = buildArgNameToValueMapping(innerNodes.paramNames, argValues)
            local turtleScript = turtleScriptModule.load()
            return turtleScript.runFromAstTree(module.astTreeApi(innerNodes.body, {
                initialLocalVars = util.mergeTables(argNamesToValueRefs, closedOverVars),
                nodeLookup = state.nodeLookup,
            }))
        end

        functionToAst[fn] = {
            paramNames = innerNodes.paramNames,
            body = innerNodes.body,
            closedOverVars = closedOverVars,
        }
        stateOps.completeExec(state, fn)
    end,
})

registerNodeType('declare', {
    init = function(varName, maybeValueNode)
        return { varName = varName, maybeValueNode = maybeValueNode }
    end,
    children = function(content)
        if content.maybeValueNode ~= nil then
            return {content.maybeValueNode}
        else
            return {}
        end
    end,
    exec = function(state, content, children)
        if stateOps.updateStateToHandleDescendants(state, children) then return end
        local newValue = nil
        if content.maybeValueNode ~= nil then
            newValue = stateOps.getSubExprValue(state, content.maybeValueNode)
        end
        stateOps.declareVar(state, content.varName, newValue)
        stateOps.completeExec(state)
    end
})

registerNodeType('assign', {
    init = function(lValueNode, rValueNode)
        return { lValueNode = lValueNode, rValueNode = rValueNode }
    end,
    children = function(content)
        return {content.lValueNode, content.rValueNode}
    end,
    exec = function(state, content, children)
        if stateOps.updateStateToHandleDescendants(state, {content.rValueNode}) then return end
        local rValue = stateOps.getSubExprValue(state, content.rValueNode)
        local lValueOpts = { assignmentTarget = { receivingValue = rValue } }
        if stateOps.updateStateToHandleDescendants(state, {content.lValueNode}, lValueOpts) then return end
        stateOps.completeExec(state)
    end
})

registerNodeType('variableLookup', {
    canBeAssignmentTarget = true,
    init = function(varName)
        return varName
    end,
    children = function(varName)
        return {}
    end,
    getVariablesNeeded = function(varName)
        return {varName}
    end,
    exec = function(state, varName, children)
        if stateOps.isAssignmentTarget(state) then
            local receivingValue = stateOps.getAssignmentTargetReceivingValue(state)
            stateOps.assignVar(state, varName, receivingValue)
            stateOps.completeExec(state)
        else
            local value = stateOps.lookupVar(state, varName)
            stateOps.completeExec(state, value)
        end
    end
})

registerNodeType('staticPropertyAccess', {
    canBeAssignmentTarget = true,
    init = function(left, rightIdentifier)
        return { left = left, rightIdentifier = rightIdentifier }
    end,
    children = function(innerNodes)
        return {innerNodes.left}
    end,
    exec = function(state, innerNodes, children)
        if stateOps.updateStateToHandleDescendants(state, children) then return end
        if stateOps.isAssignmentTarget(state) then
            local receivingValue = stateOps.getAssignmentTargetReceivingValue(state)
            local leftValue = stateOps.getSubExprValue(state, innerNodes.left)
            stateOps.safeCompleteExec(state, function()
                leftValue[innerNodes.rightIdentifier] = receivingValue
            end)
            stateOps.completeExec(state)
        else
            local leftValue = stateOps.getSubExprValue(state, innerNodes.left)
            stateOps.safeCompleteExec(state, function()
                return leftValue[innerNodes.rightIdentifier]
            end)
        end
    end,
})

registerNodeType('dynamicPropertyAccess', {
    canBeAssignmentTarget = true,
    init = function(left, key)
        return { left = left, key = key }
    end,
    children = function(innerNodes)
        return {innerNodes.left, innerNodes.key}
    end,
    exec = function(state, innerNodes, children)
        if stateOps.updateStateToHandleDescendants(state, children) then return end
        if stateOps.isAssignmentTarget(state) then
            local receivingValue = stateOps.getAssignmentTargetReceivingValue(state)
            local leftValue = stateOps.getSubExprValue(state, innerNodes.left)
            local keyValue = stateOps.getSubExprValue(state, innerNodes.key)
            stateOps.safeCompleteExec(state, function()
                leftValue[keyValue] = receivingValue
            end)
            stateOps.completeExec(state)
        else
            local leftValue = stateOps.getSubExprValue(state, innerNodes.left)
            local keyValue = stateOps.getSubExprValue(state, innerNodes.key)
            stateOps.safeCompleteExec(state, function()
                return leftValue[keyValue]
            end)
        end
    end,
})

registerNodeType('ifThen', {
    init = function(condition, ifBlock, elseBlock)
        return { condition = condition, ifBlock = ifBlock, elseBlock = elseBlock }
    end,
    children = function(innerNodes)
        if innerNodes.elseBlock == nil then
            return {innerNodes.condition, innerNodes.ifBlock}
        else
            return {innerNodes.condition, innerNodes.ifBlock, innerNodes.elseBlock}
        end
    end,
    exec = function(state, innerNodes, children)
        if stateOps.updateStateToHandleDescendants(state, {innerNodes.condition}) then return end
        local condition = stateOps.getSubExprValue(state, innerNodes.condition)
        if condition then
            if stateOps.updateStateToHandleDescendants(state, {innerNodes.ifBlock}) then return end
        elseif innerNodes.elseBlock ~= nil then
            if stateOps.updateStateToHandleDescendants(state, {innerNodes.elseBlock}) then return end
        end
        stateOps.completeExec(state)
    end
})

registerNodeType('cStyleForLoop', {
    -- opts should be of the shape
    -- { loopVar = ..., start = ..., end_ = ..., block = ... }
    init = function(opts)
        return opts
    end,
    children = function(innerNodes)
        return {innerNodes.start, innerNodes.end_, innerNodes.block}
    end,
    exec = function(state, innerNodes, children)
        if stateOps.updateStateToHandleDescendants(state, {innerNodes.start, innerNodes.end_}) then return end
        local loopVarName = innerNodes.loopVar
        local startValue = stateOps.getSubExprValue(state, innerNodes.start)
        local endValue = stateOps.getSubExprValue(state, innerNodes.end_)

        local declaring = stateOps.lookupVarRef(state, loopVarName) == nil
        if declaring then
            stateOps.declareVar(state, loopVarName, startValue)
        end
        local loopVar = stateOps.lookupVar(state, loopVarName)

        if loopVar + 1 > endValue then
            stateOps.completeExec(state)
        else
            if not declaring then
                stateOps.assignVar(state, loopVarName, loopVar + 1)
            end
    
            stateOps.forceUpdateStateToHandleDesendent(state, innerNodes.block)
        end
    end
})

registerNodeType('callFn', {
    init = function(fn, args)
        return { fn = fn, args = args }
    end,
    children = function(innerNodes)
        return {innerNodes.fn, table.unpack(innerNodes.args)}
    end,
    exec = function(state, innerNodes, children)
        if stateOps.updateStateToHandleDescendants(state, children) then return end
        local fn = stateOps.getSubExprValue(state, innerNodes.fn)
        local args = {}
        for i, argNode in ipairs(innerNodes.args) do
            table.insert(args, stateOps.getSubExprValue(state, argNode))
        end

        -- If this function is defined by turtlescript
        if functionToAst[fn] ~= nil then
            local fnAst = functionToAst[fn]
            local argNamesToValueRefs = buildArgNameToValueMapping(fnAst.paramNames, args)
            local newCallStackFrameInfo = { localVars = util.mergeTables(argNamesToValueRefs, fnAst.closedOverVars) }
            if stateOps.updateStateToHandleDescendants(state, { fnAst.body }, { newCallStackFrameInfo = newCallStackFrameInfo }) then return end
            local completionValue = stateOps.getSubExprValue(state, fnAst.body)
            stateOps.completeExec(state, completionValue)
        else
            stateOps.safeCompleteExec(state, function()
                return fn(table.unpack(args))
            end)
        end
    end
})

-- opts.initialLocalVars is an optional map of variable names to `{ content = ... }`.
-- opts.nodeLookup can be provided if a node lookup has already been built for these AST nodes,
--   so this function doesn't try to rebuild it.
function module.astTreeApi(rootNode, opts)
    opts = opts or {}
    local initialLocalVars = opts.initialLocalVars or {}
    local nodeLookup = opts.nodeLookup or nil

    if nodeLookup == nil then
        nodeLookup = rootNode.buildLookup('0')
    end
    local state = stateOps.init(rootNode.nodeId, nodeLookup, { initialLocalVars = initialLocalVars })

    return {
        nextStep = function()
            if stateOps.isDone(state) then error('Can not do a step when the program is finished') end
            local activeNodeId = stateOps.getActiveNodeId(state)
            local activeNode = nodeLookup[activeNodeId]

            if stateOps.isAssignmentTarget(state) and not activeNode.canBeAssignmentTarget then
                runtimeError('Node of type "' .. activeNode.name .. '" can not be used as the target of an assignment', state)
            end

            activeNode.exec(state)
            return stateOps.isDone(state), state.returnValue
        end,
    }
end

return module
