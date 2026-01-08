local module = {}

local e = 2.71828

-- A sigmoid curve has the steepest acceleration in the middle and a more shallow slope at the ends.
-- y at minX is 0.036
-- y at maxX is maxY
function module.sigmoidFactory(xBounds)
    local minX = xBounds.minX
    local maxX = xBounds.maxX
    return function(opts)
        local minY = opts.minY or 0
        local maxY = opts.maxY
        return function(x)
            local xCenter = minX + (maxX - minX) / 2
            local input = 8*(-xCenter + x) / (maxX - minX)
            local output = 1 / (1 + e^-input)
            return minY + (maxY - minY) * output
        end
    end
end

-- This curve starts at the y intercept and decreases over time, approaching zero.
-- The smaller the factor, the more shallow the curve.
function module.inverseSqrtCurve(opts)
    local yIntercept = opts.yIntercept
    local factor = opts.factor
    return function(x)
        return yIntercept / math.sqrt(factor * x + 1)
    end
end

return module