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
                local price, pricei = utils.calculatePrice(item, order.amount, false)
                userData.balance = userData.balance - price
                SolidityPools.items[cat][itemk].allocated = SolidityPools.items[cat][itemk].allocated - order.amount
                SolidityPools.items[cat][itemk].allocatedMoney = SolidityPools.items[cat][itemk].allocatedMoney + price
                SolidityPools.items[cat][itemk].count = SolidityPools.items[cat][itemk].count - order.amount
                utils.saveCategory(cat, SolidityPools.items[cat])
                if SolidityPools.session.is and (SolidityPools.session.uuid == userData.uuid) then
                    SolidityPools.session.balance = userData.balance
                end
                utils.saveUser(userData.uuid, userData)
                os.queueEvent("sp_render")
                SolidityPools.storage.exportItems(echest.id, item.query, order.amount)
                local msg = generateResponse("order_fulfilled", order.req, { orderId = order.id, item = item.name, amount = order.amount, price = (price/1000000), pricePerItem = (pricei/1000000) }, userData.apiKey)
                modem.transmit(order.rc, config.apiChannel, msg)
                SolidityPools.logDiscordMessage("Order fulfilled: `" .. order.id .. "`, bought `x" .. order.amount .. " " .. item.name .. "` for " .. (price/1000000) .. "kro" .. " (`" .. pricei/1000000 .. "kro/i`)\nAllocated items: `" .. ai .. " -> " .. item.allocated .. "`\nAllocated money: `" .. (am/1000000) .. "kro -> " .. (item.allocatedMoney/1000000) .. "kro`\nUser balance: `" .. (pb/1000000) .. "kro -> " .. (userData.balance/1000000) .. "kro`")
            elseif order.type == "sell" then
                local ecInv = SolidityPools.BIL.createStorage({echest.id})
                local ic = ecInv.getItemCount(item.query)
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
                SolidityPools.storage.importItems(echest.id, item.query, actuallySold)
                local price, pricei = utils.calculatePrice(item, actuallySold, true)
                userData.balance = userData.balance + price
                SolidityPools.items[cat][itemk].allocated = SolidityPools.items[cat][itemk].allocated + actuallySold
                SolidityPools.items[cat][itemk].allocatedMoney = SolidityPools.items[cat][itemk].allocatedMoney - price
                SolidityPools.items[cat][itemk].count = SolidityPools.items[cat][itemk].count + actuallySold
                utils.saveCategory(cat, SolidityPools.items[cat])
                if SolidityPools.session.is and (SolidityPools.session.uuid == userData.uuid) then
                    SolidityPools.session.balance = userData.balance
                end
                utils.saveUser(userData.uuid, userData)
                os.queueEvent("sp_render")
                local msg = generateResponse("order_fulfilled", order.req, { orderId = order.id, item = item.name, amount = actuallySold, price = (price/1000000), pricePerItem = (pricei/1000000) }, userData.apiKey)
                modem.transmit(order.rc, config.apiChannel, msg)
                SolidityPools.logDiscordMessage("Order fulfilled: `" .. order.id .. "`, sold `x" .. actuallySold .. " " .. item.name .. "` for " .. (price/1000000) .. "kro" .. " (`" .. pricei/1000000 .. "kro/i`)\nAllocated items: `" .. ai .. " -> " .. item.allocated .. "`\nAllocated money: `" .. (am/1000000) .. "kro -> " .. (item.allocatedMoney/1000000) .. "kro`\nUser balance: `" .. (pb/1000000) .. "kro -> " .. (userData.balance/1000000) .. "kro`")
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