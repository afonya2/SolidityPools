-- fix 1 item issues
-- escrow the 5%
-- calculate SPs balance by removing the debt
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

local function isPlayerClose(name)
    local man = peripheral.find("manipulator")
    for k,v in ipairs(man.sense()) do
        if (v.key == "minecraft:player") and (v.name:lower() == name:lower()) then
            return true
        end
    end
    return false
end

local function loadUser(uuid)
    if fs.exists("/users/"..uuid..".txt") then
        local file = fs.open("/users/"..uuid..".txt", "r")
        local data = textutils.unserialize(file.readAll())
        file.close()
        return data
    else
        return {
            uuid = uuid,
            name = "Unknown",
            balance = 0,
            isBanned = nil,
            isApiBanned = nil,
            apiKey = nil,
            agreed = false
        }
    end
end

local function saveUser(uuid, data)
    local file = fs.open("/users/"..uuid..".txt", "w")
    file.write(textutils.serialize(data, { allow_repetitions = true }))
    file.close()
end

local function saveCategory(cat, data)
    local file = fs.open("/items/"..cat..".conf", "w")
    file.write(textutils.serialize(data, { allow_repetitions = true }))
    file.close()
end

local function matchStr(a, b)
    local len = math.max(#a, #b)
    if len == 0 then return 100 end
    local match = 0
    for i = 1, len do
        if a:sub(i, i) == b:sub(i, i) then
            match = match + 1
        end
    end
    return math.floor(match / len * 100)
end

local function queryItem(name)
    local match = {}
    for catk, cat in pairs(SolidityPools.items) do
        for k,v in ipairs(cat) do
            local m = math.max(
                matchStr(v.name:gsub(" ", ""):lower(), name:lower()),
                matchStr(v.name:gsub(" ", "_"):lower(), name:lower())
            )
            for kk, alias in ipairs(v.aliases) do
                m = math.max(m, matchStr(alias:lower(), name:lower()))
            end
            match[v.name:gsub(" ", ""):lower()] = m
            if m == 100 then
                return match, v, catk, k
            end
        end
    end
    return match
end

local function generateRanStr(len)
    local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._+-*/"
    local str = ""
    for i = 1, len do
        local ran = math.random(1, #chars)
        str = str .. chars:sub(ran, ran)
    end
    return str
end

return {
    calculatePrice = calculatePrice,
    isPlayerClose = isPlayerClose,
    loadUser = loadUser,
    saveUser = saveUser,
    queryItem = queryItem,
    saveCategory = saveCategory,
    generateRanStr = generateRanStr
}