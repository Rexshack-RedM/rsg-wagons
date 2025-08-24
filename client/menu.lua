RegisterNetEvent("rsg-wagons:client:openStore", function(store)
    lib.registerContext({
        id = 'store_menu',
        title = locale("cl_wagon_store"),
        options = {
            {
                title = locale("cl_your_wagons"),
                description = locale("cl_see_your_wagons"),
                icon = "nui://rsg-wagons/images/wagon.png",
                onSelect = function() MyWagons(store) end
            },
            {
                title = locale("cl_wagon_buy"),
                description = locale("cl_wagon_buy_desc"),
                icon = "nui://rsg-wagons/images/buy_wagon.png",
                onSelect = function() BuyTypeWagonMenu(store) end
            }
        }
    })
    lib.showContext('store_menu')
end)

function BuyTypeWagonMenu(store)
    local opts = {}
    for type in pairs(Config.Wagons) do
        opts[#opts + 1] = {
            title = locale(type),
            icon = "nui://rsg-wagons/images/" .. type .. ".png",
            onSelect = function() BuyWagonMenu(store, type) end
        }
    end
    table.sort(opts, function(a, b) return a.title:lower() < b.title:lower() end)
    lib.registerContext({ id = 'store_type_menu', title = locale("cl_wagon_store"), options = opts })
    lib.showContext('store_type_menu')
end

function BuyWagonMenu(store, wagonType)
    ShowRotatePrompt()
    local sorted, wagonsData = {}, {}

    for type, wagons in pairs(Config.Wagons) do
        if type == wagonType then
            for model, v in pairs(wagons) do
                sorted[#sorted + 1] = {
                    name = v.name,
                    price = v.price,
                    priceGold = v.priceGold,
                    maxAnimals = v.maxAnimals,
                    slots = v.slots,
                    maxWeight = v.maxWeight,
                    model = model
                }
            end
        end
    end

    table.sort(sorted, function(a, b) return (a.price or math.huge) < (b.price or math.huge) end)

    for _, v in ipairs(sorted) do
        local priceText, useCash, useGold = "", false, false
        if v.price then priceText = "💰" .. v.price .. " "; useCash = true end
        if v.priceGold then
            priceText = priceText .. (priceText ~= "" and " or " or "") .. "🪙" .. v.priceGold .. " "
            useGold = true
        end
        if v.maxAnimals then priceText = priceText .. "| 🦌 " .. locale("animals") .. " " .. v.maxAnimals .. " " end
        if v.slots and not v.maxWeight then priceText = priceText .. "| " .. locale("slots") .. ": " .. v.slots .. " " end
        if not v.slots and v.maxWeight then priceText = priceText .. "| " .. locale("weight") .. ": " .. v.maxWeight .. " kg" end
        if v.slots and v.maxWeight then
            priceText = priceText .. "| " .. locale("slots") .. ": " .. v.slots .. " " .. locale("weight") .. ": " .. v.maxWeight .. " kg"
        end

        wagonsData[#wagonsData + 1] = {
            label = v.name,
            args = { wagonModel = v.model, useCash = useCash, useGold = useGold },
            description = locale("buy_a_wagon") .. priceText,
            close = true
        }
    end

    if wagonsData[1] then
        SpawnShowroomWagon(wagonsData[1].args.wagonModel, store)
    end

    local menuCooldown = false
    lib.registerMenu({
        id = 'buy_wagon_menu',
        title = locale("cl_wagon_store"),
        position = 'top-right',
        onSelected = function(_, _, args)
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
    }, function(_, _, args)
        local moneyType
        if args.useCash and args.useGold then
            local input = lib.inputDialog(locale("payment"), {
                { type = "select", label = locale("choose"), options = {
                    { value = "cash", label = locale("cashtype") },
                    { value = "gold", label = locale("goldtype") }
                } }
            })
            if input and input[1] then
                moneyType = input[1]
            else
                CloseShowroom()
                HideRotatePrompt()
                return
            end
        else
            moneyType = args.useCash and "cash" or "gold"
        end

        local nameInput = lib.inputDialog(locale("cl_wagon_name"), {
            { type = "input", label = locale("cl_wagon_name_label"), description = locale("cl_wagon_name_desc"), required = true, min = 1, max = 16 }
        })
        if not nameInput or not nameInput[1] then
            CloseShowroom()
            HideRotatePrompt()
            return
        end

        CloseShowroom()
        HideRotatePrompt()
        TriggerServerEvent("rsg-wagons:saveWagonToDatabase", args.wagonModel, { name = nameInput[1], buyMoneyType = moneyType }, moneyType)
    end)
    lib.showMenu('buy_wagon_menu')
end

currentWagonCustom = currentWagonCustom or {}


function MyWagons(store)
    lib.callback('rsg-wagons:checkMyWagons', false, function(wagons, custom)
        if not wagons or #wagons == 0 then
            return lib.notify({
                title = locale("error"),
                description = locale("cl_no_have_wagon"),
                type = "error",
                duration = 7000
            })
        end

        local myWagonsData = {}
        for i, wagonModel in ipairs(wagons) do
            local wagonCustom = custom[i] or {}
            myWagonsData[#myWagonsData + 1] = {
                title = wagonCustom.name or locale("cl_no_name"),
                onSelect = function()
                    SpawnShowroomMyWagon(wagonModel, store, wagonCustom)
                    SelectMyWagon(store, wagonCustom, wagonModel)
                end
            }
        end

        table.sort(myWagonsData, function(a, b)
            return a.title:lower() < b.title:lower()
        end)

        lib.registerContext({
            id = 'mywagons_menu',
            title = locale("cl_your_wagons"),
            options = myWagonsData
        })
        lib.showContext('mywagons_menu')
    end)
end


function SelectMyWagon(store, custom, wagonModel)
    ShowRotatePrompt()
    currentWagonCustom = custom or {}

    local opts = {
        {
            label = locale("activate_wagon"),
            args = { value = "activate" },
            icon = "nui://rsg-wagons/images/kit_upgrade_camp_wagon.png",
            description = locale("activate_wagon_desc"),
            close = true
        }
    }

    for type, wagons in pairs(Custom) do
        if wagons[wagonModel] then
            opts[#opts + 1] = {
                label = locale(type) .. " - $" .. (Config.CustomPrice[type] or 0),
                args = { value = type },
                icon = "nui://rsg-wagons/images/wagons_" .. type .. ".png",
                description = locale(type .. "_desc") or ""
            }
        end
    end

    table.sort(opts, function(a, b)
        if a.args.value == "activate" then return true end
        if b.args.value == "activate" then return false end
        return a.label:lower() < b.label:lower()
    end)

    opts[#opts + 1] = {
        label = "🛑 " .. locale("sell_wagon"),
        args = { value = 'sell' },
        icon = "nui://rsg-wagons/images/delete_wagon.png",
        close = true
    }

    lib.registerMenu({
        id = 'select_my_wagon_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onClose = function()
            CloseShowroom()
            HideRotatePrompt()
        end,
        options = opts
    }, function(_, _, args)
        local action = args.value
        if action == 'activate' then
            TriggerServerEvent("rsg-wagons:toggleWagonActive", wagonModel, currentWagonCustom)
            CloseShowroom()
            HideRotatePrompt()
        elseif action == 'sell' then
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
            if confirm and confirm[1] == "yes" then
                TriggerServerEvent("rsg-wagons:sellWagon", wagonModel, currentWagonCustom)
            end
            CloseShowroom()
            HideRotatePrompt()
        elseif action == "livery" then
            EditLivery(store, currentWagonCustom, wagonModel, "livery")
        elseif action == "extra" then
            EditExtra(store, currentWagonCustom, wagonModel, "extra")
        elseif action == "tint" then
            EditWagonTint(store, currentWagonCustom, wagonModel, "tint")
        elseif action == "props" then
            EditWagonProps(store, currentWagonCustom, wagonModel, "props")
        elseif action == "lantern" then
            EditLantern(store, currentWagonCustom, wagonModel, "lantern")
        end
    end)
    lib.showMenu('select_my_wagon_menu')
end


function EditLivery(store, custom, wagonModel, type)
    local currentShow = {}
    for k, v in pairs(currentWagonCustom or {}) do currentShow[k] = v end

    local items = {
        { label = "❌ " .. locale("remove"), args = { value = -1 } }
    }

    local firstLivery
    for _, v in pairs((Custom[type] and Custom[type][wagonModel]) or {}) do
        items[#items + 1] = {
            label = v[2],
            args = { value = v[1] },
            description = locale(type .. "_desc") or ""
        }
        if not firstLivery then firstLivery = v[1] end
    end

    if firstLivery then
        currentWagonCustom[type] = firstLivery
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
    end

    lib.registerMenu({
        id = 'livery_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSelected = function(_, _, args)
            currentShow[type] = args.value
            SpawnShowroomMyWagon(wagonModel, store, currentShow)
        end,
        onClose = function()
            SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
            SelectMyWagon(store, custom, wagonModel)
        end,
        options = items
    }, function(_, _, args)
        currentWagonCustom[type] = args.value
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
        TriggerServerEvent("rsg-wagons:saveCustomization", wagonModel, currentWagonCustom, type)
        SelectMyWagon(store, custom, wagonModel)
    end)
    lib.showMenu('livery_menu')
end


function EditExtra(store, custom, wagonModel, type)
    local currentShow = {}
    for k, v in pairs(currentWagonCustom or {}) do currentShow[k] = v end

    local items = {
        { label = "❌ " .. locale("remove"), args = { value = -1 } }
    }

    local firstExtra
    for k, v in pairs((Custom[type] and Custom[type][wagonModel]) or {}) do
        items[#items + 1] = {
            label = tostring(v),
            args = { value = k },
            description = locale(type .. "_desc") or ""
        }
        if not firstExtra then firstExtra = k end
    end

    if firstExtra then
        currentWagonCustom[type] = firstExtra
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
    end

    lib.registerMenu({
        id = 'extra_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSelected = function(_, _, args)
            currentShow[type] = args.value
            SpawnShowroomMyWagon(wagonModel, store, currentShow)
        end,
        onClose = function()
            SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
            SelectMyWagon(store, custom, wagonModel)
        end,
        options = items
    }, function(_, _, args)
        currentWagonCustom[type] = args.value
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
        TriggerServerEvent("rsg-wagons:saveCustomization", wagonModel, currentWagonCustom, type)
        SelectMyWagon(store, custom, wagonModel)
    end)
    lib.showMenu('extra_menu')
end


function EditLantern(store, custom, wagonModel, type)
    local currentShow = {}
    for k, v in pairs(currentWagonCustom or {}) do currentShow[k] = v end

    local items = {
        { label = "❌ " .. locale("remove"), args = { value = -1 } }
    }

    local firstLantern
    for key, val in pairs((Custom[type] and Custom[type][wagonModel]) or {}) do
        items[#items + 1] = {
            label = tostring(key),
            args = { value = val },
            description = locale(type .. "_desc") or ""
        }
        if not firstLantern then firstLantern = val end
    end

    if firstLantern then
        currentWagonCustom[type] = firstLantern
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
    end

    lib.registerMenu({
        id = 'lantern_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSelected = function(_, _, args)
            currentShow[type] = args.value
            SpawnShowroomMyWagon(wagonModel, store, currentShow)
        end,
        onClose = function()
            SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
            SelectMyWagon(store, custom, wagonModel)
        end,
        options = items
    }, function(_, _, args)
        currentWagonCustom[type] = args.value
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
        TriggerServerEvent("rsg-wagons:saveCustomization", wagonModel, currentWagonCustom, type)
        SelectMyWagon(store, custom, wagonModel)
    end)
    lib.showMenu('lantern_menu')
end


function EditWagonProps(store, custom, wagonModel, type)
    local currentShow = {}
    for k, v in pairs(currentWagonCustom or {}) do currentShow[k] = v end

    local items = {
        { label = "❌ " .. locale("remove"), args = { value = -1 } }
    }

    local ordered = {}
    for k, v in pairs((Custom[type] and Custom[type][wagonModel]) or {}) do
        ordered[#ordered + 1] = { key = k, value = v }
    end
    table.sort(ordered, function(a, b) return tonumber(a.key) < tonumber(b.key) end)

    local firstProp
    for _, prop in ipairs(ordered) do
        items[#items + 1] = {
            label = tostring(prop.key),
            args = { value = prop.value },
            description = locale(type .. "_desc") or ""
        }
        if not firstProp then firstProp = prop.value end
    end

    if firstProp then
        currentWagonCustom[type] = firstProp
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
    end

    lib.registerMenu({
        id = 'wagon_props_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSelected = function(_, _, args)
            currentShow[type] = args.value
            SpawnShowroomMyWagon(wagonModel, store, currentShow)
        end,
        onClose = function()
            SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
            SelectMyWagon(store, custom, wagonModel)
        end,
        options = items
    }, function(_, _, args)
        currentWagonCustom[type] = args.value
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
        TriggerServerEvent("rsg-wagons:saveCustomization", wagonModel, currentWagonCustom, type)
        SelectMyWagon(store, custom, wagonModel)
    end)
    lib.showMenu('wagon_props_menu')
end


function EditWagonTint(store, custom, wagonModel, type)
    local currentShow = {}
    for k, v in pairs(currentWagonCustom or {}) do currentShow[k] = v end

    local items = {
        { label = "❌ " .. locale("remove"), args = { value = -1 } }
    }

    local maxTints = (Custom[type] and Custom[type][wagonModel]) or 0
    local firstTint
    for i = 1, maxTints do
        items[#items + 1] = {
            label = tostring(i),
            args = { value = i },
            description = locale(type .. "_desc") or ""
        }
        if not firstTint then firstTint = i end
    end

    if firstTint then
        currentWagonCustom[type] = firstTint
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
    end

    lib.registerMenu({
        id = 'wagon_tint_menu',
        title = locale("cl_your_wagons"),
        position = 'top-right',
        onSelected = function(_, _, args)
            currentShow[type] = args.value
            SpawnShowroomMyWagon(wagonModel, store, currentShow)
        end,
        onClose = function()
            SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
            SelectMyWagon(store, custom, wagonModel)
        end,
        options = items
    }, function(_, _, args)
        currentWagonCustom[type] = args.value
        SpawnShowroomMyWagon(wagonModel, store, currentWagonCustom)
        TriggerServerEvent("rsg-wagons:saveCustomization", wagonModel, currentWagonCustom, type)
        SelectMyWagon(store, custom, wagonModel)
    end)
    lib.showMenu('wagon_tint_menu')
end


RegisterNetEvent("rsg-wagons:stashPermission", function(info)
    TriggerServerEvent("rsg-wagons:getOwnerPermission", info)
end)
