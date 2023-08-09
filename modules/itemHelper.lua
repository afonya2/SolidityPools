function itemHelper()
    while true do
        if SolidityPools.config.dynamicPricing then
            for k,v in pairs(SolidityPools.items) do
                for kk,vv in ipairs(v) do
                    if vv.forcePrice then
                        SolidityPools.items[k][kk].price = vv.normalPrice
                    else
                        local count = SolidityPools.BIL.getItemCount(vv.query)
                        if count == 0 then
                            SolidityPools.items[k][kk].price = vv.normalPrice
                        else
                            SolidityPools.items[k][kk].price = (vv.normalStock/count)*vv.normalPrice
                        end
                        SolidityPools.items[k][kk].count = count
                    end
                end
            end
        else
            for k,v in pairs(SolidityPools.items) do
                for kk,vv in ipairs(v) do
                    SolidityPools.items[k][kk].price = vv.normalPrice
                    SolidityPools.items[k][kk].count = SolidityPools.BIL.getItemCount(vv.query)
                end
            end
        end
        SolidityPools.pricesLoaded = true
        SolidityPools.countsLoaded = true
        if SolidityPools.itemChangeInfo.is and (os.clock()-SolidityPools.itemChangeInfo.time > 1) then
            SolidityPools.itemChangeInfo.is = false
            SolidityPools.itemChangeInfo.category = ""
            SolidityPools.itemChangeInfo.pos = 0
            SolidityPools.itemChangeInfo.mode = ""
            SolidityPools.itemChangeInfo.time = 0
        end
        os.sleep(0)
    end
end

return itemHelper