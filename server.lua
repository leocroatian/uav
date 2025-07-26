local vehiclesUsed = {}

RegisterNetEvent('UAV:Launch')
RegisterNetEvent('UAV:FinishedTracking')
RegisterNetEvent('UAV:LogVehicle')
RegisterNetEvent('UAV:VehicleDamaged')
RegisterNetEvent("UAV:VehicleDeleted")

AddEventHandler('UAV:Launch', function()
    if IsPlayerAceAllowed(source, UAV.AcePerm) then
        -- for _, player in pairs(found_players) do
        --     local id = player.id
        --     local ped = player.ped
        --     local coords = player.coords
            
        --     print("ID:", id)
        --     print("Ped:", ped)
        --     print("Coords:", coords)
        -- end
        local found_players = lib.getNearbyPlayers(GetEntityCoords(GetPlayerPed(source)), UAV.MaxDist)
        TriggerClientEvent('UAV:FindPlayers', source, (found_players))
    else
        TriggerClientEvent('UAV:NoPerms', source)
    end

    -- local found_players = lib.getNearbyPlayers(GetEntityCoords(GetPlayerPed(source)), UAV.MaxDist)
    -- TriggerClientEvent('UAV:FindPlayers', source, (found_players))
end)

AddEventHandler('UAV:FinishedTracking', function(source, vehicleUsed)
    print(('[UAV] Finished Tracking - Removing %s from the list as Player #%s finished tracking'):format(vehicleUsed, source))
    
    vehiclesUsed[vehicleUsed] = nil
end)

AddEventHandler('UAV:LogVehicle', function(vehicleUsed)
  print(('[UAV] Logging Vehicle - Player ID: %s | Vehicle Net Id: %s'):format(source, vehicleUsed))

  vehiclesUsed[vehicleUsed] = {
    networkId = vehicleUsed,
    playerId = source
  }
end)

-- Handling when the vehicle is damaged or deleted

AddEventHandler('UAV:VehicleDamaged', function(vehicleUsed)
    print(('[UAV] Vehicle with Net ID %s was damaged.'):format(vehicleUsed))

    TriggerClientEvent('UAV:StopTracking', source)

    vehiclesUsed[vehicleUsed] = nil
end)

AddEventHandler("UAV:VehicleDeleted", function(vehicleUsed)
    print(("[UAV] Vehicle with Net ID %s has been deleted."):format(vehicleUsed))

    TriggerClientEvent('UAV:StopTracking', source)

    vehiclesUsed[vehicleUsed] = nil
end)