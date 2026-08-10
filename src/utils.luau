--!strict

local globals = require("./globals")
local swan_types = require("./swan_types")

--- @class utils

local utils = {}

local function deep_clone<K, V>(t: { [K]: V }): { [K]: V }
	if type(t) ~= "table" then
		return t
	end

	local clone: any = {}
	for k, v: any in t do
		clone[k] = deep_clone(v)
	end

	return clone
end

local function assert_is_function<T>(v: T): T
	local vt = type(v)
	assert(vt == "function", `Expected a 'function', got a '{vt}', with value '{v}'!`)
	return v
end

function utils.make_proxy(real: any, state: swan_types.state, root_old: any, self_old: any): ...unknown
	if type(real) ~= "table" or utils.is_proxy(real) then
		return real
	end
	if not root_old then
		root_old = deep_clone(real)
		self_old = root_old
	end

	local proxified = {}
	for k, v in real do
		proxified[k] = utils.make_proxy(v, state, root_old, self_old[k])
	end

	local callbacks = state.callbacks
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

			for callback, state_i in callbacks do
				(callback)(root_old, state_i)
			end

			self_old[k] = v
		end,
	})
end

--[=[
	Batches any state write operation up until the given function is done running.

	```lua
	local text = swan.state("Hey, how is it going?")

	swan.effect(function()
		print(text())
	end)

	utils.batch(function()
		text("Hello, World!")
		text("Bye, World!")
	end) -- the previous effect will only print "Bye, World!"

	utils.batch(function()
		text.value = "Oops"
	end) -- be careful! If the last write operation is done through .value, the effect will also trigger! -- "Oops"
	```
]=]
function utils.batch(f: () -> ...unknown): ()
	globals.batching = true
	f()

	for _, result in globals.BATCHED do
		for callback in result[1] :: { [swan_types.callback]: true } do
			callback(result[2], result[3] :: number)
		end
	end

	globals.batching = false
	table.clear(globals.BATCHED)
end

--[=[
	[Branching](/docs/concepts#branching) function to be used within effects.

	Pass a condition to be checked, and after it a function to be run if it's successful.
	The last value, if a function, and if not after a condition, will be threated as the "else" branch.

	@param ... any -- The values and the branches.

	```lua
	local age = swan.state(16)
	local role = "admin"

	local bad_validator = swan.effect(function()
		if role ~= "admin" then -- admins can bypass the age verification
			assert(age() >= 18, "Your age is too low!")
		end
	end) -- won't detect `age` since in the first run, the condition was false, and age() wasn't called.

	local validator = swan.effect(function()
		utils.branch(
			role ~= "admin", function()
				assert(age() >= 18, "Your age is too low!")
			end
		)
	end) -- will detect `age`
	```
]=]
function utils.branch(...: any): ()
	local args = table.pack(...)
	local n = args.n
	assert(n > 1, `Expected at least 2 arguments, got {n}: {...}!`)

	local i = 1
	while i + 1 <= n do
		if args[i] or globals.current_callback then
			assert_is_function(args[i + 1])()
		end

		i += 2
	end

	if i <= n then
		assert_is_function(args[i])()
	end
end

--[=[
	Returns whether the given value is a state.

	```lua
	local not_a_state = "Hey"
	print(utils.is_state(not_a_state)) -- false

	local a_state = swan.state("Cool")
	print(utils.is_state(a_state)) -- true
	```
]=]
function utils.is_state<T>(v: T): boolean
	return getmetatable(v) == globals.STATE_MT
end

--[=[

	Returns whether the given value is a proxy.

	```lua
	local not_a_proxy = "Hey"
	print(utils.is_proxy(not_a_proxy)) -- false

	local a_proxy_state = swan.proxy_state({
		hello = "world"
	})
	print(utils.is_proxy(a_proxy_state())) -- true
	```
]=]
function utils.is_proxy<T>(v: T): boolean
	local mt = getmetatable(v)
	return mt and (mt :: any)[globals.SWAN_PROXY_ID] or false
end

--[=[

	Returns whether the given value is a state holding a proxy.

	```lua
	local not_a_proxy_state = "Hey"
	print(utils.is_proxy_state(not_a_proxy_state)) -- false
	not_a_proxy_state = swan.state("Hey")
	print(utils.is_proxy_state(not_a_proxy_state)) -- false

	local a_proxy_state = swan.proxy_state({
		hello = "world"
	})
	print(utils.is_proxy_state(a_proxy_state)) -- true
	```
]=]
function utils.is_proxy_state<T>(v: T): boolean
	return utils.is_state(v) and utils.is_proxy((v :: any).value) or false
end

--[=[
	Returns the "real" value of a proxy.

	```lua
	local todos = swan.proxy_state {
		"go outside",
		"touch grass",
		"write more todos"
	}

	print(todos(), todos()[1]) -- {}, "go outside"
	print(swan.get_real(todos())) --[[ {
		"go outside",
		"touch grass",
		"write more todos"
	}
	]]--
	```
]=]
function utils.get_real<T>(pr: swan_types.proxy_base_hack<T>): T
	return (getmetatable(pr) :: any)[globals.SWAN_REAL_ID]
end

--[=[
	Returns the "real" value of a state's proxy.

	```lua
	local todos = swan.proxy_state {
		"go outside",
		"touch grass",
		"write more todos"
	}

	print(todos(), todos()[1]) -- {}, "go outside"
	print(swan.state_get_real(todos)) --[[ {
		"go outside",
		"touch grass",
		"write more todos"
	}
	]]--
	```
]=]
function utils.state_get_real<T>(proxy_state: swan_types.state<swan_types.proxy_base_hack<T>>): T
	return utils.get_real(proxy_state())
end

--[=[
	Disconnects all the effects from a specific state or in general.

	```lua
	local money = swan.state(10000)
	local health = swan.state(100)

	swan.effect(function()
		print("Your money:", money())
		print("Your health:", health())
	end)

	swan.effect(function()
		print("Your money (again):", money())
	end)

	money(100) -- "Your money: 100", "Your health: 50", "Your money (again): 100"
	health(50) -- "Your money: 100", "Your health: 50"

	swan.clear(health)
	health(200) -- *crickets*
	money(50) -- "Your money: 50", "Your health: 200", "Your money (again): 50"

	swan.clear()
	money(10) -- *crickets*
	```
]=]
function utils.clear<T>(state: swan_types.state<T>?): ()
	table.clear(state and state.callbacks or globals.EFFECTS)
end

return utils
