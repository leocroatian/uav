RegisterNetEvent('UAV:NoPerms')
RegisterNetEvent('UAV:StopTracking')

local enemiesNear = true -- Set this to true to start checking
local blips = {} -- Table to track blips tied to entity IDs
local onCooldown = false
local cooldownTimer
local vehicleUsed

local function vehicleHearbeat() -- Checking if the vehicle has been deleted
    CreateThread(function()
        while vehicleUsed do
            Wait(2000)

            if vehicleUsed == nil then return end

            local doesExist = DoesEntityExist(vehicleUsed)

            if not doesExist then
                TriggerServerEvent("UAV:VehicleDeleted", vehicleUsed, 'deleted')
            end
        end
    end)
end

local function checkEntities(entities)
    CreateThread(function()
        enemiesNear = true
        while enemiesNear do
            local playerPed = PlayerPedId()
            if IsEntityDead(playerPed) == 1 then
                TriggerServerEvent('UAV:FinishedTracking', (vehicleUsed))
                return
            end

            local playerCoords = GetEntityCoords(playerPed)

            if next(blips) == nil then
                enemiesNear = false
            end

            for _, player in pairs(entities) do

                local id = player.id

                local player = GetPlayerFromServerId(id)
                local playerPed = GetPlayerPed(player)

                if not player or not playerPed then -- check if the player exists in the server
                    if blips[id] then
                        RemoveBlip(blips[id])
                        blips[id] = nil
                    end
                end

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

        TriggerServerEvent('UAV:FinishedTracking', (vehicleUsed))
    end)
end

local function StartTimer()
    onCooldown = true
    CreateThread(function()
        cooldownTimer = (UAV.Cooldown*1000)

        SendNUIMessage({
            type = 'startTimer',
            time = cooldownTimer/2
        })

        SetNuiFocus(false, false)

        while onCooldown do
            Wait(1000)
            cooldownTimer = cooldownTimer - 1000
            if cooldownTimer == ((UAV.Cooldown/2)*1000) then -- When the timer hits half it will automatically start turning the blips off
                if next(blips) ~= nil then
                    for _, playerId in pairs(blips) do
                        RemoveBlip(playerId)
                    end
                    TriggerServerEvent('UAV:FinishedTracking', (vehicleUsed)) -- Send back to the server that the tracking has been finished for the client and to proceed with removing the vehicle from the list.
                end
            end

            if cooldownTimer == 0 then
                onCooldown = false
                SendNUIMessage({
                    type = "stopTimer"
                })
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
            TriggerServerEvent('UAV:VehicleDeleted', vehId, 'destroyed')
        end
    end
end)

AddEventHandler('UAV:StopTracking', function(type, reason) -- Remove all of the active / current blips.
    if next(blips) ~= nil then
        for _, blip in pairs(blips) do
            RemoveBlip(blip)
            blips[blip] = nil
        end
    end

    vehicleUsed = nil

    local description = ""

    if type == 0 then
        description = "Lost connection with vehicle."
    elseif type == 1 then
        description = "No more enemies in the AO."
    elseif type == 2 then
        description = "Tracking Finished"
    end

    lib.notify({
        title = 'UAV',
        description = description,
        type = 'warning'
    })

    SendNUIMessage({
        type = "stopTimer"
    })
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

    -- if closestVeh == nil or closestVeh == 0 or gameName ~= UAV.ModelName then
    if closestVeh == nil or closestVeh == 0 then
        lib.notify({
            title = 'UAV Error',
            description = 'Could not find any close vehicle with satellite capabilities...',
            type = 'error',
        })
        return
    end

    if lib.progressBar({
        duration = UAV.TimeToUse*1000,
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