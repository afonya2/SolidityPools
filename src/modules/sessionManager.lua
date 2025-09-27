local utils = require("../utils")

local function onItemPickup()
    local config = SolidityPools.config
    SolidityPools.lockInv = true
    for i=2, 16 do
        local c = turtle.getItemCount(i)
        if c > 0 then
            turtle.select(i)
            turtle.drop(c)
        end
    end
    turtle.select(1)
    local itemData = turtle.getItemDetail(1, true)
    local itemCount = turtle.getItemCount(1)
    if (itemData.name == "sc-goodies:ender_storage") and (config.apiEnabled) then
        local userData = utils.loadUser(SolidityPools.session.uuid)
        if userData.apiChest ~= nil then
            chatbox.tell(SolidityPools.session.username, "&cYou have already set your API chest. To change it, run &7\\"..config.command.." api chest&c.", config.shopname, "format")
            turtle.drop()
            SolidityPools.lockInv = false
            return
        end
        local users = fs.list("/users")
        local nextPos = 1
        for _, user in ipairs(users) do
            local uData = utils.loadUser(user:gsub(".conf",""))
            if uData.apiChest ~= nil then
                nextPos = math.max(nextPos, uData.apiChest+1)
                break
            end
        end
        local ecChest = peripheral.wrap(config.apiChest)
        if nextPos > ecChest.size() then
            chatbox.tell(SolidityPools.session.username, "&cNo available API chest slots. Please contact an administrator.", config.shopname, "format")
            SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) wanted to set their API chest, but no slots were available.")
            turtle.drop()
            SolidityPools.lockInv = false
            return
        end
        ecChest.pullItems(SolidityPools.wiredModem.wrap.getNameLocal(), 1, 1, nextPos)
        
        local lmodem = SolidityPools.wiredModem.wrap
        lmodem.transmit(2646, 2646, textutils.serialise({
            mode = "check",
            chest = config.apiChest,
            pos = nextPos,
            user = SolidityPools.session.uuid
        }))
        local mmsg = nil
        local function a()
            while true do
                local event,side,channel,replyChannel,message = os.pullEvent("modem_message")
                if (side == SolidityPools.wiredModem.id) and (channel == 2646) and (type(message) == "string") then
                    mmsg = message
                    os.sleep(1)
                    break
                end
            end
        end
        local function b()
            os.sleep(10)
        end
        parallel.waitForAny(a, b)
        if mmsg == nil then
            chatbox.tell(SolidityPools.session.username, "&cTimeout while setting your API chest. Please try again later.", config.shopname, "format")
            SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) wanted to set their API chest, but the operation timed out.")
            ecChest.pushItems(SolidityPools.wiredModem.wrap.getNameLocal(), nextPos, 1, 1)
            turtle.drop()
            SolidityPools.lockInv = false
            return
        end
        local ok, data = pcall(textutils.unserialize, mmsg)
        if ok then
            if data.mode == "ok" then
                userData.apiChest = nextPos
                utils.saveUser(SolidityPools.session.uuid, userData)
                chatbox.tell(SolidityPools.session.username, "&aYour API chest has been set successfully!", config.shopname, "format")
                SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) set their API chest to slot `"..nextPos.."`.")
            elseif data.mode == "fail" then
                chatbox.tell(SolidityPools.session.username, "&cPlease use your own chest, and make sure it's a private chest.", config.shopname, "format")
                SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) wanted to set their API chest, but the operation failed: " .. data.message)
                ecChest.pushItems(SolidityPools.wiredModem.wrap.getNameLocal(), nextPos, 1, 1)
                turtle.drop()
            end
        else
            chatbox.tell(SolidityPools.session.username, "&cError while setting your API chest. Please try again later.", config.shopname, "format")
            SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) wanted to set their API chest, but the operation failed: " .. data)
            ecChest.pushItems(SolidityPools.wiredModem.wrap.getNameLocal(), nextPos, 1, 1)
            turtle.drop()
        end
        SolidityPools.lockInv = false
        return
    end
    local item,icat,ipos = nil, nil, nil
    for k, v in pairs(SolidityPools.items) do
        for kk, vv in ipairs(v) do
            if SolidityPools.BIL.isItemMatch(itemData, vv.query) then
                item = vv
                icat = k
                ipos = kk
            end
        end
    end
    if item then
        local highestItemAccepted = item.itemLimit - math.min(item.count, item.allocated)
        local soldCount = math.min(itemCount, highestItemAccepted)
        if soldCount < 1 then
            chatbox.tell(SolidityPools.session.username, "&cItem limit reached. The shop is not accepting any more of this item.", config.shopname, "format")
            SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) tried to sell `x" .. soldCount .. " " .. item.name .. "` but the item limit was reached.")
            turtle.drop()
            SolidityPools.lockInv = false
            return
        end
        local remainder = itemCount - soldCount
        local price, pricei, tfees = utils.calculatePrice(item, soldCount, true)
        local ok, err = pcall(SolidityPools.storage.importItems, "turtle", item.query, soldCount)
        SolidityPools.defragNeeded = true
        if not ok then
            chatbox.tell(SolidityPools.session.username, "&cError while importing items: " .. err, config.shopname, "format")
            SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) tried to sell `x" .. soldCount .. " " .. item.name .. "` but the import failed: " .. err)
            turtle.drop()
            SolidityPools.lockInv = false
            return
        end
        local userData = utils.loadUser(SolidityPools.session.uuid)
        local ai = item.allocated
        local am = item.allocatedMoney
        local pb = SolidityPools.session.balance
        SolidityPools.session.balance = SolidityPools.session.balance + price
        SolidityPools.items[icat][ipos].allocated = item.allocated + soldCount
        SolidityPools.items[icat][ipos].allocatedMoney = item.allocatedMoney - (price + tfees)
        SolidityPools.items[icat][ipos].count = item.count + soldCount
        utils.saveCategory(icat, SolidityPools.items[icat])
        userData.balance = SolidityPools.session.balance
        utils.saveUser(SolidityPools.session.uuid, userData)
        local shopDta = utils.getShopData()
        shopDta.transactionFees = shopDta.transactionFees + tfees
        utils.saveShopData(shopDta)
        os.queueEvent("sp_render")
        chatbox.tell(SolidityPools.session.username, "&aYou sold &7x"..soldCount.." "..item.name.."&a for &6"..(price/1000000).."kro &7("..(pricei/1000000).."kro/i)", config.shopname, "format")
        SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) sold `x" .. soldCount .. " " .. item.name .. "` for " .. (price/1000000) .. "kro" .. " (`" .. pricei/1000000 .. "kro/i`)\nAllocated items: `" .. ai .. " -> " .. item.allocated .. "`\nAllocated money: `" .. (am/1000000) .. "kro -> " .. (item.allocatedMoney/1000000) .. "kro`\nUser balance: `" .. (pb/1000000) .. "kro -> " .. (SolidityPools.session.balance/1000000) .. "kro`")
        if remainder > 0 then
            turtle.drop(remainder)
        end
        SolidityPools.lockInv = false
        SolidityPools.sendShopsync = true
    else
        chatbox.tell(SolidityPools.session.username, "&cThe shop doesn't purchase this item.", config.shopname, "format")
        turtle.drop()
        SolidityPools.lockInv = false
    end
end

local function itemSell()
    while true do
        if SolidityPools.session.is and (not SolidityPools.lockInv) then
            local succ = turtle.suckUp()
            if succ then
                SolidityPools.session.lastActive = os.clock()
                onItemPickup()
            end
        end
        os.sleep(0)
    end
end

local function sessionTimeout()
    local config = SolidityPools.config
    while true do
        if SolidityPools.session.is then
            if os.clock()-SolidityPools.session.lastActive > 60 then
                chatbox.tell(SolidityPools.session.username, "&cYour session has timed out due to inactivity.", config.shopname, "format")
                SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) timed out.")
                SolidityPools.session.is = false
                SolidityPools.session.uuid = ""
                SolidityPools.session.username = ""
                SolidityPools.session.balance = 0
                os.queueEvent("sp_render")
            end
        end
        os.sleep(0)
    end
end

local function sessionTerminator()
    local config = SolidityPools.config
    while true do
        if SolidityPools.session.is then
            if not utils.isPlayerClose(SolidityPools.session.username) then
                chatbox.tell(SolidityPools.session.username, "&cYour session has ended, because you moved too far away from the shop.", config.shopname, "format")
                SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) moved too far away.")
                SolidityPools.session.is = false
                SolidityPools.session.uuid = ""
                SolidityPools.session.username = ""
                SolidityPools.session.balance = 0
                os.queueEvent("sp_render")
            end
        end
        os.sleep(5)
    end
end

local function sessionManager()
    while not SolidityPools.itemsLoaded do
        os.sleep(0)
    end
    parallel.waitForAny(itemSell, sessionTimeout, sessionTerminator)
end

return sessionManager