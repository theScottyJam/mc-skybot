-- Manually loads any test files we want to test.

import('./framework.lua').registerGlobals()

local runTestModule = function(path)
    import(path)
    testFramework.clearTestGroup()
end

runTestModule('turtlescript/test.lua')
runTestModule('act/modeling/Sketch.test.lua')

testFramework.runTests()
