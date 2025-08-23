lib.locale()


RegisterNetEvent("rsg-wagons:client:openStore")
AddEventHandler("rsg-wagons:client:openStore", function(store)
    local menuData = {
        {
            title = locale("cl_your_wagons"),
            description = locale("cl_see_your_wagons"),
            icon = "nui://rsg-wagons/images/wagon.png",
            onSelect = function()
                MyWagons(store)
            end,
        },
        {
            title = locale("cl_wagon_buy"),
            description = locale("cl_wagon_buy_desc"),
            icon = "nui://rsg-wagons/images/buy_wagon.png",
            onSelect = function()
                BuyTypeWagonMenu(store)
            end,
        }
    }
    lib.registerContext({
        id = 'store_menu',
        title = locale("cl_wagon_store"),
        options = menuData
    })
    lib.showContext('store_menu')
end)



function BuyTypeWagonMenu(store)
    local wagonsTypeData = {}

    for type, wagons in pairs(Config.Wagons) do
        table.insert(wagonsTypeData, {
            title = locale(type),
            icon = "nui://rsg-wagons/images/" .. type .. ".png",
            onSelect = function()
                BuyWagonMenu(store, type)
            end,
        })
    end

    table.sort(wagonsTypeData, function(a, b)
        return a.title:lower() < b.title:lower()
    end)

    lib.registerContext({
        id = 'store_type_menu',
        title = locale("cl_wagon_store"),
        options = wagonsTypeData
    })
    lib.showContext('store_type_menu')
end

function BuyWagonMenu(store, wagonType)
    local menuCooldown = false
    ShowRotatePrompt()
    local wagonsData = {}
    local sortedWagons = {}

    for type, wagons in pairs(Config.Wagons) do
        if type == wagonType then
            for k, v in pairs(wagons) do
                table.insert(sortedWagons, {
                    name = v.name,
                    price = v.price,
                    priceGold = v.priceGold, -- Adiciona preço em ouro
                    maxAnimals = v.maxAnimals,
                    slots = v.slots,
                    maxWeight = v.maxWeight,
                    model = k
                })
            end
        end
    end

    table.sort(sortedWagons, function(a, b)
        return (a.price or math.huge) < (b.price or math.huge)
    end)

    for _, v in ipairs(sortedWagons) do
        local priceText = ""
        local useCash = false
        local useGold = false

        -- Construindo a string do preço com base no que está disponível
        if v.price then
            priceText = "💰" .. v.price .. " "
            useCash = true
        end
        if v.priceGold then
            if priceText ~= "" then
                priceText = priceText .. " or " -- Adiciona separador se ambos existirem
            end
            priceText = priceText .. " 🪙" .. v.priceGold --
            useGold = true
        end
        if v.maxAnimals then
            priceText = priceText .. " | 🦌 " .. locale("animals") .. " " .. v.maxAnimals .. " "
        end

        if v.slots and not v.maxWeight then
            priceText = priceText .. " | " .. locale("slots") .. ": " .. v.slots .. " "
        end

        if not v.slots and v.maxWeight then
            priceText = priceText .. " | " .. locale("weight") .. ": " .. v.maxWeight .. " kg"
        end

        if v.slots and v.maxWeight then
            priceText = priceText ..
                " | " .. locale("slots") .. ": " .. v.slots .. " " .. locale("weight") .. ": " .. v.maxWeight .. " kg"
        end

        table.insert(wagonsData, {
            label = v.name,
            args = { wagonModel = v.model, useCash = useCash, useGold = useGold },
            description = locale("buy_a_wagon") .. priceText,
            close = true
        })
    end

    SpawnShowroomWagon(wagonsData[1].args.wagonModel, store) -- Carregar a carroça do primeiro item da lista

    lib.registerMenu({
        id = 'buy_wagon_menu',
        title = locale("cl_wagon_store"),
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
        end,
        onSelected = function(selected, secondary, args)
            if menuCooldown then return end
            menuCooldown = true

            SpawnShowroomWagon(args.wagonModel, store)
            Wait(300)
            menuCooldown = false
        end,
        onClose = function()
            CloseShowroom()
            HideRotatePrompt()
        end,
        options = wagonsData
    }, function(selected, scrollIndex, args)
        local moneyType

        if args.useCash and args.useGold then
            local input = lib.inputDialog(locale("payment"), {
                {
                    type = "select",
                    label = locale("choose"),
                    options = {
                        { value = "cash", label = locale("cashtype") },
                        { value = "gold", label = locale("goldtype") }
                    }
                }
            })

            if input and input[1] then
                moneyType = input[1]
            else
                CloseShowroom()
                HideRotatePrompt()

                return
            end
        else
            if args.useCash then
                moneyType = "cash"
            else
                moneyType = "gold"
            end
        end

        local nameInput = lib.inputDialog(locale("cl_wagon_name"), {
            { type = "input", label = locale("cl_wagon_name_label"), description = locale("cl_wagon_name_desc"), required = true, min = 1, max = 16 },
        })

        if not nameInput or not nameInput[1] then
            CloseShowroom()
            HideRotatePrompt()
            return
        end

        CloseShowroom()
        HideRotatePrompt()

        TriggerEvent("rsg-wagons:saveWagonToDatabase", args.wagonModel, nameInput[1], moneyType)
    end)
    lib.showMenu('buy_wagon_menu')
end

------------------- My Wagons

function MyWagons(store)
    local RSGCore = exports['rsg-core']:GetCoreObject()
    RSGCore.Functions.TriggerCallback('rsg-wagons:checkMyWagons', function(wagons, custom)
        local myWagonsData = {}
        if wagons and #wagons > 0 then
            myWagonsData = {}

            for i, wagon in ipairs(wagons) do
                local wagonCustom = custom[i] or {}

                table.insert(myWagonsData, {
                    title = wagonCustom.name or locale("cl_no_name"),
                    onSelect = function()
                        SpawnShowroomMyWagon(wagon, store, wagonCustom)
                        SelectMyWagon(store, wagonCustom, wagon)
                    end,
                })
            end

            table.sort(myWagonsData, function(a, b)
                return a.label:lower() < b.label:lower()
            end)

            lib.registerContext({
                title = locale("cl_your_wagons"),
                id = 'mywagons_menu',
                options = myWagonsData
            })
            lib.showContext('mywagons_menu')
        else
            lib.notify({ title = locale("error"), description = locale("cl_no_have_wagon"), type = "error", duration = 7000 })
        end
    end)
end

function SelectMyWagon(store, custom, wagonModel)
    ShowRotatePrompt()
    local myWagonCustomData = {}
    currentWagonCustom = custom or {}

    table.insert(myWagonCustomData, {
        label = locale("activate_wagon"),
        args = { value = "activate" },
        image = "nui://rsg-wagons/images/kit_upgrade_camp_wagon.png",
        desc = locale("activate_wagon_desc"),
        close = true
    })

    for type, _ in pairs(Custom) do
        for wagon, item in pairs(Custom[type]) do
            if wagonModel == wagon then
                table.insert(myWagonCustomData, {
                    label = locale(type) .. " - $" .. Config.CustomPrice[type],
                    args = { value = type, custom = currentWagonCustom[type] or {} },
                    icon = "nui://rsg-wagons/images/wagons_" .. type .. ".png",
                    description = locale(type .. "_desc"),
                })
            end
        end
    end

    table.sort(myWagonCustomData, function(a, b)
        if a.args.value == "activate" then return true end
        if b.args.value == "activate" then return false end
        return a.label:lower() < b.label:lower()
    end)

    table.insert(myWagonCustomData, {
        label = "🛑 " .. locale("sell_wagon"),
        args = { value = 'sell' },
        icon = "nui://rsg-wagons/images/delete_wagon.png",
        close = true
    })

    lib.registerMenu({
        id = 'select_my_wagon_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
        end,
        onSelected = function(selected, secondary, args)

        end,
        onClose = function()
            CloseShowroom()
            HideRotatePrompt()
        end,
        options = myWagonCustomData
    }, function(selected, scrollIndex, args)
        if args.value == 'activate' then
            TriggerServerEvent("rsg-wagons:toggleWagonActive", wagonModel, currentWagonCustom)
            CloseShowroom()
            HideRotatePrompt()
        elseif args.value == 'sell' then
            local confirm = lib.inputDialog(locale("want_sell"), {
                {
                    type = "select",
                    label = locale("choose"),
                    options = {
                        { value = "yes", label = locale("yes") },
                        { value = "no",  label = locale("no") }
                    }
                }
            })

            if confirm[1] == "yes" then
                TriggerServerEvent("rsg-wagons:sellWagon", wagonModel, currentWagonCustom)
            end
            CloseShowroom()
            HideRotatePrompt()
        elseif args.value == "livery" then
            EditLivery(store, currentWagonCustom, wagonModel, args.value)
        elseif args.value == "extra" then
            EditExtra(store, currentWagonCustom, wagonModel, args.value)
        elseif args.value == "tint" then
            EditWagonTint(store, currentWagonCustom, wagonModel, args.value)
        elseif args.value == "props" then
            EditWagonProps(store, currentWagonCustom, wagonModel, args.value)
        elseif args.value == "lantern" then
            EditLantern(store, currentWagonCustom, wagonModel, args.value)
        end
    end)
    lib.showMenu('select_my_wagon_menu')
end

function EditLivery(store, custom, wagonModel, type)
    local currentWagonShowCustom = {}
    for k, v in pairs(currentWagonCustom) do
        currentWagonShowCustom[k] = v
    end
    local myLiveryCustom = {}


    table.insert(myLiveryCustom, {
        label = "❌ " .. locale("remove"),
        args = { value = -1 },
    })


    local firstLivery = nil

    for k, v in pairs(Custom[type][wagonModel]) do
        table.insert(myLiveryCustom, {
            label = v[2],
            args = { value = v[1] },
            description = locale(type .. "_desc") or "No description",
        })
        if not firstLivery then
            firstExtra = k
        end
    end

    if firstLivery then
        currentWagonCustom[type] = firstLivery
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
    end

    table.sort(myLiveryCustom, function(a, b)
        return a.args.value ~= false and (b.args.value == false or a.label:lower() < b.label:lower())
    end)

    lib.registerMenu({
        id = 'livery_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
        end,
        onSelected = function(selected, secondary, args)
            currentWagonShowCustom[type] = args.value
            SpawnShowroomMyWagon(wagonModel, store, currentWagonShowCustom)
        end,
        onClose = function()
            SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
            SelectMyWagon(store, custom, wagonModel)
        end,
        options = myLiveryCustom
    }, function(selected, scrollIndex, args)
        currentWagonCustom[type] = args.value
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
        TriggerServerEvent("rsg-wagons:saveCustomization", wagonModel, currentWagonCustom, type)
        SelectMyWagon(store, custom, wagonModel)
    end)
    lib.showMenu('livery_menu')
end

function EditExtra(store, custom, wagonModel, type)
    local currentWagonShowCustom = {}
    for k, v in pairs(currentWagonCustom) do
        currentWagonShowCustom[k] = v
    end
    local myExtraCustom = {}


    table.insert(myExtraCustom, {
        label = "❌ " .. locale("remove"),
        args = { value = -1 },
    })


    local firstExtra = nil

    for k, v in pairs(Custom[type][wagonModel]) do
        table.insert(myExtraCustom, {
            label = tostring(v),
            args = { value = k },
            description = locale(type .. "_desc") or "No description",
        })
        if not firstExtra then
            firstExtra = k
        end
    end

    if firstExtra then
        currentWagonCustom[type] = firstExtra
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
    end

    table.sort(myExtraCustom, function(a, b)
        return a.args.value ~= false and (b.args.value == false or a.label:lower() < b.label:lower())
    end)

    lib.registerMenu({
        id = 'extra_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
        end,
        onSelected = function(selected, secondary, args)
            currentWagonShowCustom[type] = args.value
            SpawnShowroomMyWagon(wagonModel, store, currentWagonShowCustom)
        end,
        onClose = function()
            SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
            SelectMyWagon(store, custom, wagonModel)
        end,
        options = myExtraCustom
    }, function(selected, scrollIndex, args)
        currentWagonCustom[type] = args.value
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
        TriggerServerEvent("rsg-wagons:saveCustomization", wagonModel, currentWagonCustom, type)
        SelectMyWagon(store, custom, wagonModel)
    end)
    lib.showMenu('extra_menu')
end

function EditLantern(store, custom, wagonModel, type)
    local currentWagonShowCustom = {}
    for k, v in pairs(currentWagonCustom) do
        currentWagonShowCustom[k] = v
    end
    local myLanternCustom = {}

    table.insert(myLanternCustom, {
        label = "❌ " .. locale("remove"),
        args = { value = -1 },
    })


    local firstLantern = nil

    for k, v in pairs(Custom[type][wagonModel]) do
        table.insert(myLanternCustom, {
            label = tostring(k),
            args = { value = v },
            description = locale(type .. "_desc") or "No description",
        })
        if not firstLantern then
            firstLantern = v
        end
    end

    if firstExtra then
        currentWagonCustom[type] = firstLantern
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
    end

    table.sort(myLanternCustom, function(a, b)
        return a.args.value ~= false and (b.args.value == false or a.label:lower() < b.label:lower())
    end)

    lib.registerMenu({
        id = 'lanter_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
        end,
        onSelected = function(selected, secondary, args)
            currentWagonShowCustom[type] = args.value
            SpawnShowroomMyWagon(wagonModel, store, currentWagonShowCustom)
        end,
        onClose = function()
            SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
            SelectMyWagon(store, custom, wagonModel)
        end,
        options = myExtraCustom
    }, function(selected, scrollIndex, args)
        currentWagonCustom[type] = args.value
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
        TriggerServerEvent("rsg-wagons:saveCustomization", wagonModel, currentWagonCustom, type)
        SelectMyWagon(store, custom, wagonModel)
    end)
    lib.showMenu('lantern_menu')
end

function EditWagonProps(store, custom, wagonModel, type)
    local myPropsCustom = {}
    local currentWagonShowCustom = {}
    for k, v in pairs(currentWagonCustom) do
        currentWagonShowCustom[k] = v
    end

    table.insert(myPropsCustom, {
        label = "❌ " .. locale("remove"),
        args = { value = -1 },
    })


    local firstProp = nil
    local orderedProps = {}

    for k, v in pairs(Custom[type][wagonModel]) do
        table.insert(orderedProps, { key = k, value = v })
    end

    table.sort(orderedProps, function(a, b)
        return tonumber(a.key) < tonumber(b.key) -- Garante a ordem numérica
    end)

    for _, prop in ipairs(orderedProps) do
        table.insert(myPropsCustom, {
            label = tostring(prop.key),
            args = { value = prop.value },
            description = locale(type .. "_desc") or "No description",
        })
        if not firstProp then
            firstProp = prop.value
        end
    end

    if firstProp then
        currentWagonCustom[type] = firstProp
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
    end

    table.sort(myPropsCustom, function(a, b)
        return a.args.value ~= false and (b.args.value == false or a.label:lower() < b.label:lower())
    end)

    lib.registerMenu({
        id = 'wagon_props_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
        end,
        onSelected = function(selected, secondary, args)
            currentWagonShowCustom[type] = args.value
            SpawnShowroomMyWagon(wagonModel, store, currentWagonShowCustom)
        end,
        onClose = function()
            SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
            SelectMyWagon(store, custom, wagonModel)
        end,
        options = myPropsCustom
    }, function(selected, scrollIndex, args)
        currentWagonCustom[type] = args.value
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
        TriggerServerEvent("rsg-wagons:saveCustomization", wagonModel, currentWagonCustom, type)
        SelectMyWagon(store, custom, wagonModel)
    end)
    lib.showMenu('wagon_props_menu')
end

function EditWagonTint(store, custom, wagonModel, type)
    local myTintCustom = {}
    local currentWagonShowCustom = {}
    for k, v in pairs(currentWagonCustom) do
        currentWagonShowCustom[k] = v
    end

    table.insert(myTintCustom, {
        label = "❌ " .. locale("remove"),
        args = { value = -1 },
    })


    local maxTints = Custom[type][wagonModel]
    local firstTints = nil

    for i = 1, maxTints do
        table.insert(myTintCustom, {
            label = tostring(i),
            args = { value = i },
            desc = locale(type .. "_desc") or "Sem descrição",
        })
        if not firstTints then
            firstTints = i
        end
    end

    if firstTints then
        currentWagonCustom[type] = firstTints
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
    end

    currentWagonShowCustom = {}
    currentWagonShowCustom = currentWagonCustom


    lib.registerMenu({
        id = 'wagon_tint_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSideScroll = function(selected, scrollIndex, args)
        end,
        onSelected = function(selected, secondary, args)
            currentWagonShowCustom[type] = args.value
            SpawnShowroomMyWagon(wagonModel, store, currentWagonShowCustom)
        end,
        onClose = function()
            SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
            SelectMyWagon(store, custom, wagonModel)
        end,
        options = myTintCustom
    }, function(selected, scrollIndex, args)
        currentWagonCustom[type] = args.value
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
        TriggerServerEvent("rsg-wagons:saveCustomization", wagonModel, currentWagonCustom, type)
        SelectMyWagon(store, custom, wagonModel)
    end)
    lib.showMenu('wagon_tint_menu')
end

RegisterNetEvent("rsg-wagons:stashPermission")
AddEventHandler("rsg-wagons:stashPermission", function(info)
    TriggerServerEvent("rsg-wagons:getOwnerPermission", info)
end)
