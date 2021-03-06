--
--Advanced market mod by arsdragonfly
--

advanced_market = {}
advanced_market.data = {}

local S
if (minetest.get_modpath("intllib")) then
  dofile(minetest.get_modpath("intllib").."/intllib.lua")
  S = intllib.Getter(minetest.get_current_modname())
else
  S = function ( s ) return s end
end

function advanced_market.save_data()
	if advanced_market.data == nil then
		advanced_market.data = {}
	end
	if advanced_market.data.stacks == nil then
		advanced_market.data.stacks = {}
	end
	if advanced_market.data.buffers == nil then
		advanced_market.data.buffers = {}
	end
	if advanced_market.data.orders == nil then
		advanced_market.data.orders = {}
	end
	local output = io.open(minetest.get_worldpath() .. "/advanced_market","w")
	output:write(minetest.serialize(advanced_market.data))
	io.close(output)
end

function advanced_market.initialize()
	local input = io.open(minetest.get_worldpath() .. "/advanced_market","r")
	if input then
		advanced_market.data = minetest.deserialize(input:read("*all"))
		io.close(input)
	end
	advanced_market.save_data()
end

function advanced_market.initialize_buffer(orderer,item)
	--initialize some stuff in the buffer if it's the orderer's first order
	--into: everything going in; out: everything goint out(money to be paid etc.)
	if advanced_market.data.buffers[orderer] == nil then
		advanced_market.data.buffers[orderer] = {}
	end
	local buffer = advanced_market.data.buffers[orderer]
	if buffer.out == nil then
		buffer.out = {}
	end
	if buffer.into == nil then
		buffer.into = {}
	end
	if buffer.out.money == nil then
		buffer.out.money = 0
	end
	if buffer.out.items == nil then
		buffer.out.items = {}
	end
	if buffer.out.items[item] == nil then
		buffer.out.items[item] = 0
	end
	if buffer.into.money == nil then
		buffer.into.money = 0
	end
	if buffer.into.items == nil then
		buffer.into.items = {}
	end
	if buffer.into.items[item] == nil then
		buffer.into.items[item] = 0
	end
end

function advanced_market.order(orderer,item,amount,price,ordertype)
	--check if the buyer has sufficient money
	if ordertype == "buy" and amount * price > money.get_money(orderer) then
		return false
	end
	--pick an order number
	local order_number = advanced_market.data.max_order_number or 1
	advanced_market.data.max_order_number = order_number + 1
	advanced_market.initialize_buffer(orderer,item)
	--add some stuff to the buffer
	local buffer = advanced_market.data.buffers[orderer]
	if ordertype == "buy" then
		buffer.out.money =  buffer.out.money + amount * price
		money.set_money(orderer,money.get_money(orderer) - amount * price)
		if buffer.out.items[item] == 0 then buffer.out.items[item] = nil end -- the previous buffer initializing was unnecessary; prevent creating garbage data.
	else -- ordertype is sell
		buffer.out.items[item] = buffer.out.items[item] + amount
	end
	--add to the orders list
	advanced_market.save_order(order_number,orderer,item,amount,price,ordertype,amount)
	advanced_market.save_order_in_stack(order_number,orderer,item,amount,price,ordertype,amount)
	--process the order in stack
	if advanced_market.search_for_target_order_in_stack(item,price,ordertype) then
		while true do
			local target_order_number = advanced_market.search_for_target_order_in_stack(item,price,ordertype)
			advanced_market.transact(order_number,target_order_number,item)
			--don't stop until there's no more items/available orders
			if advanced_market.data.orders[order_number].amount_left == 0 then break end
			if not advanced_market.search_for_target_order_in_stack(item,price,ordertype) then break end
		end
	end
	advanced_market.save_data()
	return true
end

function advanced_market.save_order(order_number,orderer,item,amount,price,ordertype,amount_left)
	if advanced_market.data.orders[order_number] == nil then
		advanced_market.data.orders[order_number] = {}
	end
	local order = advanced_market.data.orders[order_number]
	order.orderer = orderer
	order.item = item
	order.amount = amount
	order.price = price
	order.ordertype = ordertype
	order.amount_left = amount_left
	advanced_market.save_data()
end

function advanced_market.save_order_in_stack(order_number,orderer,item,amount,price,ordertype,amount_left)
	if advanced_market.data.stacks[item] == nil then
		advanced_market.data.stacks[item] = {}
	end
	if advanced_market.data.stacks[item][order_number] == nil then
		advanced_market.data.stacks[item][order_number] = {}
	end
	local stack_entry = advanced_market.data.stacks[item][order_number]
	stack_entry.orderer = orderer
	stack_entry.item = item
	stack_entry.amount = amount
	stack_entry.price = price
	stack_entry.ordertype = ordertype
	stack_entry.amount_left = amount_left
	advanced_market.save_data()
end

function advanced_market.search_for_target_order_in_stack(item,price,ordertype)
	--return the best target order number or false
	--orders are sorted according to price and time (order number)
	if advanced_market.data.stacks[item] == nil then
		return false
	end
	local best_order_number = 0
	local target_ordertype = ""
	local best_price = 0
	if ordertype == "buy" then
		target_ordertype = "sell"
	else
		target_ordertype = "buy"
	end
	for order_number , content in pairs(advanced_market.data.stacks[item]) do
		if advanced_market.data.stacks[item][best_order_number] == nil then
			best_price = price
		else
			best_price = advanced_market.data.stacks[item][best_order_number].price
		end
		if target_ordertype == "buy" then
			if content.ordertype == "buy" then
				if content.price > best_price then
					best_order_number = order_number
				else if (content.price == best_price) and ((order_number < best_order_number) or (best_order_number == 0 )) then
					best_order_number = order_number
				end
			end
		end
	else -- target ordertype is sell
		if content.ordertype == "sell" then
			if content.price < best_price then
				best_order_number = order_number
			else if (content.price == best_price) and ((order_number < best_order_number) or (best_order_number == 0)) then
				best_order_number = order_number
			end
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
	local order = advanced_market.data.orders[order_number]
	local target_order = advanced_market.data.orders[target_order_number]
	local orderer = order.orderer
	local target_orderer = target_order.orderer
	local orderer_buffer = advanced_market.data.buffers[orderer]
	local target_orderer_buffer = advanced_market.data.buffers[target_orderer]
	local price = target_order.price
	local orderer_price = order.price
	local order_stack_entry = advanced_market.data.stacks[item][order_number]
	local target_order_stack_entry = advanced_market.data.stacks[item][target_order_number]
	local transaction_amount = (order_stack_entry.amount_left < target_order_stack_entry.amount_left) and order_stack_entry.amount_left or target_order_stack_entry.amount_left
	--choose the smaller one of the two order numbers as the transaction amount; .. and .. or .. is a ternary operator
	order_stack_entry.amount_left = order_stack_entry.amount_left - transaction_amount
	target_order_stack_entry.amount_left = target_order_stack_entry.amount_left - transaction_amount
	if order_stack_entry.amount_left == 0 then advanced_market.remove_order_from_stack(order_number)end
	if target_order_stack_entry.amount_left == 0 then advanced_market.remove_order_from_stack(target_order_number)end
	--Modify the stack
	order.amount_left = order.amount_left - transaction_amount
	target_order.amount_left = target_order.amount_left - transaction_amount
	--Modify the orders list
	if order.ordertype == "buy" then
		--set the money and item in buffers
		orderer_buffer.out.money = orderer_buffer.out.money - transaction_amount * price
		target_orderer_buffer.into.money = target_orderer_buffer.into.money + transaction_amount * price
		if orderer_price ~= price then --the orderer offered a surplus amount of money
			orderer_buffer.out.money = orderer_buffer.out.money - transaction_amount * (orderer_price - price)
			orderer_buffer.into.money = orderer_buffer.into.money + transaction_amount * (orderer_price - price)
		end
		orderer_buffer.into.items[item] = orderer_buffer.into.items[item] + transaction_amount
		target_orderer_buffer.out.items[item] = target_orderer_buffer.out.items[item] - transaction_amount
		if target_orderer_buffer.out.items[item] == 0 then target_orderer_buffer.out.items[item] = nil end
	else --ordertype is sell
		--set the money and item in buffers
		orderer_buffer.into.money = orderer_buffer.into.money + transaction_amount * price
		target_orderer_buffer.out.money = target_orderer_buffer.out.money - transaction_amount * price
		orderer_buffer.out.items[item] = orderer_buffer.out.items[item] - transaction_amount
		if orderer_buffer.out.items[item] == 0 then orderer_buffer.out.items[item] = nil end
		target_orderer_buffer.into.items[item] = target_orderer_buffer.into.items[item] + transaction_amount
	end
	advanced_market.save_data()
end

function advanced_market.remove_order_from_stack(order_number)
	advanced_market.data.stacks[advanced_market.data.orders[order_number].item][order_number] = nil
end

function advanced_market.cancel_order(order_number)
	advanced_market.remove_order_from_stack(order_number)
	local orderer = advanced_market.data.orders[order_number].orderer
	local itemname = advanced_market.data.orders[order_number].item
	local amount_left = advanced_market.data.orders[order_number].amount_left
	local price = advanced_market.data.orders[order_number].price
	local ordertype = advanced_market.data.orders[order_number].ordertype
	local buffer = advanced_market.data.buffers[name]
	if ordertype == "buy" then
		if buffer.into.money == nil then buffer.into.money = 0 end
		buffer.into.money = buffer.into.money + amount_left * price
		buffer.out.money = buffer.out.money - amount_left * price
	else
		if buffer.into.items[itemname] == nil then buffer.into.items[itemname] = 0 end
		buffer.into.items[itemname] = buffer.into.items[itemname] + amount_left
		buffer.out.items[itemname] = buffer.into.items[itemname] - amount_left
		if buffer.out.items[itemname] == 0 then buffer.out.items[itemname] = nil end
	end
	advanced_market.data.orders[order_number].amount_left = 0
	advanced_market.save_data()
end

function advanced_market.view_orders(orderer)
	local orderstring = ""
	for order_number,order in pairs(advanced_market.data.orders) do
		if order.orderer == orderer then
			orderstring = orderstring .. order_number .. " | " .. minetest.serialize(order) .. "\n"
		end
	end
	return orderstring
end

function advanced_market.check_params(name,func,params)
	local stat,msg = func(params)
	if not stat then
		minetest.chat_send_player(name,msg)
		return false
	end
	return true
end

advanced_market.initialize()

local register_chatcommand_table = {
	params = "[buy <item> <amount> <price> | sell <price> | viewstack <item> | viewbuffer | refreshbuffer | getname | viewlog | cancelorder <ordernumber>]",
	description = "trade on the market",
	func = function(name,param)
		advanced_market.data.log = (advanced_market.data.log or "") .. name .. " , " .. param .. ";"
		local t = string.split(param, " ")
		if t[1] == nil then
				minetest.chat_send_player(name,S([[buy <item> <amount> <price> | sell <price> | viewstack <item> | viewbuffer | refreshbuffer | getname | viewlog | cancelorder <ordernumber>]]))
		end
		if t[1] == "buy" then
			if not advanced_market.check_params(
				name,
				function (params)
					if not tonumber(params[3]) or
						not tonumber(params[4]) or
						not ((tonumber(params[3])) >= 1) or
						not ((tonumber(params[4])) >= 1) then
						return false,S([[ERROR: amount and/or price is not correct number.]])
					end
					return true
				end,
				t) then return end
				if not advanced_market.order(name,t[2],math.floor(tonumber(t[3])),math.floor(tonumber(t[4])),"buy") then
					minetest.chat_send_player(name,S([[ERROR: you don't have enough money.]]))
				else
					minetest.chat_send_player(name,S([[Order submitted succesfully.]]))
				end
			end
			if t[1] == "sell" then
				local player = minetest.get_player_by_name(name)
				local wielditem = player:get_wielded_item()
				local wieldname = wielditem:get_name()
				advanced_market.data.log = advanced_market.data.log .. wieldname
				local wieldcount = wielditem:get_count()
				if not advanced_market.check_params(
					name,
					function (params)
						if wieldname == "" then
							return false,S([[ERROR: cannot sell empty item.]])
						end
						if not tonumber(params[2]) or
							not (tonumber(params[2]) >= 1) then
							return false,S([[ERROR: incorrect price.]])
						end
						minetest.chat_send_player(name,S([[Order submitted succesfully.]]))
						return true
					end,
					t) then return end
					advanced_market.order(name,wieldname,wieldcount,tonumber(t[2]),"sell")
					player:set_wielded_item(ItemStack(""))
				end
				if t[1] == "getname" then
					local player = minetest.get_player_by_name(name)
					local wielditem = player:get_wielded_item()
					local wieldname = wielditem:get_name()
					minetest.chat_send_player(name,wieldname)
				end
				if t[1] == "cancelorder" then
					--need to access advanced_market, so check_params isn't used
					if not tonumber(t[2]) or
						not advanced_market.data.orders[tonumber(t[2])] then
						minetest.chat_send_player(name,S([[ERROR: no such order.]]))
						do return end
					end
					if name ~= advanced_market.data.orders[tonumber(t[2])].orderer then
						minetest.chat_send_player(name,S([[ERROR: it's not your order.]]))
						do return end
					end
					advanced_market.cancel_order(tonumber(t[2]))
					minetest.chat_send_player(name,S([[Order cancelled succesfully.]]))
				end
				if t[1] == "vieworder" then
					minetest.chat_send_player(name,advanced_market.view_orders(name))
				end
				if t[1] == "viewlog" then
					minetest.chat_send_player(name,advanced_market.data.log)
				end
				if t[1] == "viewstack" then
					minetest.chat_send_player(name,minetest.serialize(advanced_market.data.stacks[t[2]]))
				end
				if t[1] == "viewbuffer" then
					minetest.chat_send_player(name,minetest.serialize(advanced_market.data.buffers[name]))
				end
				if t[1] == "refreshbuffer" then
					local player = minetest.get_player_by_name(name)
					local playerinv = player:get_inventory()
					for k,v in pairs(advanced_market.data.buffers[name].into.items) do
						if playerinv:room_for_item("main",ItemStack(tostring(k).." "..tostring(v))) then
							playerinv:add_item("main",ItemStack(tostring(k).." "..tostring(v)))
							advanced_market.data.buffers[name].into.items[k] = nil
						else
							minetest.chat_send_player(name,S([[WARNING: There's no room in your inventory for more items.]]))
							break
						end
					end
					money.set_money(name,money.get_money(name) + advanced_market.data.buffers[name].into.money)
					advanced_market.data.buffers[name].into.money = 0
					minetest.chat_send_player(name,S([[Buffer refreshed succesfully.]]))
				end
				advanced_market.data.log = advanced_market.data.log .. "\n"
				advanced_market.save_data()
			end
		}
		minetest.register_chatcommand("advanced_market", register_chatcommand_table)

		minetest.register_chatcommand("am", register_chatcommand_table)

		minetest.register_chatcommand("amarket", register_chatcommand_table)
