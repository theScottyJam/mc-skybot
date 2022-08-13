local module = {}

--[[
  Returns an entity factory.
  entityBuilderFn() should return something of the shape
  { init = <function>, entity = <anything> }
  init() gets called when executing the initialize entity strategy step
  and should do things like register paths between locations so they can be traversed.
  The entity itself is an arbitrary object for a strategy function to use.
--]]
function module.createEntityFactory(entityBuilderFn)
    return { build = entityBuilderFn }
end

return module