lib.locale()
    CreateThread(function()
        for k, v in pairs(Config.Stores) do
                exports["rsg-core"]:createPrompt("wagonStore" .. k, v.coords, GetHashKey(Config.Keys.OpenStore),
                    Config.Blip.blipName, {
                        type = "client",
                        event = "rsg-wagons:client:openStore",
                        args = { k },
                    })
            if Config.Blip.showBlip then
                local blip = BlipAddForCoords(1664425300, v.coords)
                SetBlipSprite(blip, -1747775003, true)
                SetBlipScale(blip, 0.2)
                SetBlipName(blip, Config.Blip.blipName)
            end
        end
    end)

------------------------ Show Room

local showroomWagon = nil
local showroomCam = nil

local rotationSpeed = 1.0 -- Rotation speed

-- Function to create the ghost wagon in the showroom
local isSpawningWagon = false

function SpawnShowroomWagon(model, store)
    if isSpawningWagon then
        return
    end

    isSpawningWagon = true -- lock

    local showroomCoords = Config.Stores[store].previewWagon
    local showroomCameraCoords = Config.Stores[store].cameraPreviewWagon

    -- Remove the previous wagon if it exists
    if showroomWagon and DoesEntityExist(showroomWagon) then
        DeleteEntity(showroomWagon)

        -- Waits for complete removal
        local timeWaited = 0
        while DoesEntityExist(showroomWagon) and timeWaited < 2000 do
            Wait(10)
            timeWaited = timeWaited + 10
        end
    end

    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    showroomWagon = CreateVehicle(model, showroomCoords.x, showroomCoords.y, showroomCoords.z, showroomCoords.w, false,
        false)

    Citizen.InvokeNative(0x75F90E4051CC084C, showroomWagon, 0)  -- _REMOVE_ALL_VEHICLE_PROPSETS
    Citizen.InvokeNative(0x8268B098F6FCA4E2, showroomWagon, 0)  -- _SET_VEHICLE_TINT
    Citizen.InvokeNative(0xF89D82A0582E46ED, showroomWagon, -1) -- _SET_VEHICLE_LIVERY

    for i = 0, 10 do
        if DoesExtraExist(showroomWagon, i) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, showroomWagon, i, true) -- Disables all extras
        end
    end

    -- Prevents the wagon from moving
    SetEntityInvincible(showroomWagon, true)
    FreezeEntityPosition(showroomWagon, true)

    -- Activates the camera for viewing
    SetUpShowroomCamera(showroomCameraCoords, showroomWagon)

    -- Releases for new spawns
    Wait(250) -- slight delay to ensure safety
    isSpawningWagon = false
end

-- Function to set up the fixed camera in the showroom
function SetUpShowroomCamera(cameraPosition, targetEntity)
    local playerPed = PlayerPedId()

    -- Freeze the player in place
    FreezeEntityPosition(playerPed, true)
    SetEntityInvincible(playerPed, true) -- Ensure the player cannot be knocked down

    -- Creating the camera
    showroomCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(showroomCam, cameraPosition.x, cameraPosition.y, cameraPosition.z) -- Fixed distance from the wagon
    PointCamAtEntity(showroomCam, targetEntity, 0, 0, 0, true)                       -- Points the camera at the wagon

    SetCamActive(showroomCam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Zoom configuration (adjust camera distance)
    SetCamFov(showroomCam, 50.0) -- Adjust FOV for zoom

    -- Prevents camera movement
    SetEntityInvincible(showroomCam, true) -- The camera cannot be knocked down
end

local inputLeft = GetHashKey("INPUT_DIVE")
local inputRight = GetHashKey("INPUT_LOOT_VEHICLE")

function ShowRotatePrompt()
    Citizen.CreateThread(function()
        -- Create a new prompt group
        rotatePromptGroup = PromptGetGroupIdForTargetEntity(PlayerPedId()) -- Ensures the group will be valid

        -- Create the prompt to rotate left (A)
        rotateLeftPrompt = PromptRegisterBegin()
        PromptSetControlAction(rotateLeftPrompt, inputLeft) -- INPUT_MOVE_LEFT_ONLY (A)
        PromptSetText(rotateLeftPrompt, CreateVarString(10, "LITERAL_STRING", locale("left")))
        PromptSetEnabled(rotateLeftPrompt, true)
        PromptSetVisible(rotateLeftPrompt, true)
        PromptSetStandardMode(rotateLeftPrompt, true)       -- Standard click mode
        PromptSetGroup(rotateLeftPrompt, rotatePromptGroup) -- Add to group
        PromptRegisterEnd(rotateLeftPrompt)

        -- Create the prompt to rotate right (D)
        rotateRightPrompt = PromptRegisterBegin()
        PromptSetControlAction(rotateRightPrompt, inputRight) -- INPUT_MOVE_RIGHT_ONLY (D)
        PromptSetText(rotateRightPrompt, CreateVarString(10, "LITERAL_STRING", locale("right")))
        PromptSetEnabled(rotateRightPrompt, true)
        PromptSetVisible(rotateRightPrompt, true)
        PromptSetStandardMode(rotateRightPrompt, true)        -- Standard click mode
        PromptSetGroup(rotateRightPrompt, rotatePromptGroup) -- Add to group
        PromptRegisterEnd(rotateRightPrompt)

        -- Create a loop to keep the group active
        Citizen.CreateThread(function()
            while rotatePromptGroup do
                Citizen.Wait(0)
                PromptSetActiveGroupThisFrame(rotatePromptGroup, CreateVarString(10, "LITERAL_STRING", "Rotate Wagon"))
            end
        end)
        ---- Creates the rotation loop
        Citizen.CreateThread(function()
            while rotatePromptGroup do
                Citizen.Wait(0)
                RotateShowroomWagon()
            end
        end)
    end)
end

-- Function to remove prompts when closing the menu
function HideRotatePrompt()
    if rotateLeftPrompt then
        PromptDelete(rotateLeftPrompt)
        rotateLeftPrompt = nil
    end
    if rotateRightPrompt then
        PromptDelete(rotateRightPrompt)
        rotateRightPrompt = nil
    end
    rotatePromptGroup = nil
end

-- Function to rotate the wagon with A and D
function RotateShowroomWagon()
    if showroomWagon then
        -- Check if the A key was pressed
        if IsControlPressed(0, inputLeft) then                       -- A (left)
            local currentHeading = GetEntityHeading(showroomWagon)
            SetEntityHeading(showroomWagon, currentHeading - rotationSpeed) -- Rotates to the left
            -- Check if the D key was pressed
        elseif IsControlPressed(0, inputRight) then                 -- D (right)
            local currentHeading = GetEntityHeading(showroomWagon)
            SetEntityHeading(showroomWagon, currentHeading + rotationSpeed) -- Rotates to the right
        end
    end
end

-- Function to remove the wagon and restore the camera
function CloseShowroom()
    if showroomWagon then
        DeleteEntity(showroomWagon)
        showroomWagon = nil
    end

    if showroomCam then
        DestroyCam(showroomCam, false)
        RenderScriptCams(false, false, 0, true, true)
        showroomCam = nil
    end

    local playerPed = PlayerPedId()

    -- Release player control and the camera
    FreezeEntityPosition(playerPed, false)
    SetEntityInvincible(playerPed, false) -- Release invincibility

    -- Turn off the camera
    RenderScriptCams(false, false, 0, true, true)
end

-------------------------------------- Show your wagon

-- Function to create the ghost wagon in the showroom
function SpawnShowroomMyWagon(model, store, custom)
    local showroomCoords = Config.Stores[store].previewWagon
    local showroomCameraCoords = Config.Stores[store].cameraPreviewWagon

    -- If the wagon already exists, we just update its properties
    if showroomWagon and DoesEntityExist(showroomWagon) then
        UpdateShowroomWagonVisuals(showroomWagon, custom)
        return -- Avoids vehicle recreation
    end

    -- If it doesn't exist, create a new one
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end

    showroomWagon = CreateVehicle(model, showroomCoords.x, showroomCoords.y, showroomCoords.z, showroomCoords.w, false,
        false)

    -- Calls the function to apply the properties
    UpdateShowroomWagonVisuals(showroomWagon, custom)

    -- Prevents the wagon from moving
    SetEntityInvincible(showroomWagon, true)
    FreezeEntityPosition(showroomWagon, true)

    -- Activates the camera for viewing
    SetUpShowroomCamera(showroomCameraCoords, showroomWagon)
end

-- Separate function to update only the visual properties
function UpdateShowroomWagonVisuals(wagon, custom)
    if not DoesEntityExist(wagon) then return end

    Citizen.InvokeNative(0x75F90E4051CC084C, wagon, 0) -- _REMOVE_ALL_VEHICLE_PROPSETS

    -- Applying specific properties
    if custom.props then
        Citizen.InvokeNative(0x75F90E4051CC084C, wagon, GetHashKey(custom.props)) -- _ADD_VEHICLE_PROPSETS
        Citizen.InvokeNative(0x31F343383F19C987, wagon, 0.5, 1)                  -- _SET_VEHICLE_TARP_HEIGHT
    end

    -- Correctly removes the old lanterns
    Citizen.InvokeNative(0xE31C0CB1C3186D40, wagon) -- _REMOVE_ALL_VEHICLE_LANTERN_PROPSETS
    Wait(50)                                        -- Wait a moment to ensure they were removed

    -- Adds the new lantern
    if custom.lantern then
        Citizen.InvokeNative(0xC0F0417A90402742, wagon, GetHashKey(custom.lantern)) -- _ADD_VEHICLE_LANTERN_PROPSETS
    end

    -- Small delay to ensure visual update
    Wait(50)

    -- Forces the vehicle update to avoid visual bugs
    Citizen.InvokeNative(0xAD738C3085FE7E11, wagon, true, true) -- Set entity as mission entity
    Citizen.InvokeNative(0x9617B6E5F65329A5, wagon)            -- Force vehicle update

    -- Application of other visuals
    Citizen.InvokeNative(0x8268B098F6FCA4E2, wagon, custom.tint or 0)   -- _SET_VEHICLE_TINT
    Citizen.InvokeNative(0xF89D82A0582E46ED, wagon, custom.livery or 0) -- _SET_VEHICLE_LIVERY

    -- Disabling random extras
    for i = 0, 10 do
        if DoesExtraExist(wagon, i) then
            Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, i, true) -- Disables all extras
        end
    end
    if custom.extra then
        Citizen.InvokeNative(0xBB6F89150BC9D16B, wagon, custom.extra, false) -- Activates the desired extra
    end
end

-- Function to set up the fixed camera in the showroom
function SetUpShowroomCamera(cameraPosition, targetEntity)
    local playerPed = PlayerPedId()

    -- Freeze the player in place
    FreezeEntityPosition(playerPed, true)
    SetEntityInvincible(playerPed, true) -- Ensure the player cannot be knocked down

    -- Creating the camera
    showroomCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(showroomCam, cameraPosition.x, cameraPosition.y, cameraPosition.z) -- Fixed distance from the wagon
    PointCamAtEntity(showroomCam, targetEntity, 0, 0, 0, true)                       -- Points the camera at the wagon

    SetCamActive(showroomCam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Zoom configuration (adjust camera distance)
    SetCamFov(showroomCam, 50.0) -- Adjust FOV for zoom

    -- Prevents camera movement
    SetEntityInvincible(showroomCam, true) -- The camera cannot be knocked down
end
