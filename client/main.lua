local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local craftingXP = 0
local craftingLevel = 1
local isMenuOpen = false
local currentBench = nil
local craftingQueue = {}
local isProcessingQueue = false
local playerInventory = {}
local selectedRecipe = nil

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    isMenuOpen = false
    cb('ok')
end)

RegisterNUICallback('craftItem', function(data, cb)
    local item = data.item
    local quantity = tonumber(data.quantity) or 1
    local benchType = data.benchType
    
    if not item then
        QBCore.Functions.Notify("No item selected!", "error")
        cb('error')
        return
    end
    
    if not benchType and currentBench then
        benchType = currentBench.name
    end
    
    if not benchType then
        QBCore.Functions.Notify("Bench type missing!", "error")
        cb('error')
        return
    end
    
    if not quantity or quantity < 1 or quantity > 100 then
        QBCore.Functions.Notify("Quantity must be between 1 and 100!", "error")
        cb('error')
        return
    end
    
    if not Config.Recipes[item] then
        QBCore.Functions.Notify("Cannot craft this item!", "error")
        cb('error')
        return
    end
    
    QBCore.Functions.TriggerCallback('crafting:server:ValidateCraft', function(result)
        if not result or not result.success then
            local errorMsg = result and result.message or "Cannot craft"
            QBCore.Functions.Notify(errorMsg, "error")
            cb('error')
            return
        end
        
        local recipe = Config.Recipes[item]
        
        local queueItem = {
            item = item,
            benchType = benchType,
            quantity = quantity,
            progress = 0,
            id = math.random(1000000, 9999999),
            craftingTime = recipe.craftingTime or Config.DefaultCraftingTime,
            validated = true,
            crafting = false
        }
        
        table.insert(craftingQueue, queueItem)
        
        SendNUIMessage({
            action = 'updateQueue',
            queue = craftingQueue
        })
        
        if not isProcessingQueue then
            ProcessCraftingQueue()
        end
        
        cb('ok')
    end, item, quantity, benchType)
end)

RegisterNUICallback('cancelCrafting', function(data, cb)
    local queueId = data.queueId
    
    for i, queueItem in ipairs(craftingQueue) do
        if queueItem.id == queueId then
            table.remove(craftingQueue, i)
            break
        end
    end
    
    SendNUIMessage({
        action = 'updateQueue',
        queue = craftingQueue
    })
    
    cb('ok')
end)

RegisterNUICallback('selectRecipe', function(data, cb)
    selectedRecipe = data.item
    cb('ok')
end)

local function UpdateLocalInventory()
    QBCore.Functions.TriggerCallback('crafting:server:GetPlayerInventory', function(inventory)
        playerInventory = inventory
        if isMenuOpen and currentBench then
            SendNUIMessage({
                action = 'updateInventory',
                inventory = inventory
            })
            
            if selectedRecipe then
                SendNUIMessage({
                    action = 'updateSelectedRecipe',
                    item = selectedRecipe
                })
            end
        end
    end)
end

function ProcessCraftingQueue()
    if #craftingQueue == 0 or isProcessingQueue then return end
    
    isProcessingQueue = true
    
    CreateThread(function()
        while #craftingQueue > 0 do
            local hasActiveCrafts = false
            local itemsToRemove = {}
            
            for i, queueItem in ipairs(craftingQueue) do
                if not queueItem.crafting and queueItem.validated then
                    queueItem.crafting = true
                    queueItem.startTime = GetGameTimer()
                    queueItem.endTime = queueItem.startTime + (queueItem.craftingTime * 1000)
                    hasActiveCrafts = true
                elseif queueItem.crafting then
                    hasActiveCrafts = true
                end
            end
            
            if hasActiveCrafts and not IsEntityPlayingAnim(PlayerPedId(), "mini@repair", "fixing_a_ped", 3) then
                local ped = PlayerPedId()
                local animDict = "mini@repair"
                local anim = "fixing_a_ped"
                
                RequestAnimDict(animDict)
                while not HasAnimDictLoaded(animDict) do
                    Wait(10)
                end
                
                TaskPlayAnim(ped, animDict, anim, 8.0, -8.0, -1, 1, 0, false, false, false)
            end
            
            local now = GetGameTimer()
            
            for i, queueItem in ipairs(craftingQueue) do
                if queueItem.crafting then
                    local elapsedTime = now - queueItem.startTime
                    local duration = queueItem.endTime - queueItem.startTime
                    
                    if duration > 0 then
                        local progress = math.min((elapsedTime / duration) * 100, 100)
                        queueItem.progress = progress
                        
                        if progress >= 100 and not queueItem.completed then
                            queueItem.completed = true
                            table.insert(itemsToRemove, i)
                            
                            TriggerServerEvent('crafting:server:CraftItem', 
                                queueItem.item, 
                                queueItem.quantity,
                                queueItem.benchType
                            )
                        end
                    end
                end
            end
            
            SendNUIMessage({
                action = 'updateQueue',
                queue = craftingQueue
            })
            
            table.sort(itemsToRemove, function(a, b) return a > b end)
            for _, index in ipairs(itemsToRemove) do
                table.remove(craftingQueue, index)
            end
            
            if #itemsToRemove > 0 then
                UpdateLocalInventory()
            end
            
            if not hasActiveCrafts then
                ClearPedTasks(PlayerPedId())
            end
            
            if #craftingQueue == 0 then
                ClearPedTasks(PlayerPedId())
                break
            end
            
            Wait(100)
        end
        
        isProcessingQueue = false
    end)
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('crafting:server:GetCraftingSkills', function(xp, level)
        craftingXP = xp
        craftingLevel = level
    end)
end)

RegisterNetEvent('crafting:client:SetXPAndLevel', function(xp, level)
    craftingXP = xp
    craftingLevel = level
    
    if isMenuOpen then
        local nextLevelXP = Config.LevelXP[craftingLevel] or "Max Level"
        SendNUIMessage({
            action = 'updateStats',
            level = craftingLevel,
            xp = craftingXP,
            nextLevelXP = nextLevelXP
        })
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
        return
    end
    Wait(1000) 
    QBCore.Functions.TriggerCallback('crafting:server:GetCraftingSkills', function(xp, level)
        craftingXP = xp
        craftingLevel = level
    end)
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        if Config and Config.CraftingBenches then
            for _, bench in pairs(Config.CraftingBenches) do
                if bench and bench.coords then
                    local distance = #(playerCoords - bench.coords)
                    
                    if distance < 10 then
                        sleep = 0
                        DrawMarker(2, bench.coords.x, bench.coords.y, bench.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 255, 255, 255, 100, false, true, 2, false, nil, nil, false)
                        
                        if distance < 1.5 then
                            DrawText3D(bench.coords.x, bench.coords.y, bench.coords.z + 0.3, '[E] Use ' .. bench.name)
                            
                            if IsControlJustReleased(0, 38) then
                                OpenCraftingMenu(bench)
                            end
                        end
                    end
                end
            end
        end
        
        Wait(sleep)
    end
end)

function OpenCraftingMenu(bench)
    if isMenuOpen then return end
    
    currentBench = bench
    isMenuOpen = true
    selectedRecipe = nil
    
    QBCore.Functions.TriggerCallback('crafting:server:GetPlayerInventory', function(inventory)
        playerInventory = inventory
        
        local filteredRecipes = {}
        
        if bench and bench.recipes then
            for _, recipeKey in ipairs(bench.recipes) do
                if Config.Recipes and Config.Recipes[recipeKey] then
                    filteredRecipes[recipeKey] = Config.Recipes[recipeKey]
                end
            end
        end
        
        local nextLevelXP = Config.LevelXP and Config.LevelXP[craftingLevel] or "Max Level"
        
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            bench = bench,
            benchType = bench.name,
            recipes = filteredRecipes,
            level = craftingLevel,
            xp = craftingXP,
            nextLevelXP = nextLevelXP,
            inventory = inventory,
            queue = craftingQueue
        })
    end)
end

function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x,y,z, 0)
    DrawText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

RegisterNUICallback('openRepairMenu', function(data, cb)
    local bench = currentBench
    OpenRepairMenu(bench)
    cb('ok')
end)

RegisterNUICallback('repairWeapon', function(data, cb)
    local weaponSlot = data.weaponHash
    local benchType = data.benchType or (currentBench and currentBench.name)
    
    TriggerServerEvent('crafting:server:RepairWeapon', weaponSlot, benchType)
    
    cb('ok')
end)

function OpenRepairMenu(bench)
    QBCore.Functions.TriggerCallback('crafting:server:GetPlayerWeapons', function(weapons)
        local repairableWeapons = {}
        
        for _, weapon in pairs(weapons) do
            if IsWeaponRepairableAtBench(weapon.name, bench) then
                table.insert(repairableWeapons, weapon)
            end
        end
        
        local playerItems = QBCore.Functions.GetPlayerData().items
        local inventory = {}
        
        for slot, item in pairs(playerItems) do
            if item then
                local itemName = item.name
                if not itemName and item.item then
                    itemName = item.item
                end
                
                if itemName then
                    inventory[itemName] = (inventory[itemName] or 0) + (item.amount or 1)
                end
            end
        end
        
        SendNUIMessage({
            action = 'openRepairMenu',
            weapons = repairableWeapons,
            repairCosts = Config.RepairCosts,
            inventory = inventory,
            level = craftingLevel,
            benchType = bench.name
        })
        
        SetNuiFocus(true, true)
    end)
end

function IsWeaponRepairableAtBench(weaponName, bench)
    for _, recipe in ipairs(bench.recipes) do
        if recipe == weaponName then
            return true
        end
    end
    
    return false
end
