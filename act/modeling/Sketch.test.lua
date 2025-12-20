-- Mostly focused on testing assertions. Issues with other behaviors can be
-- easily seen by running the program in mock mode.

local Sketch = import('./Sketch.lua')
local getErrorMessage = testFramework.getErrorMessage

testFramework.testGroup('Sketch')

test('does not allow empty maps', function()
    local error = getErrorMessage(Sketch.new, {
        layeredAsciiMap = {}
    })
    assert.equal(error, 'At least one layer must be provided.')
end)

test('does not allow empty layers', function()
    local error = getErrorMessage(Sketch.new, {
        layeredAsciiMap = {
            {}
        }
    })
    assert.equal(error, 'At least one row must be provided in a layer.')
end)

test('does not allow empty rows', function()
    local error = getErrorMessage(Sketch.new, {
        layeredAsciiMap = {{
            '',
        }}
    })
    assert.equal(error, 'At least one cell must be provided in a row.')
end)

test('it verifies that all rows in a layer to be the same length', function()
    local error = getErrorMessage(Sketch.new, {
        layeredAsciiMap = {{
            ',X',
            'X'
        }}
    })
    assert.equal(error, 'All rows must be of the same length.')
end)

test('the primary reference point cannot be found multiple times on a given layer', function()
    local error = getErrorMessage(Sketch.new, {
        layeredAsciiMap = {{
            ',X',
            'X,'
        }}
    })
    assert.equal(error, 'The primary reference point marker (,) was found multiple times on a layer')
end)

test('the primary reference point is required on each layer', function()
    local error = getErrorMessage(Sketch.new, {
        layeredAsciiMap = {
            {
                ',X',
                'X '
            },
            {
                ' X',
                'X '
            },
        }
    })
    assert.equal(error, 'Missing a primary reference point (,) on a layer')
end)

test('you can omit the primary reference point when there is only one layer', function()
    -- No error is thrown
    Sketch.new({
        layeredAsciiMap = {
            {
                ' X',
                'X '
            },
        }
    })
end)

test('secondary reference points must line up', function()
    local error = getErrorMessage(Sketch.new, {
        layeredAsciiMap = {
            {
                ', ',
                'X.'
            },
            {
                ',.',
                'X '
            },
            {
                ', ',
                'X.'
            },
        }
    })
    assert.equal(error, 'Found a secondary reference point (.) on layer 2 that does not line up with any reference points on any other layer.')
end)

test('layers cannot skip secondary reference points', function()
    local error = getErrorMessage(Sketch.new, {
        layeredAsciiMap = {
            {
                ', ',
                'X.'
            },
            {
                ', ',
                'X '
            },
            {
                ', ',
                'X.'
            },
        }
    })
    assert.equal(error, 'Expected layer 2 to have a secondary reference point at backwardIndex=2 rightIndex=2.')
end)

test('layers can skip a secondary reference point if it falls outside of its bounds', function()
    -- No error is thrown
    Sketch.new({
        layeredAsciiMap = {
            {
                ', ',
                'X.'
            },
            {
                ',',
                'X'
            },
            {
                ', ',
                'X.'
            },
        }
    })
end)

test('all markers must be found in the ASCII map', function()
    local error = getErrorMessage(Sketch.new, {
        layeredAsciiMap = {{
            ', ',
            'X '
        }},
        markers = {
            myMarker = { char = '!' },
        }
    })
    assert.equal(error, 'The marker "!" was not found.')
end)

test('markers cannot be found multiple times in the ASCII map', function()
    local error = getErrorMessage(Sketch.new, {
        layeredAsciiMap = {{
            ',!',
            'X!'
        }},
        markers = {
            myMarker = { char = '!' },
        }
    })
    assert.equal(error, 'The marker "!" was found multiple times.')
end)
