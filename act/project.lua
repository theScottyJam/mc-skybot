local module = {}

-- taskRunnerId - the task assosiated with this project.
-- opts.preConditions() (optional) takes a currentConditions, and returns true if all
--   pre-conditions are met.
-- opts.postConditions() (optional) takes a currentConditions, and mutates it to state
--   what conditions have been fulfilled.
function module.create(taskRunnerId, opts)
    opts = opts or {}
    local preConditions = opts.preConditions or function() return true end
    local postConditions = opts.postConditions or function() end

    return {
        addToProjectList = function(projectList, currentConditions)
            if not preConditions(currentConditions) then
                error('Project '..taskRunnerId..' did not have its pre-conditions satisfied.')
            end
    
            table.insert(projectList, taskRunnerId)
            postConditions(currentConditions)
        end
    }
end

return module