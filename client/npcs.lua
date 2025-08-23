local spawnedPeds = {}


CreateThread(function()
    while true do
        local sleep = 500
        local playerCoords = GetEntityCoords(cache.ped)
        for k, v in pairs(Config.Stores) do
            local dist = #(playerCoords - v.npccoords.xyz)
            if dist < 50.0 and not spawnedPeds[k] then
                spawnedPeds[k] = { spawnedPed = spawnStorePed(v.npcmodel, v.npccoords, k) }
            elseif dist >= 50.0 and spawnedPeds[k] then
                fadeOutAndDeletePed(spawnedPeds[k].spawnedPed)
                if Config.Target then
                    exports.ox_target:removeEntity(spawnedPeds[k].spawnedPed, "npc_wagonStore")
                end
                spawnedPeds[k] = nil
            end
        end
        Wait(sleep)
    end
end)


function spawnStorePed(npcModel, coords, storeId)
    if not lib.requestModel(npcModel, 5000) then return nil end
    local ped = CreatePed(npcModel, coords.x, coords.y, coords.z - 1.0, coords.w, false, false, 0, 0)
    SetEntityAlpha(ped, 0, false)
    SetRandomOutfitVariation(ped, true)
    SetEntityCanBeDamaged(ped, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    for i = 0, 255, 51 do
        Wait(50)
        SetEntityAlpha(ped, i, false)
    end
    if Config.Target and Config.FrameWork == "rsg" then
        exports.ox_target:addLocalEntity(ped, {
            {
                name = "npc_wagonStore",
                icon = "far fa-eye",
                label = locale("cl_wagon_store"),
                onSelect = function()
                    TriggerEvent("rsg-wagons:client:openStore", storeId)
                end,
                distance = 2.0
            }
        })
    end
    SetModelAsNoLongerNeeded(npcModel)
    return ped
end

function fadeOutAndDeletePed(ped)
    if not DoesEntityExist(ped) then return end
    for i = 255, 0, -51 do
        Wait(50)
        SetEntityAlpha(ped, i, false)
    end
    DeletePed(ped)
end

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for k, v in pairs(spawnedPeds) do
        if DoesEntityExist(v.spawnedPed) then
            DeletePed(v.spawnedPed)
            if Config.Target then
                exports.ox_target:removeEntity(v.spawnedPed, "npc_wagonStore")
            end
        end
        spawnedPeds[k] = nil
    end
end)
