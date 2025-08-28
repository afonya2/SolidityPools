local utils = require("../utils")

local function sessionTimeout()
    local config = SolidityPools.config
    while true do
        if SolidityPools.session.is then
            if os.clock()-SolidityPools.session.lastActive > 60 then
                chatbox.tell(SolidityPools.session.username, "&cYour session has timed out due to inactivity.", config.shopname, "format")
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
    parallel.waitForAny(sessionTimeout, sessionTerminator)
end

return sessionManager