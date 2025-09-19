local utils = require("utils")

local messages = {}

local function generateResponse(type, req, data, sign)
    local msg = {
        ["protocol"] = "SPAPIv1",
        ["type"] = type,
        ["data"] = data,
        ["reqComputer"] = req.computer,
        ["reqTime"] = req.time,
        ["time"] = math.floor(os.epoch("utc") / 1000),
        ["computer"] = os.getComputerID()
    }
    local tempmsg = textutils.serialise(textutils.unserialise(textutils.serialise(msg, { allow_repetitions = true, compact = true })), { allow_repetitions = true, compact = true })
    msg.hash = utils.bytesToHexString(SolidityPools.sha.digest(sign..tempmsg))
    return textutils.serialise(msg, { allow_repetitions = true, compact = true })
end

local function onApiMessage(msgId, pos, data, replyChannel)
    local config = SolidityPools.config
    local modem = SolidityPools.modem.wrap
    local userData = utils.loadUser(data.user)
    if userData.apiKey == nil then
        print("No api key?")
        return
    end
    local rawData = utils.copy(data)
    rawData.hash = nil
    local rawHash = utils.bytesToHexString(SolidityPools.sha.digest(userData.apiKey..textutils.serialise(rawData, { allow_repetitions = true, compact = true })))
    local apiMsg = textutils.serialise(data, { allow_repetitions = true })
    local apiMsgCut = {}
    while #apiMsg > 0 do
        table.insert(apiMsgCut, apiMsg:sub(1, 500))
        apiMsg = apiMsg:sub(501)
    end
    if rawHash ~= data.hash then
        print("Hash error: "..rawHash.." vs "..data.hash)
        SolidityPools.logDiscordMessage("X: `" .. pos.x .. "` Y: `" .. pos.y .. "` Z: `" .. pos.z .. "` User: `" .. userData.name:lower() .. "` (`" .. userData.uuid .. "`) API Authentication failed.\n```"..apiMsgCut[1].."```")
        for i=2,#apiMsgCut do
            SolidityPools.logDiscordMessage("```"..apiMsgCut[i].."```")
        end
        return
    else
        SolidityPools.logDiscordMessage("X: `" .. pos.x .. "` Y: `" .. pos.y .. "` Z: `" .. pos.z .. "` User: `" .. userData.name:lower() .. "` (`" .. userData.uuid .. "`) API request:\n```" .. apiMsgCut[1] .. "```")
        for i=2,#apiMsgCut do
            SolidityPools.logDiscordMessage("```"..apiMsgCut[i].."```")
        end
    end
    if userData.isBanned ~= nil then
        local msg = generateResponse("error", data, { message = "You are banned from using the shop.", error = "banned", reason = userData.isBanned }, userData.apiKey)
        modem.transmit(replyChannel, config.apiChannel, msg)
        return
    end
    if userData.isApiBanned ~= nil then
        local msg = generateResponse("error", data, { message = "You are banned from using the API.", error = "banned", reason = userData.isApiBanned }, userData.apiKey)
        modem.transmit(replyChannel, config.apiChannel, msg)
        return
    end
    if data.type == "balance" then
        local msg = generateResponse("balance_ack", data, { balance = userData.balance/1000000 }, userData.apiKey)
        modem.transmit(replyChannel, config.apiChannel, msg)
    elseif data.type == "info" then
        if (data.data.item == null) or (type(data.data.item) ~= "string") then
            local realBalance, allocations, perc = utils.getRealBalance()
            local strg = SolidityPools.storage.getStats()
            local msg = generateResponse("shop_info", data, {
                name = config.shopname,
                description = config.description,
                location = SolidityPools.location,
                address = config.address,
                tradingFees = config.tradingFees,
                balance = allocations.all/1000000,
                storage = {
                    all = strg.all,
                    free = strg.free,
                    used = strg.used,
                    percentage = math.floor(strg.used/strg.all*100*100)/100
                },
                version = SolidityPools.version
            }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
        else
            local possible, item = utils.queryItem(data.data.item)
            if item then
                local realBalance, allocations, perc = utils.getRealBalance()
                local msg = generateResponse("item_info", data, {
                    name = item.name,
                    aliases = item.aliases,
                    query = item.query,
                    allocatedItems = math.min(item.allocated, item.count),
                    allocatedMoney = math.min(item.allocatedMoney, allocations.all)/1000000,
                    count = item.count,
                }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            else
                local bestMatch = nil
                local bestPerc = 0
                for k, v in pairs(possible) do
                    if v > bestPerc then
                        bestPerc = v
                        bestMatch = k
                    end
                end
                if bestPerc > 50 then
                    local msg = generateResponse("error", data, { message = "Item not found. Did you mean: " .. bestMatch .. "?", error = "item_not_found", suggestion = bestMatch }, userData.apiKey)
                    modem.transmit(replyChannel, config.apiChannel, msg)
                else
                    local msg = generateResponse("error", data, { message = "Item not found.", error = "item_not_found" }, userData.apiKey)
                    modem.transmit(replyChannel, config.apiChannel, msg)
                end
            end
        end
    elseif data.type == "price" then
        if (data.data.item == nil) or (data.data.amount == nil) then
            local msg = generateResponse("error", data, { message = "Item or amount not specified.", error = "missing_data", data = { "item", "amount" } }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if type(data.data.item) ~= "string" then
            local msg = generateResponse("error", data, { message = "Invalid item specified.", error = "invalid_data", data = "item" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        local amount = tonumber(data.data.amount)
        if (amount == nan) or (math.floor(amount) ~= amount) or (amount == 0) then
            local msg = generateResponse("error", data, { message = "Invalid amount specified.", error = "invalid_data", data = "amount" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        local possible, item = utils.queryItem(data.data.item)
        if item then
            if amount < 0 then
                local price, pricei = utils.calculatePrice(item, math.abs(amount), true)
                local msg = generateResponse("price_ack", data, {
                    amount = price/1000000,
                    amountPerItem = pricei/1000000
                }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            elseif amount > 0 then
                local price, pricei = utils.calculatePrice(item, amount, false)
                local msg = generateResponse("price_ack", data, {
                    amount = price/1000000,
                    amountPerItem = pricei/1000000
                }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            end
        else
            local bestMatch = nil
            local bestPerc = 0
            for k, v in pairs(possible) do
                if v > bestPerc then
                    bestPerc = v
                    bestMatch = k
                end
            end
            if bestPerc > 50 then
                local msg = generateResponse("error", data, { message = "Item not found. Did you mean: " .. bestMatch .. "?", error = "item_not_found", suggestion = bestMatch }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            else
                local msg = generateResponse("error", data, { message = "Item not found.", error = "item_not_found" }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            end
        end
    elseif data.type == "arb" then
        if (data.data.item == nil) or (data.data.price == nil) then
            local msg = generateResponse("error", data, { message = "Item or price not specified.", error = "missing_data", data = { "item", "price" } }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if type(data.data.item) ~= "string" then
            local msg = generateResponse("error", data, { message = "Invalid item specified.", error = "invalid_data", data = "item" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        local price = tonumber(data.data.price)
        if (price == nan) or (price <= 0) then
            local msg = generateResponse("error", data, { message = "Invalid price specified.", error = "invalid_data", data = "price" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        price = math.floor(price * 1000000)
        local possible, item = utils.queryItem(data.data.item)
        if item then
            local most = 0
            local ic = 0
            for i = 1, 1000 do
                local oprice, pricei = utils.calculatePrice(item, i, true)
                if (oprice == inf) or (oprice == nan) or (oprice == 0) then
                    break
                end
                if oprice < price*i then
                    break
                end
                if oprice > most then
                    most = oprice
                    ic = i
                end
            end
            if most == 0 then
                local msg = generateResponse("arb_ack", data, {
                    canProfit = false
                }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            else
                local msg = generateResponse("arb_ack", data, {
                    canProfit = true,
                    count = ic,
                    buyPrice = price*ic/1000000,
                    sellPrice = most/1000000,
                    profit = (most - price*ic)/1000000
                }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            end
        else
            local bestMatch = nil
            local bestPerc = 0
            for k, v in pairs(possible) do
                if v > bestPerc then
                    bestPerc = v
                    bestMatch = k
                end
            end
            if bestPerc > 50 then
                local msg = generateResponse("error", data, { message = "Item not found. Did you mean: " .. bestMatch .. "?", error = "item_not_found", suggestion = bestMatch }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            else
                local msg = generateResponse("error", data, { message = "Item not found.", error = "item_not_found" }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            end
        end
    elseif data.type == "money" then
        local realBalance, allocations, perc = utils.getRealBalance()
        local msg = generateResponse("money_info", data, {
            balance = allocations.all/1000000,
            allocations = {
                all = allocations.all/1000000,
                fees = allocations.fees/1000000,
                userBalances = allocations.userBalances/1000000,
                itemAllocations = allocations.itemAllocations/1000000,
                unallocated = allocations.unallocated/1000000
            },
            percentages = {
                all = 100,
                fees = perc.fees,
                userBalances = perc.userBalances,
                itemAllocations = perc.itemAllocations,
                unallocated = perc.unallocated
            }
        }, userData.apiKey)
        modem.transmit(replyChannel, config.apiChannel, msg)
    elseif data.type == "withdraw" then
        if (data.data.amount == nil) or (data.data.address == nil) then
            local msg = generateResponse("error", data, { message = "Amount or address not specified.", error = "missing_data", data = { "amount", "address" } }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if type(data.data.address) ~= "string" then
            local msg = generateResponse("error", data, { message = "Invalid address specified.", error = "invalid_data", data = "address" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        local amount = tonumber(data.data.amount)
        if amount == nan then
            local msg = generateResponse("error", data, { message = "Invalid amount specified.", error = "invalid_data", data = "amount" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        amount = math.floor(amount * 100)
        if amount < 1 then
            local msg = generateResponse("error", data, { message = "Invalid amount specified.", error = "invalid_data", data = "amount" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if not SolidityPools.kromerConnected then
            local msg = generateResponse("error", data, { message = "Kromer API is not connected. Try again later.", error = "kromer_disconnected" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if SolidityPools.lockInv then
            local msg = generateResponse("error", data, { message = "Please wait a few seconds.", error = "please_wait" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if (amount*10000) > userData.balance then
            local msg = generateResponse("error", data, { message = "Insufficient balance.", error = "insufficient_balance" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        local realBalance, allocations, perc = utils.getRealBalance()
        if allocations.all < amount * 10000 then
            local msg = generateResponse("error", data, { message = "The shop doesn't have enough money to withdraw that amount.", error = "shop_insufficient_balance" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        local rollback = userData.balance
        userData.balance = userData.balance - (amount * 10000)
        if SolidityPools.session.is and (SolidityPools.session.uuid == userData.uuid) then
            SolidityPools.session.balance = userData.balance
            os.queueEvent("sp_render")
        end
        utils.saveUser(userData.uuid, userData)
        local ok, err = pcall(SolidityPools.kapi.makeTransaction, config.privateKey, data.data.address, amount / 100, "message=Withdrawed amount")
        if not ok then
            local msg = generateResponse("error", data, { message = "Failed to withdraw money: " .. err, error = "transaction_failed" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            userData.balance = rollback
            if SolidityPools.session.is and (SolidityPools.session.uuid == userData.uuid) then
                SolidityPools.session.balance = userData.balance
                os.queueEvent("sp_render")
            end
            utils.saveUser(data.user.uuid, userData)
            return
        end
        local msg = generateResponse("withdraw_ack", data, {
            balance = userData.balance/1000000,
        }, userData.apiKey)
        modem.transmit(replyChannel, config.apiChannel, msg)
        SolidityPools.logDiscordMessage("User: `" .. userData.name:lower() .. "` (`" .. userData.uuid .. "`) withdrew " .. (amount / 100) .. "kro to `" .. data.data.address .."`\nBalance: `" .. (rollback/1000000) .. "kro -> " .. (userData.balance/1000000) .. "kro`")
    elseif data.type == "buy" then
        if (data.data.item == nil) or (data.data.amount == nil) then
            local msg = generateResponse("error", data, { message = "Item or amount not specified.", error = "missing_data", data = { "item", "amount" } }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if type(data.data.item) ~= "string" then
            local msg = generateResponse("error", data, { message = "Invalid item specified.", error = "invalid_data", data = "item" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        local amount = tonumber(data.data.amount)
        if (amount == nan) or (math.floor(amount) ~= amount) or (amount <= 0) then
            local msg = generateResponse("error", data, { message = "Invalid amount specified.", error = "invalid_data", data = "amount" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if userData.apiChest == nil then
            local msg = generateResponse("error", data, { message = "No API chest set. Please follow the documentation.", error = "no_api_chest" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if not userData.agreed then
            local msg = generateResponse("error", data, { message = "You must agree to the terms and conditions before making a purchase.", error = "no_agreement" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if #SolidityPools.orderQueue >= 100 then
            local msg = generateResponse("error", data, { message = "Too many orders in queue, please wait a little.", error = "too_many_orders" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        local possible, item = utils.queryItem(data.data.item)
        if item then
            local orderId = math.floor(os.epoch("utc")/1000)..utils.bytesToHexString(SolidityPools.sha.digest("buy"..userData.uuid..data.data.item..amount..data.time)):sub(1,10)
            table.insert(SolidityPools.orderQueue, {
                type = "buy",
                user = userData.uuid,
                item = data.data.item,
                amount = amount,
                req = data,
                rc = replyChannel,
                id = orderId
            })
            local msg = generateResponse("order_queued", data, {
                orderId = orderId,
            }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            SolidityPools.logDiscordMessage("User: `" .. userData.name:lower() .. "` (`" .. userData.uuid .. "`) queued a buy order: `" .. amount .. "x " .. item.name .. "` Order ID: `" .. orderId .. "`")
        else
            local bestMatch = nil
            local bestPerc = 0
            for k, v in pairs(possible) do
                if v > bestPerc then
                    bestPerc = v
                    bestMatch = k
                end
            end
            if bestPerc > 50 then
                local msg = generateResponse("error", data, { message = "Item not found. Did you mean: " .. bestMatch .. "?", error = "item_not_found", suggestion = bestMatch }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            else
                local msg = generateResponse("error", data, { message = "Item not found.", error = "item_not_found" }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            end
        end
    elseif data.type == "sell" then
        if (data.data.item == nil) or (data.data.amount == nil) then
            local msg = generateResponse("error", data, { message = "Item or amount not specified.", error = "missing_data", data = { "item", "amount" } }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if type(data.data.item) ~= "string" then
            local msg = generateResponse("error", data, { message = "Invalid item specified.", error = "invalid_data", data = "item" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        local amount = tonumber(data.data.amount)
        if (amount == nan) or (math.floor(amount) ~= amount) or (amount <= 0) then
            local msg = generateResponse("error", data, { message = "Invalid amount specified.", error = "invalid_data", data = "amount" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if userData.apiChest == nil then
            local msg = generateResponse("error", data, { message = "No API chest set. Please follow the documentation.", error = "no_api_chest" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if not userData.agreed then
            local msg = generateResponse("error", data, { message = "You must agree to the terms and conditions before selling an item.", error = "no_agreement" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        if #SolidityPools.orderQueue >= 100 then
            local msg = generateResponse("error", data, { message = "Too many orders in queue, please wait a little.", error = "too_many_orders" }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            return
        end
        local possible, item = utils.queryItem(data.data.item)
        if item then
            local orderId = math.floor(os.epoch("utc")/1000)..utils.bytesToHexString(SolidityPools.sha.digest("sell"..userData.uuid..data.data.item..amount..data.time)):sub(1,10)
            table.insert(SolidityPools.orderQueue, {
                type = "sell",
                user = userData.uuid,
                item = data.data.item,
                amount = amount,
                req = data,
                rc = replyChannel,
                id = orderId
            })
            local msg = generateResponse("order_queued", data, {
                orderId = orderId,
            }, userData.apiKey)
            modem.transmit(replyChannel, config.apiChannel, msg)
            SolidityPools.logDiscordMessage("User: `" .. userData.name:lower() .. "` (`" .. userData.uuid .. "`) queued a sell order: `" .. amount .. "x " .. item.name .. "` Order ID: `" .. orderId .. "`")
        else
            local bestMatch = nil
            local bestPerc = 0
            for k, v in pairs(possible) do
                if v > bestPerc then
                    bestPerc = v
                    bestMatch = k
                end
            end
            if bestPerc > 50 then
                local msg = generateResponse("error", data, { message = "Item not found. Did you mean: " .. bestMatch .. "?", error = "item_not_found", suggestion = bestMatch }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            else
                local msg = generateResponse("error", data, { message = "Item not found.", error = "item_not_found" }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            end
        end
    else
        local msg = generateResponse("error", data, { message = "Unknown type.", error = "unknown_type" }, userData.apiKey)
        modem.transmit(replyChannel, config.apiChannel, msg)
    end
end

local function apiServer()
    while not SolidityPools.itemsLoaded do
        os.sleep(0)
    end
    local config = SolidityPools.config
    local pers = peripheral.getNames()
    local modems = 0
    for k,v in ipairs(pers) do
        local t = peripheral.getType(v)
        if t == "modem" then
            local wrp = peripheral.wrap(v)
            if wrp.isWireless() and (config.modems[v] ~= nil) then
                wrp.open(config.apiChannel)
                modems = modems + 1
            end
        end
    end
    if (modems ~= 4) and config.apiEnabled then
        error("The amount of wireless modems must be 4")
    end
    if peripheral.wrap(config.apiChest) == nil and config.apiEnabled then
        error("The API chest is not connected")
    end
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        for k,v in pairs(messages) do
            if math.floor(os.epoch("utc") / 1000) - v.time > 10 then
                messages[k] = nil
            end
        end
        if config.apiEnabled and (channel == config.apiChannel) and (type(message) == "string") then
            local ok,data = pcall(textutils.unserialize, message)
            if ok then
                if (data.computer ~= nil) and (data.computer ~= os.getComputerID()) and (data.time ~= nil) and (data.user ~= nil) and (data.hash ~= nil) and (data.protocol == "SPAPIv1") then
                    local msgId = data.computer .. "#" .. data.time
                    local realSide = config.modems[side]
                    if realSide ~= nil then
                        local hash = utils.bytesToHexString(SolidityPools.sha.digest(message))
                        if messages[msgId] then
                            if ((messages[msgId].collected.center == nil) or (messages[msgId].collected.x == nil) or (messages[msgId].collected.y == nil) or (messages[msgId].collected.z == nil)) and (messages[msgId].hash == hash) then
                                messages[msgId].collected[realSide] = distance
                                if (messages[msgId].collected.center ~= nil) and (messages[msgId].collected.x ~= nil) and (messages[msgId].collected.y ~= nil) and (messages[msgId].collected.z ~= nil) then
                                    local pos = utils.positionMessage(messages[msgId])
                                    onApiMessage(msgId, pos, data, replyChannel)
                                end
                            else
                                print("Message mismatch")
                            end
                        else
                            messages[msgId] = {
                                id = msgId,
                                data = data,
                                collected = {
                                    [realSide] = distance
                                },
                                time = data.time,
                                hash = hash
                            }
                        end
                    end
                else
                    if data.computer ~= os.getComputerID() then
                        print("Invalid message structure")
                    end
                end
            else
                print("Failed to parse message: " .. data)
            end
        end
    end
end

return apiServer