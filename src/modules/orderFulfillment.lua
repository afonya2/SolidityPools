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
        return
    end
    local ok, data = pcall(textutils.unserialize, mmsg)
    if ok then
        if data.mode == "ok" then
            SolidityPools.lockInv = true
        elseif data.mode == "fail" then
            local msg = generateResponse("order_failed", order.req, { message = "An error occurred while fulfilling your order.", error = "order_internal_error", orderId = order.id }, userData.apiKey)
            modem.transmit(order.rc, config.apiChannel, msg)
            SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `" .. data.message .. "`")
        end
    else
        local msg = generateResponse("order_failed", order.req, { message = "An error occurred while fulfilling your order.", error = "order_internal_error", orderId = order.id }, userData.apiKey)
        modem.transmit(order.rc, config.apiChannel, msg)
        SolidityPools.logDiscordMessage("Error while fulfilling order: `" .. order.id .. "`, error: `" .. data .. "`")
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