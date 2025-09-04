local function onApiMessage(message, replyChannel)
    print("Got message: " .. message)
end

local function apiServer()
    local config = SolidityPools.config
    local pers = peripheral.getNames()
    local modems = 0
    for k,v in ipairs(pers) do
        local t = peripheral.getType(v)
        if t == "modem" then
            local wrp = peripheral.wrap(v)
            if wrp.isWireless() then
                wrp.open(config.apiChannel)
                modems = modems + 1
            end
        end
    end
    if (modems ~= 4) and config.apiEnabled then
        error("The amount of wireless modems must be 4")
    end
    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        if config.apiEnabled and (channel == config.apiChannel) then
            print(side, distance)
            onApiMessage(message, replyChannel)
        end
    end
end

return apiServer