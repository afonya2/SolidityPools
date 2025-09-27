local utils = require("utils")

local function sendShopsync()
    local config = SolidityPools.config
    local sentItems = {}
    for k,v in pairs(SolidityPools.items) do
        for kk, vv in ipairs(v) do
            local queryP = SolidityPools.BIL.processQuery(vv.query)
            local p1 = utils.calculatePrice(vv, 1)/1000000
            local p2 = utils.calculatePrice(vv, 1, true)/1000000
            p1 = math.max(0.001, math.min(999999, p1))
            p2 = math.max(0.001, math.min(999999, p2))
            table.insert(sentItems, {
                prices = {
                    {
                        value = p1,
                        currency = "KRO",
                        address = (config.kromerName ~= nil and config.kromerName..".kro" or config.address)
                    }
                },
                item = {
                    name = queryP.itemId,
                    nbt = (queryP.query and queryP.query.nbt or nil),
                    displayName = vv.name
                },
                dynamicPrice = true,
                stock = math.min(vv.allocated, vv.count),
                madeOnDemand = false,
                requiresInteraction = true
            })
            table.insert(sentItems, {
                shopBuysItem = true,
                prices = {
                    {
                        value = p2,
                        currency = "KRO",
                        address = (config.kromerName ~= nil and config.kromerName..".kro" or config.address)
                    }
                },
                item = {
                    name = queryP.itemId,
                    nbt = (queryP.query and queryP.query.nbt or nil),
                    displayName = vv.name
                },
                dynamicPrice = true,
                stock = math.min(vv.allocated, vv.count),
                noLimit = false
            })
        end
    end
    local ssData = {
        type = "ShopSync",
        version = 1,
        info = {
            name = config.shopname,
            description = config.description,
            owner = table.concat(config.owners, ", "),
            computerID = os.getComputerID(),
            multiShop = nil,
            software = {
                name = "SolidityPools",
                version = SolidityPools.version
            },
            location = {
                coordinates = { SolidityPools.location.x, SolidityPools.location.y, SolidityPools.location.z }
            }
        },
        items = sentItems
    }

    local channel = 9773
    local modem = SolidityPools.modem.wrap
    modem.transmit(channel, os.getComputerID() % 65536, ssData)
end

local function shopsync()
    while not SolidityPools.itemsLoaded do
        os.sleep(0)
    end
    os.sleep(math.random(15, 30))
    sendShopsync()
    while true do
        if SolidityPools.sendShopsync then
            sendShopsync()
            SolidityPools.sendShopsync = false
        end
        os.sleep(30)
    end
end

return shopsync