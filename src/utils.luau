--!strict

const globals = require("./globals")
const swan_types = require("./swan_types")

--- @class utils

const utils = {}

const effects = globals.effects
const batched = globals.batched

const function deep_clone<K, V>(t: { [K]: V }): { [K]: V }
	if type(t) ~= "table" then
		return t
	end

	const clone: any = {}
	for k, v: any in t do
		clone[k] = deep_clone(v)
	end

	return clone
end

function utils.make_proxy(real: any, state: swan_types.state, root_old: any, self_old: any): ...unknown
	if type(real) ~= "table" or utils.is_proxy(real) then
		return real
	end

	if not root_old then
		root_old = deep_clone(real)
		self_old = root_old
	end

	const proxified = {}
	for k, v in real do
		proxified[k] = utils.make_proxy(v, state, root_old, self_old[k])
	end

	const subscribers = state.subscribers
	return setmetatable({}, {
		[globals.SWAN_PROXY_ID] = true,
		[globals.SWAN_REAL_ID] = real,
		__index = proxified,
		__newindex = function(_, k, v)
			if proxified[k] == v and not state.always_force then
				return
			end
			proxified[k] = v
			real[k] = v

			for callback, state_i in subscribers do
				(callback)(root_old, state_i)
			end

			self_old[k] = v
		end,
	})
end

--[=[
	Batches any state write operation up until the given function is done running.

	```lua
	const text = swan.state("Hey, how is it going?")

	swan.effect(function()
		print(text())
	end)

	utils.batch(function()
		text("Hello, World!")
		text("Bye, World!")
	end) -- the previous effect will only print "Bye, World!"

	utils.batch(function()
		text("Hello, World!")
		text("Bye, World!")
		text.value = "Oops"
	end) -- be careful! If the last write operation is done through .value, the effect will read that! -- "Oops"
	```
]=]
function utils.batch(fn: () -> ...unknown): ()
	globals.batching = true
	fn()

	for _, result in batched do
		for callback in result[1] :: { [swan_types.callback]: true } do
			callback(result[2], result[3] :: number)
		end
	end

	globals.batching = false
	table.clear(batched)
end

--[=[
	Returns whether the given value is a state.

	```lua
	const not_a_state = "Hey"
	print(utils.is_state(not_a_state)) -- false

	const a_state = swan.state("Cool")
	print(utils.is_state(a_state)) -- true
	```
]=]
function utils.is_state<T>(v: T): boolean
	return getmetatable(v) == globals.STATE_MT
end

--[=[
	Returns whether the given value is a computed state.

	```lua
	const not_a_computed = "Hey"
	print(utils.is_computed(not_a_computed)) -- false

	const a_computed = swan.computed(function()
		return "Cool"
	end)

	print(utils.is_computed(a_computed)) -- true
	```
]=]
function utils.is_computed<T>(v: T): boolean
	return utils.is_state(v) and ((v :: any) :: swan_types.state<T>).compute ~= nil
end

--[=[

	Returns whether the given value is a proxy.

	```lua
	const not_a_proxy = "Hey"
	print(utils.is_proxy(not_a_proxy)) -- false

	const a_proxy_state = swan.proxy {
		hello = "world"
	}
	print(utils.is_proxy(a_proxy_state())) -- true
	```
]=]
function utils.is_proxy<T>(v: T): boolean
	const mt = getmetatable(v)
	return mt and (mt :: any)[globals.SWAN_PROXY_ID] or false
end

--[=[

	Returns whether the given value is a state holding a proxy.

	```lua
	const not_a_proxy_state = "Hey"
	print(utils.is_proxy_state(not_a_proxy_state)) -- false
	not_a_proxy_state = swan.state("Hey")
	print(utils.is_proxy_state(not_a_proxy_state)) -- false

	const a_proxy_state = swan.proxy {
		hello = "world"
	}
	print(utils.is_proxy_state(a_proxy_state)) -- true
	```
]=]
function utils.is_proxy_state<T>(v: T): boolean
	return utils.is_state(v) and utils.is_proxy((v :: any).value) or false
end

--[=[
	Returns the "real" value of a proxy.

	```lua
	const todos = swan.proxy {
		"go outside",
		"touch grass",
		"write more todos"
	}

	print(todos(), todos()[1]) -- {}, "go outside"
	print(utils.get_real(todos())) --[[ {
		"go outside",
		"touch grass",
		"write more todos"
	}
	]]--
	```
]=]
function utils.get_real<T>(proxy: swan_types.proxy_base_hack<T>): T
	return (getmetatable(proxy) :: any)[globals.SWAN_REAL_ID]
end

--[=[
	Disconnects all the effects from a specific state or in general.

	```lua
	const money = swan.state(10000)
	const health = swan.state(100)

	swan.effect(function()
		print("Your money:", money())
		print("Your health:", health())
	end)

	swan.effect(function()
		print("Your money (again):", money())
	end)

	money(100) -- "Your money: 100", "Your health: 100", "Your money (again): 100"
	health(50) -- "Your money: 100", "Your health: 50"

	utils.clear(health)
	health(200) -- *crickets*
	money(50) -- "Your money: 50", "Your health: 200", "Your money (again): 50"

	utils.clear()
	money(10) -- *crickets*
	```
]=]
function utils.clear<T>(state: swan_types.state<T>?): ()
	table.clear(state and state.subscribers or effects)
end

return utils
