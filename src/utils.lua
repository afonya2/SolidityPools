local function calculatePrice(item, quantity, isSell)
    local itemAmount = math.min(item.allocated, item.count)
    local moneyAmount = math.floor(math.min(item.allocatedMoney, SolidityPools.balance))
    if quantity == 0 then
        return math.floor(moneyAmount / itemAmount), math.floor(moneyAmount / itemAmount)
    end
    local price = 0
    for i=1, quantity do
        if (itemAmount < 1) and (not isSell) then
            price = math.huge
            break
        end
        if (moneyAmount < 10000) and isSell then
            price = 0
            break
        elseif (moneyAmount < 10000) and (not isSell) then
            price = math.huge
            break
        end
        if isSell then
            itemAmount = itemAmount + 1
        else
            itemAmount = itemAmount - 1
        end
        local temp = math.floor(moneyAmount / itemAmount)
        price = price + temp
        if isSell then
            moneyAmount = moneyAmount - temp
        else
            moneyAmount = moneyAmount + temp
        end
    end
    if isSell then
        price = price - price * (SolidityPools.config.tradingFees/100)
    else
        price = price + price * (SolidityPools.config.tradingFees/100)
    end
    return math.floor(price), math.floor(price / quantity)
end

return {
    calculatePrice = calculatePrice
}