# Raw (modem) API documentation
## Message communication


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

**Errors**

### info
Returns information about the shop or a specified item

**Additional data**

- item?: string: The name or alias of the item

**Server response**

- [shop_info](#shop_info)
- [item_info](#item_info)

**Errors**

### price
Returns the price of a specific item. If you want to see the sell price of an item, set the `amount` field negative

**Additional data**

- item: string: The name or alias of the item
- amount: number: The amount you want to see buy/sell price for

**Server response**

- [price_ack](#price_ack)

**Errors**

### arb
Returns the arbitrage possibility for a specific item

**Additional data**

- item: string: The name or alias of the item
- price: number: The price of the item in another shop

**Server response**

- [arb_ack](#arb_ack)

**Errors**

### money
Returns the money information of the shop

**Additional data**

**Server response**

- [money_info](#money_info)

**Errors**

### withdraw
Lets you withdraw money

**Additional data**

- address: string: The target kromer address
- amount: number: The amount you want to withdraw

**Server response**

- [withdraw](#withdraw)

**Errors**

### buy
Queues a buy order

**Additional data**

- item: string: The name or alias of the item
- amount: number: The amount you want to buy

**Server response**

- [order_queued](#order_queued)

**Errors**

### sell
Queues a sell order

**Additional data**

- item: string: The name or alias of the item
- amount: number: The amount you want to sell

**Server response**

- [order_queued](#order_queued)

**Errors**

### getOrders
Returns your currently queued orders

**Additional data**

**Server response**

- [orders_ack](#orders_ack)

**Errors**

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

## Errors

## Limitations