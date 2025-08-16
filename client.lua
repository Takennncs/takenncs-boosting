local QBCore = exports['qb-core']:GetCoreObject()
local blips = {}
local currentSpawned = false
local currentEntity = nil
local currentModel = nil
local currentPlate = nil
local currentLocation = nil
local currentDelivery = nil
local locationPoint = nil
local deliveryNPC = nil

-- Configuration (ensure cfg is defined in a separate config.lua)
-- Example: cfg = { levels = {...}, vehicleSpawns = {...}, deliveryPoints = {...}, contractTime = {min = 5, max = 15}, levelReward = {min = 10, max = 50} }

local function resetSettings()
    for i = 1, #blips do
        if DoesBlipExist(blips[i]) then
            RemoveBlip(blips[i])
        end
    end
    blips = {}
    
    if currentEntity and DoesEntityExist(currentEntity) then
        DeleteEntity(currentEntity)
    end
    
    if deliveryNPC and DoesEntityExist(deliveryNPC) then
        exports.ox_target:removeEntity(deliveryNPC, 'receive_payment')
        DeleteEntity(deliveryNPC)
    end
    
    currentSpawned = false
    currentEntity = nil
    currentModel = nil
    currentPlate = nil
    currentLocation = nil
    currentDelivery = nil
    
    if locationPoint then
        locationPoint:remove()
        locationPoint = nil
    end
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        resetSettings()
    end
end)

exports('openTablet', function()
    SetNuiFocus(true, true)
    SendNUIMessage({action = 'openMenu', data = {levels = cfg.levels}})
    exports['takenncs-scripts']:toggleTab(true)
end)

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    exports['takenncs-scripts']:toggleTab(false)
    cb(true)
end)

RegisterNUICallback('requestData', function(data, cb)
    lib.callback('takenncs-boosting:requestData', false, function(response)
        cb(response or false)
    end)
end)

local function drawText3d(x, y, z, text)
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
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function requestNetworkControlOfEntity(entityHandle)
    if entityHandle and DoesEntityExist(entityHandle) then
        local attempt = 0
        while DoesEntityExist(entityHandle) and not NetworkHasControlOfEntity(entityHandle) and attempt < 5000 do
            Citizen.Wait(1)
            NetworkRequestControlOfEntity(entityHandle)
            attempt = attempt + 1
        end
        return DoesEntityExist(entityHandle) and NetworkHasControlOfEntity(entityHandle)
    end
    return false
end

local function getVehiclePlate(vehicle)
    if DoesEntityExist(vehicle) then
        local plate = GetVehicleNumberPlateText(vehicle)
        return QBCore.Shared.Trim(plate)
    end
    return false
end

local function createNPC()
    if not currentDelivery then
        QBCore.Functions.Notify('Viga: BOOSTI punkti ei leitud!', 'error')
        return
    end
    
    lib.requestModel(joaat('s_m_m_dockwork_01'))
    deliveryNPC = CreatePed(4, joaat('s_m_m_dockwork_01'), currentDelivery.x, currentDelivery.y, currentDelivery.z - 1.0, currentDelivery.w or 0.0, true, true)
    
    while not DoesEntityExist(deliveryNPC) do
        Wait(10)
    end
    
    FreezeEntityPosition(deliveryNPC, true)
    SetEntityInvincible(deliveryNPC, true)
    SetBlockingOfNonTemporaryEvents(deliveryNPC, true)
    
    exports.ox_target:addLocalEntity(deliveryNPC, {
        {
            name = 'receive_payment',
            label = 'Anna sõiduk üle',
            icon = 'fas fa-money-bill-wave',
            distance = 2.5,
            onSelect = function()
                local playerPed = PlayerPedId()
                local coords = GetEntityCoords(playerPed)
                local vehicle = GetClosestVehicle(coords.x, coords.y, coords.z, 10.0, 0, 71)
                
                if not vehicle then
                    QBCore.Functions.Notify('Ühtegi sõidukit ei leitud!', 'error')
                    return
                end
                
                local vehiclePlate = QBCore.Shared.Trim(GetVehicleNumberPlateText(vehicle))
                if vehiclePlate ~= currentPlate then
                    QBCore.Functions.Notify('Vale sõiduki numbrimärk!', 'error')
                    return
                end
                
                if IsPedInAnyVehicle(playerPed, false) then
                    QBCore.Functions.Notify('Välju sõidukist enne üle andmist!', 'error')
                    return
                end
                
                lib.callback('takenncs-boosting:receivePayment', false, function(success)
                    if success then
                        SetEntityAsMissionEntity(vehicle, true, true)
                        DeleteEntity(vehicle)
                        resetSettings()
                    else
                        QBCore.Functions.Notify('Üle andmine ebaõnnestus!', 'error')
                    end
                end)
            end
        }
    })
end

local function createDeliveryPoint()
    if blips[2] and DoesBlipExist(blips[2]) then
        RemoveBlip(blips[2])
    end
    if currentDelivery and currentDelivery.x and currentDelivery.y and currentDelivery.z then
        blips[2] = AddBlipForCoord(currentDelivery.x, currentDelivery.y, currentDelivery.z)
        SetBlipSprite(blips[2], 68)
SetBlipColour(blips[2], 1) -- Punane
        SetBlipScale(blips[2], 0.7)
        SetBlipDisplay(blips[2], 4)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Klient')
        EndTextCommandSetBlipName(blips[2])
        SetNewWaypoint(currentDelivery.x, currentDelivery.y)
        createNPC()
    else
        QBCore.Functions.Notify('Viga: BOOSTI punkti ei saa luua!', 'error')
    end
end

local function spawnVehicle()
    if not currentModel then
        QBCore.Functions.Notify('Viga: Sõiduki mudel puudub!', 'error')
        return
    end
    lib.requestModel(joaat(currentModel))
    currentEntity = CreateVehicle(joaat(currentModel), currentLocation.x, currentLocation.y, currentLocation.z, currentLocation.w, true, true)
    
    while not DoesEntityExist(currentEntity) do
        Wait(10)
    end
    
    SetEntityHeading(currentEntity, currentLocation.w)
    SetVehicleEngineOn(currentEntity, false, true, true)
    SetVehicleOnGroundProperly(currentEntity)
    SetVehicleNumberPlateText(currentEntity, currentPlate)
    SetVehicleDoorsLocked(currentEntity, 2)
    SetVehicleNeedsToBeHotwired(currentEntity, false)
    
    CreateThread(function()
        while DoesEntityExist(currentEntity) do
            if IsVehicleEngineOn(currentEntity) then
                if blips[1] then
                    RemoveBlip(blips[1])
                    blips[1] = nil
                end
                
                if locationPoint then
                    locationPoint:remove()
                    locationPoint = nil
                end
                
                if currentDelivery then
                    createDeliveryPoint()
                end
                break
            end
            Wait(1000)
        end
    end)
end

local function createLocationPoint()
    if not currentLocation or not currentLocation.x or not currentLocation.y then
        QBCore.Functions.Notify('Viga: Sõiduki asukoht puudub!', 'error')
        return
    end
    if blips[1] and DoesBlipExist(blips[1]) then
        RemoveBlip(blips[1])
    end
    blips[1] = AddBlipForRadius(currentLocation.x + math.random(-50.0, 50.0), currentLocation.y + math.random(-50.0, 50.0), 0.0, 75.0)
    SetBlipSprite(blips[1], 9)
    SetBlipColour(blips[1], 1)
    SetBlipAlpha(blips[1], 80)
    if locationPoint then
        locationPoint:remove()
    end
    locationPoint = lib.points.new({
        coords = currentLocation.xyz,
        distance = 75,
    })
    function locationPoint:onEnter()
        currentSpawned = true
        spawnVehicle()
    end
end

RegisterNetEvent('takenncs-boosting:client:acceptContract', function(contract)
    if contract then
        currentModel = contract.model
        currentPlate = contract.plate
        currentLocation = contract.location
        currentDelivery = contract.delivery
        createLocationPoint()
    end
end)

RegisterNUICallback('acceptContract', function(data, cb)
    lib.callback('takenncs-boosting:acceptContract', false, function(response)
        if response then
            TriggerEvent('takenncs-boosting:client:acceptContract', response)
            TriggerEvent('takenncs-boosting:client:requestData')
            cb(response)
        else
            TriggerEvent('takenncs-boosting:client:requestData')
            cb(false)
        end
    end, data.id)
end)

RegisterNUICallback('cancelContract', function(data, cb)
    lib.callback('takenncs-boosting:cancelContract', false, function(response)
        if response then
            resetSettings()
            TriggerEvent('takenncs-boosting:client:requestData')
            cb(true)
        else
            TriggerEvent('takenncs-boosting:client:requestData')
            cb(false)
        end
    end, data.id)
end)

RegisterNUICallback('joinQueue', function(data, cb)
    lib.callback('takenncs-boosting:joinQueue', false, function(response)
        if response then
            TriggerEvent('takenncs-boosting:client:requestData')
            cb(true)
        else
            cb(false)
        end
    end)
end)

RegisterNUICallback('leaveQueue', function(data, cb)
    lib.callback('takenncs-boosting:leaveQueue', false, function(response)
        if response then
            TriggerEvent('takenncs-boosting:client:requestData')
            cb(true)
        else
            cb(false)
        end
    end)
end)

RegisterNetEvent('takenncs-boosting:client:requestData', function()
    SendNUIMessage({ action = 'requestData' })
end)