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
        local highestItemAccepted = item.itemLimit - item.count
        local soldCount = math.min(itemCount, highestItemAccepted)
        if soldCount < 1 then
            chatbox.tell(SolidityPools.session.username, "&cItem limit reached. The shop is not accepting any more of this item.", config.shopname, "format")
            turtle.drop()
            SolidityPools.lockInv = false
            return
        end
        local remainder = itemCount - soldCount
        local price, pricei = utils.calculatePrice(item, soldCount, true)
        local userData = utils.loadUser(SolidityPools.session.uuid)
        SolidityPools.session.balance = SolidityPools.session.balance + price
        SolidityPools.items[icat][ipos].allocated = item.allocated + soldCount
        SolidityPools.items[icat][ipos].allocatedMoney = item.allocatedMoney - price
        SolidityPools.items[icat][ipos].count = item.count + soldCount
        utils.saveCategory(icat, SolidityPools.items[icat])
        userData.balance = SolidityPools.session.balance
        utils.saveUser(SolidityPools.session.uuid, userData)
        os.queueEvent("sp_render")
        chatbox.tell(SolidityPools.session.username, "&aYou sold &7x"..soldCount.." "..item.name.."&a for &6"..(price/1000000).."kro &7("..(pricei/1000000).."kro/i)", config.shopname, "format")
        SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) sold `x" .. soldCount .. " " .. item.name .. "` for " .. (price/1000000) .. "kro" .. " (`" .. pricei/1000000 .. "kro/i`)")
        if remainder > 0 then
            turtle.drop(remainder)
        end
        SolidityPools.storage.importItems("turtle", item.query, soldCount)
        SolidityPools.lockInv = false
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
    parallel.waitForAny(itemSell, sessionTimeout, sessionTerminator)
end

return sessionManager