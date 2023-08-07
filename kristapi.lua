--[[
    Kristapi
    Made by: afonya2@github
]]
local api = {}
local server = "https://krist.dev"

function api.getAddress(address)
    local requ = http.get(server.."/addresses/"..address)
    local out = textutils.unserialiseJSON(requ.readAll())
    if out.ok then
        return out.address
    else
        error(out.message)
    end
end

function api.getBalance(address)
    local requ = http.get(server.."/addresses/"..address)
    local out = textutils.unserialiseJSON(requ.readAll())
    if out.ok then
        return out.address.balance
    else
        error(out.message)
    end
end

function api.getTransactions(address)
    local requ = http.get(server.."/addresses/"..address.."/transactions")
    local out = textutils.unserialiseJSON(requ.readAll())
    if out.ok then
        return out.transactions
    else
        error(out.message)
    end
end

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

function api.parseMeta(meta)
    if (meta == nil) or (meta == "") then
        return {}
    end
    local out = {}
    local a = mysplit(meta, ";")
    for k,v in ipairs(a) do
        local b = mysplit(v, "=")
        if b[2] ~= nil then
            out[b[1]] = b[2]
        else
            -- if matches the format of a krist address with metaname (ie test@shop.kst), we get the metaname, aka the test
            if(b[1]:match("^.+@.+%.kst$")) then
                local c = mysplit(b[1], "@")
                out["metaname"] = c[1]
            else
                out[b[1]] = true
            end
        end
    end
    return out
end

function api.makeTransaction(privKey, to, amount, meta)
    if meta == nil then
        meta = ""
    end
    local kutyus = {
        privatekey = privKey,
        to = to,
        amount = amount,
        metadata = meta
    }
    local requ = http.post(server.."/transactions", textutils.serialiseJSON(kutyus), {["Content-Type"] = "application/json"})
    local out = textutils.unserialiseJSON(requ.readAll())
    if out.ok then
        return true
    else
        error(out.message)
    end
end

function api.websocket()
    local requ = http.post(server.."/ws/start","")
    local out = textutils.unserialiseJSON(requ.readAll())
    if out.ok then
        local sock = http.websocket(out.url)
        return sock
    else
        error(out.message)
    end
end

return api