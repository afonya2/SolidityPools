local frontend = require("modules.frontend")
--local backend = require("modules.backend")
local itemHelper = require("modules.itemHelper")
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
            :addField("Traceback: ", stack)
            :setTimestamp()
            :setFooter("SolidityPools v"..SolidityPools.version)
        dw.sendMessage(config.webhook_url, config.shopname, nil, "", {emb.sendable()})
    end
end

_G.SolidityPools = {
    config = config,
    items = items,
    version = "1.0",
    loggedIn = {},
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
    countsLoaded = false
}

local function crash(err)
    print(err)
    bsod(err)
end

parallel.waitForAny(function()
    local ok,err = xpcall(itemHelper, crash)
end,function()
    local ok,err = xpcall(frontend, crash)
end)