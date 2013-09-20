advanced_market
===============
This mod allows you to trade in minetest as if you were in a stock market.
Dependencies:
money
locked_sign
Howto:

Sell the stuff you're holding:
/advanced_market sell <price>
e.g. /advanced_market sell 5

Buy some stuff:
/advanced_market buy <item> <amount> <price>
e.g. /advanced_market buy default:dirt 1 5

View available orders of one item:
/advanced_market viewstack <item>
e.g. /advanced_market viewstack default:dirt

View your buffer:
/advanced_market viewbuffer

Move all the stuff in your buffer into your inventory:
/advanced_market refreshbuffer

Once the deal is concluded, your money/item will be put into your buffer.
use /advanced_market refreshbuffer to get them back.

arsdragonfly@gmail.com
