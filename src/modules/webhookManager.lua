local function webhookManager()
    while true do
        if SolidityPools.config.webhook then
            local message = ""
            local del = 0
            while #SolidityPools.discordCache > 0 do
                if #(message .. SolidityPools.discordCache[1] .. "\n") > 1500 then
                    break
                end
                message = message .. SolidityPools.discordCache[del+1] .. "\n"
                del = del + 1
            end
            if #message > 0 then
                local ok, err = pcall(SolidityPools.dw.sendMessage, SolidityPools.config.webhook_url, SolidityPools.config.shopname, nil, message)
                if not ok then
                    print("Error sending webhook message: " .. err)
                else
                    for i = 1, del do
                        table.remove(SolidityPools.discordCache, 1)
                    end
                end
            end
        end
        os.sleep(30)
    end
end

return webhookManager