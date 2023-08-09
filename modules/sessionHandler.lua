local config = nil
local items = nil
local BIL = nil
local loggedIn = nil
local dw = nil

local function loadCache(filename)
    local fa = fs.open(filename, "r")
    local fi = fa.readAll()
    fi = fi:gsub("SYSTEM CACHE, DO NOT EDIT!","")
    fa.close()
    return textutils.unserialise(fi)
end
local function saveCache(filename, data)
    local fa = fs.open(filename, "w")
    fa.write("SYSTEM CACHE, DO NOT EDIT!"..textutils.serialise(data))
    fa.close()
end

local function computeDP(item, count, sell)
    if sell then
        local mprice = item.normalPrice
        mprice = mprice - (mprice * (config.tradingFees/100))
        if config.dynamicPricing or item.forcePrice then
            if item.count == 0 then
                return mprice * count
            else
                return (item.normalStock/(item.count+count-1))*mprice*count
            end
        else
            return mprice * count
        end
    else
        local mprice = item.normalPrice
        mprice = mprice + (mprice * (config.tradingFees/100))
        if config.dynamicPricing or item.forcePrice then
            if item.count == 0 then
                return mprice * count
            elseif item.count-count < 0 then
                return math.huge
            else
                return (item.normalStock/(item.count-count+1))*mprice*count
            end
        else
            return mprice * count
        end
    end
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

function sessionHandler()
    config = SolidityPools.config
    items = SolidityPools.items
    BIL = SolidityPools.BIL
    loggedIn = SolidityPools.loggedIn
    dw = SolidityPools.dw
    local function itemPup()
        while true do
            os.sleep(0)
        end
    end
    local function sessionVerifier()
        while true do
            if loggedIn.is then
                if not isPlayerClose(loggedIn.username) then
                    loggedIn.saveUser()
                    chatbox.tell(loggedIn.username, "&aYour remaining &e"..loggedIn.balance.."kst &awill be stored for your next purchase", config.shopname, nil, "format")
                    loggedIn.is = false
                    loggedIn.username = ""
                    loggedIn.uuid = ""
                    loggedIn.loadUser()
                    os.queueEvent("sp_rerender")
                end
            end
            os.sleep(0)
        end 
    end
    parallel.waitForAny(itemPup, sessionVerifier)
end

return sessionHandler