local module = {}

local act = {
    blueprint = import('./blueprint.lua'),
    curves = import('./curves.lua'),
    farm = import('./farm.lua'),
    highLevelCommands = import('./highLevelCommands.lua'),
    location = import('./location.lua'),
    mill = import('./mill.lua'),
    navigate = import('./navigate.lua'),
    navigationPatterns = import('./navigationPatterns.lua'),
    project = import('./project.lua'),
    space = import('./space.lua'),
    strategy = import('./strategy.lua'),
    task = import('./task.lua'),
}

function module.registerGlobal()
    _G.act = act
end

return module
