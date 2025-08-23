RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

------------------ Functions

local function GetPlayerDataAndRemoveMoney(source, amount, moneyType)
    local citizenid = nil
    local removed = false
    local cashType = nil

    if moneyType == 'cash' or moneyType == 'gold' then
        if moneyType == 'cash' then
            cashType = Config.MoneyType.money
        elseif moneyType == 'gold' then
            cashType = Config.MoneyType.gold
        end
    else
        cashType = Config.MoneyType.money
    end


    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        citizenid = Player.PlayerData.citizenid
        local money = Player.PlayerData.money[cashType]

        if money >= amount then
            if Player.Functions.RemoveMoney(cashType, amount) then
                removed = true
            end
        end
    end

    return citizenid, removed
end

local function GetPlayerDataAndAddMoney(source, amount, moneyType)
    local citizenid = nil
    local add = false
    local cashType = nil

    if moneyType == 'cash' or moneyType == 'gold' then
        if moneyType == 'cash' then
            cashType = Config.MoneyType.money
        elseif moneyType == 'gold' then
            cashType = Config.MoneyType.gold
        end
    else
        cashType = Config.MoneyType.money
    end

    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        citizenid = Player.PlayerData.citizenid
        if Player.Functions.AddMoney(cashType, amount) then
            add = true
        end
    end

    return citizenid, add
end

local function GetCitizenID(source)
    local citizenid = nil

    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        citizenid = Player.PlayerData.citizenid
    end

    return citizenid
end

local function OpenStash(source, weight, slots, stash)
    local data = { label = "Baú", maxweight = weight * 1000, slots = slots }
    local stashName = stash
    exports['rsg-inventory']:OpenInventory(source, stashName, data)
end

local function GetName(source)
    local firstname = nil
    local lastname = nil


    local Player = RSGCore.Functions.GetPlayer(source)
    if Player then
        firstname = Player.PlayerData.charinfo.firstname
        lastname = Player.PlayerData.charinfo.lastname
    end

    return firstname, lastname
end

------------------ save wagon -------------------

RegisterServerEvent("rsg-wagons:saveWagonToDatabase")
AddEventHandler("rsg-wagons:saveWagonToDatabase", function(wagon, custom, moneyType)
    local src = source
    local maxWagonsPerPlayer = Config.maxWagonsPerPlayer -- ✅ Set the desired limit here

    local wagonName, wagonPrice = nil, nil

    -- Search for wagon details in Config
    for type, info in pairs(Config.Wagons) do
        for k, v in pairs(info) do
            if wagon == k and moneyType == "cash" then
                wagonName = v.name
                wagonPrice = v.price
                break
            elseif wagon == k and moneyType == "gold" then
                wagonName = v.name
                wagonPrice = v.priceGold
                break
            elseif wagon == k then
                wagonName = v.name
                wagonPrice = v.price
                break
            end
        end
    end

    if not wagonName or not custom then
        if Config.Debug then print("Error: Incomplete data to save the wagon.") end
        return
    end

    local citizenid, success = GetPlayerDataAndRemoveMoney(src, wagonPrice, moneyType)

    if not success then
        TriggerClientEvent('ox_lib:notify', src,
            { title = locale("error"), description = locale("cl_dont_have_money"), type = 'error', duration = 5000 })
        return
    end

    -- Checks if the wagon limit has been reached
    MySQL.Async.fetchScalar(
        "SELECT COUNT(*) FROM rsg_wagons WHERE citizenid = @citizenid",
        { ["@citizenid"] = citizenid },
        function(totalCount)
            if totalCount >= maxWagonsPerPlayer then
                TriggerClientEvent('ox_lib:notify', src,
                    { title = locale("error"), description = locale("cl_max_wagons_reached"), type = 'error', duration = 5000 })
                -- Refund the money
                GetPlayerDataAndAddMoney(source, wagonPrice, moneyType)
                return
            end

            -- Checks if a wagon with the same name already exists
            MySQL.Async.fetchScalar(
                "SELECT COUNT(*) FROM rsg_wagons WHERE citizenid = @citizenid AND JSON_EXTRACT(custom, '$.name') = @wagonName",
                {
                    ["@citizenid"] = citizenid,
                    ["@wagonName"] = custom.name
                },
                function(count)
                    if count > 0 then
                        TriggerClientEvent('ox_lib:notify', src,
                            { title = locale("error"), description = locale("cl_wagon_name_exists"), type = 'error', duration = 5000 })
                        GetPlayerDataAndAddMoney(source, wagonPrice, moneyType)
                        if Config.Debug then
                            print("Error: Player already has a wagon with the name " .. custom.name)
                        end
                        return
                    end

                    -- Saves to the database
                    MySQL.Async.execute(
                        "INSERT INTO rsg_wagons (citizenid, wagon, custom, animals) VALUES (@citizenid, @wagon, @custom, @animals)",
                        {
                            ["@citizenid"] = citizenid,
                            ["@wagon"] = wagon,
                            ["@custom"] = json.encode(custom),
                            ["@animals"] = json.encode({})
                        },
                        function(rowsChanged)
                            if rowsChanged > 0 then
                                TriggerClientEvent('ox_lib:notify', src,
                                    { title = locale("success"), description = locale("cl_you_buy"), type = 'success', duration = 5000 })
                                if Config.Debug then print("Wagon saved successfully!") end
                            else
                                print("Error saving the wagon to the database!")
                            end
                        end
                    )
                end
            )
        end
    )
end)

---- Load wagon from the database ---

RegisterServerEvent("rsg-wagons:getWagonDataByCitizenID")
AddEventHandler("rsg-wagons:getWagonDataByCitizenID", function(serverSource)
    local src = nil
    if serverSource then
        src = serverSource -- ID of the player saving the wagon
    else
        src = source       -- ID of the player saving the wagon
    end

    local citizenid = GetCitizenID(src)

    -- Queries the wagon data by citizenid and checks if the active field = 1
    MySQL.Async.fetchAll("SELECT * FROM rsg_wagons WHERE citizenid = @citizenid AND active = 1", {
        ["@citizenid"] = citizenid
    }, function(result)
        -- If the wagon is found
        if result[1] then
            local wagonData = result[1]
            local customData = json.decode(wagonData.custom)   -- Decodes the stored JSON
            local animalsData = json.decode(wagonData.animals) -- Decodes the stored JSON

            -- Sends the wagon data back to the client
            TriggerClientEvent("rsg-wagons:receiveWagonData", src, wagonData.wagon, customData, animalsData, wagonData
                .id)
        end
    end)
end)

local wagons = {}

------------------- Register Wagon -----------------
RegisterNetEvent("rsg-wagons:registerWagon")
AddEventHandler("rsg-wagons:registerWagon", function(netId, wagonID, model)
    local source = source -- ID of the player who spawned the wagon

    -- Stores the wagon data
    wagons[netId] = {
        owner = source,
        wagonID = wagonID,
        wagonModel = model

    }

end)

RegisterNetEvent("rsg-wagons:updateWagonAuth")
AddEventHandler("rsg-wagons:updateWagonAuth", function(netId, citizenID, action)
    local source = source -- ID of the player updating the wagon

    -- Checks if the wagon exists
    if wagons[netId] then
        -- Ensures the authorized list exists
        if not wagons[netId].authorized then
            wagons[netId].authorized = {}
        end

        if action == "add" then
            -- Adds a new CitizenID to the authorized list
            wagons[netId].authorized[citizenID] = true

        elseif action == "remove" then
            -- Removes the CitizenID from the authorized list
            wagons[netId].authorized[citizenID] = nil

        end

    end
end)


-- Function to get wagon information by Network ID
function GetWagonInfoByNetId(netId)
    return wagons[netId] or nil
end

-- Function to get wagon information by WagonID
function GetWagonInfoByWagonId(wagonID)
    for netId, data in pairs(wagons) do
        if data.wagonID == wagonID then
            return netId, data
        end
    end
    return nil
end

RSGCore.Functions.CreateCallback('rsg-wagons:isWagonRegistered', function(source, cb, netId)
    local source = source
    if wagons[netId] then
        if source == wagons[netId].owner then
            -- If the player is the owner of the wagon, informs that it is registered
            cb(true, true, wagons[netId].wagonID, wagons[netId].wagonModel, netId)
        else
            -- Sends the response confirming that the wagon is registered
            cb(true, false, wagons[netId].wagonID, wagons[netId].wagonModel, netId)
        end
    end
    -- If not registered, informs the client
    cb(false)
end)

RegisterServerEvent("rsg-wagons:openWagonStash")
AddEventHandler("rsg-wagons:openWagonStash", function(stash, wagonModel, wagonID, netId)
    local source = source                         -- ID of the player trying to access the stash
    local playerIdentifier = GetCitizenID(source) -- Gets the CitizenID

    -- Checks if the wagon is registered
    if wagons[netId] then
        local owner = wagons[netId].owner
        local authorized = wagons[netId].authorized or {}

        local isAuthorized = false
        for _, id in ipairs(authorized) do
            if id == playerIdentifier then
                isAuthorized = true
                break
            end
        end

        -- If the player is the owner OR is on the authorized list
        if source == owner or isAuthorized then
            for type, infos in pairs(Config.Wagons) do
                for k, v in pairs(infos) do
                    if wagonModel == k then
                        local weight = v.maxWeight
                        local slots = v.slots
                        OpenStash(source, weight, slots, stash)
                        return
                    end
                end
            end
        else
            local firstname, lastname = GetName(source)
            for type, infos in pairs(Config.Wagons) do
                for k, v in pairs(infos) do
                    if wagonModel == k then
                        local data = {
                            citizenId = playerIdentifier,
                            netId = netId,
                            firstname = firstname,
                            lastname = lastname,
                            owner = owner,
                            targetID = source,
                            stash = stash,
                            weight = v.maxWeight,
                            slots = v.slots
                        }
                        TriggerClientEvent("rsg-wagons:stashPermission", source, data)
                        return
                    end
                end
            end
        end
    end
end)


RegisterServerEvent("rsg-wagons:getOwnerPermission")
AddEventHandler("rsg-wagons:getOwnerPermission", function(data)
    local owner = data.owner
    TriggerClientEvent("btc-wagon:askOwnerPermission", owner, data)
end)

RegisterServerEvent("rsg-wagons:giveOwnerPermission")
AddEventHandler("rsg-wagons:giveOwnerPermission", function(permission, data)
    local targetID = data.targetID
    local citizenId = data.citizenId
    local netId = data.netId

    if permission == "confirm" then
        if not wagons[netId] then return end

        if not wagons[netId].authorized then
            wagons[netId].authorized = {}
        end

        -- Avoids duplication
        for _, id in ipairs(wagons[netId].authorized) do
            if id == citizenId then return end
        end

        table.insert(wagons[netId].authorized, citizenId)
        TriggerClientEvent('ox_lib:notify', targetID,
            { title = locale("success"), description = locale("have_permission"), type = 'success', duration = 5000 })
    else
        TriggerClientEvent('ox_lib:notify', targetID,
            { title = locale("error"), description = locale("no_permission"), type = 'error', duration = 5000 })
    end
end)

--------------- wagon check
RSGCore.Functions.CreateCallback('rsg-wagons:checkMyWagons', function(source, cb)
    local src = source
    local citizenid = GetCitizenID(src)

    MySQL.Async.fetchAll("SELECT wagon, custom FROM rsg_wagons WHERE citizenid = @citizenid", {
        ["@citizenid"] = citizenid
    }, function(result)
        if result and #result > 0 then
            local wagons = {}
            local customData = {}

            for _, data in ipairs(result) do
                table.insert(wagons, data.wagon)

                -- Now each wagon has its customization correctly stored
                table.insert(customData, json.decode(data.custom) or {})
            end

            cb(wagons, customData) -- Returns separate tables for models and customizations
        else
            cb({}, {}) -- Returns empty lists if the player has no wagons
        end
    end)
end)

RegisterServerEvent("rsg-wagons:saveCustomization")
AddEventHandler("rsg-wagons:saveCustomization", function(wagonModel, custom, customType)
    local src = source
    local customPrice = Config.CustomPrice[customType]

    local citizenid, success = GetPlayerDataAndRemoveMoney(src, customPrice)

    if success then
        -- Converts the custom table to JSON
        local customJSON = json.encode(custom)

        -- Finds the wagon name within the customization (in the "name" field)
        local wagonName = custom.name

        -- Updates the DB with the new customization, using the model (wagonModel) and the name (custom.name)
        MySQL.Async.execute(
            "UPDATE rsg_wagons SET custom = @custom WHERE citizenid = @citizenid AND wagon = @wagonModel AND JSON_EXTRACT(custom, '$.name') = @wagonName",
            {
                ["@custom"] = customJSON,
                ["@citizenid"] = citizenid,
                ["@wagonModel"] = wagonModel, -- Adding the model (wagonModel) as a condition in the query
                ["@wagonName"] = wagonName    -- Also searching by name (custom.name)
            }, function(affectedRows)
                if affectedRows > 0 then
                    TriggerClientEvent('ox_lib:notify', src,
                        { title = locale("success"), description = locale("cl_custom_success"), type = 'success', duration = 5000 })
                end
            end)
    else
        TriggerClientEvent('ox_lib:notify', src,
            { title = locale("error"), description = locale("cl_dont_have_money"), type = 'error', duration = 5000 })
        return
    end
end)


----- Activate a new wagon

RegisterServerEvent("rsg-wagons:toggleWagonActive", function(wagon, currentWagonCustom)
    local source = source
    local citizenID = GetCitizenID(source)     -- Gets the CitizenID correctly
    local customName = currentWagonCustom.name -- Gets the name of the customization

    if not customName or customName == "" then
        TriggerClientEvent('ox_lib:notify', source,
            { title = locale("error"), description = locale("error"), type = 'error', duration = 5000 })
        return
    end

    -- Check if the player already has an active wagon
    MySQL.Async.fetchAll("SELECT id FROM rsg_wagons WHERE citizenid = @citizenid AND active = 1", {
        ["@citizenid"] = citizenID
    }, function(activeWagons)
        if activeWagons and #activeWagons > 0 then
            -- If there is an active wagon, deactivate it
            local currentActiveWagonID = activeWagons[1].id
            MySQL.Async.execute("UPDATE rsg_wagons SET active = 0 WHERE id = @id", {
                ["@id"] = currentActiveWagonID
            })
        end

        -- Now we activate the new wagon, checking if the `custom` JSON contains the same name
        MySQL.Async.execute([[
            UPDATE rsg_wagons
            SET active = 1
            WHERE wagon = @wagon
            AND JSON_UNQUOTE(JSON_EXTRACT(custom, "$.name")) = @customName
            AND citizenid = @citizenid
        ]], {
            ["@wagon"] = wagon,
            ["@customName"] = customName,
            ["@citizenid"] = citizenID
        }, function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('ox_lib:notify', source,
                    { title = locale("success"), description = locale("ative_wagon"), type = 'success', duration = 5000 })
                Wait(500)
                TriggerEvent("rsg-wagons:getWagonDataByCitizenID", source) -- Updates the wagon data on the client
            else
                TriggerClientEvent('ox_lib:notify', source,
                    { title = locale("error"), description = locale("no_custom_wagon"), type = 'error', duration = 5000 })
            end
        end)
    end)
end)


--------------- Sell Wagon ------------------
RegisterNetEvent("rsg-wagons:sellWagon", function(wagonModel, custom)
    local src = source
    local citizenid = GetCitizenID(src) -- Gets the player's citizenid

    if not custom or not custom.name then
        TriggerClientEvent('ox_lib:notify', src,
            { title = locale("error"), description = locale("no_wagon_found"), type = 'error', duration = 5000 })
        return
    end

    local wagonName = custom.name -- Gets the wagon name from within custom

    -- Searches for the wagon in the database using the saved name
    MySQL.query("SELECT * FROM rsg_wagons WHERE citizenid = ? AND JSON_EXTRACT(custom, '$.name') = ?",
        { citizenid, wagonName }, function(result)
            if result and #result > 0 then
                local wagonData = result[1]
                local customDB = json.decode(wagonData.custom or "{}") -- Converts JSON to table
                local buyMoneyType = customDB.buyMoneyType or "cash"   -- Gets the original payment type

                -- Find the original price in Config.Wagons
                local originalPrice = nil
                local altPrice = nil

                for type, wagons in pairs(Config.Wagons) do
                    if wagons[wagonModel] then
                        -- First, try to get the value based on the original currency used
                        originalPrice = (buyMoneyType == "gold" and wagons[wagonModel].priceGold) or
                            wagons[wagonModel].price
                        -- Saves the alternative price (if the first one doesn't exist)
                        altPrice = (buyMoneyType == "gold" and wagons[wagonModel].price) or wagons[wagonModel].priceGold
                        break
                    end
                end

                -- If it didn't find the original price, it tries to use the alternative price
                if not originalPrice then
                    originalPrice = altPrice
                    buyMoneyType = (buyMoneyType == "gold") and "cash" or "gold" -- Switches to the other currency type
                end

                -- If a valid price is still not found, cancels the sale
                if not originalPrice then
                    TriggerClientEvent('ox_lib:notify', src,
                        { title = locale("error"), description = locale("no_price"), type = 'error', duration = 5000 })
                    return
                end

                -- Calculate the selling price
                local sellPrice = originalPrice * Config.Sell

                -- Remove wagon from DB
                MySQL.execute("DELETE FROM rsg_wagons WHERE citizenid = ? AND JSON_EXTRACT(custom, '$.name') = ?",
                    { citizenid, wagonName })

                -- Add the money to the player
                GetPlayerDataAndAddMoney(src, sellPrice, buyMoneyType)

                -- Notification for the player
                TriggerClientEvent('ox_lib:notify', src,
                    { title = locale("success"), description = locale("you_sell_wagon") ..
                    (buyMoneyType == "gold" and "🪙 " or "💰 ") .. sellPrice .. "!", type = 'success', duration = 5000 })
            end
        end)
end)


local wagonAnimalsData = {}

function GetLabelFromModel(item)
    if item.type == "animal" then
        local entry = Config.AnimalsStorage[item.model]
        return entry and entry.label
    elseif item.type == "pelt" then
        local entry = Config.AnimalsStorage[item.peltquality]
        return entry and entry.label
    end
end

local function getWagonMenuData(wagonId, cb)
    if not wagonId then
        print("⚠️ Invalid wagon ID.")
        cb({})
        return
    end

    -- If it's already in memory, we use it directly
    if wagonAnimalsData[wagonId] then
        local menuData = {}

        for _, item in ipairs(wagonAnimalsData[wagonId]) do
            local label = GetLabelFromModel(item) or "Unknown Item"
            table.insert(menuData, {
                label = label,
                infos = item
            })
        end

        cb(menuData)
        return
    end

    -- If it's not in memory, fetches from the database
    MySQL.query("SELECT animals FROM rsg_wagons WHERE id = ?", { wagonId }, function(result)
        local menuData = {}

        if result and result[1] and result[1].animals then
            local decoded = json.decode(result[1].animals) or {}
            -- Saves in memory
            wagonAnimalsData[wagonId] = decoded

            for _, item in ipairs(decoded) do
                local label = GetLabelFromModel(item) or "Unknown Item"
                table.insert(menuData, {
                    label = label,
                    infos = item
                })
            end
        else
            print("⚠️ No data found in the DB for the wagon:", wagonId)
        end

        cb(menuData)
    end)
end


local function updateAndSave(wagonId, newAnimal, remove) ---- if remove = true, removes the animal from the DB
    if not wagonId or not newAnimal then
        print("⚠️ Invalid data for updateAndSave")
        return
    end

    -- Ensures the wagon table is initialized
    if not wagonAnimalsData[wagonId] then
        wagonAnimalsData[wagonId] = {}
    end

    local animalsTable = wagonAnimalsData[wagonId]
    local foundIndex = nil

    -- Checks if the item already exists
    for i, animal in ipairs(animalsTable) do
        local isSame =
            animal.model == newAnimal.model and
            animal.type == newAnimal.type and
            (
                (newAnimal.type == "animal" and
                    animal.outfit == newAnimal.outfit and
                    animal.skinned == newAnimal.skinned and
                    animal.quality == newAnimal.quality) or
                (newAnimal.type == "pelt" and animal.peltquality == newAnimal.peltquality)
            )

        if isSame then
            foundIndex = i
            break
        end
    end

    if remove then
        if foundIndex then
            local currentQty = animalsTable[foundIndex].quantity or 1
            if currentQty > 1 then
                animalsTable[foundIndex].quantity = currentQty - 1
            else
                table.remove(animalsTable, foundIndex)
            end
        else
            print("⚠️ Attempting to remove an item that does not exist in the wagon")
            return
        end
    else
        if foundIndex then
            animalsTable[foundIndex].quantity = (animalsTable[foundIndex].quantity or 1) + 1
        else
            local entry = {}
            if newAnimal.type == "pelt" then
                entry = newAnimal
                entry.peltquality = newAnimal.peltquality
                entry.quantity = 1
            elseif newAnimal.type == "animal" then
                entry = newAnimal
                entry.quantity = 1
                entry.metatag = newAnimal.metatag
            end

            table.insert(animalsTable, entry)
        end
    end

    -- Updates in memory
    wagonAnimalsData[wagonId] = animalsTable

    -- Saves to the DB
    local animalsJSON = json.encode(animalsTable)
    MySQL.update("UPDATE rsg_wagons SET animals = ? WHERE id = ?", {
        animalsJSON,
        wagonId
    }, function(rowsChanged)
    end)
end

RegisterNetEvent("rsg-wagons:storeAnimalInWagon", function(wagonId, newAnimal)
    local src = source

    if not wagonId or not newAnimal or type(newAnimal) ~= "table" then
        return
    end

    -- If we already have the data in the cache, we use it directly
    local animalsTable = wagonAnimalsData[wagonId]

    if not animalsTable then
        -- If we don't have the cache yet, load from the DB and update
        MySQL.query("SELECT animals FROM rsg_wagons WHERE id = ?", { wagonId }, function(result)
            local loadedAnimals = {}

            if result and result[1] and result[1].animals then
                loadedAnimals = json.decode(result[1].animals) or {}
            end

            wagonAnimalsData[wagonId] = loadedAnimals
            animalsTable = loadedAnimals

            updateAndSave(wagonId, newAnimal)
        end)
    else
        updateAndSave(wagonId, newAnimal)
    end
end)

RSGCore.Functions.CreateCallback('rsg-wagons:getAnimalStorage', function(source, cb, wagonId)
    local source = source
    getWagonMenuData(wagonId, function(menuData)
        cb(menuData) -- Only calls the cb here, after getWagonMenuData has the data
    end)
end)

------------ Remove an animal from the wagon

RegisterNetEvent("rsg-wagons:removeAnimalFromWagon", function(wagonID, infos, label)
    local src = source
    TriggerClientEvent("rsg-wagons:spawnAnimal", src, infos)
    ------ Continue from here, before the function to remove the animal (updateandsave), check if the animal exists in the wagon and make the player spawn the animal
    updateAndSave(wagonID, infos, true)
end)

------ Remove the Wagon from the server
RegisterNetEvent("rsg-wagons:removeWagon")
AddEventHandler("rsg-wagons:removeWagon", function(netId, wagon)
    if wagons[netId] then
        local wagon = NetworkGetEntityFromNetworkId(netId)
        if wagon and DoesEntityExist(wagon) then
            DeleteEntity(wagon)
        end

        wagons[netId] = nil -- Remove from the table
    else                    --- in case it is the resource stop
        local wagon = NetworkGetEntityFromNetworkId(netId)
        if wagon and DoesEntityExist(wagon) then
            DeleteEntity(wagon)
            wagons[netId] = nil -- Remove from the table
        end
    end
end)
