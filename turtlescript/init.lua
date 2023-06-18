--[[
    There's technically a memory leak that I won't bother fixing, but I'll at least document it.
    If you close over a variable, and there's a variable with the same name in an outer scope,
    that variable will get captured as well, even though it's not the one being referenced. e.g.

    local x = 2
    return function()
        local x = 3
        return function()
            -- This is refering to the inner-most `x` variable,
            -- but both `x` variables will be captured, preventing the
            -- outer one from ever being cleaned up, even if it is unused.
            return x
        end
    end
]]

local module = {}

local tokenizer = import('./tokenizer.lua')
local parser = import('./parser.lua')

local buildAstTree = function(source)
    local tokenStream = tokenizer.createTokenStream(source, '<string input>')
    return parser.parse(tokenStream)
end

function module.run(source)
    return module.runFromAstTree(buildAstTree(source))
end

function module.runFromAstTree(astTree)
    while true do
        local done, returnValue = astTree.nextStep()
        if done then
            return returnValue
        end
    end
end

return module
