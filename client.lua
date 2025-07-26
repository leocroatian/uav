RegisterNetEvent('UAV:NoPerms')
RegisterNetEvent('UAV:StopTracking')

local enemiesNear = true -- Set this to true to start checking
local blips = {} -- Table to track blips tied to entity IDs
local onCooldown = false
local cooldownTimer
local vehicleUsed

local function vehicleHearbeat() -- Checking if the vehicle has been deleted
    CreateThread(function()
        while vehicleUsed ~= nil do
            Wait(2000)

            local veh = GetVehicleIndexFromEntityIndex(vehicleUsed)

            if not DoesEntityExist(veh) then
                TriggerServerEvent("UAV:VehicleDeleted", vehicleUsed)
                vehicleUsed = nil
            end
        end
    end)
end

local function checkEntities(entities)
    CreateThread(function()
        enemiesNear = true
        while enemiesNear do
            local playerCoords = GetEntityCoords(PlayerPedId())

            if next(blips) == nil then
                enemiesNear = false
            end

            for _, player in pairs(entities) do
                local id = player.id

                local player = GetPlayerFromServerId(id)
                local playerPed = GetPlayerPed(player)

                local entityCoords = GetEntityCoords(playerPed)
                local isDead = IsEntityDead(playerPed)

                local distance = #(playerCoords - entityCoords)

                if isDead == 1 or distance > UAV.MaxDist then -- example max range: 150 units
                    if blips[id] then
                        RemoveBlip(blips[id])
                        blips[id] = nil
                    end
                end
            end

            Wait(1000) -- Avoid spamming every frame
        end
    end)
end

local function StartTimer()
    onCooldown = true
    CreateThread(function()
        cooldownTimer = (600*1000)  -- 10 minutes
        while onCooldown do
            Wait(1000)
            cooldownTimer = cooldownTimer - 1000
            if cooldownTimer == (300*1000) then
                for _, playerId in pairs(blips) do
                    RemoveBlip(playerId)
                end
                TriggerServerEvent('UAV:FinishedTracking', (vehicleUsed)) -- Send back to the server that the tracking has been finished for the client and to proceed with removing the vehicle from the list.
                vehicleUsed = nil
            end

            if cooldownTimer == 0 then
                onCooldown = false
            end
        end
    end)
end

local function DrawBlips(entities)
    local enemyCount = 0
    local foundEnemy = false
    local serverId = GetPlayerServerId(PlayerId())

    for _, player in pairs(entities) do
        local id = player.id

        if id ~= serverId then
            if not blips[id] then
                enemyCount += 1
                -- print(("Server ID: %s | Ped ID: %s | Coords: %s"):format(id, ped, coords))
                local player = GetPlayerFromServerId(id)
                local blip = AddBlipForEntity(GetPlayerPed(player))
                SetBlipSprite(blip, 161)
                SetBlipAlpha(blip, 255)
                SetBlipColour(blip, 1)
                SetBlipScale(blip, 0.85)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName("STRING")
                AddTextComponentString(string.format("Enemy #%d", enemyCount))
                EndTextCommandSetBlipName(blip)

                blips[id] = blip
                foundEnemy = true
            end
        end
    end

    if not foundEnemy then
        lib.notify({
            title = 'UAV Error',
            description = 'No players in the area to locate.',
            type = 'error'
        })
    else
        lib.notify({
            title = 'UAV Launched',
            description = 'You have launched a UAV - Starting scan in the area for all enemies.',
            type = 'success',
            icon='fa-solid fa-satellite',
            iconColor = '#FFFFFF',
        })
        StartTimer()
    end

    checkEntities(entities)
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkVehicleUndrivable' then -- Check if the vehicle has been blown up.
        local vehId = args[1]

        if vehId == vehicleUsed then
            TriggerServerEvent('UAV:VehicleDamaged', vehId)
        end
    end
end)

AddEventHandler('UAV:StopTracking', function() -- Remove all of the active / current blips.
    for _, blip in pairs(blips) do
        RemoveBlip(blip)
        blips[blip] = nil
    end
end)

AddEventHandler('UAV:NoPerms', function()
    lib.notify({
        title = 'UAV Error',
        description = 'You do not have permissions to use this command.',
        type = 'error'
    })
end)

RegisterNetEvent('UAV:FindPlayers', function(found_players)
    local ped_coords = GetEntityCoords(PlayerPedId())
    vehicleUsed = lib.getClosestVehicle(ped_coords, 5.0, true)
    local closestVeh = GetEntityModel(vehicleUsed)
    local gameName = GetDisplayNameFromVehicleModel(closestVeh)

    if closestVeh == nil or closestVeh == 0 or gameName ~= UAV.ModelName then
        lib.notify({
            title = 'UAV Error',
            description = 'Could not find any close vehicle with satellite capabilities...',
            type = 'error',
        })
        return
    end

    if lib.progressBar({
        duration = 10000,
        label = 'Launching UAV',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = false,
            move = true,
            combat = true,
            sprint = true
        },
        anim = {
            dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a',
            clip = 'idle_a'
        },
        prop = {
            model = `prop_cs_tablet`,
            pos = vec3(-0.05, 0.0, 0.0),
            rot = vec3(0.0, 0.0, 0.0)
        },
    })
    then
        if #found_players == 0 then
            lib.notify({
                title = 'UAV Error',
                description = 'No players in the area to locate.',
                type = 'error'
            })
        else
            DrawBlips(found_players)
            TriggerServerEvent('UAV:LogVehicle', (vehicleUsed))
            vehicleHearbeat()
        end
    else
        lib.notify({
            title = 'UAV Cancelled',
            description = 'You have cancelled the UAV - Returning to drone station.',
            icon='fa-solid fa-satellite',
            iconColor = '#FFFFFF'
        })
    end
end)

RegisterCommand("uav", function(source, args, rawCommand)
    if onCooldown then
        lib.notify({
            title = 'UAV Error',
            description = ('You are on active cooldown for %s minutes'):format(math.round((cooldownTimer/1000)/60, 2)),
            type = 'error'
        })
        return
    end

    TriggerServerEvent('UAV:Launch')
end)