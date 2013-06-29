--[[
--Advanced market mod by arsdragonfly
--]]

advanced_market = {}
advanced_market.data = {}

function advanced_market.save_data()
	if advanced_market.data.orders == nil then
		advanced_market.data = {}
	end
	if advanced_market.data.stacks == nil then
		advanced_market.data.stacks = {}
	end
	if advanced_market.data.buffers == nil then
		advanced_market.data.buffers = {}
	end
	local output = io.open(minetest.get_worldpath() .. "/advanced_market","w")
	output:write(minetest.serialize(advanced_market.data))
	io.close(output)
end

function advanced_market.initialize()
	local input = io.open(minetest.get_worldpath() .. "/advanced_market","r")
	if input then
		advanced_market.data = minetest.deserialize(input:read("*l"))
		io.close(input)
	else --first run; create the data file
		advanced_market.save_data()
	end
end

function advanced_market.order(orderer,item,amount,price,ordertype)
	--check if the buyer has sufficient money
	if ordertype == "buy" then
		if amount * price > money.get_money(orderer) then
			return false
		end
	end
	--pick an order number
	local order_number = advanced_market.data.max_order_number 
	advanced_market.data.max_order_number = order_number + 1
	--initialize some stuff in the buffer if it's the orderer's first order
	if advanced_market.data.buffers[orderer] == nil then
		advanced_market.buffers[orderer] = {}
	end
	if advanced_market.data.buffers[orderer].out == nil then
		advanced_market.buffers[orderer].out = {}
	end
	if advanced_market.data.buffers[orderer].into == nil then
		advanced_market.buffers[orderer].into = {}
	end
	if advanced_market.data.buffers[orderer].out.money == nil then
		advanced_market.buffers[orderer].out.money = 0
	end
	if advanced_market.data.buffers[orderer].out.items == nil then
		advanced_market.buffers[orderer].out.items = {}
	end
	if advanced_market.data.buffers[orderer].out.items[item] == nil then
		advanced_market.buffers[orderer].out.items[item] = 0
	end
	if advanced_market.data.buffers[orderer].into.money == nil then
		advanced_market.buffers[orderer].into.money = 0
	end
	if advanced_market.data.buffers[orderer].into.items == nil then
		advanced_market.buffers[orderer].into.items = {}
	end
	if advanced_market.data.buffers[orderer].into.items[item] == nil then
		advanced_market.buffers[orderer].into.items[item] = 0
	end
	--add some stuff to the buffer
	if ordertype == "buy" then
		advanced_market.data.buffers[orderer].out.money =  advanced_market.data.buffers[orderer].out.money + amount * price
	else -- ordertype is sell
		advanced_market.data.buffers[orderer].out.items[item] = advanced_market.data.buffers[orderer].out.items[item] + amount
	end
	--add to the orders list
	advanced_market.save_order(order_number,orderer,item,amount,price,ordertype,amount)
	--process the order in stack
	if not advanced_market.search_for_target_order_in_stack(item,price,ordertype) then
		advanced_market.save_order_in_stack(order_number,orderer,item,amount,price,ordertype,amount)
	else
		while true do
			local target_order_number = advanced_market.search_for_target_order_in_stack(item,price,ordertype)
			advanced_market.transact(order_number,target_order_number,item)
			if advanced_market.data.orders[order_number].amount_left == 0 then break end
			if not advanced_market.search_for_target_order_in_stack(item,price,ordertype) then break end
		end
	end
	advanced_market.save_data()
end

function advanced_market.save_order(order_number,orderer,item,amount,price,ordertype,amount_left)
	if advanced_market.data.orders[order_number] == nil then
		advanced_market.data.orders[order_number] = {}
	end
	advanced_market.data.orders[order_number].orderer = orderer
	advanced_market.data.orders[order_number].item = item
	advanced_market.data.orders[order_number].amount = amount
	advanced_market.data.orders[order_number].price = price
	advanced_market.data.orders[order_number].ordertype = ordertype
	advanced_market.data.orders[order_number].amount_left = amount_left
	advanced_market.save_data()
end

function advanced_market.save_order_in_stack(order_number_,orderer,item,amount,price,ordertype,amount_left)
	if advanced_market.data.stacks[item] == nil then
		advanced_market.data.stacks[item] = {}
	end
	if advanced_market.data.stacks[item][order_number] == nil then
		advanced_market.data.stacks[item][order_number] = {}
	end
	advanced_market.data.stacks[item][order_number].orderer = orderer
	advanced_market.data.stacks[item][order_number].item = item
	advanced_market.data.stacks[item][order_number].amount = amount
	advanced_market.data.stacks[item][order_number].price = price
	advanced_market.data.stacks[item][order_number].ordertype = ordertype
	advanced_market.data.stacks[item][order_number].amount_left = amount_left
	advanced_market.save_data()
end

function advanced_market.search_for_target_order_in_stack(item,price,ordertype)
	--return the best target order number or false
	--orders are sorted according to price and time (order number)
	if advanced_market.data.stacks[item] == nil then
		return false
	end
	local best_order_number = 0
	if ordertype == "buy" then
		local target_ordertype == "sell"
	else
		local target_ordertype == "buy"
	end
	for order_number , content in pairs(advanced_market.data.stacks.[item]) do
		if ordertype == "buy" then
			if content.price > (advanced_market.data.stacks[item][best_order_number].price or price) then
				best_order_number = order_number
			else if (content.price = (advanced_market.data.stacks[item][best_order_number].price or price)) and (order_number < best_order_number) then
				best_order_number = order_number
			end
		end
	else -- ordertype is sell
		if content.price < (advanced_market.data.stacks[item][best_order_number].price or price) then
			best_order_number = order_number
		else if (content.price = (advanced_market.data.stacks[item][best_order_number].price or price)) and (order_number < best_order_number) then
			best_order_number = order_number
		end
	end
end
end
if best_order_number == 0 then
	return false
else
	return best_order_number
end
end

function advanced_market.transact(order_number,target_order_number,item)
	local orderer = advanced_market.data.orders[order_number].orderer
	local target_orderer = advanced_market.data.orders[target_order_number].orderer
	local price = advanced_market.data.orders[target_order_number].price
	local transaction_amount = (advanced_market.data.stacks[item][order_number].amount_left < advanced_market.data.stacks[item][target_order_number].amount_left) and advanced_market.data.stacks[item][order_number].amount_left or advanced_market.data.stacks[item][target_order_number].amount_left
	--choose the smaller one of the two order numbers as the transaction amount; .. and .. or .. is a ternary operator
	advanced_market.data.stacks[item][order_number].amount_left = advanced_market.data.stacks[item][order_number].amount_left - transaction_amount
	advanced_market.data.stacks[item][target_order_number].amount_left = advanced_market.data.stacks[item][target_order_number].amount_left - transaction_amount
	if advanced_market.data.stacks[item][order_number].amount_left == 0 then advanced_market.remove_order_from_stack(order_number)end
	if advanced_market.data.stacks[item][target_order_number].amount_left == 0 then advanced_market.remove_order_from_stack(target_order_number)end
	--Modify the stack
	advanced_market.data.orders[order_number].amount_left = advanced_market.data.orders[order_number].amount_left - transaction_amount
	advanced_market.data.orders[target_order_number].amount_left = advanced_market.data.orders[target_order_number].amount_left - transaction_amount
	--Modify the orders list
	if advanced_market.data.orders[order_number].ordertype == "buy" then
		--set the money and item
		advanced_market.data.buffers[orderer].out.money = advanced_market.data.buffers[orderer].out.money - transaction_amount * price
		advanced_market.data.buffers[target_orderer].into.money = advanced_market.data.buffers[target_orderer].into.money + transaction_amount * price
		advanced_market.data.buffers[orderer].into.items[item] = advanced_market.data.buffers[orderer].into.items[item] - transaction_amount
		advanced_market.data.buffers[target_orderer].out.items[item] = advanced_market.data.buffers[target_orderer].out.items[item] - transaction_amount
	else --ordertype is sell
		--set the money and item
		advanced_market.data.buffers[orderer].into.money = advanced_market.data.buffers[orderer].into.money + transaction_amount * price
		advanced_market.data.buffers[target_orderer].out.money = advanced_market.data.buffers[target_orderer].out.money - transaction_amount * price
		advanced_market.data.buffers[orderer].out.items[item] = advanced_market.data.buffers[orderer].out.items[item] + transaction_amount
		advanced_market.data.buffers[target_orderer].into.items[item] = advanced_market.data.buffers[target_orderer].into.items[item] + transaction_amount
	end
	advanced_market.save_data()
end

advanced_market.initialize()
