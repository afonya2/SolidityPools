local config = nil
local items = nil
local BIL = nil
local loggedIn = nil
local kapi = nil
local dw = nil

local function loadCache(filename)
    local fa,fserr = fs.open(filename, "r")
    if fa == nil then
        print("FS Error: "..fserr)
        return loadCache(filename)
    end
    local fi = fa.readAll()
    fi = fi:gsub("SYSTEM CACHE, DO NOT EDIT!","")
    fa.close()
    return textutils.unserialise(fi)
end
local function saveCache(filename, data)
    local fa,fserr = fs.open(filename, "w")
    if fa == nil then
        print("FS Error: "..fserr)
        return saveCache(filename, data)
    end
    fa.write("SYSTEM CACHE, DO NOT EDIT!"..textutils.serialise(data))
    fa.close()
end

local function computeDP(item, count, sell)
    if sell then
        local mprice = item.normalPrice
        mprice = mprice - (mprice * (config.tradingFees/100))
        if config.dynamicPricing and (not item.forcePrice) then
            if item.count == 0 then
                return mprice * count
            else
                return (item.normalStock/(item.count+count))*mprice*count
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
    return (trans.to == config.address) and (trans.meta.donate ~= "true") and ((config.kristName == nil) or (trans.sent_name == config.kristName))
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
            if trans.meta.useruuid ~= nil then
                if fs.exists("/users/"..trans.meta.useruuid..".cache") then
                    local pdat = loadCache("/users/"..trans.meta.useruuid..".cache")
                    pdat.balance = pdat.balance + trans.value
                    table.insert(pdat.transactions, 1, {
                        from = (trans.meta["return"] and trans.meta["return"] or trans.from),
                        to = "balance",
                        value = trans.value,
                        ["type"] = "deposit"
                    })
                    while #pdat.transactions > 10 do
                        table.remove(pdat.transactions, #pdat.transactions)
                    end
                    pdat.username = trans.meta.username
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
                            :addField("From: ", "`"..(trans.meta["return"] and trans.meta["return"] or trans.from).."`",true)
                            :addField("Value: ", tostring(trans.value),true)
                            :addField("-","-")
                            :addField("Metadata: ", "`"..trans.metadata.."`",true)
                            :addField("User: ", trans.meta.username.." (`"..trans.meta.useruuid.."`)",true)
                            :addField("New balance: ", tostring(math.floor(pdat.balance*1000)/1000),true)
                            :setTimestamp()
                            :setFooter("SolidityPools v"..SolidityPools.version)
                        dw.sendMessage(config.webhook_url, config.shopname, nil, "", {emb.sendable()})
                    end
                else
                    returnKrist(trans,trans.value,"User doesn't exists")
                end
            else
                returnKrist(trans,trans.value,"You must pay from SC or you must specify useruuid in your meta")
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