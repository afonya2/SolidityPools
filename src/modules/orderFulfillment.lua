local utils = require("utils")

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

local function doFulfillment(order, userData)
    local lmodem = SolidityPools.wiredModem.wrap
    local modem = SolidityPools.modem.wrap
    local config = SolidityPools.config

    local possible, item, cat, itemk = utils.queryItem(order.item)
    if item == nil then
        local msg = generateResponse("order_failed", order.req, { message = "The requested item could not be found.", error = "order_item_not_found", orderId = order.id }, userData.apiKey)
        modem.transmit(order.rc, config.apiChannel, msg)
        SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `Item not found`")
        return
    end
    if order.type == "buy" then
        if math.min(item.count, item.allocated) < order.amount then
            local msg = generateResponse("order_failed", order.req, { message = "The requested amount is not available.", error = "order_insufficient_stock", orderId = order.id }, userData.apiKey)
            modem.transmit(order.rc, config.apiChannel, msg)
            SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `Insufficient stock`")
            return
        end
        local price, pricei = utils.calculatePrice(item, order.amount, false)
        if userData.balance < price then
            local msg = generateResponse("order_failed", order.req, { message = "You do not have enough balance.", error = "order_insufficient_funds", orderId = order.id }, userData.apiKey)
            modem.transmit(order.rc, config.apiChannel, msg)
            SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `Insufficient funds`")
            return
        end
    end
    SolidityPools.lockInv = true

    lmodem.transmit(2646, 2646, textutils.serialise({
        mode = "place",
        chest = config.apiChest,
        pos = userData.apiChest
    }))
    local mmsg = nil
    local function a()
        while true do
            local event,side,channel,replyChannel,message = os.pullEvent("modem_message")
            if (side == SolidityPools.wiredModem.id) and (channel == 2646) and (type(message) == "string") then
                mmsg = message
                os.sleep(1)
                break
            end
        end
    end
    local function b()
        os.sleep(10)
    end
    parallel.waitForAny(a, b)
    if mmsg == nil then
        local msg = generateResponse("order_failed", order.req, { message = "An error occurred while fulfilling your order.", error = "order_internal_timeout", orderId = order.id }, userData.apiKey)
        modem.transmit(order.rc, config.apiChannel, msg)
        SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `timeout`")
        SolidityPools.lockInv = false
        return
    end
    local ok, data = pcall(textutils.unserialize, mmsg)
    if ok then
        if data.mode == "ok" then
            local echest = {id = nil, wrap = nil}
            for k,v in ipairs(peripheral.getNames()) do
                if v:match("ender_storage") ~= nil then
                    local wrp = peripheral.wrap(v)
                    echest.id = v
                    echest.wrap = wrp
                    break
                end
            end
            if echest.id == nil then
                local msg = generateResponse("order_failed", order.req, { message = "An error occurred while fulfilling your order.", error = "order_internal_error", orderId = order.id }, userData.apiKey)
                modem.transmit(order.rc, config.apiChannel, msg)
                SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `No ender chest found`")
                SolidityPools.lockInv = false
                return
            end
            local ai = item.allocated
            local am = item.allocatedMoney
            local pb = userData.balance
            if order.type == "buy" then
                local price, pricei, tfees = utils.calculatePrice(item, order.amount, false)
                userData.balance = userData.balance - price
                SolidityPools.items[cat][itemk].allocated = SolidityPools.items[cat][itemk].allocated - order.amount
                SolidityPools.items[cat][itemk].allocatedMoney = SolidityPools.items[cat][itemk].allocatedMoney + (price - tfees)
                SolidityPools.items[cat][itemk].count = SolidityPools.items[cat][itemk].count - order.amount
                utils.saveCategory(cat, SolidityPools.items[cat])
                if SolidityPools.session.is and (SolidityPools.session.uuid == userData.uuid) then
                    SolidityPools.session.balance = userData.balance
                end
                utils.saveUser(userData.uuid, userData)
                local shopDta = utils.getShopData()
                shopDta.transactionFees = shopDta.transactionFees + tfees
                utils.saveShopData(shopDta)
                os.queueEvent("sp_render")
                SolidityPools.storage.exportItems(echest.id, item.query, order.amount)
                local msg = generateResponse("order_fulfilled", order.req, { orderId = order.id, item = item.name, amount = order.amount, price = (price/1000000), pricePerItem = (pricei/1000000) }, userData.apiKey)
                modem.transmit(order.rc, config.apiChannel, msg)
                SolidityPools.logDiscordMessage("Order fulfilled: `" .. order.id .. "`, bought `x" .. order.amount .. " " .. item.name .. "` for " .. (price/1000000) .. "kro" .. " (`" .. pricei/1000000 .. "kro/i`)\nAllocated items: `" .. ai .. " -> " .. item.allocated .. "`\nAllocated money: `" .. (am/1000000) .. "kro -> " .. (item.allocatedMoney/1000000) .. "kro`\nUser balance: `" .. (pb/1000000) .. "kro -> " .. (userData.balance/1000000) .. "kro`")
            elseif order.type == "sell" then
                local ecList = echest.wrap.list()
                local limit = order.amount
                for k,v in pairs(ecList) do
                    if SolidityPools.BIL.isItemMatch(v, item.query) then
                        local moved = echest.wrap.pushItems(config.holderChest, k, math.max(limit, 0))
                        limit = limit - moved
                        if limit < 1 then
                            break
                        end
                    end
                end
                local holdInv = SolidityPools.BIL.createStorage({config.holderChest})
                local ic = holdInv.getItemCount(item.query)
                local actuallySold = math.min(ic, order.amount)
                if actuallySold < 1 then
                    local msg = generateResponse("order_fulfilled", order.req, { orderId = order.id, item = item.name, amount = actuallySold, price = 0, pricePerItem = 0 }, userData.apiKey)
                    modem.transmit(order.rc, config.apiChannel, msg)
                    SolidityPools.logDiscordMessage("Order fulfilled: `" .. order.id .. "`, no items in ender chest to sell.")
                    SolidityPools.lockInv = false
                    lmodem.transmit(2646, 2646, textutils.serialise({
                        mode = "break",
                        chest = config.apiChest,
                        pos = userData.apiChest
                    }))
                    return
                end
                local highestItemAccepted = item.itemLimit - math.min(item.count, item.allocated)
                local soldCount = math.min(actuallySold, highestItemAccepted)
                if soldCount < 1 then
                    local msg = generateResponse("order_failed", order.req, { message = "Item limit reached. The shop is not accepting any more of this item.", error = "order_item_limit_reached", orderId = order.id }, userData.apiKey)
                    modem.transmit(order.rc, config.apiChannel, msg)
                    SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `Item limit reached`")
                    local holdWrp = peripheral.wrap(config.holderChest)
                    for k,v in pairs(holdWrp.list()) do
                        holdWrp.pushItems(echest.id, k)
                    end
                    SolidityPools.lockInv = false
                    lmodem.transmit(2646, 2646, textutils.serialise({
                        mode = "break",
                        chest = config.apiChest,
                        pos = userData.apiChest
                    }))
                    return
                end
                local remainder = actuallySold - soldCount
                local ok2, err = pcall(SolidityPools.storage.importItems, config.holderChest, item.query, soldCount)
                SolidityPools.defragNeeded = true
                if not ok2 then
                    local msg = generateResponse("order_failed", order.req, { message = "An error occurred while importing items: " .. err, error = "order_item_import_failed", orderId = order.id }, userData.apiKey)
                    modem.transmit(order.rc, config.apiChannel, msg)
                    SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `"..err.."`")
                    local holdWrp = peripheral.wrap(config.holderChest)
                    for k,v in pairs(holdWrp.list()) do
                        holdWrp.pushItems(echest.id, k)
                    end
                    SolidityPools.lockInv = false
                    lmodem.transmit(2646, 2646, textutils.serialise({
                        mode = "break",
                        chest = config.apiChest,
                        pos = userData.apiChest
                    }))
                    return
                end
                local price, pricei, tfees = utils.calculatePrice(item, soldCount, true)
                userData.balance = userData.balance + price
                SolidityPools.items[cat][itemk].allocated = SolidityPools.items[cat][itemk].allocated + soldCount
                SolidityPools.items[cat][itemk].allocatedMoney = SolidityPools.items[cat][itemk].allocatedMoney - (price + tfees)
                SolidityPools.items[cat][itemk].count = SolidityPools.items[cat][itemk].count + soldCount
                utils.saveCategory(cat, SolidityPools.items[cat])
                if SolidityPools.session.is and (SolidityPools.session.uuid == userData.uuid) then
                    SolidityPools.session.balance = userData.balance
                end
                utils.saveUser(userData.uuid, userData)
                local shopDta = utils.getShopData()
                shopDta.transactionFees = shopDta.transactionFees + tfees
                utils.saveShopData(shopDta)
                os.queueEvent("sp_render")
                if remainder > 0 then
                    local holdWrp = peripheral.wrap(config.holderChest)
                    for k,v in pairs(holdWrp.list()) do
                        holdWrp.pushItems(echest.id, v.slot)
                    end
                end
                local msg = generateResponse("order_fulfilled", order.req, { orderId = order.id, item = item.name, amount = soldCount, price = (price/1000000), pricePerItem = (pricei/1000000) }, userData.apiKey)
                modem.transmit(order.rc, config.apiChannel, msg)
                SolidityPools.logDiscordMessage("Order fulfilled: `" .. order.id .. "`, sold `x" .. soldCount .. " " .. item.name .. "` for " .. (price/1000000) .. "kro" .. " (`" .. pricei/1000000 .. "kro/i`)\nAllocated items: `" .. ai .. " -> " .. item.allocated .. "`\nAllocated money: `" .. (am/1000000) .. "kro -> " .. (item.allocatedMoney/1000000) .. "kro`\nUser balance: `" .. (pb/1000000) .. "kro -> " .. (userData.balance/1000000) .. "kro`")
            else
                local msg = generateResponse("order_failed", order.req, { message = "An error occurred while fulfilling your order.", error = "order_internal_error", orderId = order.id }, userData.apiKey)
                modem.transmit(order.rc, config.apiChannel, msg)
                SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `Unknown order type`")
            end
            SolidityPools.lockInv = false
            lmodem.transmit(2646, 2646, textutils.serialise({
                mode = "break",
                chest = config.apiChest,
                pos = userData.apiChest
            }))
        elseif data.mode == "fail" then
            local msg = generateResponse("order_failed", order.req, { message = "An error occurred while fulfilling your order.", error = "order_internal_error", orderId = order.id }, userData.apiKey)
            modem.transmit(order.rc, config.apiChannel, msg)
            SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `" .. data.message .. "`")
            SolidityPools.lockInv = false
        end
    else
        local msg = generateResponse("order_failed", order.req, { message = "An error occurred while fulfilling your order.", error = "order_internal_error", orderId = order.id }, userData.apiKey)
        modem.transmit(order.rc, config.apiChannel, msg)
        SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `" .. data .. "`")
        SolidityPools.lockInv = false
    end
end

local function orderFulfill()
    while not SolidityPools.itemsLoaded do
        os.sleep(0)
    end
    local lmodem = SolidityPools.wiredModem.wrap
    lmodem.open(2646)
    while true do
        if (not SolidityPools.session.is) and (SolidityPools.itemsLoaded) and (not SolidityPools.lockInv) then
            if #SolidityPools.orderQueue > 0 then
                local order = table.remove(SolidityPools.orderQueue, 1)
                local userData = utils.loadUser(order.user)
                if (userData.isApiBanned == nil) and (userData.isBanned == nil) and (userData.apiChest ~= nil) then
                    doFulfillment(order, userData)
                end
            end
        end
        os.sleep(20)
    end
end

return orderFulfill