local QBCore = exports['qb-core']:GetCoreObject()

local craftingAttempts = {}
local MAX_ATTEMPTS_PER_MINUTE = 30
local ATTEMPT_RESET_TIME = 60000

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

local function CheckRateLimit(source)
    local currentTime = GetGameTimer()
    local playerId = source
    
    if not craftingAttempts[playerId] then
        craftingAttempts[playerId] = {
            count = 0,
            resetTime = currentTime + ATTEMPT_RESET_TIME
        }
    end
    
    local playerAttempts = craftingAttempts[playerId]
    
    if currentTime > playerAttempts.resetTime then
        playerAttempts.count = 0
        playerAttempts.resetTime = currentTime + ATTEMPT_RESET_TIME
    end
    
    playerAttempts.count = playerAttempts.count + 1
    
    if playerAttempts.count > MAX_ATTEMPTS_PER_MINUTE then
        print(("^1[RATE LIMIT] %s exceeded crafting rate limit: %s attempts^0"):format(GetPlayerName(playerId), playerAttempts.count))
        return false
    end
    
    return true
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

RegisterCommand('testcraft', function(source, args)
    local src = source
    local item = args[1] or "weapon_pistol"
    local quantity = tonumber(args[2]) or 1
    local benchName = args[3] or "Weapon Bench"
    
    print("^3[DEBUG] Testing craft validation:^0")
    print("Item: " .. item)
    print("Quantity: " .. quantity)
    print("Bench: " .. benchName)
    
    local recipe = Config.Recipes[item]
    if recipe then
        print("Recipe found: " .. recipe.name)
        print("Level required: " .. recipe.levelRequired)
        print("Materials: " .. json.encode(recipe.materials))
    else
        print("Recipe NOT found")
    end
end)

QBCore.Functions.CreateCallback('crafting:server:ValidateCraft', function(source, cb, item, quantity, benchName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    print("^3[DEBUG] ValidateCraft called^0")
    print("Player: " .. tostring(src) .. " (" .. GetPlayerName(src) .. ")")
    print("Item: " .. tostring(item))
    print("Quantity: " .. tostring(quantity))
    print("BenchName: " .. tostring(benchName))
    
    if not Player then
        print("^1[DEBUG] Player not found^0")
        cb({success = false, message = "Player not found"})
        return
    end
    
    local recipe = Config.Recipes[item]
    if not recipe then
        print("^1[DEBUG] Recipe not found in Config.Recipes^0")
        print("Available recipes: " .. json.encode(Config.Recipes and type(Config.Recipes)))
        cb({success = false, message = "Invalid recipe"})
        return
    end
    
    print("^2[DEBUG] Recipe found: " .. recipe.name .. "^0")
    
    local craftingLevel = GetCraftingLevel(src)
    print("^3[DEBUG] Player level: " .. craftingLevel .. ", Required: " .. recipe.levelRequired .. "^0")
    
    if craftingLevel < recipe.levelRequired then
        print("^1[DEBUG] Level too low^0")
        cb({success = false, message = "Level too low"})
        return
    end
    
    local validBench = false
    local benchRecipes = nil
    
    for _, bench in pairs(Config.CraftingBenches) do
        print("^3[DEBUG] Checking bench: " .. bench.name .. " vs " .. benchName .. "^0")
        if bench.name == benchName then
            benchRecipes = bench.recipes
            print("^2[DEBUG] Found bench recipes: " .. json.encode(benchRecipes) .. "^0")
            break
        end
    end
    
    if not benchRecipes and Config.PlaceableBenches.Types[benchName] then
        print("^3[DEBUG] Checking placeable bench: " .. benchName .. "^0")
        benchRecipes = Config.PlaceableBenches.Types[benchName].recipes
        print("^2[DEBUG] Placeable bench recipes: " .. json.encode(benchRecipes) .. "^0")
    end
    
    if benchRecipes then
        for _, recipeName in ipairs(benchRecipes) do
            print("^3[DEBUG] Checking recipe: " .. recipeName .. " vs " .. item .. "^0")
            if recipeName == item then
                validBench = true
                print("^2[DEBUG] Valid bench found^0")
                break
            end
        end
    else
        print("^1[DEBUG] No bench recipes found for: " .. benchName .. "^0")
    end
    
    if not validBench then
        print("^1[DEBUG] Cannot craft here - bench not valid^0")
        cb({success = false, message = "Cannot craft here"})
        return
    end
    
    print("^3[DEBUG] Checking materials for item: " .. item .. "^0")
    for material, amount in pairs(recipe.materials) do
        local totalNeeded = amount * quantity
        local playerHas = Player.Functions.GetItemByName(material)
        
        print("^3[DEBUG] Material: " .. material .. ", Needed: " .. totalNeeded .. "^0")
        
        if not playerHas then
            print("^1[DEBUG] Player doesn't have item: " .. material .. "^0")
            cb({success = false, message = "Missing materials: " .. material})
            return
        end
        
        print("^3[DEBUG] Player has: " .. playerHas.amount .. " of " .. material .. "^0")
        
        if playerHas.amount < totalNeeded then
            print("^1[DEBUG] Not enough: " .. material .. " (has: " .. playerHas.amount .. ", needs: " .. totalNeeded .. ")^0")
            cb({success = false, message = "Not enough materials: " .. material})
            return
        end
    end
    
    print("^2[DEBUG] All validations passed!^0")
    cb({success = true, recipe = recipe})
end)

RegisterNetEvent('crafting:server:CraftItem', function(item, quantity, benchName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    print("^3[DEBUG] CraftItem event received^0")
    print("Item: " .. item .. ", Quantity: " .. quantity .. ", Bench: " .. benchName)
    
    if not Player then 
        print("^1[DEBUG] Player not found^0")
        return 
    end
    
    if not CheckRateLimit(src) then
        TriggerClientEvent('QBCore:Notify', src, "You're crafting too fast! Slow down.", "error")
        return
    end
    
    quantity = tonumber(quantity) or 1
    if quantity <= 0 or quantity > 10 then
        print(("^1[EXPLOIT] %s attempted invalid quantity: %s^0"):format(GetPlayerName(src), quantity))
        return
    end
    
    local recipe = Config.Recipes[item]
    if not recipe then
        print(("^1[EXPLOIT] %s attempted to craft non-existent item: %s^0"):format(GetPlayerName(src), item))
        return
    end
    
    print("^3[DEBUG] Recipe found: " .. recipe.name .. "^0")
    
    local craftingLevel = GetCraftingLevel(src)
    if craftingLevel < recipe.levelRequired then
        TriggerClientEvent('QBCore:Notify', src, "You don't have the required level to craft this item!", "error")
        return
    end
    
    print("^3[DEBUG] Level check passed^0")
    
    local validBench = false
    local benchRecipes = nil
    
    for _, bench in pairs(Config.CraftingBenches) do
        if bench.name == benchName then
            benchRecipes = bench.recipes
            break
        end
    end
    
    if not benchRecipes and Config.PlaceableBenches.Types[benchName] then
        benchRecipes = Config.PlaceableBenches.Types[benchName].recipes
    end
    
    if benchRecipes then
        for _, recipeName in ipairs(benchRecipes) do
            if recipeName == item then
                validBench = true
                break
            end
        end
    end
    
    if not validBench then
        print(("^1[EXPLOIT] %s attempted to craft %s at unauthorized bench: %s^0"):format(GetPlayerName(src), item, benchName))
        return
    end
    
    print("^3[DEBUG] Bench check passed^0")
    
    local hasMaterials = true
    local materialsToRemove = {}
    
    for material, amount in pairs(recipe.materials) do
        local totalNeeded = amount * quantity
        local playerHas = Player.Functions.GetItemByName(material)
        
        print("^3[DEBUG] Checking material: " .. material .. ", Needs: " .. totalNeeded .. "^0")
        
        if not playerHas or playerHas.amount < totalNeeded then
            hasMaterials = false
            print("^1[DEBUG] Missing material: " .. material .. "^0")
            break
        end
        
        materialsToRemove[material] = totalNeeded
        print("^2[DEBUG] Material OK: " .. material .. ", Has: " .. playerHas.amount .. "^0")
    end
    
    if not hasMaterials then
        TriggerClientEvent('QBCore:Notify', src, "You don't have all the required materials!", "error")
        return
    end
    
    print("^3[DEBUG] All materials available^0")
    
    for material, amount in pairs(materialsToRemove) do
        print("^3[DEBUG] Removing " .. amount .. " of " .. material .. "^0")
        Player.Functions.RemoveItem(material, amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[material], "remove", amount)
    end
    
    print("^3[DEBUG] Adding " .. quantity .. " of " .. item .. "^0")
    Player.Functions.AddItem(item, quantity)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "add", quantity)
    
    local xpGained = recipe.xpGained * quantity
    AddCraftingXP(src, xpGained)
    
    TriggerClientEvent('QBCore:Notify', src, "Successfully crafted " .. quantity .. "x " .. recipe.name, "success")
    print("^2[DEBUG] Craft completed successfully^0")
end)

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

RegisterNetEvent('crafting:server:RepairWeapon', function(weaponSlot, benchName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if not CheckRateLimit(src) then
        TriggerClientEvent('QBCore:Notify', src, "You're repairing too fast!", "error")
        return
    end
    
    local weapon = Player.Functions.GetItemBySlot(weaponSlot)
    
    if not weapon or weapon.type ~= "weapon" then
        TriggerClientEvent('QBCore:Notify', src, "Weapon not found!", "error")
        return
    end
    
    local repairConfig = Config.RepairCosts[weapon.name]
    if not repairConfig then
        TriggerClientEvent('QBCore:Notify', src, "This weapon cannot be repaired!", "error")
        return
    end
    
    local validBench = false
    local benchRecipes = nil
    
    for _, bench in pairs(Config.CraftingBenches) do
        if bench.name == benchName then
            benchRecipes = bench.recipes
            break
        end
    end
    
    if not benchRecipes and Config.PlaceableBenches.Types[benchName] then
        benchRecipes = Config.PlaceableBenches.Types[benchName].recipes
    end
    
    if benchRecipes then
        for _, recipeName in ipairs(benchRecipes) do
            if recipeName == weapon.name then
                validBench = true
                break
            end
        end
    end
    
    if not validBench then
        print(("^1[EXPLOIT] %s attempted to repair %s at unauthorized bench: %s^0"):format(GetPlayerName(src), weapon.name, benchName))
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
