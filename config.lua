Config = {}

Config.DefaultCraftingTime = 15 -- Default crafting time in seconds if not specified in the recipe
Config.CraftingBenches = {
    {
        name = "Weapon Bench",
        coords = vector3(296.28, -1715.98, 29.18),
        radius = 2.0,
        recipes = {"weapon_pistol", "weapon_smg", "weapon_microsmg"} -- List of craftable items at this bench
    },
    {
        name = "Melee Bench",
        coords = vector3(706.04, -961.23, 30.4),
        radius = 2.0,
        recipes = {"weapon_dagger", "weapon_bat","armor", "radio"} -- List of craftable items at this bench
    },
    {
        name = "Drug Bench",
        coords = vector3(706.76, -964.67, 36.85),
        radius = 2.0,
        recipes = {"weed_ak47", "oxy"} -- List of craftable items at this bench
    },
    -- Add more benches as needed
}

-- Add repair costs to the config
Config.RepairCosts = {
    ["weapon_pistol"] = {
        materials = {
            ["iron"] = 2,
            ["steel"] = 1,
        },
        levelRequired = 0,
    },
    ["weapon_smg"] = {
        materials = {
            ["iron"] = 3,
            ["steel"] = 2,
        },
        levelRequired = 3,
    },
    ["weapon_microsmg"] = {
        materials = {
            ["iron"] = 3,
            ["steel"] = 2,
        },
        levelRequired = 5,
    },
    ["weapon_dagger"] = {
        materials = {
            ["iron"] = 1,
        },
        levelRequired = 0,
    },
    ["weapon_bat"] = {
        materials = {
            ["iron"] = 1,
        },
        levelRequired = 1,
    },
    -- Add more weapons as needed
}


Config.Recipes = {
    ["weapon_pistol"] = {
        name = "Pistol",
        materials = {
            ["iron"] = 10,
            ["steel"] = 5,
        },
        levelRequired = 0,
        xpGained = 100,
    },
	["weapon_smg"] = {
        name = "SMG",
        materials = {
            ["iron"] = 10,
            ["steel"] = 5,
        },
        levelRequired = 5,
        xpGained = 10,
    },
	["weapon_microsmg"] = {
        name = "MicroSmg",
        materials = {
            ["iron"] = 10,
            ["steel"] = 5,
        },
        levelRequired = 7,
        xpGained = 10,
    },
    ["weapon_dagger"] = {
        name = "Dagger",
        materials = {
            ["iron"] = 1,
            ["steel"] = 1,
        },
        levelRequired = 0,
        xpGained = 2,
    },
    ["weapon_bat"] = {
        name = "Baseball Bat",
        materials = {
            ["iron"] = 1,
            ["steel"] = 1,
        },
        levelRequired = 2,
        xpGained = 2,
    },
    ["armor"] = {
        name = "Armor",
        materials = {
            ["iron"] = 1,
            ["steel"] = 1,
        },
        levelRequired = 2,
        xpGained = 2,
    },
    ["radio"] = {
        name = "Radio",
        materials = {
            ["iron"] = 1,
        },
        levelRequired = 2,
        xpGained = 2,
    },
    ["weed_ak47"] = {
        name = "Ak47",
        materials = {
            ["iron"] = 1,
        },
        levelRequired = 2,
        xpGained = 2,
    },
    ["oxy"] = {
        name = "Oxy",
        materials = {
            ["iron"] = 1,
        },
        levelRequired = 2,
        xpGained = 2,
    },
    -- ... (adjust other recipes)
}

Config.LevelXP = {
    0,    -- Level 1
    100,  -- Level 2
    250,  -- Level 3
    500,  -- Level 4
    750, -- Level 5
    1000, -- level 6
    1250, -- level 7
    1500, -- level 8
    1750, -- level 9
    2000, -- level 10
    -- Add more levels as needed
}
