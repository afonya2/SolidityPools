local utils = require("utils")

local function initSocket()
    local ok, socket = pcall(SolidityPools.kapi.websocket)
    if not ok then
        print("Failed to initialize websocket: " .. socket)
        return
    end
    socket.send(textutils.serialiseJSON({
        type = "subscribe",
        id = 1,
        event = "transactions"
    }))
    SolidityPools.ws = socket
    SolidityPools.kromerConnected = true
end

local function isUserOnline(uuid)
    for k,v in ipairs(chatbox.getPlayers()) do
        if v.uuid == uuid then
            return true
        end
    end
    return false
end

local function mindTrans(trans)
    return (trans.to == SolidityPools.config.address) and (trans.meta.donate ~= "true") and ((SolidityPools.config.kristName == nil) or (trans.sent_name == SolidityPools.config.kristName))
end

local function returnKrist(trans,amount,message)
    local kapi = SolidityPools.kapi
    local config = SolidityPools.config
    if trans.meta["return"] then
        kapi.makeTransaction(config.privateKey, trans.from, amount, trans.meta["return"]..(message ~= nil and ";message="..message or ""))
    else
        kapi.makeTransaction(config.privateKey, trans.from, amount, (message ~= nil and "message="..message or ""))
    end
end

local function onSocket(data)
    local kapi = SolidityPools.kapi
    local config = SolidityPools.config
    if (data.type ~= "event") or (data.event ~= "transaction") then
        return
    end
    local trans = data.transaction
    trans.meta = kapi.parseMeta(trans.metadata)
    if not mindTrans(trans) then
        return
    end
    if trans.meta.useruuid == nil then
        returnKrist(trans, trans.value, "You must pay from RCC or you must specify useruuid in the metadata")
        return
    end
    local userData = utils.loadUser(trans.meta.useruuid)
    local pb = userData.balance
    userData.balance = userData.balance + trans.value*1000000
    if SolidityPools.session.is and (SolidityPools.session.uuid == trans.meta.useruuid) then
        SolidityPools.session.balance = userData.balance
        os.queueEvent("sp_render")
    end
    utils.saveUser(trans.meta.useruuid, userData)
    SolidityPools.logDiscordMessage("User: `" .. userData.name:lower() .. "` (`" .. trans.meta.useruuid .. "`) deposited " .. trans.value .. "kro from `" .. trans.from .. "`; ID: `" .. trans.id .. "`\nBalance: `" .. (pb/1000000) .. "kro -> " .. (userData.balance/1000000) .. "kro`")
    if isUserOnline(trans.meta.useruuid) then
        chatbox.tell(userData.name, "&7"..trans.value.."kro &ahave been deposited into your account.", config.shopname, "format")
    end
end

local function kromerManager()
    initSocket()
    os.queueEvent("sp_render")
    while true do
        if SolidityPools.ws ~= nil then
            local ok,data = pcall(SolidityPools.ws.receive)
            if ok then
                if not data then
                    print("No socket message was received...")
                    SolidityPools.kromerConnected = false
                    os.queueEvent("sp_render")
                else
                    local ok,json = pcall(textutils.unserializeJSON, data)
                    if ok then
                        SolidityPools.kromerConnected = true
                        os.queueEvent("sp_render")
                        onSocket(json)
                    else
                        print("Failed to unserialize JSON data. "..json)
                        SolidityPools.kromerConnected = false
                        os.queueEvent("sp_render")
                    end
                end
            else
                SolidityPools.ws.close()
                SolidityPools.kromerConnected = false
                os.queueEvent("sp_render")
                os.sleep(20)
                initSocket()
            end
        else
            SolidityPools.kromerConnected = false
            os.queueEvent("sp_render")
            os.sleep(20)
            initSocket()
        end
    end
end

return kromerManager