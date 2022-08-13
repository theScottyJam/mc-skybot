local module = {}

local projectRegistry = {}

-- createProjectState() returns any arbitrary record
-- nextShortTermPlan() takes a state and project state and returns a tuple
--   containing an updated project state and a short-term plan, or a tuple
--   of nils if there's nothing more to do.
--   (Note that it's allowed for the project state to be nil)
-- Returns the project id passed in
function module.register(id, opts)
    projectRegistry[id] = {
        nextShortTermPlan = opts.nextShortTermPlan,
        createProjectState = opts.createProjectState
    }
    return id
end

function module.lookup(projectId)
    return projectRegistry[projectId]
end

return module