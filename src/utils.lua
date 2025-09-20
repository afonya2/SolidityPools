local function calculatePrice(item, quantity, isSell)
    local itemAmount = math.min(item.allocated, item.count)
    local moneyAmount = math.floor(math.min(item.allocatedMoney, SolidityPools.balance))
    if quantity == 0 then
        return math.floor(moneyAmount / itemAmount), math.floor(moneyAmount / itemAmount), 0
    end
    local price = 0
    for i=1, quantity do
        if isSell then
            itemAmount = itemAmount + 1
        else
            itemAmount = itemAmount - 1
        end
        if (itemAmount < 5) and (not isSell) then
            price = math.huge
            break
        end
        if (itemAmount > item.itemLimit) and isSell then
            price = 0
            break
        end
        local temp = math.floor(moneyAmount / itemAmount)
        price = price + temp
        if isSell then
            moneyAmount = moneyAmount - temp
        else
            moneyAmount = moneyAmount + temp
        end
        if (moneyAmount < 50000) and isSell then
            price = 0
            break
        end
        if i % 1000 == 0 then
            os.sleep(0)
        end
    end
    local tradingFees = math.floor(price * (SolidityPools.config.tradingFees/100))
    if isSell then
        price = price - tradingFees
    else
        price = price + tradingFees
    end
    return math.floor(price), math.floor(price / quantity), tradingFees
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
            apiChest = nil,
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

local function includes(tbl, data)
    for k, v in pairs(tbl) do
        if v == data then
            return true, k
        end
    end
    return false
end

local function findUserByUUIDOrName(identifier)
    if string.match(identifier, "-") == "-" then
        return loadUser(identifier), identifier
    else
        local users = fs.list("/users/")
        for _, user in ipairs(users) do
            local fi = fs.open("/users/"..user, "r")
            local data = textutils.unserialize(fi.readAll())
            fi.close()
            if data.name:lower() == identifier:lower() then
                return data, user:gsub(".txt", "")
            end
        end
    end
end

local function getShopData()
    if fs.exists("shopdata.txt") then
        local f = fs.open("shopdata.txt", "r")
        local data = textutils.unserialize(f.readAll())
        f.close()
        return data
    else
        return {
            transactionFees = 0
        }
    end
end

local function saveShopData(data)
    local f = fs.open("shopdata.txt", "w")
    f.write(textutils.serialize(data))
    f.close()
end

local function getRealBalance()
    local bal = SolidityPools.kapi.getBalance(SolidityPools.config.address)*1000000
    local shopData = getShopData()
    local userBalances = 0
    local users = fs.list("/users/")
    for k,v in ipairs(users) do
        local fi = fs.open("/users/"..v, "r")
        local data = textutils.unserialize(fi.readAll())
        fi.close()
        userBalances = userBalances + data.balance
    end
    os.sleep(0)
    local itemAllocations = 0
    for k,v in pairs(SolidityPools.items) do
        for kk, vv in ipairs(v) do
            itemAllocations = itemAllocations + vv.allocatedMoney
        end
    end
    local realBalance = bal - shopData.transactionFees - userBalances - itemAllocations
    return realBalance,
        { all = bal, fees = shopData.transactionFees, userBalances = userBalances, itemAllocations = itemAllocations, unallocated = realBalance },
        { all = 100, fees = math.floor(shopData.transactionFees / bal * 10000)/100, userBalances = math.floor(userBalances / bal * 10000)/100, itemAllocations = math.floor(itemAllocations / bal * 10000)/100, unallocated = math.floor(realBalance / bal * 10000)/100 }
end

local function copy(tbl, deep)
    local out = {}
    for k,v in pairs(tbl) do
        if deep and type(v) == "table" then
            out[k] = copy(v, deep)
        else
            out[k] = v
        end
    end
    return out
end

local function positionMessage(msgObj)
    local x = (msgObj.collected.center^2 - msgObj.collected.x^2 + 4) / 4
    local y = (msgObj.collected.center^2 - msgObj.collected.y^2 + 4) / 4
    local z = (msgObj.collected.center^2 - msgObj.collected.z^2 + 4) / 4
    x = x + SolidityPools.config["modem_pos"].x
    y = y + SolidityPools.config["modem_pos"].y
    z = z + SolidityPools.config["modem_pos"].z
    return {x = x, y = y, z = z}
end

local function base10ToBase16(n)
    local convo = {[0]="0",[1]="1",[2]="2",[3]="3",[4]="4",[5]="5",[6]="6",[7]="7",[8]="8",[9]="9",[10]="a",[11]="b",[12]="c",[13]="d",[14]="e",[15]="f"}
    local out = ""
    while n > 0 do
        out = convo[n%16] .. out
        n = math.floor(n/16)
    end
    return out
end

local function bytesToHexString(tbl)
    local out = ""
    for i=1,#tbl do
        local temp = base10ToBase16(tbl[i])
        if #temp == 1 then
            temp = "0" .. temp
        end
        out = out .. temp
    end
    return out
end

local function getOrdersOfUser(uuid)
    local orders = {}
    for k,v in ipairs(SolidityPools.orderQueue) do
        if v.user == uuid then
            local ordr = copy(v, true)
            ordr.expectedTime = math.floor(os.epoch("utc")/1000) + (k * 30)
            table.insert(orders, ordr)
        end
    end
    return orders
end

local function safeSerialise(tbl)
    local tType = type(tbl)
    if tType == "table" then
        local keys = {}
        for k in pairs(tbl) do
            table.insert(keys, k)
        end
        table.sort(keys)

        local result = {}
        table.insert(result, "{")
        for i, k in ipairs(keys) do
            local v = tbl[k]
            table.insert(result, "[" .. safeSerialise(k) .. "]=" .. safeSerialise(v))
            table.insert(result, ",")
        end
        table.insert(result, "}")
        return table.concat(result)
    elseif tType == "string" then
        return string.format("%q", tbl)
    elseif tType == "number" or tType == "boolean" or tType == "nil" then
        return tostring(tbl)
    else
        error("unsupported type: " .. tType)
    end
end

return {
    calculatePrice = calculatePrice,
    isPlayerClose = isPlayerClose,
    loadUser = loadUser,
    saveUser = saveUser,
    queryItem = queryItem,
    saveCategory = saveCategory,
    generateRanStr = generateRanStr,
    includes = includes,
    findUserByUUIDOrName = findUserByUUIDOrName,
    getRealBalance = getRealBalance,
    getShopData = getShopData,
    saveShopData = saveShopData,
    copy = copy,
    positionMessage = positionMessage,
    base10ToBase16 = base10ToBase16,
    bytesToHexString = bytesToHexString,
    getOrdersOfUser = getOrdersOfUser,
    safeSerialise = safeSerialise
}