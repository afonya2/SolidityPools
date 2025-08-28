local utils = require("../utils")

local helpText = [[Available commands:
- `help` - Display this message
- `kick` - Forcefully terminate a session
- `ban <user> <reason>` - Ban a user
- `unban <user>` - Unban a user
- `apiban <user> <reason>` - API ban a user
- `unapiban <user>` - Unban a user from the API
- `allocate <item> (money/item) <delta-value>` - Allocate or deallocate money or items to/from an item
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
    else
        chatbox.tell(user, "&cUnknown command. &aType &7\\"..config.command.." admin help &afor a list of commands.", config.shopname, "format")
    end
end

return adminCommands