if not fs.exists("sha256.lua") then
    print("No sha256 found, downloading...")
    shell.run("pastebin get 6UV4qfNF sha256.lua")
end

local sha = require("sha256")
local modem = nil
for k,v in ipairs(peripheral.getNames()) do
    if peripheral.getType(v) == "modem" then
        local wrp = peripheral.wrap(v)
        if wrp.isWireless() then
            modem = wrp
            break
        end
    end
end

local function base10ToBase16(n)
    local convo = {[0]="0",[1]="1",[2]="2",[3]="3",[4]="4",[5]="5",[6]="6",[7]="7",[8]="8",[9]="9",[10]="a",[11]="b",[12]="c",[13]="d",[14]="e",[15]="f"}
    local out = ""
    while n > 0 do
        out = convo[n%16] .. out
        n = math.floor(n/16)
    end
    return out
end

local function bytesToHexString(tbl)
    local out = ""
    for i=1,#tbl do
        local temp = base10ToBase16(tbl[i])
        if #temp == 1 then
            temp = "0" .. temp
        end
        out = out .. temp
    end
    return out
end

local function copy(tbl, deep)
    local out = {}
    for k,v in pairs(tbl) do
        if deep and type(v) == "table" then
            out[k] = copy(v, deep)
        else
            out[k] = v
        end
    end
    return out
end

local function safeSerialise(tbl)
    local tType = type(tbl)
    if tType == "table" then
        local keys = {}
        for k in pairs(tbl) do
            table.insert(keys, k)
        end
        table.sort(keys)

        local result = {}
        table.insert(result, "{")
        for i, k in ipairs(keys) do
            local v = tbl[k]
            table.insert(result, "[" .. safeSerialise(k) .. "]=" .. safeSerialise(v))
            table.insert(result, ",")
        end
        table.insert(result, "}")
        return table.concat(result)
    elseif tType == "string" then
        return string.format("%q", tbl)
    elseif tType == "number" or tType == "boolean" or tType == "nil" then
        return tostring(tbl)
    else
        error("unsupported type: " .. tType)
    end
end

local function createCSPacket(uuid, apiKey, type, data)
    local msg = {
        protocol = "SPAPIv1",
        user = uuid,
        type = type,
        data = data,
        time = math.floor(os.epoch("utc") / 1000),
        computer = os.getComputerID()
    }
    local hashed = safeSerialise(copy(msg))
    msg.hash = bytesToHexString(sha.digest(apiKey .. hashed))
    return textutils.serialise(msg, { allow_repetitions = true, compact = true })
end

local function getResponse(apiKey, timeout, ...)
    local typs = {...}
    local msg = nil
    local function a()
        while true do
            local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
            if type(message) == "string" then
                local ok, data = pcall(textutils.unserialise, message)
                if ok then
                    if (data.protocol == "SPAPIv1") and (data.reqComputer == os.getComputerID()) then
                        for k,v in ipairs(typs) do
                            if data.type == v then
                                msg = data
                                return
                            end
                        end
                    end
                end
            end
        end
    end
    local function b()
        if timeout == nil then
            while true do
                os.sleep(0)
            end
        else
            os.sleep(timeout)
        end
    end
    parallel.waitForAny(a, b)
    if msg then
        local rawMsg = copy(msg)
        rawMsg.hash = nil
        local toHash = safeSerialise(rawMsg)
        local verified = bytesToHexString(sha.digest(apiKey .. toHash))
        if verified == msg.hash then
            return msg
        else
            error("A message with an invalid signature was received")
        end
    else
        return nil
    end
end

local function expect(fun, pos, arg, ...)
    local typs = {...}
    for k,v in ipairs(typs) do
        if type(arg) == v then
            return
        end
    end
    error(fun .. ": bad argument #" .. pos .. " (expected " .. table.concat(typs, "/") .. ", got " .. type(arg) .. ")")
end

local function SPApi(channel, uuid, apiKey)
    expect("SPApi", 1, channel, "number")
    expect("SPApi", 2, uuid, "string")
    expect("SPApi", 3, apiKey, "string")
    modem.open(channel)
    local testMsg = createCSPacket(uuid, apiKey, "balance", {})
    modem.transmit(channel, channel, testMsg)
    local testRes = getResponse(apiKey, 10, "balance_ack", "error")
    if (testRes == nil) or (testRes.type == "error") then
        return nil, testRes
    end

    local api = {}

    function api.balance()
        local msg = createCSPacket(uuid, apiKey, "balance", {})
        modem.transmit(channel, channel, msg)
        local res = getResponse(apiKey, 10, "balance_ack", "error")
        if (res == nil) or (res.type == "error") then
            return nil, res
        end
        return res.data.balance, res
    end
    function api.info()
        local msg = createCSPacket(uuid, apiKey, "info", {})
        modem.transmit(channel, channel, msg)
        local res = getResponse(apiKey, 10, "shop_info", "error")
        if (res == nil) or (res.type == "error") then
            return nil, res
        end
        return res.data, res
    end
    function api.itemInfo(item)
        expect("itemInfo", 1, item, "string")
        local msg = createCSPacket(uuid, apiKey, "info", { item = item })
        modem.transmit(channel, channel, msg)
        local res = getResponse(apiKey, 10, "item_info", "error")
        if (res == nil) or (res.type == "error") then
            return nil, res
        end
        return res.data, res
    end
    function api.price(item, amount)
        expect("price", 1, item, "string")
        expect("price", 2, amount, "number")
        if (amount ~= math.floor(amount)) or (amount == 0) then
            error("price: bad argument #2 (expected integer, not 0, got " .. type(amount) .. ")")
        end
        local msg = createCSPacket(uuid, apiKey, "price", { item = item, amount = amount })
        modem.transmit(channel, channel, msg)
        local res = getResponse(apiKey, 10, "price_ack", "error")
        if (res == nil) or (res.type == "error") then
            return nil, res
        end
        return res.data.amount, res.data.amountPerItem, res
    end
    function api.arb(item, price)
        expect("arb", 1, item, "string")
        expect("arb", 2, price, "number")
        if price <= 0 then
            error("arb: bad argument #2 (expected integer, > 0, got " .. type(price) .. ")")
        end
        local msg = createCSPacket(uuid, apiKey, "arb", { item = item, price = price })
        modem.transmit(channel, channel, msg)
        local res = getResponse(apiKey, 10, "arb_ack", "error")
        if (res == nil) or (res.type == "error") then
            return nil, res
        end
        return res.data, res
    end
    function api.money()
        local msg = createCSPacket(uuid, apiKey, "money", {})
        modem.transmit(channel, channel, msg)
        local res = getResponse(apiKey, 10, "money_info", "error")
        if (res == nil) or (res.type == "error") then
            return nil, res
        end
        return res.data, res
    end
    function api.withdraw(address, amount)
        expect("withdraw", 1, address, "string")
        expect("withdraw", 2, amount, "number")
        if (amount ~= math.floor(amount)) or (amount <= 0) then
            error("withdraw: bad argument #2 (expected integer, > 0, got " .. type(amount) .. ")")
        end
        local msg = createCSPacket(uuid, apiKey, "withdraw", { address = address, amount = amount })
        modem.transmit(channel, channel, msg)
        local res = getResponse(apiKey, 10, "withdraw_ack", "error")
        if (res == nil) or (res.type == "error") then
            return nil, res
        end
        return res.data.balance, res
    end
    function api.buy(item, amount, waitForComplete)
        expect("buy", 1, item, "string")
        expect("buy", 2, amount, "number")
        expect("buy", 3, waitForComplete, "boolean", "nil")
        if waitForComplete == nil then
            waitForComplete = false
        end
        if (amount ~= math.floor(amount)) or (amount <= 0) then
            error("buy: bad argument #2 (expected integer, > 0, got " .. type(amount) .. ")")
        end
        local msg = createCSPacket(uuid, apiKey, "buy", { item = item, amount = amount })
        modem.transmit(channel, channel, msg)
        local res = getResponse(apiKey, 10, "order_queued", "error")
        if (res == nil) or (res.type == "error") then
            return nil, res
        end
        if waitForComplete then
            local res2 = getResponse(apiKey, nil, "order_fulfilled", "order_failed")
            if (res2 == nil) or (res2.type == "order_failed") then
                return res.data.orderId, res2
            end
            return res.data.orderId, res2.data.item, res2.data.amount, res2.data.price, res2.data.pricePerItem, res, res2
        else
            return res.data.orderId, res
        end
    end
    function api.sell(item, amount, waitForComplete)
        expect("sell", 1, item, "string")
        expect("sell", 2, amount, "number")
        expect("sell", 3, waitForComplete, "boolean", "nil")
        if waitForComplete == nil then
            waitForComplete = false
        end
        if (amount ~= math.floor(amount)) or (amount <= 0) then
            error("sell: bad argument #2 (expected integer, > 0, got " .. type(amount) .. ")")
        end
        local msg = createCSPacket(uuid, apiKey, "sell", { item = item, amount = amount })
        modem.transmit(channel, channel, msg)
        local res = getResponse(apiKey, 10, "order_queued", "error")
        if (res == nil) or (res.type == "error") then
            return nil, res
        end
        if waitForComplete then
            local res2 = getResponse(apiKey, nil, "order_fulfilled", "order_failed")
            if (res2 == nil) or (res2.type == "order_failed") then
                return res.data.orderId, res2
            end
            return res.data.orderId, res2.data.item, res2.data.amount, res2.data.price, res2.data.pricePerItem, res, res2
        else
            return res.data.orderId, res
        end
    end
    function api.getOrders()
        local msg = createCSPacket(uuid, apiKey, "getOrders", {})
        modem.transmit(channel, channel, msg)
        local res = getResponse(apiKey, 10, "orders_ack", "error")
        if (res == nil) or (res.type == "error") then
            return nil, res
        end
        return res.data.orders, res
    end
    function api.listenForOrder(orderId)
        expect("listenForOrder", 1, orderId, "string")
        while true do
            local res = getResponse(apiKey, nil, "order_fulfilled", "order_failed")
            if res.data.orderId == orderId then
                if (res == nil) or (res.type == "order_failed") then
                    return orderId, res
                end
                return res.data.orderId, res.data.item, res.data.amount, res.data.price, res.data.pricePerItem, res
            end
        end
    end

    return api
end

return SPApi