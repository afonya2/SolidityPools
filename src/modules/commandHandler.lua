local utils = require("../utils")

local helpText = ""

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
            chatbox.tell(user, "&aWelcome to "..config.shopname.."!\n&aPlease run &7\\"..config.command.." help &ato familiarize yourself with the commands.\n&aTo buy items run &7\\"..config.command.." buy <item> <amount>&a.\n&cTo sell items drop them on top of the turtle.\n&aBy continuing you accept the &7Terms and Conditions &aof the shop.\n&aRun &7\\"..config.command.." agree &ato accept.", config.shopname, "format")
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
    elseif args[1] == "buy" then
        if #args < 3 then
            chatbox.tell(user, "&cPlease specify an item and an amount.", config.shopname, "format")
            return
        end
        local amount = tonumber(args[3])
        if (amount == nan) or (math.floor(amount) ~= amount) or (amount < 1) then
            chatbox.tell(user, "&cPlease specify a valid amount.", config.shopname, "format")
            return
        end
        if (not SolidityPools.session.is) or (SolidityPools.session.uuid ~= data.user.uuid) then
            chatbox.tell(user, "&cYou don't have an active session. &aRun &7\\"..config.command.." start &ato start one.", config.shopname, "format")
            return
        end
        if SolidityPools.lockInv then
            chatbox.tell(user, "&cPlease wait a few seconds.", config.shopname, "format")
            return
        end
        local possible, item, cat, itemk = utils.queryItem(args[2])
        if item then
            if math.min(item.count, item.allocated) < amount then
                chatbox.tell(user, "&cThe shop doesn't have enough stock of that item.", config.shopname, "format")
                return
            end
            local price, pricei = utils.calculatePrice(item, amount, false)
            if SolidityPools.session.balance < price then
                chatbox.tell(user, "&cYou don't have enough money for this purchase.", config.shopname, "format")
                return
            end
            SolidityPools.lockInv = true
            SolidityPools.session.balance = SolidityPools.session.balance - price
            SolidityPools.items[cat][itemk].allocated = SolidityPools.items[cat][itemk].allocated - amount
            SolidityPools.items[cat][itemk].allocatedMoney = SolidityPools.items[cat][itemk].allocatedMoney + price
            utils.saveCategory(cat, SolidityPools.items[cat])
            userData.balance = SolidityPools.session.balance
            utils.saveUser(data.user.uuid, userData)
            os.queueEvent("sp_render")
            chatbox.tell(user, "&aYou bought &7x"..amount.." "..item.name.." &afor &6"..(price/1000000).."kro &7("..(pricei/1000000).."kro/i)", config.shopname, "format")
            SolidityPools.storage.exportItems("turtle", item.query, amount)
            for i=1, 16 do
                if turtle.getItemCount(i) > 0 then
                    turtle.select(i)
                    turtle.drop()
                end
            end
            SolidityPools.lockInv = false
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
    elseif (args[1] == "balance") or (args[1] == "bal") then
        chatbox.tell(user, "&aYour current balance is &6" .. (userData.balance / 1000000) .. "kro", config.shopname, "format")
    elseif args[1] == "withdraw" then
        if #args < 3 then
            chatbox.tell(user, "&cPlease specify an amount and an address.", config.shopname, "format")
            return
        end
        local amount = tonumber(args[2])
        if amount == nan then
            chatbox.tell(user, "&cPlease specify a valid amount.", config.shopname, "format")
            return
        end
        amount = math.floor(amount * 100)
        if amount < 1 then
            chatbox.tell(user, "&cPlease specify a valid amount.", config.shopname, "format")
            return
        end
        if (amount*10000) > userData.balance then
            chatbox.tell(user, "&cYou don't have enough money to withdraw that amount.", config.shopname, "format")
            return
        end
        if SolidityPools.balance < amount * 10000 then
            chatbox.tell(user, "&cThe shop doesn't have enough money to withdraw that amount.", config.shopname, "format")
            return
        end
        local rollback = userData.balance
        userData.balance = userData.balance - (amount * 10000)
        utils.saveUser(data.user.uuid, userData)
        local ok, err = pcall(SolidityPools.kapi.makeTransaction, config.privateKey, args[3], amount / 100, "message=Withdrawed amount")
        if not ok then
            chatbox.tell(user, "&cFailed to withdraw money: " .. err, config.shopname, "format")
            userData.balance = rollback
            utils.saveUser(data.user.uuid, userData)
            return
        end
        chatbox.tell(user, "&aYou withdrew &6" .. (amount / 100) .. "kro &7to " .. args[3], config.shopname, "format")
    elseif args[1] == "api" then
        if args[2] == "key" then
            if args[3] == "reset" then
                userData.apiKey = utils.generateRanStr(32)
                utils.saveUser(data.user.uuid, userData)
                chatbox.tell(user, "&aYour API key have been reset! Check it by running &7\\"..config.command.." api key&a.", config.shopname, "format")
            else
                if userData.apiKey == nil then
                    chatbox.tell(user, "&cYou don't have an API key. &aRun &7\\"..config.command.." api key reset &ato generate one.", config.shopname, "format")
                    return
                end
                chatbox.tell(user, "Your UUID is: `" .. data.user.uuid .. "`\nYour API key is: `" .. userData.apiKey .. "`", config.shopname)
            end
        else
            chatbox.tell(user, "You can read the api documentation here: https://github.com/afonya2/SolidityPools/blob/v2/api/README.md", config.shopname)
        end
    elseif args[1] == "tos" then
        chatbox.tell(user, "Read the Terms and Conditions here: https://github.com/afonya2/SolidityPools/blob/v2/tos.md", config.shopname)
    else
        chatbox.tell(user, "&cUnknown command. &aType &7\\"..config.command.." help &afor a list of commands.", config.shopname, "format")
    end
end

local function commandHandler()
    helpText = [[Usage: `\]]..SolidityPools.config.command..[[ <command> [args...]`
Available commands:
- `help` - Display this message
- `start` - Start a session
- `exit/end` - End your session
- `info [<item>]` - Display information about the shop or an item
- `price <item> <amount>` - Display the price of an item
- `arb <item> <price>` - Display the arbitrage opportunity for an item
- `buy <item> <amount>` - Buy an item
- `balance/bal` - Display your current balance
- `withdraw <amount> <address>` - Withdraw an amount
- `api` - Display API information
- `api key` - Display your API key
- `api key reset` - Reset your API key
- `tos` - Display the Terms and Conditions
]]
    while true do
        local event, user, command, args, data = os.pullEvent("command")
        if command == SolidityPools.config.command then
            onCommand(user, args, data)
        end
        os.sleep(0)
    end
end

return commandHandler