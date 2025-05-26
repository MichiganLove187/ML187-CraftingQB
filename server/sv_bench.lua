local QBCore = exports['qb-core']:GetCoreObject()
local PlacedBenches = {}

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

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    LoadPlacedBenches()
end)

function LoadPlacedBenches()
    local result = MySQL.Sync.fetchAll('SELECT * FROM player_crafting_benches')
    if result and #result > 0 then
        for _, bench in ipairs(result) do
            local benchData = {
                id = bench.id,
                citizenid = bench.citizenid,
                benchType = bench.bench_type,
                coords = vector3(bench.coords_x, bench.coords_y, bench.coords_z),
                heading = bench.heading
            }
            PlacedBenches[bench.id] = benchData
            TriggerClientEvent('crafting:client:SyncBench', -1, benchData, true)
        end
        print('Loaded ' .. #result .. ' crafting benches from database')
    end
end

CreateThread(function()
    for benchType, benchConfig in pairs(Config.PlaceableBenches.Types) do
        QBCore.Functions.CreateUseableItem(benchConfig.item, function(source)
            local src = source
            TriggerClientEvent('crafting:client:PlaceBench', src, benchType)
        end)
    end
end)

RegisterNetEvent('crafting:server:PlaceBench', function(benchType, coords, heading)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local benchConfig = Config.PlaceableBenches.Types[benchType]
    if not benchConfig then return end
    
    if not Player.Functions.RemoveItem(benchConfig.item, 1) then
        TriggerClientEvent('QBCore:Notify', src, "You don't have the required item!", "error")
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    local result = MySQL.Sync.fetchAll('SELECT COUNT(*) as count FROM player_crafting_benches WHERE citizenid = ?', {citizenid})
    
    if result[1].count >= Config.PlaceableBenches.MaxPerPlayer then
        Player.Functions.AddItem(benchConfig.item, 1)
        TriggerClientEvent('QBCore:Notify', src, "You've reached the maximum number of benches!", "error")
        return
    end
    
    local id = MySQL.Sync.insert('INSERT INTO player_crafting_benches (citizenid, bench_type, coords_x, coords_y, coords_z, heading) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid,
        benchType,
        coords.x,
        coords.y,
        coords.z,
        heading
    })
    
    if id then
        local benchData = {
            id = id,
            citizenid = citizenid,
            benchType = benchType,
            coords = coords,
            heading = heading
        }
        
        PlacedBenches[id] = benchData
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[benchConfig.item], "remove")
        TriggerClientEvent('QBCore:Notify', src, "Bench placed successfully!", "success")
        TriggerClientEvent('crafting:client:SyncBench', -1, benchData, true)
    else

        Player.Functions.AddItem(benchConfig.item, 1)
        TriggerClientEvent('QBCore:Notify', src, "Failed to place bench!", "error")
    end
end)

RegisterNetEvent('crafting:server:RemoveBench', function(benchId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local benchData = PlacedBenches[benchId]
    
    if not benchData then
        TriggerClientEvent('QBCore:Notify', src, "Bench not found!", "error")
        return
    end
    
    if benchData.citizenid ~= citizenid then
        TriggerClientEvent('QBCore:Notify', src, "You don't own this bench!", "error")
        return
    end
    
    MySQL.Async.execute('DELETE FROM player_crafting_benches WHERE id = ?', {benchId})
    
    local benchConfig = Config.PlaceableBenches.Types[benchData.benchType]
    
    if benchConfig then
        Player.Functions.AddItem(benchConfig.item, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[benchConfig.item], "add")
    end
    
    PlacedBenches[benchId] = nil
    TriggerClientEvent('QBCore:Notify', src, "Bench removed successfully!", "success")
    TriggerClientEvent('crafting:client:SyncBench', -1, {id = benchId}, false)
end)

QBCore.Functions.CreateCallback('crafting:server:GetPlacedBenches', function(source, cb)
    cb(PlacedBenches)
end)
