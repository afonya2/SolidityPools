local config = nil
local items = nil
local BIL = nil
local loggedIn = nil
local kapi = nil
local dw = nil

local function loadCache(filename)
    local fa = fs.open(filename, "r")
    local fi = fa.readAll()
    fi = fi:gsub("SYSTEM CACHE, DO NOT EDIT!","")
    fa.close()
    return textutils.unserialise(fi)
end
local function saveCache(filename, data)
    local fa = fs.open(filename, "w")
    fa.write("SYSTEM CACHE, DO NOT EDIT!"..textutils.serialise(data))
    fa.close()
end

local function computeDP(item, count, sell)
    if sell then
        local mprice = item.normalPrice
        mprice = mprice - (mprice * (config.tradingFees/100))
        if config.dynamicPricing or item.forcePrice then
            if item.count == 0 then
                return mprice * count
            else
                return (item.normalStock/(item.count+count-1))*mprice*count
            end
        else
            return mprice * count
        end
    else
        local mprice = item.normalPrice
        mprice = mprice + (mprice * (config.tradingFees/100))
        if config.dynamicPricing or item.forcePrice then
            if item.count == 0 then
                return mprice * count
            elseif item.count-count < 0 then
                return math.huge
            else
                return (item.normalStock/(item.count-count+1))*mprice*count
            end
        else
            return mprice * count
        end
    end
end

local function initSocket()
    local socket = kapi.websocket()
    socket.send(textutils.serialiseJSON({
        type = "subscribe",
        id = 1,
        event = "transactions"
    }))
    SolidityPools.ws = socket
    return function()
        local ok,data = pcall(socket.receive)

        if not ok then
            print("Socket error: "..data)
            socket.close()
            return initSocket()()
        end
        return data
    end
end

local function mindTrans(trans)
    return (trans.to == config.address) and (trans.meta.donate ~= "true")
end

local function returnKrist(trans,amount,message)
    if trans.meta["return"] then
        kapi.makeTransaction(config.privateKey, trans.from, amount, trans.meta["return"]..(message ~= nil and ";message="..message or ""))
    else
        kapi.makeTransaction(config.privateKey, trans.from, amount, (message ~= nil and ";message="..message or ""))
    end
end

local function isUserOnline(uuid)
    for k,v in ipairs(chatbox.getPlayers()) do
        if v.uuid == uuid then
            return true
        end
    end
    return false
end

local function onTrans(json)
    if json.type == "event" and json.event == "transaction" then
        local trans = json.transaction
        trans.meta = kapi.parseMeta(trans.metadata)
        if mindTrans(trans) then
            if fs.exists("/users/"..trans.meta.useruuid..".cache") then
                local pdat = loadCache("/users/"..trans.meta.useruuid..".cache")
                pdat.balance = pdat.balance + trans.value
                table.insert(pdat.transactions, {
                    from = trans.from,
                    to = "balance",
                    value = trans.value,
                    ["type"] = "deposit"
                })
                saveCache("/users/"..trans.meta.useruuid..".cache", pdat)
                if loggedIn.uuid == trans.meta.useruuid then
                    loggedIn.loadUser()
                    os.queueEvent("sp_rerender")
                end
                if isUserOnline(trans.meta.useruuid) then
                    chatbox.tell(trans.meta.useruuid,"&e"..trans.value.."kst &awas deposited into your account",config.shopname,nil,"format")
                end
                if config.webhook then
                    local emb = dw.createEmbed()
                        :setAuthor("Solidity Pools")
                        :setTitle("Deposit")
                        :setColor(3328100)
                        :addField("From: ", trans.from,true)
                        :addField("Value: ", tostring(trans.value),true)
                        :addField("-","-")
                        :addField("Metadata: ", "`"..trans.metadata.."`",true)
                        :addField("User: ", trans.meta.username.." ("..trans.meta.useruuid..")",true)
                        :addField("New balance: ", tostring(math.floor(pdat.balance*1000)/1000),true)
                        :setTimestamp()
                        :setFooter("SolidityPools v"..SolidityPools.version)
                    dw.sendMessage(config.webhook_url, config.shopname, nil, "", {emb.sendable()})
                end
            else
                returnKrist(trans,trans.value,"User doesn't exists")
            end
        end
    end
end

function kristManager()
    config = SolidityPools.config
    items = SolidityPools.items
    BIL = SolidityPools.BIL
    loggedIn = SolidityPools.loggedIn
    kapi = SolidityPools.kapi
    dw = SolidityPools.dw
    local sock = initSocket()
    SolidityPools.kristConnected = true
    while true do
        local data = sock()
        if not data then
            print("Socket error")
        else
            local ok,json = pcall(textutils.unserialiseJSON, data)
            if not ok then
                print("JSON error: "..json)
            else
                onTrans(json)
            end
        end
    end
end

return kristManager