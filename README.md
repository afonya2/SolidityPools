# SolidityPools
Solidity shop system for CC
# Screenshots
![image](https://github.com/afonya2/SolidityPools/assets/64413731/d48d33dc-28f5-4471-8dc8-96f7b4fd7e53)
![image](https://github.com/afonya2/SolidityPools/assets/64413731/5483f40d-808a-4245-9e8a-ad71320e3f64)
![image](https://github.com/afonya2/SolidityPools/assets/64413731/46bb6a96-7501-4696-b407-236b62f036ae)
# How to install?
Run the following command `wget run https://github.com/afonya2/SolidityPools/raw/main/installer.lua`
# How to modify the config?
In config.conf everything is commented
```lua
{
    ["mode"] = "both", --The mode for the shop (buy|sell|both)
    ["shopname"] = "SolidityPools", --The shop's name
    ["description"] = "This is an opensauce Liquidity pools", --The shop's description
    ["owner"] = "Afonya2", -- The shop's owner (must be your ingame name) (only displayed in shopsync information, admin commands)
    ["command"] = "sp", --The command for the shop (without the \)
    ["address"] = "kasd123", --The krist wallet's address
    ["privateKey"] = "asd123", --The krist wallet's privateKey
    ["kristName"] = "sp", --The krist name for the wallet (can be nil)
    ["tradingFees"] = 5, --The trading fees for the items
    ["dynamicPricing"] = true, --The dynamic toggle switch
    ["webhook"] = true, --The webhook's toggle switch (discord only)
    ["webhook_url"] = "https://discord.com/api/webhooks/123456789/asd123-ASD123", --The webhook's url
    ["palette"] = { --The palette for the shop
        header = { --The colors for the header
            bg = 128, --The bg for the header
            fg = 1 --The fg for the header
        },
        logo = { --The color of the logo
            fg = 512
        },
        buy = { --The colors for the buy banner
            bg = 8192,
            fg = 1
        },
        sell = { --The colors for the sell banner
            bg = 16384,
            fg = 1
        },
        content = { --The colors for the content
            bg = 1,
            fg = 32768  
        },
        column = { --The colors for the columns label
            bg = 128,
            fg = 1
        },
        listA = { --The colors for the list 1,3,etc. elements
            bg = 1,
            itemfg = 128, --The foreground color for the item's name
            pricefg = 32768 --The foreground color for the item's price
        },
        listB = { --The colors for the list 2,4,etc. elements
            bg = 256,
            itemfg = 128, --The foreground color for the item's name
            pricefg = 32768 --The foreground color for the item's price
        },
        footer = { --The colors for the footer
            bg = 128,
            fg = 1,
            exitfg = 256 --The color for the exit and the deposit message
        },
    }
}
```
# How to add new items?
To create new categories just create a new file in the items directory (example: Ores.conf)
```lua
{
    {
        ["name"] = "Redstone", --The name of the item
        ["query"] = "minecraft:redstone", --The query for the item (ex. "minecraft:redstone?displayName=redstone&nbt=asd123")
        ["normalPrice"] = 1, --The normal price for the item this will be the price of the item if the stock == normalStock
        ["normalStock"] = 2, --The normal stock for the item
        ["forcePrice"] = false, --Disables the dinamic pricing for this item
    }
}
```
# Can I modify the code?
Yes, you can modify the code if you don't like the design or you have any other problems, you can also create a pull request
