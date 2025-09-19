local wirmodem = {id = nil, wrap = nil}
for k,v in ipairs({"top", "right", "left", "bottom", "behind", "front"}) do
    local t = peripheral.getType(v)
    local wrp = peripheral.wrap(v)
    if t == "modem" then
        if not wrp.isWireless() then
            wirmodem.id = v
            wirmodem.wrap = wrp
            break
        end
    end
end
if wirmodem.id == nil then
    error("No wired modem found")
end

wirmodem.wrap.open(2646)
while true do
    local event, side, channel, replyChannel, message = os.pullEvent("modem_message")
    if (side == wirmodem.id) and (channel == 2646) then
        local ok, data = pcall(textutils.unserialize, message)
        if ok then
            if data.mode == "place" then
                local chest = peripheral.wrap(data.chest)
                if not turtle.detect() then
                    if chest.getItemDetail(data.pos) ~= nil then
                        chest.pushItems(wirmodem.wrap.getNameLocal(), data.pos, 1, 1)
                        turtle.place()
                        wirmodem.wrap.transmit(replyChannel, 2646, textutils.serialise({ mode = "ok" }))
                    else
                        wirmodem.wrap.transmit(replyChannel, 2646, textutils.serialise({ mode = "fail", message = "No item found in the specified slot." }))
                    end
                else
                    wirmodem.wrap.transmit(replyChannel, 2646, textutils.serialise({ mode = "fail", message = "Something is already placed." }))
                end
            elseif data.mode == "break" then
                local chest = peripheral.wrap(data.chest)
                if turtle.detect() then
                    turtle.dig()
                    chest.pullItems(wirmodem.wrap.getNameLocal(), 1, 1, data.pos)
                    wirmodem.wrap.transmit(replyChannel, 2646, textutils.serialise({ mode = "ok" }))
                else
                    wirmodem.wrap.transmit(replyChannel, 2646, textutils.serialise({ mode = "fail", message = "Nothing is placed." }))
                end
            elseif data.mode == "check" then
                local chest = peripheral.wrap(data.chest)
                if not turtle.detect() then
                    if chest.getItemDetail(data.pos) ~= nil then
                        chest.pushItems(wirmodem.wrap.getNameLocal(), data.pos, 1, 1)
                        turtle.place()
                        os.sleep(1)
                        local wrp = peripheral.wrap("front")
                        if wrp.isPersonal() and wrp.getOwner() == data.user then
                            wirmodem.wrap.transmit(replyChannel, 2646, textutils.serialise({ mode = "ok" }))
                        else
                            wirmodem.wrap.transmit(replyChannel, 2646, textutils.serialise({ mode = "fail", message = "The item is not owned by the user." }))
                        end
                        turtle.dig()
                        chest.pullItems(wirmodem.wrap.getNameLocal(), 1, 1, data.pos)
                    else
                        wirmodem.wrap.transmit(replyChannel, 2646, textutils.serialise({ mode = "fail", message = "No item found in the specified slot." }))
                    end
                else
                    wirmodem.wrap.transmit(replyChannel, 2646, textutils.serialise({ mode = "fail", message = "Something is already placed." }))
                end
            else
                wirmodem.wrap.transmit(replyChannel, 2646, textutils.serialise({ mode = "fail", message = "Invalid mode." }))
            end
        else
            print("Received invalid data: " .. data)
        end
    end
end