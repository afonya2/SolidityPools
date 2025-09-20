# Using the API

## Setup
First, you will need an API key which you can get by running:
```
\sp2 api key
```
If you don't have one, you can create one by running `\sp2 api key reset`.

Next you will need an ender storage that is owned by you. You can get one by crafting an ender storage with a diamond.

## Using the API
You can choose 2 options here.
1. You can make your own API using the docs in: [Modem Docs](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md)
2. You can use the pre-made Lua API by running `wget https://github.com/afonya2/SolidityPools/blob/v2/api/api.lua spapi.lua`

> [!IMPORTANT]  
> You should still read [Modem Docs](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md), to learn about the limitations and errors of the api

## Lua API docs
To set it up with your api key you need to do the following:
```lua
local spapi = require("spapi")

local api = spapi(2645, "your-uuid", "your-api-key")
```

### api.balance()
Returns your current balance

**Parameters**

**Returns**

1. number: The user's balance
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#balance_ack)

Or

1. nil: There was an error while processing the request
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.balance()
```

### api.info()
Returns the shop information

**Parameters**

**Returns**

1. table: The shop information [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#shop_info)
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#shop_info)

Or

1. nil: There was an error while processing the request
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.info()
```

### api.itemInfo(item)
Returns the information of a specific item

**Parameters**

1. item: string: The name or alias of the item

**Returns**

1. table: The item information [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#item_info)
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#item_info)

Or

1. nil: There was an error while processing the request
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.itemInfo("rds")
```

### api.price(item, amount)
Returns the price of a specific item. If you want to see the sell price of an item, set the `amount` field negative

**Parameters**

1. item: string: The name or alias of the item
2. amount: number: The amount you want to see buy/sell price for

**Returns**

1. number: The price of the item
2. number: The price per item
3. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#price_ack)

Or

1. nil: There was an error while processing the request
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.price("rds", 2)
```

### api.arb(item, price)
Returns the arbitrage possibility for a specific item

**Parameters**

1. item: string: The name or alias of the item
2. price: number: The price of the item in another shop

**Returns**

1. table: The arb possibility information [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#arb_ack)
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#arb_ack)

Or

1. nil: There was an error while processing the request
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.arb("rds", 0.01)
```

### api.money()
Returns the money information of the shop

**Parameters**

**Returns**

1. table: The money information of the shop [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#money_info)
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#money_info)

Or

1. nil: There was an error while processing the request
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.money()
```

### api.withdraw(address, amount)
Lets you withdraw money

**Parameters**

1. address: string: The target kromer address
2. amount: number: The amount you want to withdraw

**Returns**

1. number: Your new balance
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#withdraw)

Or

1. nil: There was an error while processing the request
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.withdraw("kaaaaaaaaa", 2)
```

### api.buy(item, amount, waitForComplete)
Queues a buy order

**Parameters**

1. item: string: The name or alias of the item
2. amount: number: The amount you want to buy
3. waitForComplete: boolean: If the API should wait until the order is fulfilled

**Returns**

1. string: The order ID
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#order_queued)

Or **when waitForComplete is true**

1. string: The order ID
2. string: The name of the item
3. number: The amount purchased
4. number: The price of the purchase
5. number: The price per item 
6. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#order_queued)
7. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#order_fulfilled)

Or

1. nil: There was an error while processing the request
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

Or **when waitForComplete is true and the error happened in the 2nd response**

1. string: The order ID
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.buy("rds", 2, true)
```

### api.sell(item, amount, waitForComplete)
Queues a sell order

**Parameters**

1. item: string: The name or alias of the item
2. amount: number: The amount you want to sell
3. waitForComplete: boolean: If the API should wait until the order is fulfilled

**Returns**

1. string: The order ID
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#order_queued)

Or **when waitForComplete is true**

1. string: The order ID
2. string: The name of the item
3. number: The amount sold
4. number: The price of the sell
5. number: The price per item 
6. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#order_queued)
7. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#order_fulfilled)

Or

1. nil: There was an error while processing the request
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

Or **when waitForComplete is true and the error happened in the 2nd response**

1. string: The order ID
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.sell("rds", 2, true)
```

### api.getOrders()
Returns your currently queued orders

**Parameters**

**Returns**

1. table: Your queued orders [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#orders_ack)
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#orders_ack)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.getOrders()
```

### api.listenForOrder(orderId)
Can be used to wait until the order is fulfilled

> [!WARNING]  
> It might happen that the shop fulfills the order before this is ran. When that happens it will yield indefinitely!

**Parameters**

1. orderId: string: The ID of the order

**Returns**

1. string: The order ID
2. string: The name of the item
3. number: The amount sold/purchased
4. number: The price of the sell/purchase
5. number: The price per item 
6. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#order_fulfilled)

Or

1. string: The order ID
2. table: The raw response from SP [more info](https://github.com/afonya2/SolidityPools/blob/v2/api/modemdocs.md#errors)

**Throws**

- If the received message contains an invalid signature

**Example**

```lua
api.sell("rds", 2, true)
```