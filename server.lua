RegisterNetEvent('UAV:Launch')

AddEventHandler('UAV:Launch', function()
    -- if IsPlayerAceAllowed(source, UAV.AcePerm) then
    --     -- for _, player in pairs(found_players) do
    --     --     local id = player.id
    --     --     local ped = player.ped
    --     --     local coords = player.coords
            
    --     --     print("ID:", id)
    --     --     print("Ped:", ped)
    --     --     print("Coords:", coords)
    --     -- end
    --     local found_players = lib.getNearbyPlayers(GetEntityCoords(GetPlayerPed(source)), 200)
    --     TriggerClientEvent('UAV:FindPlayers', source, (found_players))
    -- else
    --     TriggerClientEvent('UAV:NoPerms', source)
    -- end

    local found_players = lib.getNearbyPlayers(GetEntityCoords(GetPlayerPed(source)), 200)
    TriggerClientEvent('UAV:FindPlayers', source, (found_players))
end)