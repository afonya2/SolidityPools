local selectedCategory = nil
local selectedItem = nil
local hitboxes = {}

local function drawRect(monitor,x,y,w,h,bg)
    monitor.setBackgroundColor(bg)
    monitor.setCursorPos(x,y)
    for i=1,h do
        monitor.write(string.rep(" ", w))
        monitor.setCursorPos(x,y+i)
    end
end

local function renderItem(monitor, k, item, x, y, longest, hidden)
    local w,h = monitor.getSize()
    local config = SolidityPools.config
    -- TODO: replace 2nd and 3rd one with actual price
    if longest == nil then
        longest = math.max(#item.name, #("Sell:  10"), #("Buy:  11"))
    end
    if longest+3 > w then
        y = y + 1
    end
    if not hidden then
        drawRect(monitor, x, y, longest + 2, 5, config.palette.items.bg)
        monitor.setCursorPos(x + 1, y + 1)
        monitor.setTextColor(config.palette.items.fg)
        monitor.write(item.name)
        monitor.setCursorPos(x + 1, y + 2)
        monitor.setTextColor(config.palette.items.sellFg)
        monitor.write("Sell: \16410")
        monitor.setCursorPos(x + 1, y + 3)
        monitor.setTextColor(config.palette.items.buyFg)
        monitor.write("Buy: \16411")
        table.insert(hitboxes, {
            x = x,
            y = y,
            w = longest + 2,
            h = 5,
            onclick = function()
                selectedItem = k
            end
        })
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
        local nx, ny, nlongest = renderItem(monitor, k, v, x, y, nil, true)
        x = nx
        y = ny
        longest = math.max(longest, nlongest)
    end
    x = 2
    y = 7
    for k, v in ipairs(SolidityPools.items[selectedCategory]) do
        local nx, ny = renderItem(monitor, k, v, x, y, longest, false)
        x = nx
        y = ny
    end
end

local function drawTable(monitor, x, y, w, h, data)
    drawRect(monitor, x, y, w, h, SolidityPools.config.palette.cards.bg)
    local colCount = #data
    if colCount == 0 then return end

    local colWidth = math.floor(w / colCount)
    local extra = w % colCount

    local startX = x
    local colIndex = 0
    for _, col in ipairs(data) do
        colIndex = colIndex + 1
        local thisWidth = colWidth
        if colIndex <= extra then
            thisWidth = thisWidth + 1
        end

        monitor.setCursorPos(startX, y)
        monitor.setTextColor(col.fg)
        monitor.setBackgroundColor(col.bg)
        monitor.write(col.name:sub(1, thisWidth-1))

        for i, row in ipairs(col.rows) do
            monitor.setCursorPos(startX, y + i)
            monitor.setTextColor(row.fg)
            monitor.setBackgroundColor(row.bg)
            monitor.write(row.text:sub(1, thisWidth-1))
        end

        startX = startX + thisWidth
    end
end


local function renderItemDetails()
    local monitor = SolidityPools.monitor.wrap
    local w,h = monitor.getSize()
    local item = SolidityPools.items[selectedCategory][selectedItem]

    drawRect(monitor, 2, 7, w-2, h-8, SolidityPools.config.palette.cards.bg)
    monitor.setCursorPos(3, 8)
    monitor.setTextColor(SolidityPools.config.palette.cards.fg)
    monitor.write(item.name)
    monitor.setCursorPos(3, 9)
    monitor.setTextColor(SolidityPools.config.palette.cards.secondFg)
    monitor.write("Aka. " .. table.concat(item.aliases, ", "))
    monitor.setCursorPos(w-1, 7)
    monitor.setTextColor(colors.red)
    monitor.write("X")
    table.insert(hitboxes, { x = w-1, y = 7, w = 1, h = 1, onclick = function ()
        selectedItem = nil
    end })

    monitor.setCursorPos(3, 11)
    monitor.setTextColor(SolidityPools.config.palette.cards.buyFg)
    monitor.setBackgroundColor(SolidityPools.config.palette.cards.bg)
    monitor.write("Buy prices:")
    drawTable(monitor, 3, 12, w-4, 2, {
        {
            name = "x1",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\16411"},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\16411/i"}
            }
        },
        {
            name = "x8",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\16411"},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\16411/i"}
            }
        },
        {
            name = "x64",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\16411"},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\16411/i"}
            }
        },
        {
            name = "x128",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\16411"},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\16411/i"}
            }
        },
    })

    monitor.setCursorPos(3, 16)
    monitor.setTextColor(SolidityPools.config.palette.cards.sellFg)
    monitor.setBackgroundColor(SolidityPools.config.palette.cards.bg)
    monitor.write("Sell prices:")
    drawTable(monitor, 3, 17, w-4, 2, {
        {
            name = "x1",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\16410"},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\16410/i"}
            }
        },
        {
            name = "x8",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\16410"},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\16410/i"}
            }
        },
        {
            name = "x64",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\16410"},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\16410/i"}
            }
        },
        {
            name = "x128",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\16410"},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\16410/i"}
            }
        },
    })
end

local function render()
    local monitor = SolidityPools.monitor.wrap
    local config = SolidityPools.config
    local bigfont = SolidityPools.bigfont
    local w,h = monitor.getSize()
    hitboxes = {}

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
        table.insert(hitboxes, { x = x, y = y, w = #k + 2, h = 1, onclick = function ()
            selectedCategory = k
            selectedItem = nil
        end })
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

    if selectedItem == nil then
        renderItems()
    else
        renderItemDetails()
    end
end

local function frontend()
    render()
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "monitor_touch" then
            local x, y = p2, p3
            for k, hitbox in ipairs(hitboxes) do
                if x >= hitbox.x and x < hitbox.x + hitbox.w and y >= hitbox.y and y < hitbox.y + hitbox.h then
                    hitbox.onclick()
                    break
                end
            end
            render()
        elseif event == "sp_render" then
            render()
        end
    end
end

return frontend