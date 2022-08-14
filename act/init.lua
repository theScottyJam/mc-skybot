local module = {}

function module.registerGlobal(base, hookListeners)
  local act = {}

  act.commands = import(base..'commands.lua')
  act.entity = import(base..'entity.lua')
  act.mockHooks = import(base..'mockHooks.lua').init(hookListeners)
  act.highLevelCommands = import(base..'highLevelCommands.lua').init(act.commands.registerCommand)
  act.location = import(base..'location.lua')
  act.navigate = import(base..'navigate.lua')
  act._state = import(base..'_state.lua')
  act.project = import(base..'project.lua')
  act.shortTermPlaner = import(base..'shortTermPlaner.lua')
  act.space = import(base..'space.lua')
  act.strategy = import(base..'strategy.lua')

  _G.act = act
end

return module