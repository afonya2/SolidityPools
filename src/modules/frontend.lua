local selectedCategory = nil
local selectedItem = nil
local hitboxes = {}
local utils = require("../utils")

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
    local x1, x1i = utils.calculatePrice(item, 1, false)
    local sx1, sx1i = utils.calculatePrice(item, 1, true)
    if longest == nil then
        longest = math.max(#item.name, #("Sell:  "..(sx1/1000000)), #("Buy:  "..(x1/1000000)))
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
        monitor.write("Sell: \164" .. (sx1/1000000))
        monitor.setCursorPos(x + 1, y + 3)
        monitor.setTextColor(config.palette.items.buyFg)
        monitor.write("Buy: \164" .. (x1/1000000))
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
    if not SolidityPools.kromerConnected then
        y = y + 1
    end
    local longest = 0
    for k, v in ipairs(SolidityPools.items[selectedCategory]) do
        local nx, ny, nlongest = renderItem(monitor, k, v, x, y, nil, true)
        x = nx
        y = ny
        longest = math.max(longest, nlongest)
    end
    x = 2
    y = 7
    if not SolidityPools.kromerConnected then
        y = y + 1
    end
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

    local baseY = 8
    if not SolidityPools.kromerConnected then
        drawRect(monitor, 2, 8, w-2, h-9, SolidityPools.config.palette.cards.bg)
        baseY = baseY + 1
    else
        drawRect(monitor, 2, 7, w-2, h-8, SolidityPools.config.palette.cards.bg)
    end
    monitor.setCursorPos(3, baseY)
    monitor.setTextColor(SolidityPools.config.palette.cards.fg)
    monitor.write(item.name)
    monitor.setCursorPos(3, baseY + 1)
    monitor.setTextColor(SolidityPools.config.palette.cards.secondFg)
    monitor.write("Aka. " .. table.concat(item.aliases, ", "))
    monitor.setCursorPos(w-1, baseY - 1)
    monitor.setTextColor(colors.red)
    monitor.write("X")
    table.insert(hitboxes, { x = w-1, y = baseY - 1, w = 1, h = 1, onclick = function ()
        selectedItem = nil
    end })

    monitor.setCursorPos(3, baseY + 3)
    monitor.setTextColor(SolidityPools.config.palette.cards.buyFg)
    monitor.setBackgroundColor(SolidityPools.config.palette.cards.bg)
    monitor.write("Buy prices:")
    local x1, x1i = utils.calculatePrice(item, 1, false)
    local x8, x8i = utils.calculatePrice(item, 8, false)
    local x64, x64i = utils.calculatePrice(item, 64, false)
    local x128, x128i = utils.calculatePrice(item, 128, false)
    drawTable(monitor, 3, baseY + 4, w-4, 2, {
        {
            name = "x1",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\164"..(x1/1000000)},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\164"..(x1i/1000000).."/i"}
            }
        },
        {
            name = "x8",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\164"..(x8/1000000)},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\164"..(x8i/1000000).."/i"}
            }
        },
        {
            name = "x64",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\164"..(x64/1000000)},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\164"..(x64i/1000000).."/i"}
            }
        },
        {
            name = "x128",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\164"..(x128/1000000)},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.buyFg, text = "\164"..(x128i/1000000).."/i"}
            }
        },
    })

    monitor.setCursorPos(3, baseY + 8)
    monitor.setTextColor(SolidityPools.config.palette.cards.sellFg)
    monitor.setBackgroundColor(SolidityPools.config.palette.cards.bg)
    monitor.write("Sell prices:")
    x1, x1i = utils.calculatePrice(item, 1, true)
    x8, x8i = utils.calculatePrice(item, 8, true)
    x64, x64i = utils.calculatePrice(item, 64, true)
    x128, x128i = utils.calculatePrice(item, 128, true)
    drawTable(monitor, 3, baseY + 9, w-4, 2, {
        {
            name = "x1",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\164"..(x1/1000000)},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\164"..(x1i/1000000).."/i"}
            }
        },
        {
            name = "x8",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\164"..(x8/1000000)},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\164"..(x8i/1000000).."/i"}
            }
        },
        {
            name = "x64",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\164"..(x64/1000000)},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\164"..(x64i/1000000).."/i"}
            }
        },
        {
            name = "x128",
            bg = SolidityPools.config.palette.cards.bg,
            fg = SolidityPools.config.palette.cards.secondFg,
            rows = {
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\164"..(x128/1000000)},
                {bg = SolidityPools.config.palette.cards.bg, fg = SolidityPools.config.palette.cards.sellFg, text = "\164"..(x128i/1000000).."/i"}
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

    -- Draw the kromer warning
    if not SolidityPools.kromerConnected then
        monitor.setCursorPos(w/2-#("Warning: Kromer is not connected, depositting is temporarily disabled.")/2+1, 6)
        monitor.setTextColor(colors.black)
        monitor.setBackgroundColor(colors.yellow)
        monitor.clearLine()
        monitor.write("Warning: Kromer is not connected, depositting is temporarily disabled.")
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