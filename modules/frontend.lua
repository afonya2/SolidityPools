local monitor = nil
local config = nil
local items = nil
local bigfont = nil
local BIL = nil
local w,h = 0

local selectedCategory = ""

function renderInit()
    monitor.setTextScale(0.5)
    monitor.setBackgroundColor(config.palette.content.bg)
    monitor.setTextColor(config.palette.content.fg)
    monitor.clear()

    monitor.setBackgroundColor(config.palette.header.bg)
    monitor.setTextColor(config.palette.header.fg)
    monitor.setCursorPos(1,1)
    monitor.clearLine()
    monitor.setCursorPos(1,2)
    monitor.clearLine()
    monitor.setCursorPos(1,3)
    monitor.clearLine()
    monitor.setCursorPos(1,4)
    monitor.clearLine()

    monitor.setBackgroundColor(config.palette.footer.bg)
    monitor.setTextColor(config.palette.footer.fg)
    monitor.setCursorPos(1,h-5)
    monitor.clearLine()
    monitor.setCursorPos(1,h-4)
    monitor.clearLine()
    monitor.setCursorPos(1,h-3)
    monitor.clearLine()
    monitor.setCursorPos(1,h-2)
    monitor.clearLine()
    monitor.setCursorPos(1,h-1)
    monitor.clearLine()
    monitor.setCursorPos(1,h)
    monitor.clearLine()

    monitor.setCursorPos(w/2-#config.description/2,1)
    monitor.write(config.description)
    bigfont.writeOn(monitor, 1, config.shopname, w/2-(#config.shopname*3)/2,2)
    bigfont.writeOn(monitor, 1, "Start with: \\"..config.command.." start", 2,h-3)
    renderCategories()
    renderBanners()
    renderItems()
end

function renderCategories()
    local i = 1
    local x = 2
    for k,v in pairs(items) do
        if k == selectedCategory then
            monitor.setBackgroundColor(config.palette.content.bg)
            monitor.setTextColor(config.palette.content.fg)
        else
            monitor.setBackgroundColor(config.palette.footer.bg)
            monitor.setTextColor(config.palette.footer.fg)
        end
        if k == selectedCategory then
            monitor.setCursorPos(x-1,h-5)
        else
            monitor.setCursorPos(x,h-5)
        end
        monitor.write(" "..k.." ")
        x = x + #k + 2
        i = i + 1
    end
end

function renderBanners()
    if config.mode == "both" then
        local mid = w/2
        for y=5,5+4 do
            for x=1,mid do
                monitor.setBackgroundColor(config.palette.buy.bg)
                monitor.setCursorPos(x,y)
                monitor.write(" ")
            end
            for x=mid+1,w+1 do
                monitor.setBackgroundColor(config.palette.sell.bg)
                monitor.setCursorPos(x,y)
                monitor.write(" ")
            end
        end

        monitor.setBackgroundColor(config.palette.buy.bg)
        monitor.setTextColor(config.palette.buy.fg)
        bigfont.writeOn(monitor, 1, "Buy", mid/2-(#("Buy")*3)/2, 6)
        monitor.setCursorPos(mid/2-#("\\"..config.command.." buy <item> <amount>")/2, 5+4)
        monitor.write("\\"..config.command.." buy <item> <amount>")
        monitor.setBackgroundColor(config.palette.sell.bg)
        monitor.setTextColor(config.palette.sell.fg)
        bigfont.writeOn(monitor, 1, "Sell", (mid/2-(#("Sell")*3)/2)+mid, 6)
        monitor.setCursorPos((mid/2-#("Drop above the turtle")/2)+mid, 5+4)
        monitor.write("Drop above the turtle")
    elseif config.mode == "buy" then

    elseif config.mode == "sell" then

    else
        bsod("Invalid config for mode!")
    end
end

function renderItems()
    
end

function rerender()
    renderInit()
end

function frontend()
    monitor = SolidityPools.monitor.wrap
    config = SolidityPools.config
    items = SolidityPools.items
    bigfont = SolidityPools.bigfont
    BIL = SolidityPools.BIL
    for k,v in pairs(items) do
        selectedCategory = k
        break
    end
    w,h = monitor.getSize()
    rerender()
end

return frontend