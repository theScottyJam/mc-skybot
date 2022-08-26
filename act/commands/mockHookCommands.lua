local publicHelpers = import('./_publicHelpers.lua')

local module = {}

local registerCommand = publicHelpers.registerCommand

module.registerCobblestoneRegenerationBlock = registerCommand(
    'mockHooks:registerCobblestoneRegenerationBlock',
    function(state, coord)
        local mockHooks = _G.act.mockHooks
        local space = _G.act.space
        mockHooks.registerCobblestoneRegenerationBlock(coord)
    end
)

return module
