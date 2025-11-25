local QBCore = exports['qb-core']:GetCoreObject()
local PlacedBenches = {}
local BenchObjects = {}
local isPlacing = false
local currentBenchType = nil
local currentBenchObject = nil
local currentBenchRotation = 0.0

if not Config.PlaceableBenches or type(Config.PlaceableBenches) ~= "table" then
    Config.PlaceableBenches = {
        Enabled = true,
        UseQBTarget = true,
        MaxPerPlayer = 3,
        Types = {}
    }
    print("Warning: Config.PlaceableBenches is not properly configured. Using default values.")
end

if not Config.PlaceableBenches.Types then
    Config.PlaceableBenches.Types = {}
end

function OptimizedRayCast(distance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    
    local camForward = vector3(
        -math.sin(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
        math.cos(math.rad(camRot.z)) * math.abs(math.cos(math.rad(camRot.x))),
        math.sin(math.rad(camRot.x))
    )
    
    local rayEnd = vector3(
        camCoords.x + (camForward.x * distance),
        camCoords.y + (camForward.y * distance),
        camCoords.z + (camForward.z * distance)
    )
    
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(
        camCoords.x, camCoords.y, camCoords.z,
        rayEnd.x, rayEnd.y, rayEnd.z,
        -1, playerPed, 4
    )
    
    local _, hit, endCoords, _, entity = GetShapeTestResult(rayHandle)
    
    if not hit then
        endCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 2.0, -0.5)
        local success, groundZ = GetGroundZFor_3dCoord(endCoords.x, endCoords.y, endCoords.z, false)
        if success then
            endCoords = vector3(endCoords.x, endCoords.y, groundZ + 0.1)
        end
    end
    
    return hit, endCoords, entity
end

local currentHeightText = ""
local lastHeightUpdate = 0

function UpdateHeightDisplay(height)
    local currentTime = GetGameTimer()
    if currentTime - lastHeightUpdate > 100 then
        lastHeightUpdate = currentTime
        currentHeightText = string.format("Height: %.2f (Press  up and down arrows to adjust)", height)
    end
end

function ClearHeightDisplay()
    currentHeightText = ""
end

CreateThread(function()
    while true do
        if currentHeightText ~= "" and isPlacing then
            SetTextFont(4)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextCentre(true)
            SetTextEntry("STRING")
            AddTextComponentString(currentHeightText)
            DrawText(0.5, 0.9)
        end
        Wait(0)
    end
end)

RegisterNetEvent('crafting:client:SyncBench', function(benchData, isAdding)
    if isAdding then
        PlacedBenches[benchData.id] = benchData
        
        local benchConfig = Config.PlaceableBenches.Types[benchData.benchType]
        if not benchConfig then return end
        
        local model = GetHashKey(benchConfig.model)
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(10)
        end
        
        local object = CreateObject(model, benchData.coords.x, benchData.coords.y, benchData.coords.z, false, false, false)
        SetEntityHeading(object, benchData.heading)
        FreezeEntityPosition(object, true)
        SetEntityAsMissionEntity(object, true, true)
        
        BenchObjects[benchData.id] = object
        
        if Config.PlaceableBenches.UseQBTarget then
            exports['qb-target']:AddTargetEntity(object, {
                options = {
                    {
                        type = "client",
                        event = "crafting:client:OpenBenchMenu",
                        icon = "fas fa-hammer",
                        label = "Use " .. benchConfig.name,
                        benchId = benchData.id
                    },
                    {
                        type = "client",
                        event = "crafting:client:PickupBench",
                        icon = "fas fa-hand-paper",
                        label = "Pick Up " .. benchConfig.name,
                        benchId = benchData.id,
                        canInteract = function()
                            local PlayerData = QBCore.Functions.GetPlayerData()
                            return PlayerData.citizenid == benchData.citizenid
                        end
                    }
                },
                distance = 2.0
            })
        end
    else
        local benchId = benchData.id
        if BenchObjects[benchId] and DoesEntityExist(BenchObjects[benchId]) then
            if Config.PlaceableBenches.UseQBTarget then
                exports['qb-target']:RemoveTargetEntity(BenchObjects[benchId])
            end
            DeleteEntity(BenchObjects[benchId])
            BenchObjects[benchId] = nil
        end
        PlacedBenches[benchId] = nil
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.TriggerCallback('crafting:server:GetPlacedBenches', function(benches)
        for id, benchData in pairs(benches) do
            TriggerEvent('crafting:client:SyncBench', benchData, true)
        end
    end)
end)

CreateThread(function()
    if Config.PlaceableBenches.UseQBTarget then return end
    
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local PlayerData = QBCore.Functions.GetPlayerData()
        
        for id, benchData in pairs(PlacedBenches) do
            local benchConfig = Config.PlaceableBenches.Types[benchData.benchType]
            if benchConfig and BenchObjects[id] and DoesEntityExist(BenchObjects[id]) then
                local objectCoords = GetEntityCoords(BenchObjects[id])
                local distance = #(playerCoords - objectCoords)
                
                if distance < 5.0 then
                    sleep = 0
                    if distance < 2.0 then
                        local text = '[E] Use ' .. benchConfig.name
                        if PlayerData.citizenid == benchData.citizenid then
                            text = text .. ' | [G] Pick Up'
                        end
                        
                        SetTextFont(4)
                        SetTextScale(0.35, 0.35)
                        SetTextColour(255, 255, 255, 255)
                        SetTextCentre(true)
                        SetTextEntry("STRING")
                        AddTextComponentString(text)
                        DrawText(0.5, 0.85)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('crafting:client:PlaceBench', function(benchType)
    if isPlacing then return end
    
    local benchConfig = Config.PlaceableBenches.Types[benchType]
    if not benchConfig then return end
    
    isPlacing = true
    currentBenchType = benchType
    currentBenchRotation = GetEntityHeading(PlayerPedId())
    local currentHeight = 0.0
    
    local model = GetHashKey(benchConfig.model)
    
    QBCore.Functions.Notify("Preparing bench placement...", "primary", 2000)
    
    CreateThread(function()
        if not IsModelValid(model) then
            QBCore.Functions.Notify("Invalid bench model!", "error")
            isPlacing = false
            ClearHeightDisplay()
            return
        end
        
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(10)
        end
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local forwardVector = GetEntityForwardVector(playerPed)
        local startCoords = vector3(
            playerCoords.x + (forwardVector.x * 2.0),
            playerCoords.y + (forwardVector.y * 2.0),
            playerCoords.z
        )
        
        local success, groundZ = GetGroundZFor_3dCoord(startCoords.x, startCoords.y, startCoords.z, false)
        if success then
            startCoords = vector3(startCoords.x, startCoords.y, groundZ + 0.1)
        end
        
        currentBenchObject = CreateObject(model, startCoords.x, startCoords.y, startCoords.z, false, false, false)
        SetEntityHeading(currentBenchObject, currentBenchRotation)
        SetEntityAlpha(currentBenchObject, 200, false)
        SetEntityCollision(currentBenchObject, false, false)
        
        QBCore.Functions.Notify("Controls: SCROLL=Rotate | ARROWS=Height | ENTER=Place | BACKSPACE=Cancel", "primary", 8000)
        
        CreateThread(function()
            while isPlacing and DoesEntityExist(currentBenchObject) do
                local hit, coords, entity = OptimizedRayCast(10.0)
                if hit then
                    local adjustedCoords = vector3(coords.x, coords.y, coords.z + currentHeight)
                    SetEntityCoords(currentBenchObject, adjustedCoords.x, adjustedCoords.y, adjustedCoords.z)
                else
                    local playerPed = PlayerPedId()
                    local playerCoords = GetEntityCoords(playerPed)
                    local forwardVector = GetEntityForwardVector(playerPed)
                    local fallbackCoords = vector3(
                        playerCoords.x + (forwardVector.x * 3.0),
                        playerCoords.y + (forwardVector.y * 3.0),
                        playerCoords.z + currentHeight
                    )
                    local success, groundZ = GetGroundZFor_3dCoord(fallbackCoords.x, fallbackCoords.y, fallbackCoords.z, false)
                    if success then
                        fallbackCoords = vector3(fallbackCoords.x, fallbackCoords.y, groundZ + 0.1 + currentHeight)
                    end
                    SetEntityCoords(currentBenchObject, fallbackCoords.x, fallbackCoords.y, fallbackCoords.z)
                end
                
                SetEntityHeading(currentBenchObject, currentBenchRotation)
                
                UpdateHeightDisplay(currentHeight)
                
                if IsControlPressed(0, 14) then
                    currentBenchRotation = currentBenchRotation + 1.5
                    if currentBenchRotation > 360.0 then currentBenchRotation = 0.0 end
                elseif IsControlPressed(0, 15) then
                    currentBenchRotation = currentBenchRotation - 1.5
                    if currentBenchRotation < 0.0 then currentBenchRotation = 360.0 end
                end
                
                if IsControlJustPressed(0, 172) then
                    currentHeight = currentHeight + 0.1
                elseif IsControlJustPressed(0, 173) then
                    currentHeight = currentHeight - 0.1
                end
                
                if IsControlJustPressed(0, 10) then
                    currentHeight = 0.0
                end
                
                if IsControlJustReleased(0, 18) then
                    local finalCoords = GetEntityCoords(currentBenchObject)
                    local finalHeading = GetEntityHeading(currentBenchObject)
                    
                    local success, groundZ = GetGroundZFor_3dCoord(finalCoords.x, finalCoords.y, finalCoords.z, false)
                    if success then
                        finalCoords = vector3(finalCoords.x, finalCoords.y, groundZ + 0.1)
                    end
                    
                    isPlacing = false
                    DeleteObject(currentBenchObject)
                    currentBenchObject = nil
                    ClearHeightDisplay()
                    
                    TriggerServerEvent('crafting:server:PlaceBench', currentBenchType, finalCoords, finalHeading)
                    return
                end
                
                if IsControlJustReleased(0, 177) then
                    isPlacing = false
                    if DoesEntityExist(currentBenchObject) then
                        DeleteObject(currentBenchObject)
                        currentBenchObject = nil
                    end
                    ClearHeightDisplay()
                    QBCore.Functions.Notify("Bench placement cancelled.", "error")
                    return
                end
                
                Wait(0)
            end
        end)
    end)
end)

RegisterNetEvent('crafting:client:OpenBenchMenu', function(data)
    if not data or not data.benchId then return end
    local benchData = PlacedBenches[data.benchId]
    if not benchData then return end
    local benchConfig = Config.PlaceableBenches.Types[benchData.benchType]
    if not benchConfig then return end
    
    local virtualBench = {
        name = benchConfig.name,
        coords = benchData.coords,
        radius = 2.0,
        recipes = benchConfig.recipes
    }
    
    OpenCraftingMenu(virtualBench)
end)

RegisterNetEvent('crafting:client:PickupBench', function(data)
    if not data or not data.benchId then return end
    local benchId = data.benchId
    if not PlacedBenches[benchId] then return end
    TriggerServerEvent('crafting:server:RemoveBench', benchId)
end)
