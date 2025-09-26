# Raw (modem) API documentation
## Client to Server packets
```lua
{
    protocol = "SPAPIv1",
    user = "your-uuid", -- Your UUID
    type = "balance", -- The type of the packet
    data = { -- The additional data you send
        ...
    },
    time = math.floor(os.epoch("utc") / 1000), -- The time when the packet was created
    computer = os.getComputerID() -- The ID of the computer
}
```
After you create the packet, you need to sign it and send it to the server [Message communication](#message-communication)

### balance
Returns the user's current balance

**Additional data**

**Server response**

- [balance_ack](#balance_ack)

### info
Returns information about the shop or a specified item

**Additional data**

- item?: string: The name or alias of the item

**Server response**

- [shop_info](#shop_info)
- [item_info](#item_info)

**Errors**

- [item_not_found](#item_not_found)

### price
Returns the price of a specific item. If you want to see the sell price of an item, set the `amount` field negative

**Additional data**

- item: string: The name or alias of the item
- amount: number: The amount you want to see buy/sell price for

**Server response**

- [price_ack](#price_ack)

**Errors**

- [missing_data](#missing_data)
- [invalid_data](#invalid_data)
- [item_not_found](#item_not_found)

### arb
Returns the arbitrage possibility for a specific item

**Additional data**

- item: string: The name or alias of the item
- price: number: The price of the item in another shop

**Server response**

- [arb_ack](#arb_ack)

**Errors**

- [missing_data](#missing_data)
- [invalid_data](#invalid_data)
- [item_not_found](#item_not_found)

### money
Returns the money information of the shop

**Additional data**

**Server response**

- [money_info](#money_info)

### withdraw
Lets you withdraw money

**Additional data**

- address: string: The target kromer address
- amount: number: The amount you want to withdraw

**Server response**

- [withdraw](#withdraw)

**Errors**

- [missing_data](#missing_data)
- [invalid_data](#invalid_data)
- [kromer_disconnected](#kromer_disconnected)
- [please_wait](#please_wait)
- [insufficient_balance](#insufficient_balance)
- [shop_insufficient_balance](#shop_insufficient_balance)
- [transaction_failed](#transaction_failed)

### buy
Queues a buy order

**Additional data**

- item: string: The name or alias of the item
- amount: number: The amount you want to buy

**Server response**

- [order_queued](#order_queued)

**Errors**

- [missing_data](#missing_data)
- [invalid_data](#invalid_data)
- [item_not_found](#item_not_found)
- [no_api_chest](#no_api_chest)
- [no_agreement](#no_agreement)
- [too_many_orders](#too_many_orders)
- [too_many_active_orders](#too_many_active_orders)

### sell
Queues a sell order

**Additional data**

- item: string: The name or alias of the item
- amount: number: The amount you want to sell

**Server response**

- [order_queued](#order_queued)

**Errors**

- [missing_data](#missing_data)
- [invalid_data](#invalid_data)
- [item_not_found](#item_not_found)
- [no_api_chest](#no_api_chest)
- [no_agreement](#no_agreement)
- [too_many_orders](#too_many_orders)
- [too_many_active_orders](#too_many_active_orders)

### getOrders
Returns your currently queued orders

**Additional data**

**Server response**

- [orders_ack](#orders_ack)

## Server to Client packets
```lua
{
    ["protocol"] = "SPAPIv1",
    ["type"] = "balance_ack", -- The type of the packet
    ["data"] = { -- The additional data the shop sends
        ...
    },
    ["reqComputer"] = 0, -- The ID of your computer
    ["reqTime"] = 0, -- The time when you sent your request
    ["time"] = math.floor(os.epoch("utc") / 1000), -- The time when the shop generated the response
    ["computer"] = os.getComputerID() -- The computer ID of the shop
}
```
After a packet is created, it gets signed [Message communication](#message-communication)

### balance_ack
Returns the user's current balance

**Additional data**

- balance: number: The current balance of the user

### shop_info
Returns information about the shop

**Additional data**

- name: string: The name of the shop
- description: string: The description of the shop
- location: table: The x,y,z location of the shop
- address: string: The kromer address of the shop
- tradingFees: number: The trading fees applied in percentage
- balance: number: The current balance of the shop
- storage: table: Information about storage `{ all,free,used,percentage }`
- version: string: The version of SolidityPools ran on the shop

### item_info
Returns information about a specified item

**Additional data**

- name: string: The name of the item
- aliases: table: The list of aliases for the item
- query: string: The item query of the item
- allocatedItems: number: The amount of items allocated
- allocatedMoney: number: The amount of money allocated
- count: number: The amount of items there is in stock

### price_ack
Returns the price of a specific item. If you want to see the sell price of an item, set the `amount` field negative

**Additional data**

- amount: number: The price of the item
- amountPerItem: number: The price per item

### arb_ack
Returns the arbitrage possibility for a specific item

**Additional data**

- canProfit: boolean: If profitting is possible

Or

- canProfit: boolean: If profitting is possible
- count: number: The amount of items you need to buy
- buyPrice: number: The price of purchasing this much items
- sellPrice: number: The amount of money you get for selling the items
- profit: number: The profit

### money_info
Returns the money information of the shop

**Additional data**

- balance: number: The balance of the shop
- allocations: table: The money allocations `{all, fees, userBalances, itemAllocations, unallocated}`
- percentages: table: The money percentages `{all, fees, userBalances, itemAllocations, unallocated}`

### withdraw_ack
Lets you withdraw money

**Additional data**

- balance: number: Your new balance

### order_queued
Tells the user that their order have been queued

**Additional data**

- orderId: string: The ID of the order

### orders_ack
Returns your currently queued orders

**Additional data**

- orders: table: Your currently queued orders
```lua
{
    id = "abcdef", -- The ID of the order
    item = "rds", -- The item you will buy/sell
    amount = 10, -- The amount of items you will buy/sell
    expectedTime = 0, -- The expected UNIX time when your order will be ready
    type = "buy" -- The type of the order
}
```

### order_fulfilled
The order was successfully fulfilled

**Additional data**

- orderId: string: The order ID
- item: string: The name of the item
- amount: number: The amount you bought/sold
- price: number: The price of the items
- pricePerItem: number: The price per item

### order_failed
An error message, indicates that there was an error while fulfilling your order

**See**

- [order_internal_error](#order_internal_error)
- [order_internal_timeout](#order_internal_timeout)
- [order_item_import_failed](#order_item_import_failed)
- [order_item_limit_reached](#order_item_limit_reached)

## Errors
Errors are Server to Client packets with type `error`. They always have an `error` and a `message` field explaining the error.

### banned
You are banned from using the shop or from using the API

**Additional data**

- reason: string: The reason of the ban

### item_not_found
The item you specified can not be found

**Additional data**

- suggestion?: string: The suggested item, if there is one

### missing_data
You didn't specify enough data

**Additional data**

- data: table: The list of data you need to specify

### invalid_data
You sent invalid data

**Additional data**

- data: string: The invalid data

### kromer_disconnected
Kromer is not connected

### please_wait
Please wait a few seconds, until the shop processes something

### insufficient_balance
You don't have enough money

### shop_insufficient_balance
The shop doesn't have enough money

### transaction_failed
The withdraw transaction failed

### no_api_chest
You don't have an API chest set up, please look at [Setup](https://github.com/afonya2/SolidityPools/blob/v2/api/README.md#setup)

### no_agreement
You need to agree to the TOS before making any orders. Run `\sp2 agree` to agree to the TOS

### too_many_orders
There are too many orders for the shop to process at the moment. See [Limitations](#limitations)

### too_many_active_orders
You have too many orders pending. See [Limitations](#limitations)

### unknown_type
The packet type is unknown

### order_internal_timeout
There was an internal timeout while fulfilling your order

**Additional data**

- orderId: string: The ID of the order

### order_internal_error
There was an internal error while fulfilling your order

**Additional data**

- orderId: string: The ID of the order

### order_item_limit_reached
The item limit is reached and the shop won't accept more of that item

**Additional data**

- orderId: string: The ID of the order

### order_item_import_failed
There was an error while trying to import your items into the storage

**Additional data**

- orderId: string: The ID of the order

## Limitations

- Each computer is limited to 1 packet/second. Further packets will be dropped.
- Invalid packet format, invalid signature will result in the packet getting dropped.
- The shop can have 100 queued orders at a time.
- Each user can have 5 queued orders at a time.
- Cross-dimension packets are dropped for security reasons.

## Message communication
SolidityPools uses symmetric message signatures to verify that a packet is from a specific user.

Example code for signing and transmitting:
```lua
local sha = require("sha256") -- https://pastebin.com/6UV4qfNF
local apiKey = ""
local port = 1234

local function base10ToBase16(n)
    local convo = {[0]="0",[1]="1",[2]="2",[3]="3",[4]="4",[5]="5",[6]="6",[7]="7",[8]="8",[9]="9",[10]="a",[11]="b",[12]="c",[13]="d",[14]="e",[15]="f"}
    local out = ""
    while n > 0 do
        out = convo[n%16] .. out
        n = math.floor(n/16)
    end
    return out
end
local function bytesToHexString(tbl)
    local out = ""
    for i=1,#tbl do
        local temp = base10ToBase16(tbl[i])
        if #temp == 1 then
            temp = "0" .. temp
        end
        out = out .. temp
    end
    return out
end
local function copy(tbl, deep)
    local out = {}
    for k,v in pairs(tbl) do
        if deep and type(v) == "table" then
            out[k] = copy(v, deep)
        else
            out[k] = v
        end
    end
    return out
end
local function safeSerialise(tbl)
    local tType = type(tbl)
    if tType == "table" then
        local keys = {}
        for k in pairs(tbl) do
            table.insert(keys, k)
        end
        table.sort(keys)

        local result = {}
        table.insert(result, "{")
        for i, k in ipairs(keys) do
            local v = tbl[k]
            table.insert(result, "[" .. safeSerialise(k) .. "]=" .. safeSerialise(v))
            table.insert(result, ",")
        end
        table.insert(result, "}")
        return table.concat(result)
    elseif tType == "string" then
        return string.format("%q", tbl)
    elseif tType == "number" or tType == "boolean" or tType == "nil" then
        return tostring(tbl)
    else
        error("unsupported type: " .. tType)
    end
end

local msg = {
    ...
}
local hashed = safeSerialise(copy(msg))
msg.hash = bytesToHexString(sha.digest(apiKey .. hashed))
modem.transmit(port, port, textutils.serialise(msg, { allow_repetitions = true, compact = true }))
```