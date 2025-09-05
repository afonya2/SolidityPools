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
    msg.hash = utils.bytesToHexString(SolidityPools.sha.digest(sign..textutils.serialise(msg, { allow_repetitions = true, compact = true })))
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
    if rawHash ~= data.hash then
        print("Hash error: "..rawHash.." vs "..data.hash)
        SolidityPools.logDiscordMessage("X: `" .. pos.x .. "` Y: `" .. pos.y .. "` Z: `" .. pos.z .. "` User: `" .. userData.name:lower() .. "` (`" .. userData.uuid .. "`) API Authentication failed.")
        return
    else
        SolidityPools.logDiscordMessage("X: `" .. pos.x .. "` Y: `" .. pos.y .. "` Z: `" .. pos.z .. "` User: `" .. userData.name:lower() .. "` (`" .. userData.uuid .. "`) API request: `" .. data.type .. "`")
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
        if data.data.item == null then
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
                local msg = generateResponse("item_info", data, {
                    amount = price/1000000,
                    amountPerItem = pricei/1000000
                }, userData.apiKey)
                modem.transmit(replyChannel, config.apiChannel, msg)
            elseif amount > 0 then
                local price, pricei = utils.calculatePrice(item, amount, false)
                local msg = generateResponse("item_info", data, {
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
    else
        local msg = generateResponse("error", data, { message = "Unknown type.", error = "unknown_type" }, userData.apiKey)
        modem.transmit(replyChannel, config.apiChannel, msg)
    end
end

local function apiServer()
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
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        for k,v in pairs(messages) do
            if math.floor(os.epoch("utc") / 1000) - v.time > 10 then
                messages[k] = nil
            end
        end
        if config.apiEnabled and (channel == config.apiChannel) then
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