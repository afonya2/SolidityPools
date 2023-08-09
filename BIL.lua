--[[
    Bagi's Inventory Libary (BIL)
    Made by: afonya2@github
]]
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

function BIL.isItemMatch(storage, slot, rawDat, query)
    local pq = BIL.processQuery(query)
    local stwrap = peripheral.wrap(storage)
    if pq.query == nil then
        if rawDat.name ~= pq.itemId then
            return false
        end
        return true
    else
        if rawDat.name ~= pq.itemId then
            return false
        end
        local stdetail = stwrap.getItemDetail(slot)
        for k,v in pairs(pq.query) do
            if stdetail[k] ~= v then
                return false
            end
        end
        return true
    end
end

function BIL.getStorages(addTurtle)
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
        return turtle.getItemDetail(i, true)
    end
    out.getItemLimit = function(slot)
        return turtle.getItemDetail(i, true).maxCount
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

function BIL.translateStorages(storages)
    local out = {}
    for k,v in ipairs(storages) do
        if peripheral.isPresent(v) then
            if (v == "turtle") and (turtle ~= nil) then
                local mod = peripheral.find("modem")
                local wrap = generateTurtleInvWrap(mod.getNameLocal())
                table.insert(out, {
                    id = mod.getNameLocal(),
                    wrap = wrap
                })
            else
                local wrap = generateCustomInvWrap(v)
                table.insert(out, {
                    id = v,
                    wrap = wrap
                })
            end
        end
    end
    return out
end

function BIL.getStorage(lid)
    if peripheral.isPresent(v) then
        if (lid == "turtle") and (turtle ~= nil) then
            local mod = peripheral.find("modem")
            local wrap = generateTurtleInvWrap(mod.getNameLocal())
            return {
                id = mod.getNameLocal(),
                wrap = wrap
            }
        else
            local wrap = generateCustomInvWrap(lid)
            return {
                id = lid,
                wrap = wrap
            }
        end
    else
        return nil, "Peripheral not found"
    end
end

function BIL.list(storages)
    if storages == nil then
        storages = BIL.getStorages()
    end
    local ustorages = BIL.translateStorages(storages)
    local out = {}
    local iout = {}
    for k,v in ipairs(ustorages) do
        local llist = v.wrap.list()
        for kk,vv in pairs(llist) do
            if iout[vv.name..","..(vv.nbt or "")] == nil then
                table.insert(out, {
                    id = vv.name,
                    count = vv.count,
                    nbt = vv.nbt
                })
                iout[vv.name..","..(vv.nbt or "")] = #out
            else
                out[iout[vv.name..","..(vv.nbt or "")]].count = out[iout[vv.name..","..(vv.nbt or "")]].count + vv.count
            end
        end
    end
    return out
end

function BIL.getSize(storages)
    if storages == nil then
        storages = BIL.getStorages()
    end
    local ustorages = BIL.translateStorages(storages)
    local out = {
        total = 0,
        used = 0,
        free = 0
    }
    for k,v in ipairs(ustorages) do
        out.total = out.total + v.wrap.size()
        local llist = v.wrap.list()
        for kk,vv in pairs(llist) do
            if vv ~= nil then
                out.used = out.used + 1
            end
        end 
    end
    out.free = out.total - out.used
    return out
end

function BIL.getItemCount(query, storages)
    if storages == nil then
        storages = BIL.getStorages()
    end
    local ustorages = BIL.translateStorages(storages)
    local count = 0
    for k,v in ipairs(ustorages) do
        local llist = v.wrap.list()
        for kk,vv in pairs(llist) do
            if BIL.isItemMatch(v.id, kk, vv, query) then
                count = count + vv.count
            end
        end
    end
    return count
end

function BIL.transferItems(to, query, slimit, storages)
    if storages == nil then
        storages = BIL.getStorages()
    end
    local ustorages = BIL.translateStorages(storages)
    if (not peripheral.isPresent(to)) and ((to ~= "turtle") or (turtle == nil)) then
        return nil, "To peripheral is not present"
    end
    local ic = BIL.getItemCount(query, storages)
    if ic < slimit then
        slimit = ic
    end
    local function trans(remm)
        for k,v in ipairs(ustorages) do
            local llist = v.wrap.list()
            for kk,vv in pairs(llist) do
                if BIL.isItemMatch(v.id, kk, vv, query) then
                    return v.wrap.pushItems(to, kk, remm)
                end
            end
        end
    end
    local ramm = slimit
    while ramm > 0 do
        local ca = trans(ramm)
        ramm = ramm - ca
    end
    return slimit
end

function BIL.dropItems(query, slimit, storages)
    if storages == nil then
        storages = BIL.getStorages()
    end
    local ustorages = BIL.translateStorages(storages)
    if turtle == nil then
        return nil, "Computer must be a turtle"
    end
    local ic = BIL.getItemCount(query, storages)
    if ic < slimit then
        slimit = ic
    end
    local function trans(remm)
        for k,v in ipairs(ustorages) do
            local llist = v.wrap.list()
            for kk,vv in pairs(llist) do
                if BIL.isItemMatch(v.id, kk, vv, query) then
                    local pushed = v.wrap.pushItems("turtle", kk, remm)
                    turtle.drop()
                    return pushed
                end
            end
        end
    end
    local ramm = slimit
    while ramm > 0 do
        local ca = trans(ramm)
        ramm = ramm - ca
    end
    return slimit
end

return BIL