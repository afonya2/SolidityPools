local function itemManager()
    local lastRescan = os.clock()
    while true do
        if os.clock() - lastRescan > 20 then
            lastRescan = os.clock()
            SolidityPools.storage.rescanAll()
            for k, v in pairs(SolidityPools.items) do
                for kk,vv in ipairs(v) do
                    local count = SolidityPools.storage.getItemCount(vv.query)
                    SolidityPools.items[k][kk].count = count
                end
            end
            SolidityPools.itemsLoaded = true
        end
        os.sleep(0)
    end
end

return itemManager