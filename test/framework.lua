local module = {}

local successCount = 0
local failCount = 0
local allTests = {}
local focusTests = {}
local testGroup = nil
function module.test(message, testFn)
    if testGroup == nil then
        error('Please provide a test group name for this module before running tests against it.')
    end

    local fullMessage = testGroup .. ' > ' .. message

    table.insert(allTests, function()
        local success, maybeError = xpcall(testFn, debug.traceback)
        if success then
            print('✓ ' .. fullMessage)
            successCount = successCount + 1
        else
            print('✕ ' .. fullMessage)
            print(maybeError)
            print()
            failCount = failCount + 1
        end
    end)
end

function module.testOnly(message, testFn)
    module.test(message, testFn)
    table.insert(focusTests, allTests[#allTests])
end

function module.runTests()
    local testsToRun = allTests
    if #focusTests > 0 then testsToRun = focusTests end
    for _, testFn in ipairs(testsToRun) do
        testFn()
    end

    print()
    print('Completed ' .. successCount .. '/' .. successCount + failCount)
    if failCount > 0 then
        print()
        print('ERROR: Not all tests ran successfully')
    end
end

function module.testGroup(name)
    testGroup = name
end

function module.clearTestGroup(name)
    testGroup = nil
end

module.assert = {
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

function module.getErrorMessage(fn, ...)
    local success, maybeError = pcall(fn, table.unpack({ ... }))
    if success then
        error('Expected the function to throw')
    end

    -- This will technically fail to properly remove the stacktrace if this test is
    -- ever running in a directory that has `: ` in one of the folder names.
    return string.gsub(maybeError, '^.-: ', '')
end

function module.registerGlobals()
    _G.test = module.test
    _G.testOnly = module.testOnly
    _G.assert = module.assert
    _G.testFramework = module
end

return module
