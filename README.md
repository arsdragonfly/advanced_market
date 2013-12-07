advanced\_market
===============
This mod allows you to trade in minetest as if you were in a stock market.
Dependencies:
money
locked\_sign

Howto:

Command can be /am, /amarket or /advanced\_market
Sell the stuff you're holding:
/am sell PRICE
e.g. /am sell 5

Buy some stuff:
/am buy ITEM AMOUNT PRICE
e.g. /am buy default:dirt 1 5

View available orders of one item:
/am viewstack ITEM
e.g. /am viewstack default:dirt

View your buffer:
/am viewbuffer

Get the engine name of wielditem:
/am getname

View the log:
/am viewlog

View your orders:
/am vieworder
(output will be like: ORDERNUMBER | blah blah blah)

Cancel an order:
/am cancelorder ORDERNUMBER
e.g. /am cancelorder 1

Move all the stuff in your buffer into your inventory:
/am refreshbuffer

Once the deal is concluded, your money/item will be put into your buffer.
use /am refreshbuffer to get them back.

arsdragonfly@gmail.com
