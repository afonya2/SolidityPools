print("Welcome to the SolidityPools installer!")

local repo = "afonya2/SolidityPools"
local branch = "main"
local files = {
    ["items/Ores.conf"] = "items/Ores.conf",
    ["modules/adminCommands.lua"] = "modules/adminCommands.lua",
    ["modules/commandHandler.lua"] = "modules/commandHandler.lua",
    ["modules/frontend.lua"] = "modules/frontend.lua",
    ["modules/itemHelper.lua"] = "modules/itemHelper.lua",
    ["modules/kristManager.lua"] = "modules/kristManager.lua",
    ["modules/sessionHandler.lua"] = "modules/sessionHandler.lua",
    ["modules/shopsync.lua"] = "modules/shopsync.lua",
    ["bigfont.lua"] = "bigfont.lua",
    ["BIL.lua"] = "BIL.lua",
    ["config.conf"] = "config.conf",
    ["discordWebhook.lua"] = "discordWebhook.lua",
    ["kristapi.lua"] = "kristapi.lua",
    ["main.lua"] = "main.lua"
}
print("Scanning for old config files...")
local cfgfiles = {
    "config.conf",
}
local cfgcache = {}
print("Do you want to keep your config files? (y/n)")
local yass = io.read()
if yass == "y" then
    for k,v in ipairs(cfgfiles) do
        if fs.exists(v) then
            local h = fs.open(v, "rb")
            cfgcache[v] = h.readAll()
            h.close()
        end
    end
end
print("Downloading files...")
for k,v in pairs(files) do
    print("Downloading file "..k)
    local url = "https://raw.githubusercontent.com/"..repo.."/"..branch.."/"..k
    local con = http.get({url = url, binary = true})
    local h = fs.open(v, "wb")
    h.write(con.readAll())
    h.close()
    print("done")
end
print("Loading old config files...")
for k,v in pairs(cfgcache) do
    local h = fs.open(k, "wb")
    h.write(v)
    h.close()
end

print("Done")
print("To configure your shop edit the config.conf file")
print("To configure your items edit the items/Ores.conf file")
print("To start the shop on startup, rename the main.lua to startup.lua")