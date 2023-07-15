local module = {}

local nodes = import('./nodes.lua')
local util = import('../util.lua')

local syntaxError = function(message, range)
    error(
        message .. '\n'
        .. 'at ' .. range.start.fileName .. ' ' .. range.start.lineNum .. ':' .. range.start.colNum
    )
end

local parse = {}

function module.parse(tokenStream)
    local turtleScriptDirective = tokenStream.next()
    if turtleScriptDirective.type ~= 'DIRECTIVE' or turtleScriptDirective.trimmedValue ~= 'TURTLE SCRIPT' then
        error('The first line of a turtlescript file must be the `--! TURTLE SCRIPT` directive.')
    end

    local rootNode = nodes.root(turtleScriptDirective.range.start, parse.block(tokenStream))

    local eof = tokenStream.next()
    if eof.type ~= 'EOF' then error() end

    return nodes.astTreeApi(rootNode)
end

function parse.block(tokenStream, opts)
    opts = opts or {}
    -- `nil` means an EOF ends the block.
    -- Otherwise this should be a list of strings.
    local endsWith = opts.endsWith or nil

    local firstToken = tokenStream.peek()
    local endedWith
    local statementNodes = {}
    while true do
        -- tokenStream.peek().type ~= 'EOF' and (endWith == nil or tokenStream.peek().value ~= endsWith)
        if endsWith == nil and tokenStream.peek().type == 'EOF' then
            endedWith = nil
            break
        end
        if endsWith ~= nil then
            local matchesEndValue = util.findInArrayTable(endsWith, function(endsWithValue)
                return endsWithValue == tokenStream.peek().value end
            )
            if matchesEndValue then
                endedWith = tokenStream.next()
                break
            end
            if tokenStream.peek().type == 'EOF' then
                local joinedEndsWith = util.joinArrayTable(endsWith)
                syntaxError('Encountered an EOF while looking for one of {"'..joinedEndsWith..'"} to terminate the block.', firstToken.range)
            end
        end
        local nextStatement = parse.statement(tokenStream)
        table.insert(statementNodes, nextStatement)
    end

    return nodes.block(tokenStream.peek().range.start, statementNodes), endedWith
end

function parse.statement(tokenStream)
    if tokenStream.peek().type == 'KEYWORD' then
        local keywordToken = tokenStream.next()
        local keyword = keywordToken.value
        if keyword == 'return' then
            local returnValueNodes = {}
            while true do
                table.insert(returnValueNodes, parse.expression1(tokenStream))
                if tokenStream.peek().value == ',' then
                    tokenStream.next()
                else
                    break
                end
            end
            return nodes.return_(keywordToken.range.start, returnValueNodes)
        elseif keyword == 'local' then
            local identifier = tokenStream.next()
            if identifier.type ~= 'IDENTIFIER' then
                syntaxError('Expected to find an identifier after `local`, but found «' .. identifier.value .. '»', identifier.range)
            end
            local maybeRValue = nil
            if tokenStream.peek().type == 'OPERATOR' and tokenStream.peek().value == '=' then
                tokenStream.next()
                maybeRValue = parse.expression1(tokenStream)
            end
            return nodes.declare(keywordToken.range.start, identifier.value, maybeRValue)
        elseif keyword == 'if' then
            local keywordPos = keywordToken.range.start
            local ifChain = {}
            local finalElse = nil
            while true do
                local conditionExpr = parse.expression1(tokenStream)
                local thenToken = tokenStream.next()
                if thenToken.value ~= 'then' then
                    syntaxError('Expected to find "then" at the end if the "if" condition, but found «' .. thenToken.value .. '»', thenToken.range)
                end
                local ifBlock, endedWith = parse.block(tokenStream, { endsWith = {'elseif', 'else', 'end'} })
                table.insert(ifChain, { condition = conditionExpr, ifBlock = ifBlock, pos = keywordPos })
                keywordPos = endedWith.range.start
                if endedWith.value == 'else' then
                    finalElse = parse.block(tokenStream, { endsWith = {'end'} })
                    break
                elseif endedWith.value == 'end' then
                    break
                end
            end

            local current = finalElse -- may be nil, that's fine
            for i, chainLink in ipairs(util.reverseTable(ifChain)) do
                current = nodes.ifThen(chainLink.pos, chainLink.condition, chainLink.ifBlock, current)
            end
            return current
        elseif keyword == 'for' then
            local forLoopPos = keywordToken.range.start
            local loopVarToken = tokenStream.next()
            if loopVarToken.type ~= 'IDENTIFIER' then
                syntaxError('Expected to find an identifier after "for", but found «' .. loopVarToken.value .. '»', loopVarToken.range)
            end
            local equalToken = tokenStream.next()
            if equalToken.value ~= '=' then
                syntaxError('Expected to find an equal sign ("="), but found «' .. equalToken.value .. '»', equalToken.range)
            end
            local startExpr = parse.expression1(tokenStream)
            local commaToken = tokenStream.next()
            if commaToken.value ~= ',' then
                syntaxError('Expected to find a comma (",") to separate the start and end of the range, but found «' .. commaToken.value .. '»', commaToken.range)
            end
            local endExpr = parse.expression1(tokenStream)
            local doToken = tokenStream.next()
            if doToken.value ~= 'do' then
                syntaxError('Expected to find "do" to start the for loop\'s block, but found «' .. doToken.value .. '»', doToken.range)
            end
            local block = parse.block(tokenStream, { endsWith = {'end'} })

            return nodes.cStyleForLoop(forLoopPos, {
                loopVar = loopVarToken.value,
                start = startExpr,
                end_ = endExpr,
                block = block,
            })
        else
            error('Unexpected keyword: ' .. keyword)
        end
    elseif tokenStream.peek().type == 'IDENTIFIER' then
        -- Parses, e.g., `ab()` or `ab.cd``
        local exprNode = parse.expression1(tokenStream)
        if tokenStream.peek().type == 'OPERATOR' and tokenStream.peek().value == '=' then
            local assignToken = tokenStream.next()
            return nodes.assign(assignToken.range.start, exprNode, parse.expression1(tokenStream))
        end
        return exprNode
    else
        syntaxError('Expected a statement, but found «' .. tokenStream.peek().value .. '»', tokenStream.peek().range)
    end
end

function parse.expression1(tokenStream)
    local leftExpr = parse.expression2(tokenStream)

    if tokenStream.peek().type == 'OPERATOR' and tokenStream.peek().value == '+' then
        local addToken = tokenStream.next()
        return nodes.add(addToken.range.start, leftExpr, parse.expression1(tokenStream))
    end

    return leftExpr
end

function parse.expression2(tokenStream)
    local expr = parse.expression3(tokenStream)

    while true do
        if tokenStream.peek().value == '.' then
            local dotToken = tokenStream.next()
            local identifierToken = tokenStream.next()
            if identifierToken.type ~= 'IDENTIFIER' then
                syntaxError('Expected to find an identifier, but found «' .. identifierToken.value .. '»', identifierToken.range)
            end
            expr = nodes.staticPropertyAccess(dotToken.range.start, expr, identifierToken.value)
        elseif tokenStream.peek().value == '[' then
            local openBracketToken = tokenStream.next()
            local keyExpr = parse.expression1(tokenStream)
            local closeBracketToken = tokenStream.next()
            if closeBracketToken.value ~= ']' then
                syntaxError('Expected to find a closing square bracket ("]"), but found «' .. closeBracketToken.value .. '»', closeBracketToken.range)
            end
            expr = nodes.dynamicPropertyAccess(openBracketToken.range.start, expr, keyExpr)
        elseif tokenStream.peek().value == '(' then
            local openParanToken = tokenStream.next()
            local argNodes = {}
            if tokenStream.peek().value == ')' then
                tokenStream.next()
            else
                while true do
                    local argExpr = parse.expression1(tokenStream)
                    table.insert(argNodes, argExpr)
                    if tokenStream.peek().value == ')' then
                        tokenStream.next()
                        break
                    end
                    local commaToken = tokenStream.next()
                    if commaToken.value ~= ',' then
                        syntaxError('Expected to find a comma (","), but found «' .. commaToken.value .. '»', commaToken.range)
                    end
                end
            end
            expr = nodes.callFn(openParanToken.range.start, expr, argNodes)
        else
            break
        end
    end

    return expr
end

function parse.expression3(tokenStream)
    local nextToken = tokenStream.next()
    if nextToken.value == 'nil' then
        return nodes.nil_(nextToken.range.start)
    elseif nextToken.value == 'true' then
        return nodes.boolean(nextToken.range.start, true)
    elseif nextToken.value == 'false' then
        return nodes.boolean(nextToken.range.start, false)
    elseif nextToken.type == 'NUMBER' then
        return nodes.number(nextToken.range.start, nextToken.valueAsNumber)
    elseif nextToken.type == 'STRING' then
        return nodes.string(nextToken.range.start, nextToken.stringContent)
    elseif nextToken.type == 'IDENTIFIER' then
        return nodes.variableLookup(nextToken.range.start, nextToken.value)
    elseif nextToken.value == '{' then
        return parse.table(tokenStream, nextToken)
    elseif nextToken.value == 'function' then
        local functionToken = nextToken
        local openParanToken = tokenStream.next()
        if openParanToken.value ~= '(' then
            syntaxError('Expected to find an opening parentheses ("("), but found «' .. openParanToken.value .. '»', openParanToken.range)
        end

        local paramNames = {}
        if tokenStream.peek().value == ')' then
            tokenStream.next()
        else
            while true do
                local identifierToken = tokenStream.next()
                if identifierToken.type ~= 'IDENTIFIER' then
                    syntaxError('Expected to find an identifier, but found «' .. identifierToken.value .. '»', identifierToken.range)
                end
                table.insert(paramNames, identifierToken.value)
                if tokenStream.peek().value == ')' then
                    tokenStream.next()
                    break
                end
                local commaToken = tokenStream.next()
                if commaToken.value ~= ',' then
                    syntaxError('Expected to find a comma (","), but found «' .. commaToken.value .. '»', commaToken.range)
                end
            end
        end
        local fnBody = parse.block(tokenStream, { endsWith = {'end'} })
        return nodes.function_(functionToken.range.start, paramNames, fnBody)
    end

    syntaxError('Expected to find an expression, but found «' .. nextToken.value .. '»', nextToken.range)
end

function parse.table(tokenStream, openingBracketToken)
    local newTableEntries = {}
    local nextListKey = 1
    while true do
        if tokenStream.peek().value == '}' then
            tokenStream.next()
            return nodes.table(openingBracketToken.range.start, newTableEntries)
        end

        local key
        if tokenStream.peek().value == '[' then
            tokenStream.next()
            local keyNode = parse.expression1(tokenStream)
            local closingBracketToken = tokenStream.next()
            if closingBracketToken.value ~= ']' then
                syntaxError('Expected to find a closing bracket ("]"), but found «' .. closingBracketToken.value .. '»', closingBracketToken.range)
            end
            local equalToken = tokenStream.next()
            if equalToken.value ~= '=' then
                syntaxError('Expected to find an equal sign ("="), but found «' .. equalToken.value .. '»', equalToken.range)
            end
            key = { dynamic = keyNode }
        elseif tokenStream.peek(2).value == '=' then
            local identifierToken = tokenStream.next()
            tokenStream.next() -- Skip the `=` token
            if identifierToken.type ~= 'IDENTIFIER' then
                syntaxError('Expected to find an identifier, but found «' .. identifierToken.value .. '»', identifierToken.range)
            end

            key = { static = identifierToken.value }
        else
            key = { static = nextListKey }
            nextListKey = nextListKey + 1
        end

        local value = parse.expression1(tokenStream)
        table.insert(newTableEntries, {key, value})
        
        local separatorToken = tokenStream.peek()
        if separatorToken.value ~= '}' and separatorToken.value ~= ',' then
            syntaxError('Expected to find "," or "}", but found «' .. separatorToken.value .. '»', separatorToken.range)
        end
        if separatorToken.value == ',' then
            tokenStream.next()
        end
    end
end

return module
