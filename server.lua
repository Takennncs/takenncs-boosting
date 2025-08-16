local QBCore = exports['qb-core']:GetCoreObject()
local availableContracts = {}
local currentContracts = {}
local loadedPlayers = {}

local function loadPlayer(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        return
    end
    local citizenid = player.PlayerData.citizenid
    loadedPlayers[source] = {
        xp = 0,
        finished = 0,
        queued = false
    }
    local result = MySQL.prepare.await('SELECT * FROM `takenncs-boosting` WHERE charId = ?', { citizenid })
    if result then
        loadedPlayers[source].xp = result.xp or 0
        loadedPlayers[source].finished = result.finished or 0
    else
        MySQL.insert('INSERT INTO `takenncs-boosting` (charId, xp, finished) VALUES (?, 0, 0)', { citizenid }, function(id)
            if not id then
                TriggerClientEvent('QBCore:Notify', source, 'Viga: Andmebaasi uuendamine ebaõnnestus!', 'error')
            end
        end)
    end
end

AddEventHandler('ox:playerLoaded', function(source)
    loadPlayer(source)
end)

AddEventHandler('playerDropped', function()
    if loadedPlayers[source] then
        loadedPlayers[source] = nil
    end
end)

CreateThread(function()
    local players = QBCore.Functions.GetPlayers()
    for _, source in pairs(players) do
        local player = QBCore.Functions.GetPlayer(source)
        if player then
            loadPlayer(source)
        end
    end
end)

local function miniUuid()
    local time = os.time()
    local random = math.random(100000, 999999)
    return string.format('%x-%x', time, random)
end

local function calculatePriceRange(price)
    return math.random(1000, 2000)
end

local function generatePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = ''
    for i = 1, 8 do
        local rand = math.random(1, #chars)
        plate = plate .. chars:sub(rand, rand)
    end
    return plate
end

local function getRandomVehicle()
    local returnable = {}
    for k, v in pairs(exports['qb-core']:getSharedVehicles()) do
        table.insert(returnable, v)
    end
    if #returnable > 0 then
        math.randomseed(os.time() + math.random(1000))
        return returnable[math.random(#returnable)]
    end
    return nil
end

CreateThread(function()
    while true do
        local players = QBCore.Functions.GetPlayers()
        for _, source in pairs(players) do
            local player = QBCore.Functions.GetPlayer(source)
            if player then
                local citizenid = player.PlayerData.citizenid
                if availableContracts[citizenid] then
                    for i = #availableContracts[citizenid], 1, -1 do
                        if os.time() - (availableContracts[citizenid][i].created or 0) > 3600 then
                            table.remove(availableContracts[citizenid], i)
                        end
                    end
                end
                local loadedPlayer = loadedPlayers[source]
                if loadedPlayer and loadedPlayer.queued then
                    if not availableContracts[citizenid] then
                        availableContracts[citizenid] = {}
                    end
                    local vehicleValues = getRandomVehicle()
                    if vehicleValues and vehicleValues.model then
                        local contract = {
                            id = miniUuid(),
                            plate = generatePlate(),
                            model = vehicleValues.model,
                            vehicleName = vehicleValues.name,
                            price = calculatePriceRange(vehicleValues.price),
                            location = cfg.vehicleSpawns[math.random(1, #cfg.vehicleSpawns)],
                            delivery = cfg.deliveryPoints[math.random(1, #cfg.deliveryPoints)],
                            created = os.time()
                        }
                        table.insert(availableContracts[citizenid], contract)
                        TriggerClientEvent('takenncs-boosting:client:requestData', source)
                    end
                end
            end
        end
        Wait(math.random(cfg.contractTime.min, cfg.contractTime.max) * 60000)
    end
end)

lib.callback.register('takenncs-boosting:requestData', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if player and loadedPlayers[source] then
        local citizenid = player.PlayerData.citizenid
        local data = {
            inQueue = loadedPlayers[source].queued,
            availableContracts = availableContracts[citizenid] or {},
            boostingXp = loadedPlayers[source].xp,
            currentContract = currentContracts[citizenid] or nil
        }
        return data
    end
    return false
end)

local function getContractById(charId, contractId)
    for _, contract in ipairs(availableContracts[charId] or {}) do
        if contract.id == contractId then
            return contract
        end
    end
    return nil
end

local function sendMail(source, contract)
    local phoneNumber = exports['lb-phone']:GetEquippedPhoneNumber(source)
    if phoneNumber then
        local mail = exports['lb-phone']:GetEmailAddress(phoneNumber)
        if mail then
            exports['lb-phone']:SendMail({
                to = mail,
                sender = 'M. Vickers',
                subject = 'Sõiduki kohaletoimetamine',
                message = string.format(
                    'Tere!\n\nPalun võta peale sõiduk %s (%s) ning seejärel too see Tarnepunkti. Meie mehaanikud võtavad sealt üle ja hoolitsevad edasise eest.\n\nParimate soovidega,\n\nM. Vickers',
                    contract.vehicleName, contract.plate
                )
            })
        end
    end
end

local function removeAvailableContract(charId, id)
    for index, contract in ipairs(availableContracts[charId] or {}) do
        if contract.id == id then
            table.remove(availableContracts[charId], index)
            break
        end
    end
end

lib.callback.register('takenncs-boosting:acceptContract', function(source, id)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        TriggerClientEvent('QBCore:Notify', source, 'Viga: Mängijat ei leitud!', 'error')
        return false
    end

    local citizenid = player.PlayerData.citizenid
    if currentContracts[citizenid] then
        TriggerClientEvent('QBCore:Notify', source, 'Sul on juba töö käimas! Lõpeta see enne uue võtmist.', 'error')
        return false
    end

    local contract = getContractById(citizenid, id)
    if contract then
        if player.PlayerData.money['bank'] >= contract.price then
            player.Functions.RemoveMoney('bank', contract.price)
            currentContracts[citizenid] = contract
            removeAvailableContract(citizenid, id)
            sendMail(source, contract)
            TriggerClientEvent('QBCore:Notify', source, 'Tööots leitud! Otsi sõiduk ja vii sihtpunkti.', 'success')
            TriggerClientEvent('takenncs-boosting:client:requestData', source)
            return contract
        else
            TriggerClientEvent('QBCore:Notify', source, 'Sul ei ole piisavalt raha selle töö jaoks!', 'error')
            return false
        end
    else
        TriggerClientEvent('QBCore:Notify', source, 'Tööotsu ei leitud!', 'error')
        return false
    end
end)

lib.callback.register('takenncs-boosting:cancelContract', function(source, id)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        TriggerClientEvent('QBCore:Notify', source, 'Viga: Mängijat ei leitud!', 'error')
        return false
    end

    local citizenid = player.PlayerData.citizenid
    if availableContracts[citizenid] then
        for i, contract in ipairs(availableContracts[citizenid]) do
            if contract.id == id then
                table.remove(availableContracts[citizenid], i)
                TriggerClientEvent('takenncs-boosting:client:requestData', source)
                TriggerClientEvent('QBCore:Notify', source, 'Tööots tühistatud!', 'success')
                return true
            end
        end
    end
    
    if currentContracts[citizenid] and currentContracts[citizenid].id == id then
        currentContracts[citizenid] = nil
        TriggerClientEvent('takenncs-boosting:client:requestData', source)
        TriggerClientEvent('QBCore:Notify', source, 'Tööots tühistatud!', 'success')
        return true
    end

    TriggerClientEvent('QBCore:Notify', source, 'Tööotsu ei leitud tühistamiseks!', 'error')
    return false
end)

lib.callback.register('takenncs-boosting:joinQueue', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if player and loadedPlayers[source] then
        loadedPlayers[source].queued = true
        TriggerClientEvent('QBCore:Notify', source, 'Liitusite järjekorraga!', 'info')
        TriggerClientEvent('takenncs-boosting:client:requestData', source)
        return true
    end
    TriggerClientEvent('QBCore:Notify', source, 'Viga: Järjekorraga liitumine ebaõnnestus!', 'error')
    return false
end)

lib.callback.register('takenncs-boosting:leaveQueue', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if player and loadedPlayers[source] then
        loadedPlayers[source].queued = false
        TriggerClientEvent('QBCore:Notify', source, 'Lahkusite järjekorrast!', 'info')
        TriggerClientEvent('takenncs-boosting:client:requestData', source)
        return true
    end
    TriggerClientEvent('QBCore:Notify', source, 'Viga: Järjekorrast lahkumine ebaõnnestus!', 'error')
    return false
end)

lib.callback.register('takenncs-boosting:receivePayment', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    if not player then
        TriggerClientEvent('QBCore:Notify', source, 'Viga: Mängijat ei leitud!', 'error')
        return false
    end

    local citizenid = player.PlayerData.citizenid
    if not currentContracts[citizenid] then
        TriggerClientEvent('QBCore:Notify', source, 'Viga: Aktiivset tööotsu ei leitud!', 'error')
        return false
    end

    local contract = currentContracts[citizenid]
    local loadedPlayer = loadedPlayers[source]
    if not loadedPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Viga: Mängija andmed puuduvad!', 'error')
        return false
    end

    local function getLevelByXP()
        local myXp = loadedPlayer.xp or 0
        for _, data in pairs(cfg.levels) do
            if myXp >= data.xp then
                return data
            end
        end
        return cfg.levels[1]
    end

    local myLevel = getLevelByXP()
    local reward = QBCore.Shared.Round(contract.price * (myLevel.procentage or 1.0))
    local levelReward = math.random(cfg.levelReward.min, cfg.levelReward.max)

    loadedPlayer.xp = (loadedPlayer.xp or 0) + levelReward
    loadedPlayer.finished = (loadedPlayer.finished or 0) + 1
    
    MySQL.update('UPDATE `takenncs-boosting` SET xp = ?, finished = ? WHERE charId = ?', {
        loadedPlayer.xp, loadedPlayer.finished, citizenid
    }, function(affectedRows)
        if affectedRows == 0 then
            TriggerClientEvent('QBCore:Notify', source, 'Viga: Andmebaasi uuendamine ebaõnnestus!', 'error')
        end
    end)

    local success = exports.ox_inventory:AddItem(source, 'money', reward)
    if not success then
        success = player.Functions.AddMoney('bank', reward)
    end

    if not success then
        TriggerClientEvent('QBCore:Notify', source, 'Viga: Makse lisamine ebaõnnestus!', 'error')
        return false
    end

    currentContracts[citizenid] = nil
    TriggerClientEvent('QBCore:Notify', source, ('Teile maksti $%s!'):format(reward), 'success')
    TriggerClientEvent('takenncs-boosting:client:requestData', source)
    return true
end)

QBCore.Commands.Add('giveboost', 'Anna mängijale boostiöö', {
    {name='player', help='Mängija server ID'},
    {name='model', help='Sõiduki mudel (valikuline)'}
}, false, function(source, args)
    if not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('QBCore:Notify', source, 'Sul ei ole õigusi selle käsu kasutamiseks!', 'error')
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('QBCore:Notify', source, 'Palun sisesta kehtiv mängija ID!', 'error')
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Mängijat ei leitud!', 'error')
        return
    end

    local vehicleValues = args[2] and exports['qb-core']:getSharedVehicles()[args[2]] or getRandomVehicle()
    if not vehicleValues then
        TriggerClientEvent('QBCore:Notify', source, 'Sõiduki mudelit ei leitud!', 'error')
        return
    end

    local contract = {
        id = miniUuid(),
        plate = generatePlate(),
        model = vehicleValues.model,
        vehicleName = vehicleValues.name,
        price = calculatePriceRange(vehicleValues.price),
        location = cfg.vehicleSpawns[math.random(1, #cfg.vehicleSpawns)],
        delivery = cfg.deliveryPoints[math.random(1, #cfg.vehicleSpawns)],
        created = os.time()
    }

    local citizenId = targetPlayer.PlayerData.citizenid
    if not availableContracts[citizenId] then
        availableContracts[citizenId] = {}
    end
    table.insert(availableContracts[citizenId], contract)

    TriggerClientEvent('QBCore:Notify', source, ('Boost antud mängijale %s: %s (%s)'):format(targetPlayer.PlayerData.name, contract.vehicleName, contract.plate), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Sulle anti uus boostiöö: %s (%s)'):format(contract.vehicleName, contract.plate), 'success')
    TriggerClientEvent('takenncs-boosting:client:requestData', targetId)
end, 'admin')

QBCore.Commands.Add('clearboostcontract', 'Tühista mängija aktiivne boostiöö', {
    {name='playerId', help='Mängija server ID'},
    {name='contractId', help='Tööotsu ID (valikuline)', optional=true}
}, false, function(source, args)
    if not QBCore.Functions.HasPermission(source, 'admin') then
        TriggerClientEvent('QBCore:Notify', source, 'Sul ei ole õigusi selle käsu kasutamiseks!', 'error')
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('QBCore:Notify', source, 'Palun sisesta kehtiv mängija ID!', 'error')
        return
    end

    local targetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not targetPlayer then
        TriggerClientEvent('QBCore:Notify', source, 'Mängijat ei leitud!', 'error')
        return
    end

    local citizenid = targetPlayer.PlayerData.citizenid
    local contractId = args[2]
    local cleared = false

    if contractId then
        if availableContracts[citizenid] then
            for i = #availableContracts[citizenid], 1, -1 do
                if availableContracts[citizenid][i].id == contractId then
                    table.remove(availableContracts[citizenid], i)
                    cleared = true
                end
            end
        end
        if currentContracts[citizenid] and currentContracts[citizenid].id == contractId then
            currentContracts[citizenid] = nil
            cleared = true
        end
    else
        if currentContracts[citizenid] then
            currentContracts[citizenid] = nil
            cleared = true
        end
        if availableContracts[citizenid] then
            availableContracts[citizenid] = {}
            cleared = true
        end
    end

    if cleared then
        TriggerClientEvent('takenncs-boosting:client:requestData', targetId)
        TriggerClientEvent('QBCore:Notify', targetId, 'Sinu aktiivne boostiöö tühistati admini poolt.', 'info')
        TriggerClientEvent('QBCore:Notify', source, 'Mängija aktiivne töö tühistatud!', 'success')
    else
        TriggerClientEvent('QBCore:Notify', source, 'Mängijal ei ole aktiivset tööd või määratud tööotsu ei leitud!', 'error')
    end
end, 'admin')