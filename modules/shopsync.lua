local config = nil
local items = nil
local BIL = nil

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
        if config.dynamicPricing and (not item.forcePrice) then
            if item.count == 0 then
                return mprice * count
            else
                return (item.normalStock/(item.count+count))*mprice*count
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

local function getWModem()
    local peps = peripheral.getNames()
    for k,v in ipairs(peps) do
        local t = peripheral.getType(v)
        if t == "modem" then
            if peripheral.wrap(v).isWireless() then
                return peripheral.wrap(v)
            end
        end
    end
end

local function sendShopsync()
    local coords = {gps.locate()}
    local itms = {}
    for k,v in pairs(items) do
        for kk,vv in ipairs(v) do
            local procs = BIL.processQuery(vv.query)
            table.insert(itms, {
                prices = {
                    {
                        value = math.floor(computeDP(vv, 1)*1000)/1000,
                        currency = "KST",
                        address = (config.kristName ~= nil and (config.kristName..".kst") or config.address)
                    }
                },
                item = {
                    name = procs.itemId,
                    nbt = (procs.query ~= nil and procs.query.nbt or nil),
                    displayName = vv.name,
                },
                dynamicPrice = (config.dynamicPricing and (not vv.forcePrice)),
                stock = vv.count,
                madeOnDemand = false,
                requiresInteraction = true
            })
            table.insert(itms, {
                shopBuysItem = true,
                prices = {
                    {
                        value = math.floor(computeDP(vv, 1, true)*1000)/1000,
                        currency = "KST"
                    }
                },
                item = {
                    name = procs.itemId,
                    nbt = (procs.query ~= nil and procs.query.nbt or nil),
                    displayName = vv.name,
                },
                dynamicPrice = (config.dynamicPricing and (not vv.forcePrice)),
                stock = vv.count,
                noLimit = true
            })
        end 
    end
    local data = {
        ["type"] = "ShopSync",
        info = {
            name = config.shopname,
            description = config.description,
            owner = config.owner,
            computerID = os.getComputerID(),
            software = {
                name = "SolidityPools",
                version = SolidityPools.version
            },
            location = {
                coordinates = coords
            }
        },
        items = itms
    }
    local mods = getWModem()
    mods.transmit(9773, os.getComputerID()%65536, data)
end

function shopsync()
    config = SolidityPools.config
    items = SolidityPools.items
    BIL = SolidityPools.BIL
    local mods = getWModem()
    if mods == nil then
        bsod("No wireless modem found")
    end
    while (not SolidityPools.pricesLoaded) or (not SolidityPools.countsLoaded) do
        os.sleep(0)
    end
    os.sleep(math.random() * 15 + 15)
    sendShopsync()
    local was = false
    while true do
        if SolidityPools.itemChangeInfo.is then
            was = true
        end
        if (not SolidityPools.itemChangeInfo.is) and was then
            sendShopsync()
            was = false
            os.sleep(30)
        end
        os.sleep(0)
    end
end

return shopsync