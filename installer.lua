print("Welcome to the SolidityPools V2 installer!")

local repo = "afonya2/SolidityPools"
local branch = "v2"
local files = {
    ["items/Ores.conf"] = "items/Ores.conf",
    ["src/modules/adminCommands.lua"] = "modules/adminCommands.lua",
    ["src/modules/apiServer.lua"] = "modules/apiServer.lua",
    ["src/modules/commandHandler.lua"] = "modules/commandHandler.lua",
    ["src/modules/frontend.lua"] = "modules/frontend.lua",
    ["src/modules/itemManager.lua"] = "modules/itemManager.lua",
    ["src/modules/kromerManager.lua"] = "modules/kromerManager.lua",
    ["src/modules/orderFulfillment.lua"] = "modules/orderFulfillment.lua",
    ["src/modules/sessionManager.lua"] = "modules/sessionManager.lua",
    ["src/modules/webhookManager.lua"] = "modules/webhookManager.lua",
    ["src/modules/shopsync.lua"] = "modules/shopsync.lua",
    ["src/BIL.lua"] = "BIL.lua",
    ["config.conf"] = "config.conf",
    ["src/discordWebhook.lua"] = "discordWebhook.lua",
    ["src/kromerapi.lua"] = "kromerapi.lua",
    ["src/main.lua"] = "main.lua",
    ["src/utils.lua"] = "utils.lua"
}
print("Scanning for old config files...")
local cfgfiles = {
    "config.conf",
    "items/Ores.conf"
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

if not fs.exists("sha256.lua") then
    print("No sha256 found, downloading...")
    shell.run("pastebin get 6UV4qfNF sha256.lua")
end
if not fs.exists("bigfont.lua") then
    print("No bigfont found, downloading...")
    shell.run("pastebin get 3LfWxRWh bigfont.lua")
end

print("Done")
print("To configure your shop edit the config.conf file")
print("To configure your items edit the items/Ores.conf file")
print("To start the shop on startup, rename the main.lua to startup.lua")