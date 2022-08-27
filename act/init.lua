local mockHooksModule = import('./mockHooks.lua')

local module = {}

local act = {
    commands = import('./commands/init.lua'),
    curves = import('./curves.lua'),
    farm = import('./farm.lua'),
    highLevelCommands = import('./highLevelCommands.lua'),
    location = import('./location.lua'),
    mill = import('./mill.lua'),
    mockHooks = nil,
    navigate = import('./navigate.lua'),
    planner = import('./planner.lua'),
    project = import('./project.lua'),
    space = import('./space.lua'),
    strategy = import('./strategy.lua'),
    task = import('./task.lua'),
}

function module.registerGlobal(hookListeners)
    act.mockHooks = mockHooksModule.init(hookListeners)
    _G.act = act
end

return module
