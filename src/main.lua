local bigfont = require("bigfont")
local sha = require("sha256")
local dw = require("discordWebhook")
local BIL = require("BIL")
local kapi = require("kromerapi")
local frontend = require("modules.frontend")
local itemManager = require("modules.itemManager")
local commandHandler = require("modules.commandHandler")
local sessionManager = require("modules.sessionManager")
local kromerManager = require("modules.kromerManager")
local webhookManager = require("modules.webhookManager")

local function loadConfig(filename)
    local fa = fs.open(filename, "r")
    local fi = fa.readAll()
    fa.close()
    return textutils.unserialise(fi)
end
local function saveConfig(filename, data)
    local fa = fs.open(filename, "w")
    fa.write(textutils.serialise(data))
    fa.close()
end

if turtle == nil then
    print("Computer must be a turtle")
    return
end
if chatbox == nil then
    print("Chatbox must be registered")
    return
end
local pepVerifier = {
    storage = false,
    ["wireless modem"] = false,
    ["wired modem"] = false,
    ["manipulator with entity sensor"] = false,
    monitor = false
}
local papsi = peripheral.getNames()
for k,v in ipairs(papsi) do
    local t,t2 = peripheral.getType(v)
    if t2 == "inventory" then
        pepVerifier.storage = true
    end
    if t == "modem" then
        if peripheral.wrap(v).isWireless() then
            pepVerifier["wireless modem"] = true
        else
            pepVerifier["wired modem"] = true
        end
    end
    if t == "monitor" then
        pepVerifier.monitor = true
    end
    if (t == "manipulator") and (peripheral.wrap(v).sense() ~= nil) then
        pepVerifier["manipulator with entity sensor"] = true
    end
end
local tterm = false
for k,v in pairs(pepVerifier) do
    if v == false then
        print("A(n) "..k.." is required to run this program")
        tterm = true
    end
end
if tterm then
    return
end

if not fs.exists("config.conf") then
    print("Config file not found")
    return
end
local config = loadConfig("config.conf")
local items = {}
local idir = fs.list("items/")
for k,v in ipairs(idir) do
    local itms = loadConfig("items/"..v)
    items[v:gsub(".conf","")] = itms
end
local monitor = peripheral.find("monitor")
monitor.setTextScale(0.5)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()

local function mysplit (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

local function bsod(message)
    monitor.setBackgroundColor(colors.blue)
    monitor.setTextColor(colors.white)
    monitor.clear()
    bigfont.blitOn(monitor, 1, ":(", "00", "bb", 2, 2)
    monitor.setCursorPos(2, 5)
    monitor.write("The shop ran into a problem and will restart in a few minutes")
    monitor.setCursorPos(2, 6)
    monitor.write("Information: "..message)
    local stack = debug.traceback()
    for k,v in ipairs(mysplit(stack, "\n")) do
        monitor.setCursorPos(2, 7+k)
        monitor.write(v)
    end
    SolidityPools.logDiscordMessage("The shop crashed: `" .. message .. "`\n```"..stack.."```")
    local function waiter()
        while true do
            if #SolidityPools.discordCache < 1 then
                break
            end
            os.sleep(1)
        end
    end
    parallel.waitForAny(waiter, webhookManager)
    os.sleep(30)
    os.reboot()
end

local storage = BIL.createStorage()
local x,y,z = gps.locate()

if (SolidityPools ~= nil) and (SolidityPools.ws ~= nil) then
    SolidityPools.ws.close()
end

_G.SolidityPools = {
    config = config,
    items = items,
    version = "2.0.0",
    session = {
        is = false,
        uuid = "",
        username = "",
        balance = 0,
        lastActive = 0
    },
    monitor = {
        id = peripheral.getName(monitor),
        wrap = monitor
    },
    bsod = bsod,
    dw = dw,
    bigfont = bigfont,
    sha = sha,
    BIL = BIL,
    storage = storage,
    kapi = kapi,
    ws = nil,
    itemsLoaded = false,
    kromerConnected = false,
    lockInv = false,
    balance = 100000000,
    location = {
        x = x,
        y = y,
        z = z
    },
    discordCache = {},
    logDiscordMessage = function(msg)
        if config.webhook then
            table.insert(SolidityPools.discordCache, msg)
        end
    end
}

local function crash(err)
    if err ~= "Terminated" then
        print(err)
        bsod(err)
    else
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.white)
        monitor.clear()
    end
end

parallel.waitForAny(function()
    local ok,err = xpcall(frontend, crash)
end,function()
    local ok,err = xpcall(itemManager, crash)
end,function()
    local ok,err = xpcall(commandHandler, crash)
end,function()
    local ok,err = xpcall(sessionManager, crash)
end,function()
    local ok,err = xpcall(kromerManager, crash)
end,function()
    local ok,err = xpcall(webhookManager, crash)
end)