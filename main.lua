local frontend = require("modules.frontend")
local itemHelper = require("modules.itemHelper")
local commandHandler = require("modules.commandHandler")
local kristManager = require("modules.kristManager")
local sessionHandler = require("modules.sessionHandler")
local shopsync = require("modules.shopsync")
local adminCommands = require("modules.adminCommands")
local bigfont = require("bigfont")
local dw = require("discordWebhook")
local BIL = require("BIL")
local kapi = require("kristapi")

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

function bsod(message)
    monitor.setBackgroundColor(colors.blue)
    monitor.setTextColor(colors.white)
    monitor.clear()
    bigfont.blitOn(monitor, 1, ":(", "00", "bb", 2, 2)
    monitor.setCursorPos(2, 5)
    monitor.write("The shop ran into a problem and needs restart")
    monitor.setCursorPos(2, 6)
    monitor.write("Information: "..message)
    local stack = debug.traceback()
    for k,v in ipairs(mysplit(stack, "\n")) do
        monitor.setCursorPos(2, 7+k)
        monitor.write(v)
    end
    if config.webhook then
        local emb = dw.createEmbed()
            :setAuthor("Solidity Pools")
            :setTitle("The shop ran into a problem and needs restart")
            :setColor(13120050)
            :setDescription("Information: "..message)
            :addField("Traceback: ", "`"..stack.."`")
            :setTimestamp()
            :setFooter("SolidityPools v"..SolidityPools.version)
        dw.sendMessage(config.webhook_url, config.shopname, nil, "", {emb.sendable()})
    end
end

if (SolidityPools ~= nil) and (SolidityPools.ws ~= nil) then
    SolidityPools.ws.close()
end

_G.SolidityPools = {
    config = config,
    items = items,
    version = "1.0",
    loggedIn = {
        is = false,
        username = "",
        uuid = "",
        balance = 0,
        transactions = {},
        timeout = 0,
        msgId = "",
        itmsBought = 0,
        itmsSold = 0,
        moneyGained = 0,
        itemTransactions = {}
    },
    monitor = {
        id = peripheral.getName(monitor),
        wrap = monitor
    },
    bsod = bsod,
    dw = dw,
    bigfont = bigfont,
    BIL = BIL,
    kapi = kapi,
    pricesLoaded = false,
    countsLoaded = false,
    kristConnected = false,
    itemChangeInfo = {
        is = false,
        category = "",
        pos = 0,
        mode = "",
        time = 0
    }
}
function SolidityPools.loggedIn.loadUser()
    if fs.exists("users/"..SolidityPools.loggedIn.uuid..".cache") then
        local dat = loadCache("users/"..SolidityPools.loggedIn.uuid..".cache")
        SolidityPools.loggedIn.balance = dat.balance
        SolidityPools.loggedIn.transactions = dat.transactions
    else
        SolidityPools.loggedIn.balance = 0
        SolidityPools.loggedIn.transactions = {}
    end
end
function SolidityPools.loggedIn.saveUser()
    saveCache("users/"..SolidityPools.loggedIn.uuid..".cache", {
        balance = SolidityPools.loggedIn.balance,
        transactions = SolidityPools.loggedIn.transactions,
        username = SolidityPools.loggedIn.username
    })
end

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
    local ok,err = xpcall(itemHelper, crash)
end,function()
    local ok,err = xpcall(frontend, crash)
end,function()
    local ok,err = xpcall(commandHandler, crash)
end,function()
    local ok,err = xpcall(kristManager, crash)
end,function()
    local ok,err = xpcall(sessionHandler, crash)
end,function()
    local ok,err = xpcall(shopsync, crash)
end,function()
    local ok,err = xpcall(adminCommands, adminCommands)
end)