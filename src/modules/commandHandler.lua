local utils = require("../utils")

local helpText = [[Usage: `\]]..SolidityPools.config.command..[[ <command> [args...]`
Available commands:
- `help` - Display this message
- `start` - Start a session
- `exit/end` - End your session
- `info [<item>]` - Display information about the shop or an item
- `price <item> <amount>` - Display the price of an item
- `arb <item> <price>` - Display the arbitrage opportunity for an item
- `buy <item> <amount>` - Buy an item
- `balance` - Display your current balance
- `withdraw <amount>` - Withdraw an amount
- `api (key) [<reset>]` - Display API information, your API key or reset it
]]

local function onCommand(user, args, data)
    local config = SolidityPools.config
    local userData = utils.loadUser(data.user.uuid)
    userData.name = user:lower()
    utils.saveUser(data.user.uuid, userData)
    if args[1] == "help" then
        chatbox.tell(user, helpText, config.shopname)
    elseif args[1] == "start" then
        if not utils.isPlayerClose(user) then
            chatbox.tell(user, "&cYou must be close to the shop to start a session.", config.shopname, "format")
            return
        end
        if SolidityPools.session.is then
            chatbox.tell(user, "&cThere's currently an active session.", config.shopname, "format")
            return
        end
        if userData.agreed then
            SolidityPools.session.is = true
            SolidityPools.session.uuid = data.user.uuid
            SolidityPools.session.username = user:lower()
            SolidityPools.session.balance = userData.balance
            SolidityPools.session.lastActive = os.clock()
            chatbox.tell(user, "&aSession started.", config.shopname, "format")
            os.queueEvent("sp_render")
        else
            chatbox.tell(user, "&aWelcome to "..config.shopname.."!\n&aPlease run &7\\"..config.command.." help &ato familiarize yourself with the commands.\nBy continuing you accept the &7Terms and Conditions &aof the shop.\n&aRun &7\\"..config.command.." agree &ato accept.", config.shopname, "format")
        end
    elseif args[1] == "agree" then
        if userData.agreed then
            chatbox.tell(user, "&cYou have already agreed to the Terms and Conditions.", config.shopname, "format")
            return
        end
        userData.agreed = true
        utils.saveUser(data.user.uuid, userData)
        chatbox.tell(user, "&aYou have agreed to the Terms and Conditions.\n&aRun &7\\"..config.command.." start &ato start a session.", config.shopname, "format")
    elseif (args[1] == "exit") or (args[1] == "end") then
        if (not SolidityPools.session.is) or (SolidityPools.session.uuid ~= data.user.uuid) then
            chatbox.tell(user, "&cYou don't have a session to end.", config.shopname, "format")
            return
        end
        userData.balance = SolidityPools.session.balance
        utils.saveUser(data.user.uuid, userData)
        SolidityPools.session.is = false
        SolidityPools.session.uuid = ""
        SolidityPools.session.username = ""
        SolidityPools.session.balance = 0
        chatbox.tell(user, "&aSession ended.", config.shopname, "format")
        os.queueEvent("sp_render")
    elseif args[1] == "info" then
        if #args < 2 then
            local strg = SolidityPools.storage.getStats()
            local text = [[&aShop info:
&aName: &7]]..config.shopname..[[

&aDescription: &7]]..config.description..[[

&aLocation: &7x: ]]..SolidityPools.location.x..[[ y: ]]..SolidityPools.location.y..[[ z: ]]..SolidityPools.location.z..[[

&aAddress: &7]]..config.address..[[

&aTrading Fees: &7]]..config.tradingFees..[[%
&aBalance: &6]]..(SolidityPools.balance/1000000)..[[kro

&aStorage: &7]]..strg.used..[[/]]..strg.all..[[ (]]..(math.floor(strg.used/strg.all*100*100)/100)..[[%)
&aVersion: &7]]..SolidityPools.version
            chatbox.tell(user, text, config.shopname, "format")
        else
            local possible, item = utils.queryItem(args[2])
            if item then
                local itemC = SolidityPools.storage.getItemCount(item.query)
                local text = [[&aItem info:
&aName: &7]]..item.name..[[

&aAliases: &7]]..table.concat(item.aliases, ", ")..[[

&aQuery: &7]]..item.query..[[

&aAllocated items: &7]]..math.min(item.allocated, itemC)..[[

&aAllocated money: &6]]..(math.min(item.allocatedMoney, SolidityPools.balance)/1000000)..[[kro
&aCount: &7]]..itemC
                chatbox.tell(user, text, config.shopname, "format")
            else
                local bestMatch = nil
                local bestPerc = 0
                for k, v in pairs(possible) do
                    if v > bestPerc then
                        bestPerc = v
                        bestMatch = k
                    end
                end
                if bestPerc > 50 then
                    chatbox.tell(user, "&cItem not found. &aDid you mean: &7" .. bestMatch .. "&a?", config.shopname, "format")
                else
                    chatbox.tell(user, "&cItem not found.", config.shopname, "format") 
                end
            end
        end
    elseif args[1] == "price" then
        if #args < 3 then
            chatbox.tell(user, "&cPlease specify an item and an amount.", config.shopname, "format")
            return
        end
        local amount = tonumber(args[3])
        if (amount == nan) or (math.floor(amount) ~= amount) or (amount == 0) then
            chatbox.tell(user, "&cPlease specify a valid amount.", config.shopname, "format")
            return
        end
        local possible, item = utils.queryItem(args[2])
        if item then
            if amount < 0 then
                local price, pricei = utils.calculatePrice(item, math.abs(amount), true)
                chatbox.tell(user, "&cSelling &7x"..math.abs(amount).." "..item.name.." &cwould earn you &6" .. (price/1000000) .. "kro &7("..(pricei/1000000).."kro/i)", config.shopname, "format")
            elseif amount > 0 then
                local price, pricei = utils.calculatePrice(item, amount, false)
                chatbox.tell(user, "&aBuying &7x"..amount.." "..item.name.." &awould cost you &6" .. (price/1000000) .. "kro &7("..(pricei/1000000).."kro/i)", config.shopname, "format")
            end
        else
            local bestMatch = nil
            local bestPerc = 0
            for k, v in pairs(possible) do
                if v > bestPerc then
                    bestPerc = v
                    bestMatch = k
                end
            end
            if bestPerc > 50 then
                chatbox.tell(user, "&cItem not found. &aDid you mean: &7" .. bestMatch .. "&a?", config.shopname, "format")
            else
                chatbox.tell(user, "&cItem not found.", config.shopname, "format") 
            end
        end
    else
        chatbox.tell(user, "&cUnknown command. Type &7\\"..config.command.." help &afor a list of commands.", config.shopname, "format")
    end
end

local function commandHandler()
    while true do
        local event, user, command, args, data = os.pullEvent("command")
        if command == SolidityPools.config.command then
            onCommand(user, args, data)
        end
        os.sleep(0)
    end
end

return commandHandler