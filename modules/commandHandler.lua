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

local function onCommand(user, args, data)
    if fs.exists("/bans.cache") then
        local bans = loadCache("/bans.cache")
        if (bans[user:lower()] ~= nil) and (user ~= config.owner) then
            chatbox.tell(user, "&cYou are banned from &7"..config.shopname.."&c, reason: &7"..bans[user:lower()], config.shopname, nil, "format")
            return
        end
    end
    if args[1] == "help" then
        local helptxt = [[
`\]]..config.command..[[ help`
Provides this help message
`\]]..config.command..[[ start`
Starts a session
`\]]..config.command..[[ arb <item> <price>`
Computes market arbitrage
`\]]..config.command..[[ price <item> <amount>`
Queries an item's price
`\]]..config.command..[[ buy <item> <amount>`
Buys an item
`\]]..config.command..[[ info [<item>]`
Displays information about the shop / item
`\]]..config.command..[[ exit`
Exits a session
`\]]..config.command..[[ balance`
Displays your balance
`\]]..config.command..[[ withdraw <amount> [<target>]`
Withdraws Krist from your account
        ]]
        chatbox.tell(user, helptxt, config.shopname, nil, "markdown")
    elseif args[1] == "start" then
        if not isPlayerClose(user) then
            local x,_,z = gps.locate()
            chatbox.tell(user, "&cPlease come close to the shop (x: "..x..", z: "..z..")", config.shopname, nil, "format")
            return
        end
        if not loggedIn.is then
            chatbox.tell(user, "&aStarting session as &7"..user, config.shopname, nil, "format")
            loggedIn.is = true
            loggedIn.username = user:lower()
            loggedIn.uuid = data.user.uuid
            loggedIn.timeout = os.clock()
            loggedIn.itmsBought = 0
            loggedIn.itmsSold = 0
            loggedIn.moneyGained = 0
            loggedIn.itemTransactions = {}
            loggedIn.loadUser()
            if not fs.exists("/users/"..loggedIn.uuid..".cache") then
                loggedIn.saveUser()
            end
            if config.webhook then
                local emb = dw.createEmbed()
                    :setAuthor("Solidity Pools")
                    :setTitle("Session start")
                    :setColor(3302600)
                    :addField("User: ", loggedIn.username.." (`"..loggedIn.uuid.."`)",true)
                    :addField("Balance: ", tostring(math.floor(loggedIn.balance*1000)/1000),true)
                    :addField("-","-")
                    :addField("Item's sold: ", tostring(math.floor(loggedIn.itmsSold*1000)/1000),true)
                    :addField("Item's bought: ", tostring(math.floor(loggedIn.itmsBought*1000)/1000),true)
                    :addField("Money gained/spent: ", tostring(math.floor(loggedIn.moneyGained*1000)/1000),true)
                    :setTimestamp()
                    :setFooter("SolidityPools v"..SolidityPools.version)
                local dms = dw.sendMessage(config.webhook_url, config.shopname, nil, "", {emb.sendable()})
                loggedIn.msgId = dms.id
            end
            os.queueEvent("sp_rerender")
        else
            chatbox.tell(user, "&cThere is currently a running session", config.shopname, nil, "format")
        end
    elseif args[1] == "price" then
        if (args[2] == nil) or (args[3] == nil) then
            chatbox.tell(user, "&cUsage \\"..config.command.." price <item> <amount>", config.shopname, nil, "format")
            return
        end
        if tonumber(args[3]) == nil then
            chatbox.tell(user, "&cAmount must be a number", config.shopname, nil, "format")
            return
        end
        if tonumber(args[3]) ~= math.floor(tonumber(args[3])) then
            chatbox.tell(user, "&cAmount must be an exact number", config.shopname, nil, "format")
            return
        end
        for k,v in pairs(items) do
            for kk,vv in ipairs(v) do
                if vv.name:gsub(" ", ""):lower() == args[2]:lower() then
                    if config.mode == "both" then
                        if tonumber(args[3]) > 0 then
                            local pric = computeDP(vv,tonumber(args[3]))
                            chatbox.tell(user, "&aBuying &7x"..args[3].." "..vv.name.." &awould cost you &e"..(math.floor(pric*1000)/1000).."kst &7("..(math.floor(pric/tonumber(args[3])*1000)/1000).."kst/i)", config.shopname, nil, "format")
                        elseif tonumber(args[3]) < 0 then
                            local pric = computeDP(vv,math.abs(tonumber(args[3])),true)
                            chatbox.tell(user, "&cSelling &7x"..math.abs(tonumber(args[3])).." "..vv.name.." &cwould earn you &e"..(math.floor(pric*1000)/1000).."kst &7("..(math.floor(pric/math.abs(tonumber(args[3]))*1000)/1000).."kst/i)", config.shopname, nil, "format")
                        else
                            chatbox.tell(user, "&aThe middle price of &7"..args[2].." &ais &e"..vv.price.."kst", config.shopname, nil, "format")
                        end
                    elseif config.mode == "buy" then
                        if tonumber(args[3]) > 0 then
                            local pric = computeDP(vv,tonumber(args[3]))
                            chatbox.tell(user, "&aBuying &7x"..args[3].." "..vv.name.." &awould cost you &e"..(math.floor(pric*1000)/1000).."kst &7("..(math.floor(pric/tonumber(args[3])*1000)/1000).."kst/i)", config.shopname, nil, "format")
                        elseif tonumber(args[3]) < 0 then
                            local pric = computeDP(vv,math.abs(tonumber(args[3])))
                            chatbox.tell(user, "&aBuying &7x"..math.abs(tonumber(args[3])).." "..vv.name.." &awould cost you &e"..(math.floor(pric*1000)/1000).."kst &7("..(math.floor(pric/math.abs(tonumber(args[3]))*1000)/1000).."kst/i)", config.shopname, nil, "format")
                        else
                            chatbox.tell(user, "&aThe middle price of &7"..args[2].." &ais &e"..vv.price.."kst", config.shopname, nil, "format")
                        end
                    elseif config.mode == "sell" then
                        if tonumber(args[3]) > 0 then
                            local pric = computeDP(vv,tonumber(args[3]),true)
                            chatbox.tell(user, "&cSelling &7x"..args[3].." "..vv.name.." &cwould earn you &e"..(math.floor(pric*1000)/1000).."kst &7("..(math.floor(pric/tonumber(args[3])*1000)/1000).."kst/i)", config.shopname, nil, "format")
                        elseif tonumber(args[3]) < 0 then
                            local pric = computeDP(vv,math.abs(tonumber(args[3])),true)
                            chatbox.tell(user, "&cSelling &7x"..math.abs(tonumber(args[3])).." "..vv.name.." &cwould earn you &e"..(math.floor(pric*1000)/1000).."kst &7("..(math.floor(pric/math.abs(tonumber(args[3]))*1000)/1000).."kst/i)", config.shopname, nil, "format")
                        else
                            chatbox.tell(user, "&aThe middle price of &7"..args[2].." &ais &e"..vv.price.."kst", config.shopname, nil, "format")
                        end
                    end 
                    return
                end
            end
        end
        chatbox.tell(user, "&cInvalid item", config.shopname, nil, "format")
    elseif args[1] == "arb" then
        if (args[2] == nil) or (args[3] == nil) then
            chatbox.tell(user, "&cUsage \\"..config.command.." arb <item> <price>", config.shopname, nil, "format")
            return
        end
        if tonumber(args[3]) == nil then
            chatbox.tell(user, "&cPrice must be a number", config.shopname, nil, "format")
            return
        end
        for k,v in pairs(items) do
            for kk,vv in ipairs(v) do
                if vv.name:gsub(" ", ""):lower() == args[2]:lower() then
                    if computeDP(vv, 1, true) < tonumber(args[3]) then
                        chatbox.tell(user, "&cThere is no way to profit arbitrage at current prices", config.shopname, nil, "format")
                        return 
                    end
                    for ib=1,math.huge do
                        if (computeDP(vv, ib, true) < tonumber(args[3])*ib) or (ib == 10001) then
                            local diff = computeDP(vv, ib-1, true)-tonumber(args[3])*(ib-1)
                            local totell = [[
&aIf a shop selling for &e]]..args[3]..[[kst&a, then:
&aBuy &7]]..(ib-1)..[[ &aitems, paying &e]]..(math.floor(tonumber(args[3])*(ib-1)*1000)/1000)..[[kst
&aSell &7]]..(ib-1)..[[ &aitems here, earning &e]]..(math.floor(computeDP(vv, ib-1, true)*1000)/1000)..[[kst
&aKeep the difference of &e]]..(math.floor(diff*1000)/1000)..[[kst &aas profit
                            ]]
                            chatbox.tell(user, totell, config.shopname, nil, "format")
                            return
                        end
                    end
                    return
                end
            end
        end
        chatbox.tell(user, "&cInvalid item", config.shopname, nil, "format")
    elseif args[1] == "balance" then
        if fs.exists("/users/"..data.user.uuid..".cache") then
            local pdat = loadCache("/users/"..data.user.uuid..".cache")
            chatbox.tell(user, "&aBalance: &e"..(math.floor(pdat.balance*1000)/1000).."kst", config.shopname, nil, "format")
        else
            chatbox.tell(user, "&aBalance: &e0kst", config.shopname, nil, "format")
        end
    elseif args[1] == "withdraw" then
        if (args[2] == nil) then
            chatbox.tell(user, "&cUsage \\"..config.command.." withdraw <amount> [<target>]", config.shopname, nil, "format")
            return
        end
        if tonumber(args[2]) == nil then
            chatbox.tell(user, "&cAmount must be a number", config.shopname, nil, "format")
            return
        end
        if tonumber(args[2]) < 1 then
            chatbox.tell(user, "&cNice try dude!", config.shopname, nil, "format")
            return
        end
        if tonumber(args[2]) ~= math.floor(tonumber(args[2])) then
            chatbox.tell(user, "&cAmount must be an exact number", config.shopname, nil, "format")
            return
        end
        if args[3] == nil then
            args[3] = (data.user.uuid.."@sc.kst"):gsub("-","")
        end
        if fs.exists("/users/"..data.user.uuid..".cache") then
            local pdat = loadCache("/users/"..data.user.uuid..".cache")
            if pdat.balance < tonumber(args[2]) then
                chatbox.tell(user, "&cYou don't have enough funds to withdraw this amount", config.shopname, nil, "format")
                return
            end
            if SolidityPools.kapi.getBalance(config.address) < tonumber(args[2]) then
                chatbox.tell(user, "&c"..config.shopname.." don't have enough funds to withdraw this amount", config.shopname, nil, "format")
                return
            end
            pdat.balance = pdat.balance - tonumber(args[2])
            table.insert(pdat.transactions, 1, {
                from = "balance",
                to = args[3],
                value = tonumber(args[2]),
                ["type"] = "withdraw"
            })
            while #pdat.transactions > 10 do
                table.remove(pdat.transactions, #pdat.transactions)
            end
            local ok,err = pcall(SolidityPools.kapi.makeTransaction, config.privateKey, args[3], tonumber(args[2]), "message=Withdrawed amount")
            if not ok then
                chatbox.tell(user, "&cCan't create transaction, reason: &7"..err, config.shopname, nil, "format")
                return
            end
            pdat.username = user
            saveCache("/users/"..data.user.uuid..".cache", pdat)
            if loggedIn.uuid == data.user.uuid then
                loggedIn.loadUser()
                os.queueEvent("sp_rerender")
            end
            chatbox.tell(user,"&e"..tonumber(args[2]).."kst &awas withdrawed from your account",config.shopname,nil,"format")
            if config.webhook then
                local emb = dw.createEmbed()
                    :setAuthor("Solidity Pools")
                    :setTitle("Withdraw")
                    :setColor(3328100)
                    :addField("User: ", user.." (`"..data.user.uuid.."`)",true)
                    :addField("To: ", "`"..args[3].."`",true)
                    :addField("Value: ", args[2],true)
                    :addField("New balance: ", tostring(math.floor(pdat.balance*1000)/1000),true)
                    :setTimestamp()
                    :setFooter("SolidityPools v"..SolidityPools.version)
                dw.sendMessage(config.webhook_url, config.shopname, nil, "", {emb.sendable()})
            end
        else
            chatbox.tell(user, "&cYou don't have enough funds to withdraw this amount", config.shopname, nil, "format")
        end
    elseif args[1] == "info" then
        if args[2] == nil then
            local stor = BIL.getSize()
            local x,y,z = gps.locate()
            local smsg = [[
&aShop info:
&aname: &7]]..config.shopname..[[

&aDescription: &7]]..config.description..[[

&aLocation: &7]].."x: "..x..", y: "..y..", z: "..z..[[

&aaddress: &7]]..config.address..[[

&aTrading fees: &7]]..config.tradingFees..[[%
&aBalance: &e]]..SolidityPools.kapi.getBalance(config.address)..[[kst
&aStorage: &7]]..stor.used.."/"..stor.total.." ("..(math.floor(stor.used/stor.total*100*1000)/1000).."%)"..[[
            ]]
            chatbox.tell(user, smsg, config.shopname, nil, "format")
        else
            for k,v in pairs(items) do
                for kk,vv in ipairs(v) do
                    if vv.name:gsub(" ", ""):lower() == args[2]:lower() then
                        local itmsg = [[
&aItem info:
&aItem name: &7]]..vv.name..[[

&aItem query: &7]]..vv.query..[[

&aItem count: &7]]..vv.count..[[

&aPrice: &e]]..(math.floor(vv.price*1000)/1000)..[[kst
                        ]]
                        chatbox.tell(user, itmsg, config.shopname, nil, "format")
                        return
                    end
                end
            end
            chatbox.tell(user, "&cInvalid item", config.shopname, nil, "format")
        end
    elseif args[1] == "buy" then
        if config.mode == "sell" then
            chatbox.tell(user, "&cThis shop only buys items!", config.shopname, nil, "format")
            return
        end
        if (args[2] == nil) or (args[3] == nil) then
            chatbox.tell(user, "&cUsage \\"..config.command.." buy <item> <amount>", config.shopname, nil, "format")
            return
        end
        if tonumber(args[3]) == nil then
            chatbox.tell(user, "&cAmount must be a number", config.shopname, nil, "format")
            return
        end
        if tonumber(args[3]) < 1 then
            chatbox.tell(user, "&cNice try dude!", config.shopname, nil, "format")
            return
        end
        if tonumber(args[3]) ~= math.floor(tonumber(args[3])) then
            chatbox.tell(user, "&cAmount must be an exact number", config.shopname, nil, "format")
            return
        end
        if (not loggedIn.is) or (loggedIn.uuid ~= data.user.uuid) then
            chatbox.tell(user, "&cCurrently you are not in a session", config.shopname, nil, "format")
            return
        end
        if SolidityPools.itemChangeInfo.is then
            chatbox.tell(user, "&cPlease wait a few seconds", config.shopname, nil, "format")
            return
        end
        for k,v in pairs(items) do
            for kk,vv in ipairs(v) do
                if vv.name:gsub(" ", ""):lower() == args[2]:lower() then
                    local costMoney = computeDP(vv, tonumber(args[3]))
                    local pdat = loadCache("/users/"..data.user.uuid..".cache")
                    if pdat.balance < costMoney then
                        chatbox.tell(user, "&cYou don't have enough funds to buy this amount", config.shopname, nil, "format")
                        return
                    end
                    if vv.count < tonumber(args[3]) then
                        chatbox.tell(user, "&cNot enough items in the storage", config.shopname, nil, "format")
                        return
                    end
                    pdat.balance = pdat.balance - costMoney
                    table.insert(pdat.transactions, 1, {
                        from = "balance",
                        to = "system",
                        value = costMoney,
                        ["type"] = "buy"
                    })
                    while #pdat.transactions > 10 do
                        table.remove(pdat.transactions, #pdat.transactions)
                    end
                    pdat.username = user
                    loggedIn.itmsBought = loggedIn.itmsBought + tonumber(args[3])
                    loggedIn.moneyGained = loggedIn.moneyGained - costMoney
                    if loggedIn.itemTransactions[vv.name] == nil then
                        loggedIn.itemTransactions[vv.name] = 0
                    end
                    loggedIn.itemTransactions[vv.name] = loggedIn.itemTransactions[vv.name] - tonumber(args[3])
                    saveCache("/users/"..data.user.uuid..".cache", pdat)
                    loggedIn.loadUser()
                    SolidityPools.itemChangeInfo.is = true
                    SolidityPools.itemChangeInfo.category = k
                    SolidityPools.itemChangeInfo.pos = kk
                    SolidityPools.itemChangeInfo.mode = "buy"
                    SolidityPools.itemChangeInfo.time = os.clock()
                    BIL.dropItems(vv.query, tonumber(args[3]))
                    os.queueEvent("sp_rerender")
                    chatbox.tell(user, "&2Success! &aYou bought &7x"..tonumber(args[3]).." "..vv.name.." &afor &e"..(math.floor(costMoney*1000)/1000).."kst &7("..(math.floor(costMoney/tonumber(args[3])*1000)/1000).."kst/i)", config.shopname, nil, "format")
                    loggedIn.timeout = os.clock()
                    if config.webhook then
                        local emb = dw.createEmbed()
                            :setAuthor("Solidity Pools")
                            :setTitle("Item bought")
                            :setColor(3302600)
                            :addField("User: ", loggedIn.username.." (`"..loggedIn.uuid.."`)",true)
                            :addField("Balance: ", tostring(math.floor(loggedIn.balance*1000)/1000),true)
                            :addField("-","-")
                            :addField("Item's sold: ", tostring(math.floor(loggedIn.itmsSold*1000)/1000),true)
                            :addField("Item's bought: ", tostring(math.floor(loggedIn.itmsBought*1000)/1000),true)
                            :addField("Money gained/spent: ", tostring(math.floor(loggedIn.moneyGained*1000)/1000),true)
                            :addField("-","-")
                            :addField("Item name: ", vv.name, true)
                            :addField("Count: ", args[3], true)
                            :addField("Cost: ", tostring(math.floor(costMoney*1000)/1000),true)
                            :setTimestamp()
                            :setFooter("SolidityPools v"..SolidityPools.version)
                        dw.editMessage(config.webhook_url, loggedIn.msgId, "", {emb.sendable()})
                    end
                    return
                end
            end
        end
        chatbox.tell(user, "&cInvalid item", config.shopname, nil, "format")
    elseif args[1] == "exit" then
        if (loggedIn.is) and (loggedIn.uuid == data.user.uuid) then
            loggedIn.saveUser()
            chatbox.tell(user, "&aYour remaining &e"..(math.floor(loggedIn.balance*1000)/1000).."kst &awill be stored for your next purchase", config.shopname, nil, "format")
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
                    :setDescription("Item changes in the storage")
                    :setColor(3302600)
                    :addField("User: ", loggedIn.username.." (`"..loggedIn.uuid.."`)",true)
                    :addField("Balance: ", tostring(math.floor(loggedIn.balance*1000)/1000),true)
                    :addField("-","-")
                    :setTimestamp()
                    :setFooter("SolidityPools v"..SolidityPools.version)
                for k,v in pairs(loggedIn.itemTransactions) do
                    if v ~= 0 then
                        emb2:addField(k, tostring(v), true)
                    end
                end
                dw.sendMessage(config.webhook_url, config.shopname, nil, "", {emb2.sendable()})
            end
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
            chatbox.tell(user, "&cCurrently you are not in a session", config.shopname, nil, "format")
        end
    elseif args[1] == "admin" then
    else
        chatbox.tell(user, "&cInvalid command, try \\"..config.command.." help", config.shopname, nil, "format")
    end
end 

function commandHandler()
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
        if command == config.command then
            onCommand(user, args, data)
        end
        os.sleep(0)
    end
end

return commandHandler