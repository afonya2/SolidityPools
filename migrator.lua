local oldusers = fs.list("oldusers/")
for k,v in pairs(oldusers) do
    print("Migrating user "..v)
    local f = fs.open("oldusers/"..v, "r")
    local data = textutils.unserialise(f.readAll():gsub("SYSTEM CACHE, DO NOT EDIT!", ""))
    f.close()
    local nf = fs.open("users/"..v:gsub(".cache", "")..".txt", "w")
    local nUser = {
        uuid = v:gsub(".cache", ""),
        name = data.username or "Unknown",
        balance = math.floor(data.balance * 1000000) or 0,
        isBanned = nil,
        isApiBanned = nil,
        apiKey = nil,
        apiChest = nil,
        agreed = false
    }
    nf.write(textutils.serialise(nUser, { allow_repetitions = true }))
    nf.close()
end

print("Migrated "..#oldusers.." users!")