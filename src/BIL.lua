local BIL = {}

function mysplit (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

function BIL.processQuery(query)
    local out = {}
    local ms1 = mysplit(query, "?")
    out.itemId = ms1[1]
    out.raw_query = ms1[2]
    out.query = {}
    local ms2 = mysplit(ms1[2] or "", "&")
    for k,v in ipairs(ms2) do
        local ms3 = mysplit(v, "=")
        if ms3[2] == nil then
            ms3[2] = true
        end
        out.query[ms3[1]] = ms3[2]
    end
    if ms1[2] == nil then
        out.query = nil
    end
    return out
end

function BIL.isItemMatch(itemData, query)
    local pq = BIL.processQuery(query)
    if pq.query == nil then
        if itemData.name ~= pq.itemId then
            return false
        end
        return true
    else
        if rawDat.name ~= pq.itemId then
            return false
        end
        for k,v in pairs(pq.query) do
            if itemData[k] ~= v then
                return false
            end
        end
        return true
    end
end


function BIL.listStorages(addTurtle)
    local peps = peripheral.getNames()
    local out = {}
    for k,v in ipairs(peps) do
        local _,t = peripheral.getType(v)
        if t == "inventory" then
            table.insert(out, v)
        end
    end
    if addTurtle then
        table.insert(out, "turtle")
    end
    return out
end


local function generateTurtleInvWrap(tid)
    local out = {}
    out.size = function()
        return 16
    end
    out.list = function()
        local llist = {}
        for i=1,16 do
            llist[i] = turtle.getItemDetail(i)
        end
        return llist
    end
    out.getItemDetail = function(slot)
        return turtle.getItemDetail(slot, true)
    end
    out.getItemLimit = function(slot)
        return turtle.getItemDetail(slot, true).maxCount
    end
    out.pushItems = function(toName, fromSlot, limit, toSlot)
        local wrap = peripheral.wrap(toName)
        return wrap.pullItems(tid, fromSlot, limit, toSlot)
    end
    out.pullItems = function(fromName, fromSlot, limit, toSlot)
        local wrap = peripheral.wrap(fromName)
        return wrap.pushItems(tid, fromSlot, limit, toSlot)
    end
    return out
end

local function generateCustomInvWrap(pid)
    local wrapp = peripheral.wrap(pid)
    local out = {}
    out.size = function()
        return wrapp.size()
    end
    out.list = function()
        return wrapp.list()
    end
    out.getItemDetail = function(slot)
        return wrapp.getItemDetail(slot)
    end
    out.getItemLimit = function(slot)
        return wrapp.getItemLimit(slot)
    end
    out.pushItems = function(toName, fromSlot, limit, toSlot)
        if (toName == "turtle") and (turtle ~= nil) then
            local mod = peripheral.find("modem")
            return wrapp.pushItems(mod.getNameLocal(), fromSlot, limit, toSlot)
        else
            return wrapp.pushItems(toName, fromSlot, limit, toSlot)
        end
    end
    out.pullItems = function(fromName, fromSlot, limit, toSlot)
        if (fromName == "turtle") and (turtle ~= nil) then
            local mod = peripheral.find("modem")
            return wrapp.pullItems(mod.getNameLocal(), fromSlot, limit, toSlot)
        else
            return wrapp.pullItems(fromName, fromSlot, limit, toSlot)
        end
    end
    return out
end


function BIL.getStorage(lid)
    if (lid == "turtle") and (turtle ~= nil) then
        local mod = peripheral.find("modem")
        local wrap = generateTurtleInvWrap(mod.getNameLocal())
        return {
            id = mod.getNameLocal(),
            wrap = wrap
        }
    else
        if peripheral.isPresent(lid) then
            local wrap = generateCustomInvWrap(lid)
            return {
                id = lid,
                wrap = wrap
            }
        else
            return nil, "Peripheral not found"
        end
    end
end

function BIL.getStorages(storages)
    local out = {}
    for k,v in ipairs(storages) do
        table.insert(out, BIL.getStorage(v))
    end
    return out
end

function BIL.createStorage(storages)
    if (storages == nil) then
        storages = BIL.listStorages()
    end
    local out = {}
    out.itemCache = {}
    out.storageIds = storages
    out.storages = BIL.getStorages(storages)
    out.stats = {}

    function out.rescanAll()
        local tempItemCache = {}
        local tempStats = {}
        for k,v in ipairs(out.storages) do
            if peripheral.isPresent(v.id) or ((out.storageIds[k] == "turtle") and (turtle ~= nil)) then
                local size = v.wrap.size()
                local list = v.wrap.list()
                tempItemCache[v.id] = {}
                tempStats[v.id] = {
                    all = size,
                    used = 0,
                    free = 0
                }
                for i=1,size do
                    local detail = list[i]
                    tempItemCache[v.id][i] = detail
                    if detail ~= nil then
                        tempStats[v.id].used = tempStats[v.id].used + 1
                    end
                end
                tempStats[v.id].free = tempStats[v.id].all - tempStats[v.id].used
            else
                error("Peripheral is not present")
            end
        end
        out.itemCache = tempItemCache
        out.stats = tempStats
    end
    function out.rescan(storageId)
        local data = nil
        local searchId = storageId
        if searchId == "turtle" then
            local mod = peripheral.find("modem")
            searchId = mod.getNameLocal()
        end
        for k,v in ipairs(out.storages) do
            if v.id == searchId then
                data = v
            end
        end
        if data ~= nil then
            if (not peripheral.isPresent(data.id)) and ((data.id ~= "turtle") or (turtle == nil)) then
                error("Peripheral is not present")
            end
            local size = data.wrap.size()
            local list = data.wrap.list()
            out.itemCache[data.id] = {}
            out.stats[data.id] = {
                all = size,
                used = 0,
                free = 0
            }
            for i=1,size do
                local detail = list[i]
                table.insert(out.itemCache[data.id], detail)
                if detail ~= nil then
                    out.stats[data.id].used = out.stats[data.id].used + 1
                end
            end
            out.stats[data.id].free = out.stats[data.id].all - out.stats[data.id].used
        else
            error("Invalid storage id")
        end
    end
    function out.getStats()
        local oout = {
            all = 0,
            used = 0,
            free = 0
        }
        for k,v in pairs(out.stats) do
            oout.all = oout.all + v.all
            oout.used = oout.used + v.used
        end
        oout.free = oout.all - oout.used
        return oout
    end
    function out.list()
        local oout = {}
        local iout = {}
        for k,v in pairs(out.itemCache) do
            for kk,vv in pairs(v) do
                if iout[vv.name..","..(vv.nbt or "")] == nil then
                    table.insert(oout, {
                        id = vv.name,
                        count = vv.count,
                        nbt = vv.nbt
                    })
                    iout[vv.name..","..(vv.nbt or "")] = #oout
                else
                    oout[iout[vv.name..","..(vv.nbt or "")]].count = oout[iout[vv.name..","..(vv.nbt or "")]].count + vv.count
                end
            end
        end
        return oout
    end
    function out.getItemCount(query)
        local count = 0
        for k,v in pairs(out.itemCache) do
            for kk,vv in pairs(v) do
                if BIL.isItemMatch(vv, query) then
                    count = count + vv.count
                end
            end
        end
        return count
    end
    function out.exportItems(to, query, limit)
        if (not peripheral.isPresent(to)) and ((to ~= "turtle") or (turtle == nil)) then
            error("To peripheral is not present")
        end
        for k,v in ipairs(out.storageIds) do
            if v == to then
                error("Can't export into itself")
            end
        end
        local ic = out.getItemCount(query)
        if ic < limit then
            limit = ic
        end
        local function trans(remm)
            for k,v in ipairs(out.storages) do
                if peripheral.isPresent(v.id) or ((out.storageIds[k] == "turtle") and (turtle ~= nil)) then
                    local list = v.wrap.list()
                    for kk,vv in pairs(list) do
                        if BIL.isItemMatch(vv, query) then
                            local ca = v.wrap.pushItems(to, kk, remm)
                            out.itemCache[v.id][kk].count = out.itemCache[v.id][kk].count - ca
                            if out.itemCache[v.id][kk].count < 1 then
                                out.itemCache[v.id][kk] = nil
                            end
                            return ca
                        end
                    end
                else
                    error("Peripheral is not present")
                end
            end
        end
        local ramm = limit
        while ramm > 0 do
            local ca = trans(ramm)
            ramm = ramm - ca
        end
        return limit
    end
    function out.importItems(from, query, limit)
        if (not peripheral.isPresent(from)) and ((from ~= "turtle") or (turtle == nil)) then
            error("To peripheral is not present")
        end
        for k,v in ipairs(out.storageIds) do
            if v == from then
                error("Can't import from itself")
            end
        end
        local fromWrap = BIL.getStorage(from)
        local function emptyestChest()
            local freeSpaces = {}
            for k,v in ipairs(out.storages) do
                if peripheral.isPresent(v.id) or ((out.storageIds[k] == "turtle") and (turtle ~= nil)) then
                    local size = v.wrap.size()
                    local list = v.wrap.list()
                    local free = 0
                    for i=1,size do
                        if list[i] == nil then
                            free = free + 1
                        end
                    end
                    table.insert(freeSpaces, free)
                else
                    error("Peripheral is not present")
                end
            end
            local highest = 0
            local highesti = -1
            for k,v in ipairs(freeSpaces) do
                if v > highest then
                    highest = v
                    highesti = k
                end
            end
            return (highesti ~= -1 and out.storages[highesti] or nil)
        end
        local function trans(remm)
            local list = fromWrap.wrap.list()
            local toChest = emptyestChest()
            if toChest == nil then
                error("Out of space")
            end
            for k,v in pairs(list) do
                if BIL.isItemMatch(v, query) then
                    local listette = toChest.wrap.list()
                    for i=1,toChest.wrap.size() do
                        if listette[i] == nil then
                            -- BETTER IDEA: save the chest contents, and compute where was the item change
                            local ca = fromWrap.wrap.pushItems(toChest.id, k, remm, i)
                            if out.itemCache[toChest.id][i] == nil then
                                out.itemCache[toChest.id][i] = toChest.wrap.list()[i]
                            else
                                out.itemCache[toChest.id][i].count = out.itemCache[toChest.id][i].count + ca
                            end
                            return ca
                        end
                    end
                end
            end
        end
        local ramm = limit
        while ramm > 0 do
            local ca = trans(ramm)
            ramm = ramm - ca
        end
        return limit
    end
    function out.defragStorage()
        local function matchItem(item, query)
            for k,v in pairs(query) do
                if (k ~= "count") and (item[k] ~= v) then
                    return false
                end
            end
            return true
        end
        for k,v in ipairs(out.storages) do
            for kk,vv in pairs(out.itemCache[v.id]) do
                local limit = v.wrap.getItemLimit(kk)
                if vv.count < limit then
                    for kkk,vvv in ipairs(out.storages) do
                        for kkkk,vvvv in pairs(out.itemCache[vvv.id]) do
                            if (k < kkk) or (kk < kkkk) then
                                if matchItem(vvvv, vv) then
                                    vvv.wrap.pushItems(v.id, kkkk, 64, kk)
                                end
                            end
                        end
                    end
                end
            end
        end
        out.rescanAll()
    end
    out.rescanAll()
    return out
end

return BIL