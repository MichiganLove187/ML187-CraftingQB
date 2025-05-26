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
                        
                        DrawText3D(objectCoords.x, objectCoords.y, objectCoords.z + (benchConfig.zOffset or 1.0), text)
                        
                        if IsControlJustReleased(0, 38) then -- E key
                            TriggerEvent('crafting:client:OpenBenchMenu', {benchId = id})
                        end
                        
                        if IsControlJustReleased(0, 47) and PlayerData.citizenid == benchData.citizenid then -- G key
                            TriggerEvent('crafting:client:PickupBench', {benchId = id})
                        end
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
    currentBenchRotation = 0.0
    local currentHeight = 0.0
    
    local model = GetHashKey(benchConfig.model)
    RequestModel(model)
    
    QBCore.Functions.Notify("Preparing bench placement...", "primary", 2000)
    
    CreateThread(function()
        while not HasModelLoaded(model) do
            RequestModel(model)
            Wait(10)
        end
        
        local hit, coords, entity = OptimizedRayCast(5.0)
        local initialCoords = coords
        if not hit then

            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local forward = GetEntityForwardVector(playerPed)
            initialCoords = playerCoords + forward * 1.0
        end
        
        currentBenchObject = CreateObject(model, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false)
        SetEntityHeading(currentBenchObject, GetEntityHeading(PlayerPedId()))
        SetEntityAlpha(currentBenchObject, 200, false)
        SetEntityCollision(currentBenchObject, false, false)
        
        QBCore.Functions.Notify("Controls:", "primary", 10000)
        QBCore.Functions.Notify("SCROLL WHEEL: Rotate | ARROW KEYS: Adjust Height", "primary", 10000)
        QBCore.Functions.Notify("ENTER: Confirm Placement | BACKSPACE: Cancel", "primary", 10000)
        
        CreateThread(function()
            local lastRaycastTime = 0
            
            while isPlacing do
                local currentTime = GetGameTimer()
                local playerPed = PlayerPedId()
                local playerCoords = GetEntityCoords(playerPed)
                
                if currentTime - lastRaycastTime > 50 then
                    lastRaycastTime = currentTime
                    local hit, coords, entity = OptimizedRayCast(5.0)
                    
                    if hit then

                        local adjustedCoords = vector3(coords.x, coords.y, coords.z + currentHeight)
                        
                        SetEntityCoords(currentBenchObject, adjustedCoords.x, adjustedCoords.y, adjustedCoords.z)
                        SetEntityHeading(currentBenchObject, currentBenchRotation)
                    end
                end
                
                if IsControlJustPressed(0, 14) then -- Scroll down
                    currentBenchRotation = currentBenchRotation + 5.0
                    if currentBenchRotation > 360.0 then currentBenchRotation = 0.0 end
                elseif IsControlJustPressed(0, 15) then -- Scroll up
                    currentBenchRotation = currentBenchRotation - 5.0
                    if currentBenchRotation < 0.0 then currentBenchRotation = 360.0 end
                end
                
                if IsControlJustPressed(0, 172) then -- Arrow Up
                    currentHeight = currentHeight + 0.05
                elseif IsControlJustPressed(0, 173) then -- Arrow Down
                    currentHeight = currentHeight - 0.05
                elseif IsControlJustPressed(0, 174) then -- Arrow Left
                    currentHeight = currentHeight - 0.01
                elseif IsControlJustPressed(0, 175) then -- Arrow Right
                    currentHeight = currentHeight + 0.01
                end
                
                if DoesEntityExist(currentBenchObject) then
                    local objectCoords = GetEntityCoords(currentBenchObject)
                    local heightText = string.format("Height: %.2f", currentHeight)
                    DrawText3D(objectCoords.x, objectCoords.y, objectCoords.z + 0.5, heightText)
                end
                
                if IsControlJustReleased(0, 18) then -- Enter key
                    if DoesEntityExist(currentBenchObject) then
                        local finalCoords = GetEntityCoords(currentBenchObject)
                        isPlacing = false
                        DeleteObject(currentBenchObject)
                        currentBenchObject = nil
                        
                        TriggerServerEvent('crafting:server:PlaceBench', currentBenchType, finalCoords, currentBenchRotation)
                    end
                end
                
                if IsControlJustReleased(0, 177) then -- Backspace key
                    isPlacing = false
                    if DoesEntityExist(currentBenchObject) then
                        DeleteObject(currentBenchObject)
                        currentBenchObject = nil
                    end
                    QBCore.Functions.Notify("Bench placement cancelled.", "error")
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

function OptimizedRayCast(distance)
    local camCoords = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(2)
    local camForward = CamRotationToDirection(camRot)
    local rayTo = vector3(
        camCoords.x + camForward.x * distance,
        camCoords.y + camForward.y * distance,
        camCoords.z + camForward.z * distance
    )
    
    local rayHandle = StartShapeTestRay(
        camCoords.x, camCoords.y, camCoords.z,
        rayTo.x, rayTo.y, rayTo.z,
        1, PlayerPedId(), 0
    )
    
    local _, hit, endCoords, _, entity = GetShapeTestResult(rayHandle)
    return hit == 1, endCoords, entity
end

function CamRotationToDirection(rotation)
    local rotZ = math.rad(rotation.z)
    local rotX = math.rad(rotation.x)
    local cosRotX = math.abs(math.cos(rotX))
    
    return vector3(
        -math.sin(rotZ) * cosRotX,
        math.cos(rotZ) * cosRotX,
        math.sin(rotX)
    )
end

function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

if not DrawText3D then
    function DrawText3D(x, y, z, text)
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        SetDrawOrigin(x, y, z, 0)
        DrawText(0.0, 0.0)
        local factor = (string.len(text)) / 370
        DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 75)
        ClearDrawOrigin()
    end
end
