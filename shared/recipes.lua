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
