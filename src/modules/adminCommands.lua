local utils = require("../utils")

local helpText = [[Available commands:
- `help` - Display this message
- `kick` - Forcefully terminate a session
- `ban <user> <reason>` - Ban a user
- `unban <user>` - Unban a user
- `apiban <user> <reason>` - API ban a user
- `unapiban <user>` - Unban a user from the API
- `allocate <item> (money/item) <delta-value>` - Allocate or deallocate money or items to/from an item, internal value for money
- `setItemLimit <item> <limit>` - Set the limit for an item
- `balance/bal <user>` - Check a user's balance
- `changebal <user> <delta-value>` - Change a user's balance, internal value
]]

local function adminCommands(user, args, data, userData)
    local config = SolidityPools.config
    if args[2] == "help" then
        chatbox.tell(user, helpText, config.shopname)
    elseif args[2] == "kick" then
        if not SolidityPools.session.is then
            chatbox.tell(user, "&cThere is no active session to terminate.", config.shopname, "format")
            return
        end
        chatbox.tell(SolidityPools.session.username, "&cYour session have been terminated.", config.shopname, "format")
        chatbox.tell(user, "&aSession terminated.", config.shopname, "format")
        SolidityPools.logDiscordMessage("User: `" .. SolidityPools.session.username:lower() .. "` (`" .. SolidityPools.session.uuid .. "`) was kicked.")
        SolidityPools.session.is = false
        SolidityPools.session.uuid = ""
        SolidityPools.session.username = ""
        SolidityPools.session.balance = 0
        os.queueEvent("sp_render")
    elseif args[2] == "ban" then
        if #args < 4 then
            chatbox.tell(user, "&cPlease specify a user and a reason.", config.shopname, "format")
            return
        end
        local targetUser = args[3]
        local reason = table.concat(args, " ", 4)
        local targetData, targetUUID = utils.findUserByUUIDOrName(targetUser)
        if not targetData then
            chatbox.tell(user, "&cUser not found.", config.shopname, "format")
            return
        end
        if targetData.isBanned ~= nil then
            chatbox.tell(user, "&cUser is already banned.", config.shopname, "format")
            return
        end
        targetData.isBanned = reason
        utils.saveUser(targetUUID, targetData)
        chatbox.tell(user, "&aBanned user: &7" .. targetData.name .. " (&7" .. targetUUID .. ") &afor reason: &7" .. reason, config.shopname, "format")
        SolidityPools.logDiscordMessage("User: `" .. targetData.name:lower() .. "` (`" .. targetUUID .. "`) was banned for: `" .. reason.."`")
    elseif args[2] == "unban" then
        if #args < 3 then
            chatbox.tell(user, "&cPlease specify a user.", config.shopname, "format")
            return
        end
        local targetUser = args[3]
        local targetData, targetUUID = utils.findUserByUUIDOrName(targetUser)
        if not targetData then
            chatbox.tell(user, "&cUser not found.", config.shopname, "format")
            return
        end
        if targetData.isBanned == nil then
            chatbox.tell(user, "&cUser is not banned.", config.shopname, "format")
            return
        end
        targetData.isBanned = nil
        utils.saveUser(targetUUID, targetData)
        chatbox.tell(user, "&aUnbanned user: &7" .. targetData.name .. " (&7" .. targetUUID .. ")", config.shopname, "format")
        SolidityPools.logDiscordMessage("User: `" .. targetData.name:lower() .. "` (`" .. targetUUID .. "`) was unbanned")
    elseif args[2] == "apiban" then
        if #args < 4 then
            chatbox.tell(user, "&cPlease specify a user and a reason.", config.shopname, "format")
            return
        end
        local targetUser = args[3]
        local reason = table.concat(args, " ", 4)
        local targetData, targetUUID = utils.findUserByUUIDOrName(targetUser)
        if not targetData then
            chatbox.tell(user, "&cUser not found.", config.shopname, "format")
            return
        end
        if targetData.isApiBanned ~= nil then
            chatbox.tell(user, "&cUser is already banned.", config.shopname, "format")
            return
        end
        targetData.isApiBanned = reason
        utils.saveUser(targetUUID, targetData)
        chatbox.tell(user, "&aAPI Banned user: &7" .. targetData.name .. " (&7" .. targetUUID .. ") &afor reason: &7" .. reason, config.shopname, "format")
        SolidityPools.logDiscordMessage("User: `" .. targetData.name:lower() .. "` (`" .. targetUUID .. "`) was api banned for: `" .. reason.."`")
    elseif args[2] == "unapiban" then
        if #args < 3 then
            chatbox.tell(user, "&cPlease specify a user.", config.shopname, "format")
            return
        end
        local targetUser = args[3]
        local targetData, targetUUID = utils.findUserByUUIDOrName(targetUser)
        if not targetData then
            chatbox.tell(user, "&cUser not found.", config.shopname, "format")
            return
        end
        if targetData.isApiBanned == nil then
            chatbox.tell(user, "&cUser is not banned.", config.shopname, "format")
            return
        end
        targetData.isApiBanned = nil
        utils.saveUser(targetUUID, targetData)
        chatbox.tell(user, "&aAPI Unbanned user: &7" .. targetData.name .. " (&7" .. targetUUID .. ")", config.shopname, "format")
        SolidityPools.logDiscordMessage("User: `" .. targetData.name:lower() .. "` (`" .. targetUUID .. "`) was api unbanned")
    elseif args[2] == "allocate" then
        if #args < 5 then
            chatbox.tell(user, "&cPlease specify an item, a type and a delta-value.", config.shopname, "format")
            return
        end
        local amount = tonumber(args[5])
        if (amount == nan) or (math.floor(amount) ~= amount) or (amount == 0) then
            chatbox.tell(user, "&cPlease specify a valid value.", config.shopname, "format")
            return
        end
        local possible, item, cat, pos = utils.queryItem(args[3])
        if item then
            if args[4] == "item" then
                SolidityPools.items[cat][pos].allocated = item.allocated + amount
                utils.saveCategory(cat, SolidityPools.items[cat])
                chatbox.tell(user, "&aSuccessfully changed allocated items of &7"..item.name.."&a by &7"..amount.."&a. New allocated items: &7"..SolidityPools.items[cat][pos].allocated, config.shopname, "format")
            elseif args[4] == "money" then
                SolidityPools.items[cat][pos].allocatedMoney = item.allocatedMoney + amount
                utils.saveCategory(cat, SolidityPools.items[cat])
                chatbox.tell(user, "&aSuccessfully changed allocated money of &7"..item.name.."&a by &6"..(amount/1000000).."kro&a. New allocated money: &6"..(SolidityPools.items[cat][pos].allocatedMoney/1000000).."kro", config.shopname, "format")
            else
                chatbox.tell(user, "&cPlease specify a valid type (money/item).", config.shopname, "format")
                return
            end
            os.queueEvent("sp_render")
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
    elseif args[2] == "setItemLimit" then
        if #args < 4 then
            chatbox.tell(user, "&cPlease specify an item and a limit.", config.shopname, "format")
            return
        end
        local limit = tonumber(args[4])
        if (limit == nan) or (math.floor(limit) ~= limit) or (limit == 0) then
            chatbox.tell(user, "&cPlease specify a valid value.", config.shopname, "format")
            return
        end
        local possible, item, cat, pos = utils.queryItem(args[3])
        if item then
            SolidityPools.items[cat][pos].itemLimit = limit
            utils.saveCategory(cat, SolidityPools.items[cat])
            chatbox.tell(user, "&aSuccessfully changed item limit of &7"..item.name.."&a to &7"..limit.."&a.", config.shopname, "format")
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
    elseif (args[2] == "balance") or (args[2] == "bal") then
        if #args < 3 then
            chatbox.tell(user, "&cPlease specify a user.", config.shopname, "format")
            return
        end
        local targetUser = args[3]
        local targetData, targetUUID = utils.findUserByUUIDOrName(targetUser)
        if not targetData then
            chatbox.tell(user, "&cUser not found.", config.shopname, "format")
            return
        end
        chatbox.tell(user, "&7"..targetData.name.." ("..targetUUID..")&a's balance: &6" .. (targetData.balance/1000000) .. "kro", config.shopname, "format")
    elseif args[2] == "changebal" then
        if #args < 4 then
            chatbox.tell(user, "&cPlease specify a user and a delta-value.", config.shopname, "format")
            return
        end
        local amount = tonumber(args[4])
        if (amount == nan) or (math.floor(amount) ~= amount) or (amount == 0) then
            chatbox.tell(user, "&cPlease specify a valid value.", config.shopname, "format")
            return
        end
        local targetUser = args[3]
        local targetData, targetUUID = utils.findUserByUUIDOrName(targetUser)
        if not targetData then
            chatbox.tell(user, "&cUser not found.", config.shopname, "format")
            return
        end
        targetData.balance = targetData.balance + amount
        utils.saveUser(targetUUID, targetData)
        chatbox.tell(user, "&aSuccessfully changed &7"..targetData.name.."&a's balance to &6" .. (targetData.balance/1000000) .. "kro", config.shopname, "format")
        SolidityPools.logDiscordMessage("User: `" .. targetData.name:lower() .. "` (`" .. targetUUID .. "`)'s balance was set to: " .. (targetData.balance/1000000) .. "kro")
    else
        chatbox.tell(user, "&cUnknown command. &aType &7\\"..config.command.." admin help &afor a list of commands.", config.shopname, "format")
    end
end

return adminCommands