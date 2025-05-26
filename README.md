ML187-Crafting


INSALL SIMPLY DRAG AND DROP SET UP CONFIG HOW YOUD LIKE 

RUN RUN RUN THAT SQL AND EVERYTHING WILL WORK AS EXPECTED

PLEASE RENAME TO ml187-crafting before USING SCRIPT
RUN NEW SQL FOR NEW PERSISTANT PLACEABLE CRAFTING TABLES 


ADD THESE ITEMS TO QBCORE SHARED 
```
--ml187-crafting
    ["crafting_weapon_bench"] = {
        ["name"] = "crafting_weapon_bench",
        ["label"] = "Weapon Crafting Bench",
        ["weight"] = 1000,
        ["type"] = "item",
        ["image"] = "weapon_bench.png",
        ["unique"] = true,
        ["useable"] = true,
        ["shouldClose"] = true,
        ["combinable"] = nil,
        ["description"] = "A bench for crafting weapons"
    },

    ["crafting_melee_bench"] = {
        ["name"] = "crafting_melee_bench",
        ["label"] = "Melee Crafting Bench",
        ["weight"] = 1000,
        ["type"] = "item",
        ["image"] = "melee_bench.png",
        ["unique"] = true,
        ["useable"] = true,
        ["shouldClose"] = true,
        ["combinable"] = nil,
        ["description"] = "A bench for crafting melee weapons"
    },
    
    ["crafting_drug_bench"] = {
        ["name"] = "crafting_drug_bench",
        ["label"] = "Drug Crafting Table",
        ["weight"] = 1000,
        ["type"] = "item",
        ["image"] = "drug_bench.png",
        ["unique"] = true,
        ["useable"] = true,
        ["shouldClose"] = true,
        ["combinable"] = nil,
        ["description"] = "A table for crafting drugs"
    },
```


AND AGAIN DO NOT FORGET TO RENAME SCRIPT TO ml187-crafting 
