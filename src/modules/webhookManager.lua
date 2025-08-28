local function webhookManager()
    while true do
        if SolidityPools.config.webhook then
            local message = ""
            while #SolidityPools.discordCache > 0 do
                if #(message .. SolidityPools.discordCache[1] .. "\n") > 1500 then
                    break
                end
                message = message .. table.remove(SolidityPools.discordCache, 1) .. "\n"
            end
            if #message > 0 then
                SolidityPools.dw.sendMessage(SolidityPools.config.webhook_url, SolidityPools.config.shopname, nil, message)
            end
        end
        os.sleep(30)
    end
end

return webhookManager