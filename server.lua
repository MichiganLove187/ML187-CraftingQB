local QBCore = exports['qb-core']:GetCoreObject()

local function GetCraftingSkills(citizenid)
    local result = MySQL.Sync.fetchAll('SELECT xp, level FROM player_crafting_skills WHERE citizenid = ?', {citizenid})
    if result[1] then
        return result[1].xp, result[1].level
    else
        return 0, 1
    end
end

local function SaveCraftingSkills(citizenid, xp, level)
    MySQL.Async.execute('INSERT INTO player_crafting_skills (citizenid, xp, level) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE xp = ?, level = ?', 
    {citizenid, xp, level, xp, level})
end

local function CalculateLevel(xp)
    for level, requiredXP in ipairs(Config.LevelXP) do
        if xp < requiredXP then
            return level
        end
    end
    return #Config.LevelXP + 1 
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local citizenid = Player.PlayerData.citizenid
    local xp, level = GetCraftingSkills(citizenid)
    TriggerClientEvent('crafting:client:SetXPAndLevel', src, xp, level)
end)

QBCore.Functions.CreateCallback('crafting:server:GetCraftingSkills', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb(0, 1) end
    
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.Sync.fetchAll('SELECT xp, level FROM player_crafting_skills WHERE citizenid = ?', {citizenid})
    
    if result and result[1] then
        cb(result[1].xp, result[1].level)
    else
        MySQL.Async.execute('INSERT INTO player_crafting_skills (citizenid, xp, level) VALUES (?, ?, ?)', {
            citizenid, 0, 1
        })
        cb(0, 1)
    end
end)

QBCore.Functions.CreateCallback('crafting:server:CanCraftItem', function(source, cb, item, recipe)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local craftingXP, craftingLevel = GetCraftingSkills(Player.PlayerData.citizenid)
    
    if craftingLevel < recipe.levelRequired then
        cb(false)
        return
    end

    for material, amount in pairs(recipe.materials) do
        if Player.Functions.GetItemByName(material) == nil or Player.Functions.GetItemByName(material).amount < amount then
            cb(false)
            return
        end
    end

    cb(true)
end)

RegisterNetEvent('crafting:server:CraftItem', function(item, recipe, quantity)
    quantity = tonumber(quantity) or 1
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local craftingLevel = GetCraftingLevel(src)
    if craftingLevel < recipe.levelRequired then
        TriggerClientEvent('QBCore:Notify', src, "You don't have the required level to craft this item!", "error")
        return
    end
    
    local hasMaterials = true
    local materialsToRemove = {}
    
    for material, amount in pairs(recipe.materials) do
        local totalNeeded = amount * quantity
        local playerHas = Player.Functions.GetItemByName(material)
        
        if not playerHas or playerHas.amount < totalNeeded then
            hasMaterials = false
            break
        end
        
        materialsToRemove[material] = totalNeeded
    end
    
    if not hasMaterials then
        TriggerClientEvent('QBCore:Notify', src, "You don't have all the required materials!", "error")
        return
    end
    
    for material, amount in pairs(materialsToRemove) do
        Player.Functions.RemoveItem(material, amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[material], "remove", amount)
    end
    
    Player.Functions.AddItem(item, quantity)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "add", quantity)
    
    local xpGained = recipe.xpGained * quantity
    AddCraftingXP(src, xpGained)
    
    TriggerClientEvent('QBCore:Notify', src, "Successfully crafted " .. quantity .. "x " .. recipe.name, "success")
end)

function GetCraftingLevel(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 1 end
    
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.Sync.fetchAll('SELECT level FROM player_crafting_skills WHERE citizenid = ?', {citizenid})
    
    if result and result[1] then
        return result[1].level
    else
        MySQL.Async.execute('INSERT INTO player_crafting_skills (citizenid, xp, level) VALUES (?, ?, ?)', {
            citizenid, 0, 1
        })
        return 1
    end
end

function AddCraftingXP(source, xp)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.Sync.fetchAll('SELECT xp, level FROM player_crafting_skills WHERE citizenid = ?', {citizenid})
    
    if not result or not result[1] then
        MySQL.Async.execute('INSERT INTO player_crafting_skills (citizenid, xp, level) VALUES (?, ?, ?)', {
            citizenid, xp, 1
        })
        TriggerClientEvent('crafting:client:SetXPAndLevel', source, xp, 1)
        return
    end
    
    local currentXP = result[1].xp + xp
    local currentLevel = result[1].level
    local newLevel = currentLevel
    
    while Config.LevelXP[newLevel] and currentXP >= Config.LevelXP[newLevel] do
        newLevel = newLevel + 1
        TriggerClientEvent('QBCore:Notify', source, "Crafting level up! You are now level " .. newLevel, "success")
    end
    
    MySQL.Async.execute('UPDATE player_crafting_skills SET xp = ?, level = ? WHERE citizenid = ?', {
        currentXP, newLevel, citizenid
    })
    
    TriggerClientEvent('crafting:client:SetXPAndLevel', source, currentXP, newLevel)
end

QBCore.Functions.CreateCallback('crafting:server:GetPlayerInventory', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    local inventory = {}
    
    for _, item in pairs(Player.PlayerData.items) do
        if item then
            inventory[item.name] = item.amount
        end
    end
    
    cb(inventory)
end)

--- added REPAIR

QBCore.Functions.CreateCallback('crafting:server:GetPlayerWeapons', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return cb({}) end
    
    local weapons = {}
    
    for _, item in pairs(Player.PlayerData.items) do
        if item and item.type == "weapon" then
            local condition = 100
            if item.info and item.info.quality then
                condition = item.info.quality
            end
            
            table.insert(weapons, {
                name = item.name,
                label = QBCore.Shared.Items[item.name].label,
                slot = item.slot,
                condition = condition
            })
        end
    end
    
    cb(weapons)
end)

RegisterNetEvent('crafting:server:RepairWeapon', function(weaponSlot, repairCost)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    print("Server: RepairWeapon event triggered")
    print("Player: " .. tostring(src))
    print("Weapon slot: " .. tostring(weaponSlot))
    
    if not Player then 
        print("Player not found")
        return 
    end
    
    local weapon = Player.Functions.GetItemBySlot(weaponSlot)
    
    if not weapon or weapon.type ~= "weapon" then
        print("Weapon not found or not a weapon type")
        TriggerClientEvent('QBCore:Notify', src, "Weapon not found!", "error")
        return
    end
    
    print("Found weapon: " .. weapon.name)
    
    local repairConfig = Config.RepairCosts[weapon.name]
    if not repairConfig then
        print("No repair config for: " .. weapon.name)
        TriggerClientEvent('QBCore:Notify', src, "This weapon cannot be repaired!", "error")
        return
    end
    
    local craftingLevel = GetCraftingLevel(src)
    if craftingLevel < repairConfig.levelRequired then
        TriggerClientEvent('QBCore:Notify', src, "You don't have the required level to repair this weapon!", "error")
        return
    end
    
    local hasMaterials = true
    local materialsToRemove = {}
    
    for material, amount in pairs(repairConfig.materials) do
        local playerHas = Player.Functions.GetItemByName(material)
        
        if not playerHas or playerHas.amount < amount then
            hasMaterials = false
            break
        end
        
        materialsToRemove[material] = amount
    end
    
    if not hasMaterials then
        TriggerClientEvent('QBCore:Notify', src, "You don't have all the required materials for repair!", "error")
        return
    end
    
    for material, amount in pairs(materialsToRemove) do
        Player.Functions.RemoveItem(material, amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[material], "remove", amount)
    end
    
    local info = weapon.info or {}
    info.quality = 100
    
    Player.Functions.RemoveItem(weapon.name, 1, weapon.slot)
    Player.Functions.AddItem(weapon.name, 1, weapon.slot, info)
    
    AddCraftingXP(src, math.floor(repairConfig.levelRequired * 5) + 5)
    
    TriggerClientEvent('QBCore:Notify', src, "Weapon repaired successfully!", "success")
end)
