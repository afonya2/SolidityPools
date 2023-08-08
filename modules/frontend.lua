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

    monitor.setBackgroundColor(config.palette.header.bg)
    monitor.setTextColor(config.palette.header.fg)
    monitor.setCursorPos(w/2-#config.description/2,1)
    monitor.write(config.description)
    bigfont.writeOn(monitor, 1, config.shopname, w/2-(#config.shopname*3)/2,2)

    monitor.setTextColor(config.palette.logo.fg)
    monitor.setCursorPos(w-#("SolidityPools")+1, 1)
    monitor.write("SolidityPools")

    monitor.setBackgroundColor(config.palette.footer.bg)
    monitor.setTextColor(config.palette.footer.fg)
    bigfont.writeOn(monitor, 1, "Start with: \\"..config.command.." start", 2,h-3)
    renderCategories()
    renderBanners()
    renderItems()
end

function renderCategories()
    monitor.setBackgroundColor(config.palette.footer.bg)
    monitor.setTextColor(config.palette.footer.fg)
    monitor.setCursorPos(1,h-5)
    monitor.clearLine()
    local x = 2
    for k,v in pairs(items) do
        if k == selectedCategory then
            monitor.setBackgroundColor(config.palette.content.bg)
            monitor.setTextColor(config.palette.content.fg)
        else
            monitor.setBackgroundColor(config.palette.footer.bg)
            monitor.setTextColor(config.palette.footer.fg)
        end
        monitor.setCursorPos(x-1,h-5)
        monitor.write(" "..k.." ")
        x = x + #k + 2
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
        renderColumns()
    elseif config.mode == "buy" then
        for y=5,5+4 do
            for x=1,w do
                monitor.setBackgroundColor(config.palette.buy.bg)
                monitor.setCursorPos(x,y)
                monitor.write(" ")
            end
        end

        monitor.setBackgroundColor(config.palette.buy.bg)
        monitor.setTextColor(config.palette.buy.fg)
        bigfont.writeOn(monitor, 1, "Buy", w/2-(#("Buy")*3)/2, 6)
        monitor.setCursorPos(w/2-#("\\"..config.command.." buy <item> <amount>")/2, 5+4)
        monitor.write("\\"..config.command.." buy <item> <amount>")
        renderColumns()
    elseif config.mode == "sell" then
        for y=5,5+4 do
            for x=1,w do
                monitor.setBackgroundColor(config.palette.sell.bg)
                monitor.setCursorPos(x,y)
                monitor.write(" ")
            end
        end

        monitor.setBackgroundColor(config.palette.sell.bg)
        monitor.setTextColor(config.palette.sell.fg)
        bigfont.writeOn(monitor, 1, "Sell", w/2-(#("Sell")*3)/2, 6)
        monitor.setCursorPos(w/2-#("Drop above the turtle")/2, 5+4)
        monitor.write("Drop above the turtle")
        renderColumns()
    else
        bsod("Invalid config for mode!")
    end
end

function renderColumns()
    if config.mode == "both" then
        local mid = w/2
        monitor.setBackgroundColor(config.palette.column.bg)
        monitor.setTextColor(config.palette.column.fg)
        monitor.setCursorPos(1, 5+4+1)
        monitor.clearLine()
        monitor.setCursorPos(w/2-#("Item")/2+1, 5+4+1)
        monitor.write("Item")

        monitor.setCursorPos(mid/2/2-#("x64")/2, 5+4+1)
        monitor.write("x64")
        monitor.setCursorPos(mid/2-#("x8")/2, 5+4+1)
        monitor.write("x8")
        monitor.setCursorPos((mid/2/2-#("x1")/2)+mid/2, 5+4+1)
        monitor.write("x1")

        monitor.setCursorPos((mid/2/2-#("x1")/2)+mid, 5+4+1)
        monitor.write("x1")
        monitor.setCursorPos((mid/2-#("x8")/2)+mid, 5+4+1)
        monitor.write("x8")
        monitor.setCursorPos(((mid/2/2-#("x64")/2)+mid/2)+mid, 5+4+1)
        monitor.write("x64")
    elseif config.mode == "buy" then
        monitor.setBackgroundColor(config.palette.column.bg)
        monitor.setTextColor(config.palette.column.fg)
        monitor.setCursorPos(1, 5+4+1)
        monitor.clearLine()
        monitor.setCursorPos(w-#("Item")+1, 5+4+1)
        monitor.write("Item")
        
        monitor.setCursorPos(w/2/2/2-#("x4096")/2, 5+4+1)
        monitor.write("x4096")
        monitor.setCursorPos((w/2/2/2-#("x512")/2)+w/2/2/2, 5+4+1)
        monitor.write("x512")
        monitor.setCursorPos((w/2/2-#("x128")/2)+w/2/2/2, 5+4+1)
        monitor.write("x128")
        monitor.setCursorPos(w/2-#("x64")/2, 5+4+1)
        monitor.write("x64")
        monitor.setCursorPos((w/2/2/2-#("x32")/2)+w/2, 5+4+1)
        monitor.write("x32")
        monitor.setCursorPos((w/2/2-#("x1")/2)+w/2, 5+4+1)
        monitor.write("x8")
        monitor.setCursorPos((w/2/2-#("x1")/2)+w/2/2/2+w/2, 5+4+1)
        monitor.write("x1")
    elseif config.mode == "sell" then
        monitor.setBackgroundColor(config.palette.column.bg)
        monitor.setTextColor(config.palette.column.fg)
        monitor.setCursorPos(1, 5+4+1)
        monitor.clearLine()
        monitor.setCursorPos(1, 5+4+1)
        monitor.write("Item")

        monitor.setCursorPos(w/2/2/2-#("x1")/2, 5+4+1)
        monitor.write("x1")
        monitor.setCursorPos((w/2/2/2-#("x8")/2)+w/2/2/2, 5+4+1)
        monitor.write("x8")
        monitor.setCursorPos((w/2/2-#("x32")/2)+w/2/2/2, 5+4+1)
        monitor.write("x32")
        monitor.setCursorPos(w/2-#("x64")/2, 5+4+1)
        monitor.write("x64")
        monitor.setCursorPos((w/2/2/2-#("x128")/2)+w/2, 5+4+1)
        monitor.write("x128")
        monitor.setCursorPos((w/2/2-#("x512")/2)+w/2, 5+4+1)
        monitor.write("x512")
        monitor.setCursorPos((w/2/2-#("x4096")/2)+w/2/2/2+w/2, 5+4+1)
        monitor.write("x4096")
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
    local function categoryClicker()
        while true do
            local event, side, x, y = os.pullEvent("monitor_touch")
            if side == SolidityPools.monitor.id then
                if y == h-5 then
                    local xx = 2
                    for k,v in pairs(items) do
                        if (xx-1 <= x) and (xx+#k >= x) then
                            selectedCategory = k
                            renderCategories()
                            break
                        end
                        xx = xx + #k + 2
                    end
                end
            end
        end
    end
    parallel.waitForAny(categoryClicker)
end

return frontend