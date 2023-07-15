local module = {}

local util = import('util.lua')

function trim(str)
    return string.match(str, '^%s*(.-)%s*$')
end

-- endPos should be one past the end of the extract
function createExtract(charStream, startPos, endPos)
    local targetText = string.sub(charStream.source, startPos.index, endPos.index - 1)
    -- `end` should point to the character at one passed the end of the range.
    local range = { start = startPos, end_ = endPos }
    return {
        value = targetText,
        range = range,
        -- `fields` is optional, and is used to set additional token fields, or override existing ones.
        intoToken = function(tokenName, fields)
            if fields == nil then files = {} end
            return util.mergeTables({
                type = tokenName,
                value = targetText, -- `value` is often used to help build error messages.
                range = range,
            }, fields)
        end,
        -- Builds a larger extract by grabbing this extract, the other extract, and everything in between.
        joinWith = function(otherExtract)
            return createExtract(charStream, startPos, otherExtract.range.end_)
        end
    }
end

function createCharStream(source, fileName)
    local colNum = 1
    local lineNum = 1
    local index = 1
    local charStream
    charStream = {
        source = source,
        atEnd = function()
            if index > #source + 1 then
                error('The character stream was found to be passed the end, when it should not have been.')
            end
            return index == #source + 1
        end,
        -- `end_` is optional.
        slice = function(start, end_)
            start = start + index
            if end_ ~= nil then end_ = end_ + index end
            return string.sub(source, start, end_)
        end,
        -- `i` is optional.
        at = function(i)
            if i == nil then i = 0 end
            return string.sub(source, index + i, index + i)
        end,
        -- `amount` is optional and defaults to 1.
        advance = function(amount)
            if amount == nil then amount = 1 end
            for i = 1, amount do
                if string.sub(source, index, index) == '\n' then
                    lineNum = lineNum + 1
                    colNum = 1
                else
                    colNum = colNum + 1
                end
                index = index + 1
                if index > #source + 1 then
                    error('Attempted to advance the character stream passed the end')
                end
            end
        end,
        getPosition = function()
            return {
                fileName = fileName,
                colNum = colNum,
                lineNum = lineNum,
                index = index,
            }
        end,
        -- May return nil
        extract = function(patterns)
            for _, pattern in ipairs(patterns) do
                local start, end_ = string.find(source, pattern, index)
                if start == index then
                    local startPos = charStream.getPosition()
                    charStream.advance(end_ - start + 1)
                    local endPos = charStream.getPosition()
                    return createExtract(charStream, startPos, endPos)
                end
            end
            return nil
        end,
    }

    return charStream
end

local getNextToken = function(charStream)
    local extracted

    local somethingInterestingRemoved
    repeat
        somethingInterestingRemoved = false
        extracted = charStream.extract({'%s+'})
        if extracted ~= nil then somethingInterestingRemoved = true end

        extracted = charStream.extract({'%-%-!'})
        if extracted ~= nil then
            -- First pattern tries to go to the next new line. If that fails (because there isn't another new line),
            -- just eat everything up until the end of the file.
            local contentExtracted = charStream.extract({'.-\n', '.*$'})
            return extracted.joinWith(contentExtracted).intoToken('DIRECTIVE', {
                trimmedValue = trim(contentExtracted.value)
            })
        end

        extracted = charStream.extract({'%-%-'})
        if extracted ~= nil then
            -- First pattern tries to go to the next new line. If that fails (because there isn't another new line),
            -- just eat everything up until the end of the file.
            extracted = charStream.extract({'.-\n', '.*$'})
            somethingInterestingRemoved = true
        end
    until somethingInterestingRemoved == false

    extracted = charStream.extract({'%d+'})
    if extracted ~= nil then
        return extracted.intoToken('NUMBER', {
            valueAsNumber = tonumber(extracted.value)
        })
    end

    extracted = charStream.extract({'+', '-', '*', '/', '=', '{', '}', '%[', '%]', '%(', '%)', ',', '%.%.', '%.'})
    if extracted ~= nil then
        return extracted.intoToken('OPERATOR')
    end

    -- The %f[^%a] sequence is needed to make sure we're not ripping apart words when we match.
    -- e.g. the word endThis is a single identifier, not the keyword "end" followed by the identifier "This".
    local b = '%f[^%a_]' -- `b` for `boundary`
    extracted = charStream.extract({
        'return'..b,
        'local'..b,
        'function'..b,
        'if'..b,
        'then'..b,
        'elseif'..b,
        'else'..b,
        'end'..b,
        'for'..b,
        'do'..b,
    })
    if extracted ~= nil then
        return extracted.intoToken('KEYWORD')
    end

    extracted = charStream.extract({'[%a_][%a%d_]*'})
    if extracted ~= nil then
        return extracted.intoToken('IDENTIFIER')
    end

    if charStream.at() == "'" or charStream.at() == '"' then
        return extractString(charStream)
    end

    if charStream.atEnd() then
        local pos = charStream.getPosition()
        return {
            type = 'EOF',
            value = '<EOF>',
            range = { start=pos, end_=pos },
        }
    end

    local snippet = charStream.slice(0, 15)
    error('Failed to understand the following syntax: '..snippet..'…')
end

function extractString(charStream)
    local startPos = charStream.getPosition()
    local deliminater = charStream.at()
    local stringContent = ''
    local escaped = false
    while true do
        charStream.advance()
        local char = charStream.at()
        if char == '\n' or charStream.atEnd() then
            local extract = createExtract(charStream, startPos, charStream.getPosition())
            error('Failed to find a matching quote for a string literal: '..extract.value..'…')
        end
        if not escaped and char == deliminater then
            break
        end
        if escaped then
            local unescapedChar
            if char == 'n' then unescapedChar = '\n'
            elseif char == "'" then unescapedChar = "'"
            elseif char == '"' then unescapedChar = '"'
            elseif char == '\\' then unescapedChar = '\\'
            else error('Unknown escape character in string literal: "\\'..char..'".')
            end
            stringContent = stringContent .. unescapedChar
            escaped = false
        elseif not escaped and char == '\\' then
            escaped = true
        else
            stringContent = stringContent .. char
        end
    end
    charStream.advance()
    local endPos = charStream.getPosition()

    local extract = createExtract(charStream, startPos, endPos)
    return extract.intoToken('STRING', {
        stringContent = stringContent
    })
end

function module.createTokenStream(source, fileName)
    local charStream = createCharStream(source, fileName)
    local index = 1
    local bufferedToken1 = getNextToken(charStream)
    local bufferedToken2 = getNextToken(charStream)
    return {
        peek = function(lookahead)
            if lookahead == 1 or lookahead == nil then
                return bufferedToken1
            elseif lookahead == 2 then
                return bufferedToken2
            else
                error('Invalid lookahead parameter')
            end
        end,
        next = function()
            local lastBuffered = bufferedToken1
            bufferedToken1 = bufferedToken2
            bufferedToken2 = getNextToken(charStream)
            return lastBuffered
        end,
    }
end

return module
