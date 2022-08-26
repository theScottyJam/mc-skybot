local module = {}

function module.registerGlobal(base, hookListeners)
  local act = {}

  act._state = import(base..'_state.lua')
  act.commands = import(base..'commands/init.lua')
  act.farm = import(base..'farm.lua')
  act.highLevelCommands = import(base..'highLevelCommands.lua')
  act.location = import(base..'location.lua')
  act.mill = import(base..'mill.lua')
  act.mockHooks = import(base..'mockHooks.lua').init(hookListeners)
  act.navigate = import(base..'navigate.lua')
  act.planner = import(base..'planner.lua')
  act.project = import(base..'project.lua')
  act.space = import(base..'space.lua')
  act.strategy = import(base..'strategy.lua')
  act.task = import(base..'task.lua')

  _G.act = act
end

return module