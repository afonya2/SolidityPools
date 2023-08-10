local config = nil
local items = nil
local BIL = nil
local loggedIn = nil
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

local function isPlayerClose(name)
    local man = peripheral.find("manipulator")
    for k,v in ipairs(man.sense()) do
        if (v.key == "minecraft:player") and (v.name:lower() == name:lower()) then
            return true
        end
    end
    return false
end

local function getTargetStorage()
    local storages = BIL.getStorages()
    local highst = 0
    local highsti = 0
    for k,v in ipairs(storages) do
        local stinfo = BIL.getSize({v})
        if stinfo.free > highst then
            highst = stinfo.free
            highsti = k
        end
    end
    if highsti ~= 0 then
        return storages[highsti]
    end
end

local function onItemPickup()
    for k,v in pairs(items) do
        for kk,vv in ipairs(v) do
            if BIL.isItemMatch("turtle", 1, turtle.getItemDetail(1), vv.query) then
                local targetStorage = getTargetStorage()
                if targetStorage ~= nil then
                    local tsw = peripheral.wrap(targetStorage)
                    local mod = peripheral.find("modem")
                    local worthMoney = computeDP(vv, turtle.getItemCount(1), true)
                    local coant = turtle.getItemCount(1)
                    local pdat = loadCache("/users/"..loggedIn.uuid..".cache")
                    pdat.balance = pdat.balance + worthMoney
                    table.insert(pdat.transactions, {
                        from = "system",
                        to = "balance",
                        value = worthMoney,
                        ["type"] = "sell"
                    })
                    saveCache("/users/"..loggedIn.uuid..".cache", pdat)
                    loggedIn.loadUser()
                    SolidityPools.itemChangeInfo.is = true
                    SolidityPools.itemChangeInfo.category = k
                    SolidityPools.itemChangeInfo.pos = kk
                    SolidityPools.itemChangeInfo.mode = "sell"
                    SolidityPools.itemChangeInfo.time = os.clock()
                    tsw.pullItems(mod.getNameLocal(), 1)
                    os.queueEvent("sp_rerender")
                    chatbox.tell(loggedIn.uuid, "&2Success! &aYou sold &7x"..coant.." "..vv.name.." &afor &e"..(math.floor(worthMoney*1000)/1000).."kst &7("..(math.floor(worthMoney/coant*1000)/1000).."kst/i)", config.shopname, nil, "format")
                    if config.webhook then
                        local emb = dw.createEmbed()
                            :setAuthor("Solidity Pools")
                            :setTitle("Item sell")
                            :setColor(3302600)
                            :addField("User: ", loggedIn.username.." (`"..loggedIn.uuid.."`)",true)
                            :addField("New balance: ", tostring(math.floor(pdat.balance*1000)/1000),true)
                            :addField("-","-")
                            :addField("Item name: ", vv.name,true)
                            :addField("Count: ", coant,true)
                            :addField("Worth: ", tostring(math.floor(worthMoney*1000)/1000),true)
                            :setTimestamp()
                            :setFooter("SolidityPools v"..SolidityPools.version)
                        dw.sendMessage(config.webhook_url, config.shopname, nil, "", {emb.sendable()})
                    end
                else
                    turtle.drop()
                    chatbox.tell(loggedIn.uuid, "&cOur storage is full, please try again later", config.shopname, nil, "format")
                end
                return
            end
        end
    end
    turtle.drop()
end

function sessionHandler()
    config = SolidityPools.config
    items = SolidityPools.items
    BIL = SolidityPools.BIL
    loggedIn = SolidityPools.loggedIn
    dw = SolidityPools.dw
    local function itemPup()
        while true do
            if ((config.mode == "both") or (config.mode == "sell")) and loggedIn.is then
                local succ = turtle.suckUp()
                if succ then
                    onItemPickup()
                end
            end
            os.sleep(0)
        end
    end
    local function sessionVerifier()
        while true do
            if loggedIn.is then
                if not isPlayerClose(loggedIn.username) then
                    loggedIn.saveUser()
                    chatbox.tell(loggedIn.username, "&aYour remaining &e"..(math.floor(loggedIn.balance*1000)/1000).."kst &awill be stored for your next purchase", config.shopname, nil, "format")
                    loggedIn.is = false
                    loggedIn.username = ""
                    loggedIn.uuid = ""
                    loggedIn.loadUser()
                    os.queueEvent("sp_rerender")
                end
            end
            os.sleep(0)
        end 
    end
    parallel.waitForAny(itemPup, sessionVerifier)
end

return sessionHandler