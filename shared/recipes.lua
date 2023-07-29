return {
    crafting = {
        {
            from = {
                {'minecraft:cobblestone', 'minecraft:cobblestone', 'minecraft:cobblestone'},
                {'minecraft:cobblestone', nil, 'minecraft:cobblestone'},
                {'minecraft:cobblestone', 'minecraft:cobblestone', 'minecraft:cobblestone'},
            },
            to = 'minecraft:furnace',
            yields = 1,
        },
        {
            from = {
                {'minecraft:log'},
            },
            to = 'minecraft:planks',
            yields = 4,
        },
        {
            from = {
                {'minecraft:planks'},
                {'minecraft:planks'},
            },
            to = 'minecraft:stick',
            yields = 4,
        },
        {
            from = {
                {'minecraft:charcoal'},
                {'minecraft:stick'},
            },
            to = 'minecraft:torch',
            yields = 4,
        },
    },
    smelting = {
        {
            from = 'minecraft:log',
            to = 'minecraft:charcoal'
        },
        {
            from = 'minecraft:cobblestone',
            to = 'minecraft:stone'
        },
    },
}
