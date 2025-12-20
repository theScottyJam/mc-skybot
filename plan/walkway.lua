local act = import('act/init.lua')

local navigate = act.navigate

local module = {}

local leftRightWalkwayBlueprint = act.blueprint.create({
    key = {
        ['minecraft:smoothStone'] = 's',
        ['minecraft:stoneBricks'] = 's',
        ['minecraft:torch'] = '*',
    },
    markers = {
        entrance = {
            behavior = 'buildStartCoord',
            char = '!',
        },
    },
    buildStartMarker = 'entrance',
    layers = {
        {
            ',     .',
            'WWWWWWW',
            '   *   ',
            '       ',
            '!      ',
            '       ',
            '   *   ',
            'WWWWWWW',
        },
        {
            ',     .',
            'sssssss',
            'XXXXXXX',
            'XXsssXX',
            'ss   ss',
            'XXsssXX',
            'XXXXXXX',
            'sssssss',
        },
    }
})

local leftDownWalkwayBlueprint = act.blueprint.create({
    key = {
        ['minecraft:smoothStone'] = 's',
        ['minecraft:stoneBricks'] = 's',
        ['minecraft:torch'] = '*',
    },
    markers = {
        entrance = {
            behavior = 'buildStartCoord',
            char = '!',
        },
    },
    buildStartMarker = 'entrance',
    layers = {
        {
            ',     .',
            'WWWWWWW',
            '   *  W',
            '      W',
            '!    *W',
            '      W',
            '      W',
            '      W',
        },
        {
            ',     .',
            'sssssss',
            'XXXXXXs',
            'XXssXXs',
            'ss  sXs',
            'XXs sXs',
            'XXXsXXs',
            'XXXsXXs',
        },
    }
})

local leftDownRightWalkwayBlueprint = act.blueprint.create({
    key = {
        ['minecraft:smoothStone'] = 's',
        ['minecraft:stoneBricks'] = 's',
        ['minecraft:torch'] = '*',
    },
    markers = {
        entrance = {
            behavior = 'buildStartCoord',
            char = '!',
        },
    },
    buildStartMarker = 'entrance',
    layers = {
        {
            ',     .',
            'WWWWWWW',
            '   *   ',
            '       ',
            '!      ',
            '       ',
            '       ',
            'W      W',
        },
        {
            ',     .',
            'sssssss',
            'XXXXXXX',
            'XXsssXX',
            'ss   ss',
            'XXs sXX',
            'XXXsXXX',
            'sXXsXXs',
        },
    }
})

-- TODO: Expose functionality on the module table
return module
