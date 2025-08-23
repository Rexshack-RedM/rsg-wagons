RSGCore = exports['rsg-core']:GetCoreObject()

local wagonBlip = nil
local vehicle = nil
local mywagon = nil
local wagon = nil
local isNearWagon = false -- Flag to know if the player is near the wagon
local isOwner = false
local wagonID = nil
local wagonNetId = nil
local wagonModel = nil
local StashPrompt
local DeletePrompt
local CarcassPrompt
local StockCarcassPrompt
local WagonGroup = GetRandomIntInRange(0, 0xffffff)
local openMenu = false
local cargo = false

lib.locale()

function HasItem(itemName, itemQnt)
    if itemQnt then
        itemQnt = itemQnt
    else
        itemQnt = 1
    end

    local hasItem = RSGCore.Functions.HasItem(itemName, itemQnt)
    if hasItem then
        return true
    else
        return false
    end
end

-- If you wish to trigger the action from another script, use:
RegisterNetEvent("rsg-wagons:client:dellwagon")
AddEventHandler("rsg-wagons:client:dellwagon", function()
    DeleteWagon()
end)

RegisterNetEvent("rsg-wagons:client:callwagon")
AddEventHandler("rsg-wagons:client:callwagon", function()
    CallWagon()
end)
---- Thanks daryldixon4074 for idea :)
----


local function FindSafeSpawnCoords(baseCoords, attempts, radius, minDistance)
    attempts = attempts or 10
    radius = radius or Config.SpawnRadius or 10.0
    minDistance = minDistance or 5.0

    local players = GetActivePlayers()

    for i = 1, attempts do
        local angle = math.rad((360 / attempts) * i)
        local offsetX = math.cos(angle) * radius
        local offsetY = math.sin(angle) * radius
        local tryCoords = vector3(baseCoords.x + offsetX, baseCoords.y + offsetY, baseCoords.z)

        local isFar = true
        for _, playerId in ipairs(players) do
            local ped = PlayerPedId()
            local pedCoords = GetEntityCoords(ped)
            if #(pedCoords - tryCoords) < minDistance then
                isFar = false
                break
            end
        end

        if isFar then
            local ped = PlayerPedId()
            local location = GetEntityCoords(ped)
            local x, y, z = table.unpack(location)
            local found, roadCoords = GetClosestVehicleNode(x - 15, y, z, 0, 3.0, 0.0)
            local _, _, nodeHeading = GetNthClosestVehicleNodeWithHeading(x - 15, y, z, 1, 1, 0, 0)
            if found then
                return found, roadCoords, nodeHeading
            end
        end
    end

    return nil -- No safe location found
end


local function SpawnWagon(model, tint, livery, props, extra, lantern, myWagonID)
    local ped = PlayerPedId()
    local hash = joaat(model)
    local veh = GetVehiclePedIsUsing(ped)
    local location = GetEntityCoords(ped)
    local x, y, z = table.unpack(location)
    local _, nodePosition = GetClosestVehicleNode(x - 15, y, z, 0, 3.0, 0.0)
    local distance = math.floor(#(nodePosition - location))
    local radius = Config.SpawnRadius or 10.0
    local onRoad = distance < radius

    -- Search for a nearby road node to ensure the spawn is on the road
    local playerCoords = GetEntityCoords(PlayerPedId())
    local found, safeCoords, nodeHeading = FindSafeSpawnCoords(playerCoords)


    if not safeCoords then
        lib.notify({ title = locale("error"), description = locale("cl_no_road"), type = "error", duration = 7000 })
        return
    end

    if not found then
        lib.notify({ title = locale("error"), description = locale("cl_no_road"), type = "error", duration = 7000 })
        return
    end

    if not onRoad then
        lib.notify({ title = locale("error"), description = locale("cl_no_road"), type = "error", duration = 7000 })
        return
    end

    if not IsModelInCdimage(hash) then return end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(0)
    end

    if IsPedInAnyVehicle(ped) then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end

    mywagon = CreateVehicle(hash, safeCoords.x, safeCoords.y, safeCoords.z, nodeHeading, true, false)
    SetVehicleDirtLevel(mywagon, 0.0)

    Wait(100)

    -- Removing all random properties
    Citizen.InvokeNative(0x75F90E4051CC084C, mywagon, 0) -- _REMOVE_ALL_VEHICLE_PROPSETS
    Citizen.InvokeNative(0xE31C0CB1C3186D40, mywagon)    -- _REMOVE_ALL_VEHICLE_LANTERN_PROPSETS


    -- Applying specific properties
    if props then
        Citizen.InvokeNative(0x75F90E4051CC084C, mywagon, GetHashKey(props)) -- _ADD_VEHICLE_PROPSETS
        Citizen.InvokeNative(0x31F343383F19C987, mywagon, 0.5, 1)            -- _SET_VEHICLE_TARP_HEIGHT
    end


    if lantern then
        Citizen.InvokeNative(0xC0F0417A90402742, mywagon, GetHashKey(lantern)) -- _ADD_VEHICLE_LANTERN_PROPSETS
    end

    Citizen.InvokeNative(0x8268B098F6FCA4E2, mywagon, tint)        -- _SET_VEHICLE_TINT
    Citizen.InvokeNative(0xF89D82A0582E46ED, mywagon, livery or 0) -- _SET_VEHICLE_LIVERY

    -- Forces a vehicle update to fix possible graphical errors
    Citizen.InvokeNative(0xAD738C3085FE7E11, mywagon, true, true) -- Set entity as mission entity
    Citizen.InvokeNative(0x9617B6E5F65329A5, mywagon)             -- Force vehicle update

    Wait(50)                                                      -- Extra time to ensure visual update

    -- Disabling random extras
    for i = 0, 10 do
        if DoesExtraExist(mywagon, i) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, mywagon, i, true) -- Disables all extras
        end
    end
    if extra then
        Citizen.InvokeNative(0xBB6F89150BC9D16B, mywagon, extra, false) -- Activates the desired extra
    end

    -- Register the vehicle on the network **after** all modifications
    NetworkRegisterEntityAsNetworked(mywagon)               -- Ensures the wagon is visible to other players
    SetVehicleIsConsideredByPlayer(mywagon, true)
    Citizen.InvokeNative(0xBB5A3FA8ED3979C5, mywagon, true) -- _SET_VEHICLE_IS_CONSIDERED_BY_PLAYER

    -- Check if the wagon was correctly registered on the network
    local networkId = NetworkGetNetworkIdFromEntity(mywagon)

    while not NetworkDoesEntityExistWithNetworkId(networkId) do
        Wait(50) -- Waits until the wagon is fully registered on the network
    end

    getControlOfEntity(mywagon)

    if Config.Target then
        Wait(100)
        CreateWagonTarget(networkId)
    end

    TriggerServerEvent("rsg-wagons:registerWagon", networkId, myWagonID, model) -- Sends the event to the server with the network ID


    -- Creating blip
    local blipModel = GetHashKey("blip_player_coach")
    wagonBlip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, -1230993421, mywagon)
    SetBlipSprite(wagonBlip, blipModel, true)
    Citizen.InvokeNative(0x9CB1A1623062F402, wagonBlip, locale("cl_your_wagon"))
end

function CreateWagonTarget(netId)
    local networkId = netId
    Wait(100)
    if networkId then
        exports.ox_target:addEntity(networkId, {
            {
                name = "npc_wagonStash",
                icon = "fa-solid fa-box-open",
                label = locale("cl_wagon_stash"),
                onSelect = function()
                    StashWagon()
                end,
                distance = 1.5
            }
        })
        Wait(100)
        exports.ox_target:addEntity(networkId, {
            {
                name = "npc_wagonShowCarcass",
                icon = "fa-solid fa-boxes-stacked",
                label = locale("cl_see_carcass"),
                onSelect = function()
                    ShowCarcass()
                end,
                distance = 1.5
            }
        })
        Wait(100)
        exports.ox_target:addEntity(networkId, {
            {
                name = "npc_wagonStockCarcass",
                icon = "fa-solid fa-paw",
                label = locale("cl_stock_carcass"),
                onSelect = function()
                    StockCarcass()
                end,
                distance = 1.5
            }
        })
        Wait(100)
        exports.ox_target:addEntity(networkId, {
            {
                name = "npc_wagonDelete",
                icon = "fa-solid fa-warehouse",
                label = locale("cl_flee_wagon"),
                onSelect = function()
                    DeleteThisWagon()
                end,
                distance = 1.5
            }
        })
    end
    -- end
end

--- Control the Entity

function getControlOfEntity(entity)
    NetworkRequestControlOfEntity(entity)
    SetEntityAsMissionEntity(entity, true, true)
    local timeout = 2000

    while timeout > 0 and NetworkHasControlOfEntity(entity) == nil do
        Wait(100)
        timeout = timeout - 100
    end
    return NetworkHasControlOfEntity(entity)
end

-- Function to check the player's proximity to a wagon

local function EnumerateVehicles(callback)
    local handle, vehicle = FindFirstVehicle()
    local success
    repeat
        if DoesEntityExist(vehicle) then
            callback(vehicle)
        end
        success, vehicle = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)
end

-- Helper function to check if a model is a wagon
local function IsThisModelAWagon(model)
    for _, wagonType in pairs(Config.Wagons) do
        for wagonModel, _ in pairs(wagonType) do
            local hash = GetHashKey(wagonModel)
            if hash == model then
                return true
            end
        end
    end
    return false
end

local wagonVerificationCache = {}

local function GetClosestWagon(callback)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local closestWagon = nil
    local closestDist = 2
    local networkId = nil

    EnumerateVehicles(function(vehicle)
        local model = GetEntityModel(vehicle)
        if IsThisModelAWagon(model) then
            local wagonCoords = GetEntityCoords(vehicle)
            local dist = #(pedCoords - wagonCoords)

            if dist <= closestDist then
                closestWagon = vehicle
                closestDist = dist
                networkId = NetworkGetNetworkIdFromEntity(vehicle)
            end
        end
    end)

    if not closestWagon or not networkId then
        callback(nil, nil, nil, nil)
        return
    end

    -- ⚡ Verification via cache
    if wagonVerificationCache[networkId] then
        local data = wagonVerificationCache[networkId]
        callback(closestWagon, closestDist, data.owner, data.id, data.model, networkId)
        return
    end

    -- 🧠 Not in cache, performs verification with the server
    RSGCore.Functions.TriggerCallback('rsg-wagons:isWagonRegistered',
        function(isRegistered, owner, wagonID, model, netId)
            -- Saves to cache for subsequent calls

            if isRegistered then
                callback(closestWagon, closestDist, owner, wagonID, model, netId)
                wagonVerificationCache[netId] = {
                    owner = owner,
                    id = wagonID,
                    model = model
                }
            else
                callback(closestWagon, closestDist, nil, nil, nil)
            end
        end, networkId)
end

local animalStorageCache = {}

if Config.Target then
    ------------------------- Check the Stash
    function StashWagon()
        GetClosestWagon(function(wagon, dist, owner, id, model, netId)
            if wagon then
                if id then
                    isOwner = owner
                    wagonID = id
                    wagonModel = model
                    wagonNetId = netId

                    -- Checks and stores the maximum number of animals allowed
                    if animalStorageCache[netId] == nil then
                        local maxAnimal = 0
                        for tipo, modelos in pairs(Config.Wagons) do
                            for model, data in pairs(modelos) do
                                if model == wagonModel then
                                    maxAnimal = data.maxAnimals or 0
                                    break
                                end
                            end
                        end
                        animalStorageCache[netId] = maxAnimal
                    end
                    TriggerServerEvent("rsg-wagons:openWagonStash", "Wagon_Stash_" .. wagonID, wagonModel, wagonID,
                        wagonNetId)
                end
            end
        end)
    end

    function ShowCarcass()
        GetClosestWagon(function(wagon, dist, owner, id, model, netId)
            if wagon then
                if id then
                    isOwner = owner
                    wagonID = id
                    wagonModel = model
                    wagonNetId = netId

                    -- Checks and stores the maximum number of animals allowed
                    if animalStorageCache[netId] == nil then
                        local maxAnimal = 0
                        for tipo, modelos in pairs(Config.Wagons) do
                            for model, data in pairs(modelos) do
                                if model == wagonModel then
                                    maxAnimal = data.maxAnimals or 0
                                    break
                                end
                            end
                        end
                        animalStorageCache[netId] = maxAnimal
                    end
                end
                if isOwner then
                    local maxAnimal = animalStorageCache[wagonNetId] or 0
                    if maxAnimal > 0 then
                        CarcassInWagon(wagonID)
                    else
                        lib.notify({ title = locale("error"), description = locale("no_animals_in_wagon"), type = "error", duration = 7000 })
                    end
                else
                    lib.notify({ title = locale("error"), description = locale("no_permission"), type = "error", duration = 7000 })
                end
            end
        end)
    end

    function StockCarcass()
        GetClosestWagon(function(wagon, dist, owner, id, model, netId)
            if wagon then
                if id then
                    isOwner = owner
                    wagonID = id
                    wagonModel = model
                    wagonNetId = netId

                    -- Checks and stores the maximum number of animals allowed
                    if animalStorageCache[netId] == nil then
                        local maxAnimal = 0
                        for tipo, modelos in pairs(Config.Wagons) do
                            for model, data in pairs(modelos) do
                                if model == wagonModel then
                                    maxAnimal = data.maxAnimals or 0
                                    break
                                end
                            end
                        end
                        animalStorageCache[netId] = maxAnimal
                    end
                end
                local maxAnimal = animalStorageCache[wagonNetId] or 0
                if maxAnimal > 0 then
                    StoreCarriedEntityInWagon()
                else
                    lib.notify({ title = locale("error"), description = locale("no_animals_in_wagon"), type = "error", duration = 7000 })
                end
            end
        end)
    end

    function DeleteThisWagon()
        GetClosestWagon(function(wagon, dist, owner, id, model, netId)
            if wagon then
                if id then
                    isOwner = owner
                    wagonID = id
                    wagonModel = model
                    wagonNetId = netId

                    -- Checks and stores the maximum number of animals allowed
                    if animalStorageCache[netId] == nil then
                        local maxAnimal = 0
                        for tipo, modelos in pairs(Config.Wagons) do
                            for model, data in pairs(modelos) do
                                if model == wagonModel then
                                    maxAnimal = data.maxAnimals or 0
                                    break
                                end
                            end
                        end
                        animalStorageCache[netId] = maxAnimal
                    end
                end
                if isOwner then
                    DeleteWagon()
                else
                    lib.notify({ title = locale("error"), description = locale("no_permission"), type = "error", duration = 7000 })
                end
            end
        end)
    end
end

if not Config.Target then
    Citizen.CreateThread(function()
        while true do
            GetClosestWagon(function(wagon, dist, owner, id, model, netId)
                if wagon then
                    if id then
                        isNearWagon = true
                        isOwner = owner
                        wagonID = id
                        wagonModel = model
                        wagonNetId = netId

                        -- Checks and stores the maximum number of animals allowed
                        if animalStorageCache[netId] == nil then
                            local maxAnimal = 0
                            for tipo, modelos in pairs(Config.Wagons) do
                                for model, data in pairs(modelos) do
                                    if model == wagonModel then
                                        maxAnimal = data.maxAnimals or 0
                                        break
                                    end
                                end
                            end
                            animalStorageCache[netId] = maxAnimal


                        end

                    else
                        isNearWagon = false

                    end
                else
                    isNearWagon = false
                end
            end)

            Wait(500)
        end
    end)

    -- set Stash prompt
    function StashPrompt() -- Open the wagon's inventory
        Citizen.CreateThread(function()
            local str = locale("cl_wagon_stash")
            StashPrompt = Citizen.InvokeNative(0x04F97DE45A519419)
            PromptSetControlAction(StashPrompt, GetHashKey(Config.Keys.OpenWagonStash))
            local str = CreateVarString(10, "LITERAL_STRING", str)
            PromptSetText(StashPrompt, str)
            PromptSetEnabled(StashPrompt, true)
            PromptSetVisible(StashPrompt, true)
            PromptSetHoldMode(StashPrompt, true)
            PromptSetGroup(StashPrompt, WagonGroup)
            PromptRegisterEnd(StashPrompt)
        end)
    end

    function DeletePrompt() -- Send the wagon away
        Citizen.CreateThread(function()
            local str = locale("cl_flee_wagon")
            DeletePrompt = Citizen.InvokeNative(0x04F97DE45A519419)
            PromptSetControlAction(DeletePrompt, GetHashKey("INPUT_FRONTEND_CANCEL"))
            local str = CreateVarString(10, "LITERAL_STRING", str)
            PromptSetText(DeletePrompt, str)
            PromptSetEnabled(DeletePrompt, true)
            PromptSetVisible(DeletePrompt, true)
            PromptSetHoldMode(DeletePrompt, true)
            PromptSetGroup(DeletePrompt, WagonGroup)
            PromptRegisterEnd(DeletePrompt)
        end)
    end

    function CarcassPrompt() -- Look at the animals/pelt in the wagon
        Citizen.CreateThread(function()
            local str = locale("cl_see_carcass")
            CarcassPrompt = Citizen.InvokeNative(0x04F97DE45A519419)
            PromptSetControlAction(CarcassPrompt, GetHashKey("INPUT_INTERACT_LOCKON_ANIMAL"))
            local str = CreateVarString(10, "LITERAL_STRING", str)
            PromptSetText(CarcassPrompt, str)
            PromptSetEnabled(CarcassPrompt, true)
            PromptSetVisible(CarcassPrompt, true)
            PromptSetHoldMode(CarcassPrompt, true)
            PromptSetGroup(CarcassPrompt, WagonGroup)
            PromptRegisterEnd(CarcassPrompt)
        end)
    end

    local StoredWagonAnimals = {} -- Store the animals/pelt in the wagon
    function StockCarcassPrompt() --- Store the animals/pelt in the wagon
        Citizen.CreateThread(function()
            local str = locale("cl_stock_carcass")
            StockCarcassPrompt = Citizen.InvokeNative(0x04F97DE45A519419)
            PromptSetControlAction(StockCarcassPrompt, GetHashKey("INPUT_DOCUMENT_PAGE_PREV"))
            local str = CreateVarString(10, "LITERAL_STRING", str)
            PromptSetText(StockCarcassPrompt, str)
            PromptSetEnabled(StockCarcassPrompt, true)
            PromptSetVisible(StockCarcassPrompt, true)
            PromptSetHoldMode(StockCarcassPrompt, true)
            PromptSetGroup(StockCarcassPrompt, WagonGroup)
            PromptRegisterEnd(StockCarcassPrompt)
        end)
    end

    -- Function to handle interaction prompts
    Citizen.CreateThread(function()
        StashPrompt()
        DeletePrompt()
        CarcassPrompt()
        StockCarcassPrompt()
        local ped = PlayerPedId()
        while true do
            local waitTime = 2000 -- Default wait time
            local PedInVehicle = IsPedInAnyVehicle(ped)
            local maxAnimal = animalStorageCache[wagonNetId] or 0

            if isNearWagon and not PedInVehicle and isOwner and not openMenu then
                waitTime = 2 -- Updates to a quick check when close
                local Stash = CreateVarString(10, "LITERAL_STRING", locale("cl_your_wagon"))
                PromptSetActiveGroupThisFrame(WagonGroup, Stash)

                ----------------- Make Prompts invisible so they don't appear on the screen until the correct check is done
                PromptSetEnabled(CarcassPrompt, false)
                PromptSetVisible(CarcassPrompt, false)
                PromptSetEnabled(StockCarcassPrompt, false)
                PromptSetVisible(StockCarcassPrompt, false)

                if PromptHasHoldModeCompleted(StashPrompt) then
                    -- Temporarily disables the prompt to avoid multiple triggers
                    PromptSetEnabled(StashPrompt, false)
                    PromptSetVisible(StashPrompt, false)
                    TriggerServerEvent("rsg-wagons:openWagonStash", "Wagon_Stash_" .. wagonID, wagonModel, wagonID,
                        wagonNetId)
                    -- Small delay to avoid instant reactivation
                    Wait(500)

                    -- Reactivates the prompt for future interactions
                    PromptSetEnabled(StashPrompt, true)
                    PromptSetVisible(StashPrompt, true)
                elseif PromptHasHoldModeCompleted(DeletePrompt) then
                    -- Temporarily disables the prompt to avoid multiple triggers
                    PromptSetEnabled(DeletePrompt, false)
                    PromptSetVisible(DeletePrompt, false)
                    if isOwner then
                        -- If the player is the owner of the wagon, opens the inventory
                        DeleteWagon()
                    else
                        -- If not the owner, notifies that access is denied
                        lib.notify({ title = locale("error"), description = locale("cl_not_owner"), type = "error", duration = 7000 })
                    end

                    -- Small delay to avoid instant reactivation
                    Wait(500)

                    -- Reactivates the prompt for future interactions
                    PromptSetEnabled(DeletePrompt, true)
                    PromptSetVisible(DeletePrompt, true)
                elseif maxAnimal > 0 then
                    PromptSetEnabled(CarcassPrompt, true)
                    PromptSetVisible(CarcassPrompt, true)
                    PromptSetEnabled(StockCarcassPrompt, true)
                    PromptSetVisible(StockCarcassPrompt, true)
                    if PromptHasHoldModeCompleted(CarcassPrompt) then
                        PromptSetEnabled(CarcassPrompt, false)
                        PromptSetVisible(CarcassPrompt, false)

                        CarcassInWagon(wagonID)
                        openMenu = true
                        Wait(1000)
                        PromptSetEnabled(CarcassPrompt, true)
                        PromptSetVisible(CarcassPrompt, true)
                    elseif PromptHasHoldModeCompleted(StockCarcassPrompt) then
                        PromptSetEnabled(StockCarcassPrompt, false)
                        PromptSetVisible(StockCarcassPrompt, false)

                        StoreCarriedEntityInWagon()
                        Wait(1000)

                        PromptSetEnabled(StockCarcassPrompt, true)
                        PromptSetVisible(StockCarcassPrompt, true)
                    end
                end
            elseif isNearWagon and not PedInVehicle and not isOwner and not openMenu then --- This is the prompt logic for non-owners
                waitTime = 2                                                              -- Updates to a quick check when close
                local Stash = CreateVarString(10, "LITERAL_STRING", locale("cl_your_wagon"))
                PromptSetActiveGroupThisFrame(WagonGroup, Stash)
                PromptSetEnabled(DeletePrompt, false)
                PromptSetVisible(DeletePrompt, false)


                if PromptHasHoldModeCompleted(StashPrompt) then
                    -- Temporarily disables the prompt to avoid multiple triggers
                    PromptSetEnabled(StashPrompt, false)
                    PromptSetVisible(StashPrompt, false)
                    -- If the player is the owner of the wagon, opens the inventory
                    TriggerServerEvent("rsg-wagons:openWagonStash", "Wagon_Stash_" .. wagonID, wagonModel, wagonID,
                        wagonNetId)

                    -- Small delay to avoid instant reactivation
                    Wait(500)

                    -- Reactivates the prompt for future interactions
                    PromptSetEnabled(StashPrompt, true)
                    PromptSetVisible(StashPrompt, true)
                end
                if maxAnimal > 0 then
                    PromptSetEnabled(StockCarcassPrompt, true)
                    PromptSetVisible(StockCarcassPrompt, true)
                    if PromptHasHoldModeCompleted(StockCarcassPrompt) then
                        PromptSetEnabled(StockCarcassPrompt, false)
                        PromptSetVisible(StockCarcassPrompt, false)

                        StoreCarriedEntityInWagon()
                        Wait(1000)

                        PromptSetEnabled(StockCarcassPrompt, true)
                        PromptSetVisible(StockCarcassPrompt, true)
                    end
                end
            end
            Wait(waitTime)
        end
    end)
end
---------- Give permission to open inventory
RegisterNetEvent("btc-wagon:askOwnerPermission")
AddEventHandler("btc-wagon:askOwnerPermission", function(data)
    local alert = lib.alertDialog({
        header = locale("alert"),
        content = locale("player_stash") .. data.firstname .. " " .. data.lastname .. locale("player_stash_02"),
        centered = true,
        cancel = true
    })
    local permission = alert
    TriggerServerEvent("rsg-wagons:giveOwnerPermission", permission, data)
end)

RegisterNetEvent("rsg-wagons:receiveWagonData")
AddEventHandler("rsg-wagons:receiveWagonData", function(wagonModel, customData, animalsData, myWagonID)
    if mywagon and DoesEntityExist(mywagon) then
        DeleteWagon()
        Wait(500)
    end

    if wagonBlip and DoesBlipExist(wagonBlip) then
        RemoveBlip(wagonBlip)
    end

    if wagonModel then
        local model = wagonModel
        local tint = customData.tint
        local livery = customData.livery
        local props = customData.props
        local extra = customData.extra
        local lantern = customData.lantern

        SpawnWagon(model, tint, livery, props, extra, lantern, myWagonID)
    else
        lib.notify({ title = locale("error"), description = locale("cl_no_wagon"), type = "error", duration = 7000 })
    end
end)

RegisterNetEvent("rsg-wagons:saveWagonToDatabase")
AddEventHandler("rsg-wagons:saveWagonToDatabase", function(wagonModel, name, moneyType)
    local customData = {
        name = name,
        tint = 0,
        livery = -1,
        props = false,
        extra = 0,
        buyMoneyType = moneyType,
    }

    TriggerServerEvent("rsg-wagons:saveWagonToDatabase", wagonModel, customData, moneyType)
end)

function DeleteWagon()
    if mywagon and DoesEntityExist(mywagon) then
        local netId = NetworkGetNetworkIdFromEntity(mywagon)

        -- Remove from server
        TriggerServerEvent("rsg-wagons:removeWagon", netId, mywagon)
        -- DeleteVehicle(mywagon)
        mywagon = false
        RemoveBlip(wagonBlip)
        if animalStorageCache[wagonNetId] then
            animalStorageCache[wagonNetId] = nil
        end
        wagonVerificationCache[netId] = nil

        if Config.Target then
            exports.ox_target:removeEntity(netId, "npc_wagonStash")
            exports.ox_target:removeEntity(netId, "npc_wagonShowCarcass")
            exports.ox_target:removeEntity(netId, "npc_wagonStockCarcass")
            exports.ox_target:removeEntity(netId, "npc_wagonDelete")
        end
    end
end

if Config.SpawnKey then
    Citizen.CreateThread(function()
        while true do
            local sleep = 10
            if IsControlJustReleased(0, GetHashKey(Config.SpawnKey)) then
                CallWagon()
            end
            if mywagon and DoesEntityExist(mywagon) then
                sleep = 1000
            end
            Wait(sleep)
        end
    end)
end

function CallWagon()
    if mywagon and DoesEntityExist(mywagon) then
        lib.notify({ title = locale("error"), description = locale("cl_have_wagon"), type = "error", duration = 7000 })
        return
    end

    if wagonBlip and DoesBlipExist(wagonBlip) then
        RemoveBlip(wagonBlip)
    end

    TriggerServerEvent("rsg-wagons:getWagonDataByCitizenID")
end

------------------------- Function for carcasses


----- Thanks to masmana - mas_huntingwagon
local function GetFirstEntityPedIsCarrying(ped)
    return Citizen.InvokeNative(0xD806CD2A4F2C2996, ped)
end
local function GetMetaPedAssetTint(ped, index)
    return Citizen.InvokeNative(0xE7998FEC53A33BBE, ped, index, Citizen.PointerValueInt(), Citizen.PointerValueInt(),
        Citizen.PointerValueInt(), Citizen.PointerValueInt())
end

local function GetMetaPedAssetGuids(ped, index)
    return Citizen.InvokeNative(0xA9C28516A6DC9D56, ped, index, Citizen.PointerValueInt(), Citizen.PointerValueInt(),
        Citizen.PointerValueInt(), Citizen.PointerValueInt())
end

local function GetNumComponentsInPed(ped)
    return Citizen.InvokeNative(0x90403E8107B60E81, ped, Citizen.ResultAsInteger())
end

local function GetIsCarriablePelt(entity)
    return Citizen.InvokeNative(0x255B6DB4E3AD3C3E, entity)
end

local function GetCarriableFromEntity(entity)
    return Citizen.InvokeNative(0x31FEF6A20F00B963, entity)
end

local function GetCarcassMetaTag(entity)
    local metatag = {}
    local numComponents = GetNumComponentsInPed(entity)
    for i = 0, numComponents - 1, 1 do
        local drawable, albedo, normal, material = GetMetaPedAssetGuids(entity, i)
        local palette, tint0, tint1, tint2 = GetMetaPedAssetTint(entity, i)
        metatag[i] = {
            drawable = drawable,
            albedo = albedo,
            normal = normal,
            material = material,
            palette = palette,
            tint0 = tint0,
            tint1 = tint1,
            tint2 = tint2
        }

    end
    return metatag
end

local function UpdatePedVariation(ped)
    Citizen.InvokeNative(0xAAB86462966168CE, ped, true)                           -- UNKNOWN "Fixes outfit"- always paired with _UPDATE_PED_VARIATION
    Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false) -- _UPDATE_PED_VARIATION
end

local function SetMetaPedTag(ped, drawable, albedo, normal, material, palette, tint0, tint1, tint2)
    return Citizen.InvokeNative(0xBC6DF00D7A4A6819, ped, drawable, albedo, normal, material, palette, tint0, tint1, tint2)
end

local function GetPedMetaOutfitHash(ped)
    return Citizen.InvokeNative(0x30569F348D126A5A, ped, Citizen.ResultAsInteger())
end

local function IsEntityFullyLooted(entity)
    return Citizen.InvokeNative(0x8DE41E9902E85756, entity)
end

local function GetPedDamageCleanliness(ped)
    return Citizen.InvokeNative(0x88EFFED5FE8B0B4A, ped, Citizen.ResultAsInteger())
end


local function EquipMetaPedOutfit(ped, hash)
    return Citizen.InvokeNative(0x1902C4CFCC5BE57C, ped, hash)
end

local function ApplyCarcasMetaTag(entity, metatag)
    if not metatag or type(metatag) ~= "table" then return end

    for _, data in pairs(metatag) do
        if data then
            SetMetaPedTag(entity, data.drawable, data.albedo, data.normal, data.material, data.palette,
                data.tint0, data.tint1, data.tint2)
        end
    end

    UpdatePedVariation(entity)
end

local function SetPedDamageCleanliness(ped, damageCleanliness)
    return Citizen.InvokeNative(0x7528720101A807A5, ped, damageCleanliness)
end

local function GetPedQuality(ped)
    return Citizen.InvokeNative(0x7BCC6087D130312A, ped)
end

local function SetPedQuality(ped, quality)
    return Citizen.InvokeNative(0xCE6B874286D640BB, ped, quality)
end

local function TaskStatus(task)
    local ped = PlayerPedId()
    local count = 0
    repeat
        count = count + 1
        Wait(0)
    until (GetScriptTaskStatus(ped, task, true) == 8) or count > 100
end

function StoreCarriedEntityInWagon()
    RSGCore.Functions.TriggerCallback("rsg-wagons:getAnimalStorage", function(menuData)
        local ped = PlayerPedId()
        local carriedEntity = GetFirstEntityPedIsCarrying(ped)
        local carriedModel = GetEntityModel(carriedEntity)
        local animalCheck = false

        if not carriedEntity or not DoesEntityExist(carriedEntity) then
            lib.notify({ title = locale("error"), description = locale("carry_nothing"), type = "error", duration = 7000 })
            return
        end

        -- if not isNearWagon or not isOwner or not wagonID or not wagonNetId then
        --     Notify(locale("closest_to_wagon"), 5000, "error")
        --     return
        -- end

        -- Checks wagon capacity
        local totalStored = 0
        for k, v in pairs(menuData) do
            totalStored = totalStored + (v.infos.quantity or 1)
        end

        local maxAnimal = animalStorageCache[wagonNetId] or 0 -- fallback to 0 if it doesn't exist
        if totalStored >= maxAnimal then
            lib.notify({ title = locale("error"), description = locale("wagon_full"), type = "error", duration = 7000 })
            return
        end

        -- Identifies type
        local data = {
            model = carriedModel,
        }

        if GetIsCarriablePelt(carriedEntity) then
            data.type = "pelt"
            data.peltquality = GetCarriableFromEntity(carriedEntity)
        else
            for k, v in pairs(Config.AnimalsStorage) do
                if k == carriedModel then
                    animalCheck = true
                    break
                end
            end

            if animalCheck then
                data.type = "animal"
                data.metatag = GetCarcassMetaTag(carriedEntity)
                data.outfit = GetPedMetaOutfitHash(carriedEntity)
                data.skinned = IsEntityFullyLooted(carriedEntity) or false
                data.damage = GetPedDamageCleanliness(carriedEntity) or 0
                data.quality = GetPedQuality(carriedEntity) or 0
            else
                lib.notify({ title = locale("error"), description = locale("carry_nothing"), type = "error", duration = 7000 })
                return
            end
        end

        -- Stores
        TriggerServerEvent("rsg-wagons:storeAnimalInWagon", wagonID, data)
        DeleteEntity(carriedEntity)
    end, wagonID)
end

-------------- To see the carcasses inside the wagon
function CarcassInWagon(wagonID)
    local carcassInWagon = {}
    RSGCore.Functions.TriggerCallback("rsg-wagons:getAnimalStorage", function(menuData)
        if not menuData or #menuData == 0 then
            lib.notify({ title = locale("error"), description = locale("wagon_no_animals"), type = "error", duration = 7000 })
            openMenu = false
            return
        end

        -- Saves to cache for subsequent calls
        for k, v in pairs(menuData) do
            table.insert(carcassInWagon, {
                label = v.label,
                value = v.infos.type,
                infos = v.infos,
                desc = locale("animal_desc") .. v.infos.quantity .. " " .. v.label .. locale("animal_desc2"),
            })
        end
        local nuifocus = false
        MenuData.Open(
            "default", GetCurrentResourceName(), "carcass_menu",
            {
                title = locale("animals_in_wagon"),
                subtext = locale("animals_in_wagon_desc"),
                align = Config.PositionMenu,
                elements = carcassInWagon
            },
            function(data, menu)
                menu.close()
                local infos = data.current.infos
                local label = data.current.label

                TriggerServerEvent("rsg-wagons:removeAnimalFromWagon", wagonID, infos, label)
                openMenu = false
            end,
            function(data, menu)
                menu.close()
                openMenu = false
            end,
            function(data, menu)
            end, nuifocus
        )
    end, wagonID)
end

RegisterNetEvent("rsg-wagons:spawnAnimal")
AddEventHandler("rsg-wagons:spawnAnimal", function(data)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    RequestModel(data.model)
    while not HasModelLoaded(data.model) do
        Wait(10)
    end
    if IsModelAPed(data.model) then
        cargo = CreatePed(data.model, coords.x, coords.y, coords.z, 0, true, true)
        SetEntityHealth(cargo, 0, ped)
        SetPedQuality(cargo, data.quality)
        SetPedDamageCleanliness(cargo, data.damage)
        if data.skinned then
            Wait(1000)
            Citizen.InvokeNative(0x6BCF5F3D8FFE988D, cargo, true) -- FullyLooted
            ApplyCarcasMetaTag(cargo, data.metatag)
        else
            EquipMetaPedOutfit(cargo, data.outfit)
            UpdatePedVariation(cargo)
        end
    else
        cargo = CreateObject(data.model, coords.x, coords.y, coords.z, true, true, true, 0, 0)
        Citizen.InvokeNative(0x78B4567E18B54480, cargo)                                                                  -- MakeObjectCarriable
        Citizen.InvokeNative(0xF0B4F759F35CC7F5, cargo, Citizen.InvokeNative(0x34F008A7E48C496B, cargo, 0), ped, 7, 512) -- TaskCarriable
        Citizen.InvokeNative(0x399657ED871B3A6C, cargo, data.peltquality)                                                -- SetEntityCarcassType https://pastebin.com/C1WvQjCy
    end
    Citizen.InvokeNative(0x18FF3110CF47115D, cargo, 21, true)                                                            --SetEntityCarryingFlag
    TaskPickupCarriableEntity(ped, cargo)
    SetEntityVisible(cargo, false)
    FreezeEntityPosition(cargo, true)

    TaskStatus(`SCRIPT_TASK_PICKUP_CARRIABLE_ENTITY`)

    FreezeEntityPosition(cargo, false)
    SetEntityVisible(cargo, true)
    Citizen.InvokeNative(0x18FF3110CF47115D, cargo, 21, false) --SetEntityCarryingFlag
end)

--------------- OX-TARGET


AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    if mywagon and DoesEntityExist(mywagon) then
        local netId = NetworkGetNetworkIdFromEntity(mywagon)

        -- Remove from server
        TriggerServerEvent("rsg-wagons:removeWagon", netId, mywagon)
        -- DeleteVehicle(mywagon)
        mywagon = false
        RemoveBlip(wagonBlip)
        if animalStorageCache[wagonNetId] then
            animalStorageCache[wagonNetId] = nil
        end
        wagonVerificationCache[netId] = nil

        if Config.Target then
            exports.ox_target:removeEntity(netId, "npc_wagonStash")
            exports.ox_target:removeEntity(netId, "npc_wagonShowCarcass")
            exports.ox_target:removeEntity(netId, "npc_wagonStockCarcass")
            exports.ox_target:removeEntity(netId, "npc_wagonDelete")
        end
    end
end)
