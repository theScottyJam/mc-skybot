local turtlescript = import('./init.lua')
local run = turtlescript.run

local runContent = function (source)
    return turtlescript.run('--! TURTLE SCRIPT\n'..source)
end

---- Testing framework ----
local test, testOnly, runTests, assert, getErrorMessage
do
    local successCount = 0
    local failCount = 0
    local allTests = {}
    local focusTests = {}
    test = function(message, testFn)
        table.insert(allTests, function()
            local success, maybeError = xpcall(testFn, debug.traceback)
            if success then
                print('✓ ' .. message)
                successCount = successCount + 1
            else
                print('✕ ' .. message)
                print(maybeError)
                print()
                failCount = failCount + 1
            end
        end)
    end

    testOnly = function(message, testFn)
        test(message, testFn)
        table.insert(focusTests, allTests[#allTests])
    end

    runTests = function()
        local testsToRun = allTests
        if #focusTests > 0 then testsToRun = focusTests end
        for _, testFn in ipairs(testsToRun) do
            testFn()
        end

        print()
        print('Completed ' .. successCount .. '/' .. successCount + failCount)
        if failCount > 0 then
            print()
            print('ERROR: Not all tests ran successfuly')
        end
    end

    assert = {
        -- `message` is optional
        ok = function(condition, message)
            if not condition then
                error(message or 'Assertion Failed.')
            end
        end,
        equal = function(actual, expectation)
            if actual ~= expectation then
                error(
                    'Expected the following values to be equal.\n'..
                    'expectation: '..tostring(expectation)..'\n'..
                    'actual:      '..tostring(actual)
                )
            end
        end,
        containString = function(actual, expectation)
            if type(actual) ~= 'string' then
                error('Expected the following to be a string: ' .. tostring(actual))
            end
            if not string.find(actual, expectation, nil, true) then
                error(
                    'Expected value 1 to contain value 2.\n1: ' .. tostring(actual)
                    .. '\n2: ' .. tostring(expectation)
                )
            end
        end,
    }

    getErrorMessage = function(fn, ...)
        local success, maybeError = pcall(fn, table.unpack({ ... }))
        if success then
            error('Expected the function to throw')
        end

        -- This will technically fail to properly remove the stacktrace if this test is
        -- ever running in a directory that has `: ` in one of the folder names.
        return string.gsub(maybeError, '^.-: ', '')
    end
end

test('it is a syntax error to not contain turtlescript directive up top', function()
    local error = getErrorMessage(run, 'return 0')
    assert.equal(error, 'The first line of a turtlescript file must be the `--! TURTLE SCRIPT` directive.')
end)

test('able to run an empty script (aside from the "TURTLE SCRIPT" directive)', function()
    run('--! TURTLE SCRIPT')
    run('--! TURTLE SCRIPT\n')
end)

test('line-comments', function()
    local result = runContent('-- example comment\nreturn 2')
    assert.equal(result, 2)
end)

test('line-comments can be found at the end of a file', function()
    local result = runContent('return 2\n-- there is an EOF right after this, not a newline')
    assert.equal(result, 2)
end)

test('unexpected EOF', function()
    local error = getErrorMessage(runContent, 'local x =')
    assert.equal(error, 'Expected to find an expression, but found «<EOF>»\nat <string input> 2:10')
end)

test('unexpected syntax', function()
    local error = getErrorMessage(runContent, 'local %&^')
    assert.equal(error, 'Failed to understand the following syntax: %&^…')
end)

test('it handles numeric literals', function()
    assert.equal(runContent('return 42'), 42)
end)

test('it handles nil literals', function()
    assert.equal(runContent('return nil'), nil)
end)

test('it handles the `true` boolean literal', function()
    assert.equal(runContent('return true'), true)
end)

test('it handles the `false` boolean literal', function()
    assert.equal(runContent('return false'), false)
end)

test('it can access the global table', function()
    assert.equal(runContent('return _G'), _G)
end)

test('it can directly access fields from the global table', function()
    assert.equal(runContent('return table'), table)
end)

-- add --
do
    local prefix = 'add: '

    test(prefix..'can add numbers', function()
        assert.equal(runContent('return 1 + 2 + 3'), 6)
    end)

    test(prefix..'can not add with nil', function()
        local error = getErrorMessage(runContent, 'return 1 + nil')
        assert.equal(error, "Runtime error at <string input>:2: attempt to perform arithmetic on a nil value (upvalue 'rightValue')")
    end)
end

-- declarations --
do
    local prefix = 'declarations: '
    -- syntax --

    test(prefix..'an identifier is expected after "local"', function()
        local error = getErrorMessage(runContent, 'local 42')
        assert.equal(error, 'Expected to find an identifier after `local`, but found «42»\nat <string input> 2:7')
    end)

    test(prefix..'an equals sign (or next statement) is expected after the variable name in a declaration', function()
        local error = getErrorMessage(runContent, 'local value +')
        assert.equal(error, 'Expected a statement, but found «+»\nat <string input> 2:13')
    end)

    -- semantics --

    test(prefix..'can not redeclare a variable', function()
        local error = getErrorMessage(runContent, 'local value = 2\nlocal value = 3')
        assert.equal(error, 'Runtime error at <string input>:3: Variable "value" got re-declared')
    end)

    -- behavior --

    test(prefix..'able to declare then use a variable', function()
        local value = runContent('local value = 2\nreturn value')
        assert.equal(value, 2)
    end)

    test(prefix..'able to declare without assigning', function()
        local value = runContent('local value\nreturn value')
        assert.equal(value, nil)
    end)

    test(prefix..'can declare a veriable with a keyword in the name', function()
        local value = runContent('local endIf = 2\n return endIf')
        assert.equal(value, 2)
    end)
end

-- assignments --
do
    local prefix = 'assignments: '
    test(prefix..'invalid expression in an lvalue', function()
        local error = getErrorMessage(runContent, 'a + 3 = 99')
        assert.equal(error, 'Runtime error at <string input>:2: Node of type "add" can not be used as the target of an assignment')
    end)

    test(prefix..'able to reassign', function()
        local value = runContent('local x = 2\nx = 3\nreturn x')
        assert.equal(value, 3)
    end)
end

-- strings --
do
    local prefix = 'strings: '
    -- syntax --

    test(prefix..'fail to terminate string before reaching EOF', function()
        local error = getErrorMessage(runContent, 'return "xxx')
        assert.equal(error, 'Failed to find a matching quote for a string literal: "xxx…')
    end)

    test(prefix..'fail to terminate string before reaching a nwe line', function()
        local error = getErrorMessage(runContent, 'return "xxx\nxx"')
        assert.equal(error, 'Failed to find a matching quote for a string literal: "xxx…')
    end)

    test(prefix..'invalid escape character', function()
        local error = getErrorMessage(runContent, 'return "\\x"')
        assert.equal(error, 'Unknown escape character in string literal: "\\x".')
    end)

    -- behavior --

    test(prefix..'able to create a string literal with single quotes', function()
        local value = runContent("return 'abc'")
        assert.equal(value, 'abc')
    end)

    test(prefix..'able to create a string literal with double quotes', function()
        local value = runContent('return "abc"')
        assert.equal(value, 'abc')
    end)

    test(prefix..'able to escape special characters in a string literal', function()
        local value = runContent("return \" \\' \\n \\\" \\\\ \"")
        assert.equal(value, " ' \n \" \\ ")
    end)

    test(prefix..'can use the opposite quote type inside a string without escaping it', function()
        local value = runContent("return \"a'c\"")
        assert.equal(value, "a'c")
    end)
end

-- tables --
do
    local prefix = 'tables: '
    -- syntax --

    test(prefix..'gives an error when missing a closing bracket', function()
        local error = getErrorMessage(runContent, 'return { x = 2')
        assert.equal(error, 'Expected to find "," or "}", but found «<EOF>»\nat <string input> 2:15')
    end)

    test(prefix..'gives an error when missing a comma', function()
        local error = getErrorMessage(runContent, 'return { x = 2 y = 3 }')
        assert.equal(error, 'Expected to find "," or "}", but found «y»\nat <string input> 2:16')
    end)

    -- Equivalently, this test shows a missing comma between two elements in an array-like table.
    test(prefix..'gives an error when missing an equal sign', function()
        local error = getErrorMessage(runContent, 'return { x 2 }')
        assert.equal(error, 'Expected to find "," or "}", but found «2»\nat <string input> 2:12')
    end)

    test(prefix..'gives an error when missing an identifier', function()
        local error = getErrorMessage(runContent, 'return { = 2 }')
        assert.equal(error, 'Expected to find an expression, but found «=»\nat <string input> 2:10')
    end)

    test(prefix..'gives an error when missing closing dynamic key bracket', function()
        local error = getErrorMessage(runContent, "return { [1+2 = '3' }")
        assert.equal(error, 'Expected to find a closing bracket ("]"), but found «=»\nat <string input> 2:15')
    end)

    test(prefix..'gives an error when missing an equal sign after a dynamic key', function()
        local error = getErrorMessage(runContent, "return { [1+2], '3' }")
        assert.equal(error, 'Expected to find an equal sign ("="), but found «,»\nat <string input> 2:15')
    end)

    -- behavior --
    
    test(prefix..'can create a table', function()
        local value = runContent("return { x = 2, y = 3 }")
        assert.equal(value.x, 2)
        assert.equal(value.y, 3)
    end)

    test(prefix..'can create an empty table', function()
        local value = runContent("return {}")
        assert.equal(value.something, nil)
    end)

    test(prefix..'can create a array-like table', function()
        local value = runContent("return {2, 3}")
        assert.equal(value[1], 2)
        assert.equal(value[2], 3)
    end)

    test(prefix..'can create a table that mixes positional and key-value elements', function()
        local value = runContent("return {2, key='value', 3}")
        assert.equal(value[1], 2)
        assert.equal(value.key, 'value')
        assert.equal(value[2], 3)
    end)

    test(prefix..'can create a table with a dynamic key', function()
        local value = runContent("return { [1+2] = '3' }")
        assert.equal(value[3], '3')
    end)
end

-- static property access --
do
    local prefix = 'static property access: '
    -- syntax --

    test(prefix..'gives an error when the right side of the dot is not an identifier', function()
        local error = getErrorMessage(runContent, "local tbl = {}\nreturn tbl.3")
        assert.equal(error, 'Expected to find an identifier, but found «3»\nat <string input> 3:12')
    end)

    -- behavior --

    test(prefix..'able to access an existing table property', function()
        local value = runContent('local tbl = { x = 2 }\nreturn tbl.x')
        assert.equal(value, 2)
    end)

    test(prefix..'able to access a nested property', function()
        local value = runContent('local tbl = { x = { y = 2 } }\nreturn tbl.x.y')
        assert.equal(value, 2)
    end)

    test(prefix..'gives the nil value when the property does not exist', function()
        local value = runContent('local tbl = {}\nreturn tbl.x')
        assert.equal(value, nil)
    end)

    test(prefix..'able to assign to a table field', function()
        local value = runContent('local tbl = {}\ntbl.x = 2\nreturn tbl')
        assert.equal(value.x, 2)
    end)

    test(prefix..'able to assign to a nested field', function()
        local value = runContent('local tbl = { x = { y = 4 } }\ntbl.x.y = 2\nreturn tbl')
        assert.equal(value.x.y, 2)
    end)
end

-- dynamic property access --
do
    local prefix = 'dynamic property access: '
    -- syntax --

    test(prefix..'gives an error when missing the right bracket', function()
        local error = getErrorMessage(runContent, "local tbl = {}\nreturn tbl['x'")
        assert.equal(error, 'Expected to find a closing square bracket ("]"), but found «<EOF>»\nat <string input> 3:15')
    end)

    -- behavior --

    test(prefix..'able to access an existing table property', function()
        local value = runContent('local tbl = { x = 2 }\nreturn tbl["x"]')
        assert.equal(value, 2)
    end)

    test(prefix..'able to access a nested property', function()
        local value = runContent('local tbl = { x = { y = 2 } }\nreturn tbl["x"]["y"]')
        assert.equal(value, 2)
    end)

    test(prefix..'able to mix static and dynamic property access', function()
        local value = runContent('local tbl = { x = { y = 2 } }\nreturn tbl.x["y"]')
        assert.equal(value, 2)
    end)

    test(prefix..'gives the nil value when the property does not exist', function()
        local value = runContent('local tbl = {}\nreturn tbl["x"]')
        assert.equal(value, nil)
    end)

    test(prefix..'able to index into array-like tables with numbers', function()
        local value = runContent('local tbl = {42}\nreturn tbl[1]')
        assert.equal(value, 42)
    end)

    test(prefix..'able to assign to a table field', function()
        local value = runContent('local tbl = {}\ntbl["x"] = 2\nreturn tbl')
        assert.equal(value.x, 2)
    end)

    test(prefix..'able to assign to a nested field', function()
        local value = runContent('local tbl = { x = { y = 4 } }\ntbl["x"]["y"] = 2\nreturn tbl')
        assert.equal(value.x.y, 2)
    end)

    test(prefix..'able to mix static and dynamic property access when assigning', function()
        local value = runContent('local tbl = { x = { y = 4 } }\ntbl.x["y"] = 2\nreturn tbl')
        assert.equal(value.x.y, 2)
    end)
end

-- if-then --
do
    local prefix = 'if-then: '
    -- syntax --

    test(prefix..'missing "then (test 1)"', function()
        local error = getErrorMessage(runContent, "if true return 2")
        assert.equal(error, 'Expected to find "then" at the end if the "if" condition, but found «return»\nat <string input> 2:9')
    end)

    test(prefix..'missing "then" (test 2)', function()
        local error = getErrorMessage(runContent, "if true then return 1\nelse if false return 2 end")
        assert.equal(error, 'Expected to find "then" at the end if the "if" condition, but found «return»\nat <string input> 3:15')
    end)

    test(prefix..'missing "end"', function()
        local error = getErrorMessage(runContent, "if true then return 1")
        assert.equal(error, 'Encountered an EOF while looking for one of {"elseif, else, end"} to terminate the block.\nat <string input> 2:14')
    end)

    -- behavior --
    test(prefix..'you enter the if block if the condition is true', function()
        local value = runContent('if true then return "yes" end return "no"')
        assert.equal(value, 'yes')
    end)

    test(prefix..'you do not enter the if block if the condition is false', function()
        local value = runContent('if false then return "yes" end return "no"')
        assert.equal(value, 'no')
    end)

    test(prefix..'you do not enter the else block if the condition is true', function()
        local value = runContent('if true then return "yes" else return "no" end')
        assert.equal(value, 'yes')
    end)

    test(prefix..'you enter the else block if the condition is false', function()
        local value = runContent('if false then return "yes" else return "no" end')
        assert.equal(value, 'no')
    end)

    test(prefix..'larger if-else chain (test 1)', function()
        local value = runContent(
            'local x\nif false then return "bad" elseif true then x = 2 else return "bad" end\nreturn x'
        )
        assert.equal(value, 2)
    end)

    test(prefix..'larger if-else chain (test 2)', function()
        local value = runContent('local x\nif false then return "bad" elseif true then return "good" end')
        assert.equal(value, 'good')
    end)

    test(prefix..'larger if-else chain (test 3)', function()
        local value = runContent('local x\nif true then x = 1 elseif true then return "bad" end\n return x')
        assert.equal(value, 1)
    end)
end

-- function call --
do
    local prefix = 'function call: '
    -- syntax --

    test(prefix..'forbids trailing commas', function()
        local error = getErrorMessage(runContent, "local tbl = {}\ntable.insert(tbl,2,)")
        assert.equal(error, 'Expected to find an expression, but found «)»\nat <string input> 3:20')
    end)

    test(prefix..'missing comma error', function()
        local error = getErrorMessage(runContent, "local tbl = {}\ntable.insert(tbl 2)")
        assert.equal(error, 'Expected to find a comma (","), but found «2»\nat <string input> 3:18')
    end)

    -- behavior --
    test(prefix..'can call native functions', function()
        local value = runContent('local tbl = {}\ntable.insert(tbl, 2)\nreturn tbl')
        assert.equal(value[1], 2)
    end)

    test(prefix..'throws a proper error when calling a function with bad arguments', function()
        local error = getErrorMessage(runContent, 'table.insert(nil, nil)')
        assert.equal(error, "Runtime error at <string input>:2: bad argument #1 to 'fn' (table expected, got no value)")
    end)
end

-- functions --
do
    local prefix = 'functions: '
    -- syntax --

    test(prefix..'missing left parentheses error', function()
        local error = getErrorMessage(runContent, "return function x) end")
        assert.equal(error, 'Expected to find an opening parentheses ("("), but found «x»\nat <string input> 2:17')
    end)

    test(prefix..'forbids trailing commas', function()
        local error = getErrorMessage(runContent, "return function (x,y,) return 2 end")
        assert.equal(error, 'Expected to find an identifier, but found «)»\nat <string input> 2:22')
    end)

    -- behavior --

    test(prefix..'can declare and call a function', function()
        local value = runContent('local fn = function(x) return x + 1 end\nreturn fn(2) + 1')
        assert.equal(value, 4)
    end)

    test(prefix..'can declare and call a function with extra arguments', function()
        local value = runContent('local fn = function(x) return x + 1 end\nreturn fn(2, 5) + 1')
        assert.equal(value, 4)
    end)

    test(prefix..'can declare and call a function without enough arguments', function()
        local value = runContent('local fn = function(x) return { arg = x } end\nreturn fn()')
        assert.equal(value.arg, nil)
    end)

    test(prefix..'can declare and call a function without a `return`', function()
        local value = runContent('local fn = function() end\nreturn { result = fn() }')
        assert.equal(value.result, nil)
    end)

    test(prefix..'can declare and return a function', function()
        local value = runContent('return function(x) return x + 1 end')
        assert.equal(value(2), 3)
    end)

    test(prefix..'can declare and return a function, that is later called with too many arguments', function()
        local value = runContent('return function(x) return x + 1 end')
        assert.equal(value(2, 5), 3)
    end)

    test(prefix..'can declare and return a function, that is later called without enough arguments', function()
        local value = runContent('return function(x) return { arg = x } end')
        assert.equal(value().arg, nil)
    end)

    test(prefix..'can declare a function that takes no parameters', function()
        local value = runContent('return function() return true end')
        assert.equal(value(), true)
    end)

    test(prefix..'can declare a function without a `return`, and call it from outside', function()
        local fn = runContent('return function() end')
        assert.equal(fn(), nil)
    end)

    test(prefix..'can use an external higher order function', function()
        local fn = runContent([[
return function(outsideHigherOrderFn)
    return outsideHigherOrderFn(function(x)
        return x + 1
    end)
end
        --]])
        local result = fn(function(fn2) return fn2(5) end)

        assert.equal(result, 6)
    end)
end

-- closures --
do
    local prefix = 'closures: '
    -- behavior --

    test(prefix..'can use a closed over variable in a function that is defined and called in turtlescript', function()
        local value = runContent('local x = 2\nlocal fn = function() return x end\n return fn()')
        assert.equal(value, 2)
    end)

    test(prefix..'can use a closed over variable in a function that is defined in turtlescript but called outside', function()
        local fn = runContent('local x = 2\nreturn function() return x end')
        assert.equal(fn(), 2)
    end)

    test(prefix..'can assign to a closed over variable', function()
        local value = runContent('local x = 2\nlocal fn = function(y) x = y end\nfn(3)\nreturn x')
        assert.equal(value, 3)
    end)
end

runTests()
