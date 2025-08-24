local showroomWagon, showroomCam
local rotationSpeed = 1.0
local isSpawningWagon = false
local rotatePromptGroup, rotateLeftPrompt, rotateRightPrompt
local inputLeft = GetHashKey("INPUT_DIVE")
local inputRight = GetHashKey("INPUT_LOOT_VEHICLE")


CreateThread(function()
    for k, v in pairs(Config.Stores) do
        exports['rsg-core']:createPrompt(
            "wagonStore" .. k,
            v.coords,
            GetHashKey(Config.Keys.OpenStore),
            Config.Blip.blipName,
            { type = "client", event = "rsg-wagons:client:openStore", args = { k } }
        )

        if Config.Blip.showBlip then
            local blip = BlipAddForCoords(1664425300, v.coords)
            SetBlipSprite(blip, -1747775003, true)
            SetBlipScale(blip, 0.2)
            SetBlipName(blip, Config.Blip.blipName)
        end
    end
end)


function SpawnShowroomWagon(model, store)
    if isSpawningWagon then return end
    isSpawningWagon = true

    local coords = Config.Stores[store].previewWagon
    local camCoords = Config.Stores[store].cameraPreviewWagon

    if showroomWagon and DoesEntityExist(showroomWagon) then
        DeleteEntity(showroomWagon)
        local t = 0
        while DoesEntityExist(showroomWagon) and t < 2000 do
            Wait(10)
            t += 10
        end
    end

    if not lib.requestModel(model, 5000) then
        isSpawningWagon = false
        return
    end

    showroomWagon = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, false, false)
    Citizen.InvokeNative(0x75F90E4051CC084C, showroomWagon, 0)
    Citizen.InvokeNative(0x8268B098F6FCA4E2, showroomWagon, 0)
    Citizen.InvokeNative(0xF89D82A0582E46ED, showroomWagon, -1)

    for i = 0, 10 do
        if DoesExtraExist(showroomWagon, i) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, showroomWagon, i, true)
        end
    end

    SetEntityInvincible(showroomWagon, true)
    FreezeEntityPosition(showroomWagon, true)

    SetUpShowroomCamera(camCoords, showroomWagon)
    SetModelAsNoLongerNeeded(model)

    Wait(250)
    isSpawningWagon = false
end


function SpawnShowroomMyWagon(model, store, custom)
    local coords = Config.Stores[store].previewWagon
    local camCoords = Config.Stores[store].cameraPreviewWagon

    if showroomWagon and DoesEntityExist(showroomWagon) then
        UpdateShowroomWagonVisuals(showroomWagon, custom)
        return
    end

    if not lib.requestModel(model, 5000) then return end

    showroomWagon = CreateVehicle(model, coords.x, coords.y, coords.z, coords.w, false, false)
    UpdateShowroomWagonVisuals(showroomWagon, custom)

    SetEntityInvincible(showroomWagon, true)
    FreezeEntityPosition(showroomWagon, true)

    SetUpShowroomCamera(camCoords, showroomWagon)
    SetModelAsNoLongerNeeded(model)
end


function UpdateShowroomWagonVisuals(wagon, custom)
    if not DoesEntityExist(wagon) then return end

    Citizen.InvokeNative(0x75F90E4051CC084C, wagon, 0)
    if custom.props then
        Citizen.InvokeNative(0x75F90E4051CC084C, wagon, GetHashKey(custom.props))
        Citizen.InvokeNative(0x31F343383F19C987, wagon, 0.5, 1)
    end

    Citizen.InvokeNative(0xE31C0CB1C3186D40, wagon)
    Wait(50)

    if custom.lantern then
        Citizen.InvokeNative(0xC0F0417A90402742, wagon, GetHashKey(custom.lantern))
    end

    Wait(50)
    Citizen.InvokeNative(0xAD738C3085FE7E11, wagon, true, true)
    Citizen.InvokeNative(0x9617B6E5F65329A5, wagon)

    Citizen.InvokeNative(0x8268B098F6FCA4E2, wagon, custom.tint or 0)
    Citizen.InvokeNative(0xF89D82A0582E46ED, wagon, custom.livery or 0)

    for i = 0, 10 do
        if DoesExtraExist(wagon, i) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, i, true)
        end
    end
    if custom.extra then
        Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, custom.extra, false)
    end
end


function SetUpShowroomCamera(cameraPosition, targetEntity)
    FreezeEntityPosition(cache.ped, true)
    SetEntityInvincible(cache.ped, true)

    showroomCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(showroomCam, cameraPosition.x, cameraPosition.y, cameraPosition.z)
    PointCamAtEntity(showroomCam, targetEntity, 0, 0, 0, true)

    SetCamActive(showroomCam, true)
    RenderScriptCams(true, false, 0, true, true)
    SetCamFov(showroomCam, 50.0)
end


function ShowRotatePrompt()
    rotatePromptGroup = PromptGetGroupIdForTargetEntity(cache.ped)

    rotateLeftPrompt = PromptRegisterBegin()
    PromptSetControlAction(rotateLeftPrompt, inputLeft)
    PromptSetText(rotateLeftPrompt, CreateVarString(10, "LITERAL_STRING", locale("left")))
    PromptSetEnabled(rotateLeftPrompt, true)
    PromptSetVisible(rotateLeftPrompt, true)
    PromptSetStandardMode(rotateLeftPrompt, true)
    PromptSetGroup(rotateLeftPrompt, rotatePromptGroup)
    PromptRegisterEnd(rotateLeftPrompt)

    rotateRightPrompt = PromptRegisterBegin()
    PromptSetControlAction(rotateRightPrompt, inputRight)
    PromptSetText(rotateRightPrompt, CreateVarString(10, "LITERAL_STRING", locale("right")))
    PromptSetEnabled(rotateRightPrompt, true)
    PromptSetVisible(rotateRightPrompt, true)
    PromptSetStandardMode(rotateRightPrompt, true)
    PromptSetGroup(rotateRightPrompt, rotatePromptGroup)
    PromptRegisterEnd(rotateRightPrompt)

    CreateThread(function()
        while rotatePromptGroup do
            Wait(0)
            PromptSetActiveGroupThisFrame(rotatePromptGroup, CreateVarString(10, "LITERAL_STRING", "Rotate Wagon"))
            RotateShowroomWagon()
        end
    end)
end

function HideRotatePrompt()
    if rotateLeftPrompt then PromptDelete(rotateLeftPrompt) end
    if rotateRightPrompt then PromptDelete(rotateRightPrompt) end
    rotateLeftPrompt, rotateRightPrompt, rotatePromptGroup = nil, nil, nil
end

function RotateShowroomWagon()
    if not showroomWagon then return end
    local heading = GetEntityHeading(showroomWagon)
    if IsControlPressed(0, inputLeft) then
        SetEntityHeading(showroomWagon, heading - rotationSpeed)
    elseif IsControlPressed(0, inputRight) then
        SetEntityHeading(showroomWagon, heading + rotationSpeed)
    end
end

function CloseShowroom()
    if showroomWagon then DeleteEntity(showroomWagon) showroomWagon = nil end
    if showroomCam then
        DestroyCam(showroomCam, false)
        RenderScriptCams(false, false, 0, true, true)
        showroomCam = nil
    end
    FreezeEntityPosition(cache.ped, false)
    SetEntityInvincible(cache.ped, false)
end
