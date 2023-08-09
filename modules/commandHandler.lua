local config = nil
local items = nil
local BIL = nil
local loggedIn = nil

local function loadCache(filename)
    local fa = fs.open(filename, "r")
    local fi = fa.readAll()
    fi = fi:gsub("SYSTEM CACHE, DO NOT EDIT!","")
    fa.close()
    return textutils.unserialise(fi)
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

local function onCommand(user, args, data)
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
        ]]
        chatbox.tell(user, helptxt, config.shopname, nil, "markdown")
    elseif args[1] == "start" then
        if not loggedIn.is then
            chatbox.tell(user, "&aStarting session as &7"..user, config.shopname, nil, "format")
            loggedIn.is = true
            loggedIn.username = user:lower()
            loggedIn.uuid = data.user.uuid
            loggedIn.loadUser()
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
        for k,v in pairs(items) do
            for kk,vv in ipairs(v) do
                if vv.name:gsub(" ", ""):lower() == args[2]:lower() then
                    if tonumber(args[3]) > 0 then
                        local pric = computeDP(vv,tonumber(args[3]))
                        chatbox.tell(user, "&aBuying &7x"..args[3].." "..vv.name.." &awould cost you &e"..(math.floor(pric*1000)/1000).."kst &7("..(math.floor(pric/tonumber(args[3])*1000)/1000).."kst/i)", config.shopname, nil, "format")
                    elseif tonumber(args[3]) < 0 then
                        local pric = computeDP(vv,math.abs(tonumber(args[3])),true)
                        chatbox.tell(user, "&cSelling &7x"..math.abs(tonumber(args[3])).." "..vv.name.." &cwould earn you &e"..(math.floor(pric*1000)/1000).."kst &7("..(math.floor(pric/math.abs(tonumber(args[3]))*1000)/1000).."kst/i)", config.shopname, nil, "format")
                    else
                        chatbox.tell(user, "&aThe middle price of &7"..args[2].." &ais &e"..vv.price.."kst", config.shopname, nil, "format")
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
    elseif args[1] == "balance" then
        if fs.exists("/users/"..data.user.uuid..".cache") then
            local pdat = loadCache("/users/"..data.user.uuid..".cache")
        else
            chatbox.tell(user, "&cPrice must be a number", config.shopname, nil, "format")
        end
    elseif args[1] == "exit" then
        if (loggedIn.is) and (loggedIn.uuid == data.user.uuid) then
            loggedIn.saveUser()
            chatbox.tell(user, "&aYour remaining &e"..loggedIn.balance.."kst &awill be stored for your next purchase", config.shopname, nil, "format")
            loggedIn.is = false
            loggedIn.username = ""
            loggedIn.uuid = ""
            loggedIn.loadUser()
            os.queueEvent("sp_rerender")
        else
            chatbox.tell(user, "&cCurrently you are not in a session", config.shopname, nil, "format")
        end
    else
        chatbox.tell(user, "&cInvalid command, try \\"..config.command.." help", config.shopname, nil, "format")
    end
end 

function commandHandler()
    config = SolidityPools.config
    items = SolidityPools.items
    BIL = SolidityPools.BIL
    loggedIn = SolidityPools.loggedIn
    while true do
        local event, user, command, args, data = os.pullEvent("command")
        if command == config.command then
            onCommand(user, args, data)
        end
        os.sleep(0)
    end
end

return commandHandler