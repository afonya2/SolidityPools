local selectedCategory = nil
local selectedItem = nil

local function drawRect(monitor,x,y,w,h,bg)
    monitor.setBackgroundColor(bg)
    monitor.setCursorPos(x,y)
    for i=1,h do
        monitor.write(string.rep(" ", w))
        monitor.setCursorPos(x,y+i)
    end
end

local function renderItem(monitor, item, x, y, longest, hidden)
    local w,h = monitor.getSize()
    local config = SolidityPools.config
    -- TODO: replace 2nd one with actual price
    if longest == nil then
        longest = math.max(#item.name, #("Sell:  10"), #("Buy:  11"))
    end
    if longest+3 > w then
        y = y + 1
    end
    drawRect(monitor, x, y, longest + 2, 5, config.palette.items.bg)
    if not hidden then
        monitor.setCursorPos(x + 1, y + 1)
        monitor.setTextColor(config.palette.items.fg)
        monitor.write(item.name)
        monitor.setCursorPos(x + 1, y + 2)
        monitor.setTextColor(config.palette.items.sellFg)
        monitor.write("Sell: \16410")
        monitor.setCursorPos(x + 1, y + 3)
        monitor.setTextColor(config.palette.items.buyFg)
        monitor.write("Buy: \16411")
    end
    x = x + longest + 3
    return x, y, longest
end

local function renderItems()
    local monitor = SolidityPools.monitor.wrap
    local x = 2
    local y = 7
    local longest = 0
    for k, v in ipairs(SolidityPools.items[selectedCategory]) do
        local nx, ny, nlongest = renderItem(monitor, v, x, y, nil, true)
        x = nx
        y = ny
        longest = math.max(longest, nlongest)
    end
    x = 2
    y = 7
    for k, v in ipairs(SolidityPools.items[selectedCategory]) do
        local nx, ny = renderItem(monitor, v, x, y, longest, false)
        x = nx
        y = ny
    end
end

local function render()
    local monitor = SolidityPools.monitor.wrap
    local config = SolidityPools.config
    local bigfont = SolidityPools.bigfont
    local w,h = monitor.getSize()

    monitor.setTextScale(0.5)
    monitor.setBackgroundColor(config.palette.content.bg)
    monitor.setTextColor(config.palette.content.fg)
    monitor.clear()

    -- Draw the header and the shop info
    drawRect(monitor,1,1,w,5,config.palette.header.bg)
    monitor.setTextColor(config.palette.header.fg)
    bigfont.writeOn(monitor, 1, config.shopname, 2, 2)
    monitor.setCursorPos(2, 5)
    monitor.write(config.description)

    -- Draw the menu
    monitor.setTextColor(config.palette.header.fg)
    local x = #config.shopname*3+3
    local y = 2
    for k,v in pairs(SolidityPools.items) do
        if selectedCategory == nil then
            selectedCategory = k
        end
        if x + #k + 3 > w then
            x = #config.shopname*3+3
            y = y + 1
        end
        if y > 4 then
            break
        end
        if selectedCategory == k then
            monitor.setTextColor(config.palette.header.bg)
            monitor.setBackgroundColor(config.palette.header.fg)
        else
            monitor.setTextColor(config.palette.header.fg)
            monitor.setBackgroundColor(config.palette.header.bg)
        end
        monitor.setCursorPos(x, y)
        monitor.write("["..k.."]")
        x = x + #k + 3
    end
    monitor.setTextColor(config.palette.header.fg)
    monitor.setBackgroundColor(config.palette.header.bg)
    if SolidityPools.session.is then
        local balDisp = SolidityPools.session.balance/1000000
        monitor.setCursorPos(w-#(SolidityPools.session.username.."  "..balDisp)+1, 5)
        monitor.setTextColor(config.palette.menu.loginFg)
        monitor.write(SolidityPools.session.username.." ")
        monitor.setTextColor(config.palette.menu.moneyFg)
        monitor.write("\164"..balDisp)
    else
        monitor.setCursorPos(w-#("Login: \\"..config.command.." start")+1, 5)
        monitor.setTextColor(config.palette.menu.loginFg)
        monitor.write("Login: \\"..config.command.." start")
    end

    -- Draw the footer
    drawRect(monitor,1,h,w,1,config.palette.footer.bg)
    monitor.setTextColor(config.palette.footer.fg)
    monitor.setCursorPos(1, h)
    monitor.write((config.kromerName ~= nil and config.kromerName..".kro" or config.address).." - "..config.owners[1])

    -- Draw the SP logo
    monitor.setTextColor(config.palette.logo.fg)
    monitor.setCursorPos(w-#("SolidityPools v"..SolidityPools.version)+1, h)
    monitor.write("SolidityPools v"..SolidityPools.version)

    renderItems()
end

local function frontend()
    render()
end

return frontend