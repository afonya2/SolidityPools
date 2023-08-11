local config = nil
local items = nil
local BIL = nil
local loggedIn = nil
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

local function isPlayerClose(name)
    local man = peripheral.find("manipulator")
    for k,v in ipairs(man.sense()) do
        if (v.key == "minecraft:player") and (v.name:lower() == name:lower()) then
            return true
        end
    end
    return false
end

local function onAdminCommand(user, args, data)
    if args[2] == "help" then
        local helptxt = [[
`\]]..config.command..[[ admin ban <username> <reason>`
Bans a player from the shop
`\]]..config.command..[[ admin unban <username>`
Unbans a player from the shop
`\]]..config.command..[[ admin kick`
Forcefully ends the current session
        ]]
        chatbox.tell(user, helptxt, config.shopname, nil, "markdown")
    elseif args[2] == "kick" then
        if not loggedIn.is then
            chatbox.tell(user, "&cCurrently no session is running", config.shopname, nil, "format")
            return
        end
        loggedIn.saveUser()
        chatbox.tell(loggedIn.uuid, "&aYour remaining &e"..(math.floor(loggedIn.balance*1000)/1000).."kst &awill be stored for your next purchase", config.shopname, nil, "format")
        if config.webhook then
            local emb = dw.createEmbed()
                :setAuthor("Solidity Pools")
                :setTitle("Session ended")
                :setColor(3302600)
                :addField("User: ", loggedIn.username.." (`"..loggedIn.uuid.."`)",true)
                :addField("Balance: ", tostring(math.floor(loggedIn.balance*1000)/1000),true)
                :addField("-","-")
                :addField("Item's sold: ", tostring(math.floor(loggedIn.itmsSold*1000)/1000),true)
                :addField("Item's bought: ", tostring(math.floor(loggedIn.itmsBought*1000)/1000),true)
                :addField("Money gained/spent: ", tostring(math.floor(loggedIn.moneyGained*1000)/1000),true)
                :setTimestamp()
                :setFooter("SolidityPools v"..SolidityPools.version)
            dw.editMessage(config.webhook_url, loggedIn.msgId, "", {emb.sendable()})
            local emb2 = dw.createEmbed()
                :setAuthor("Solidity Pools")
                :setTitle("Session details")
                :setColor(3302600)
                :addField("User: ", loggedIn.username.." (`"..loggedIn.uuid.."`)",true)
                :addField("Balance: ", tostring(math.floor(loggedIn.balance*1000)/1000),true)
                :addField("-","-")
                :setTimestamp()
                :setFooter("SolidityPools v"..SolidityPools.version)
            for k,v in pairs(loggedIn.itemTransactions) do
                emb2:addField(k, tostring(v), true)
            end
            dw.sendMessage(config.webhook_url, config.shopname, nil, "", {emb2.sendable()})
        end
        chatbox.tell(user, "&2Success! &aTerminated &7"..loggedIn.username.." &7("..loggedIn.uuid..")&a's session", config.shopname, nil, "format")
        loggedIn.is = false
        loggedIn.username = ""
        loggedIn.uuid = ""
        loggedIn.timeout = 0
        loggedIn.itmsBought = 0
        loggedIn.itmsSold = 0
        loggedIn.moneyGained = 0
        loggedIn.msgId = ""
        loggedIn.itemTransactions = {}
        loggedIn.loadUser()
        os.queueEvent("sp_rerender")
    else
        chatbox.tell(user, "&cInvalid command, try \\"..config.command.." admin help", config.shopname, nil, "format")
    end
end 

function adminCommands()
    config = SolidityPools.config
    items = SolidityPools.items
    BIL = SolidityPools.BIL
    loggedIn = SolidityPools.loggedIn
    dw = SolidityPools.dw
    while (not SolidityPools.pricesLoaded) or (not SolidityPools.countsLoaded) do
        os.sleep(0)
    end
    while true do
        local event, user, command, args, data = os.pullEvent("command")
        if (command == config.command) and (args[1] == "admin") and (user == config.owner) then
            onAdminCommand(user, args, data)
        elseif (command == config.command) and (args[1] == "admin") then
            chatbox.tell(user, "&cAccess deined!", config.shopname, nil, "format")
        end
        os.sleep(0)
    end
end

return adminCommands