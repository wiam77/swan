--!strict
--[[
TODO:
	- These bugs, AFAIK, cannot currently be solved, as they are Luau bugs, and not my implementation's.
	
	When creating a State, if its variable type is annotated,
	and the type of the value passed to swan.state() doesn't match,
	there should be a type error:
	local health : swan.state<number> = swan.state("i'm not a number") -- doesn't error

	Typings for implicit derives.
]]--

--- @class swan
local swan = {}

-- TYPES --

--[=[
	@type cleanup () -> ...unknown
	@within swan

	Function which gets called when its effect is disconnected.
]=]
export type cleanup = () -> ...unknown

--[=[
	@type disconnecter () -> ()
	@within swan

	Function which disconnects an effect from its states.
]=]
export type disconnecter = () -> ()

--[=[
	@type callback ((old_value : T?, state_i : number?) -> cleanup) | ((old_value : T?, state_i : number?) -> nil | ())
	@within swan

	Function which gets called when its effect is triggered.\
	`old_value` is the state's previous value, which is going to be the same as the current one when an effect is forced.\
	`state_i` is the order of appearance of the state within the callback.
]=]
export type callback<T = unknown> = ((old_value : T?, state_i : number?) -> cleanup)
				  | ((old_value : T?, state_i : number?) -> ())
				  | ((old_value : T?, state_i : number?) -> nil) -- TODO: "nil" should be "false?"

--[=[
	@type state<T> {value : T, always_force : boolean, callbacks : {[callback<T>] : number}} & ((() -> T) | ((new_value : T?, force : boolean?) -> T))
	@within swan

	The [state](/docs/concepts#state) type.
]=]
export type state<T = unknown> = {
	value : T,
	always_force : boolean,
	read callbacks : {[callback<T>] : number}
} & ( |	(() -> T)
      |	((new_value : T?, force : boolean?) -> T))

type function indexer(t : type) : type
	return (t:indexer() :: any).index
end

--[=[
	@type identifier keyof<T> | indexer<T>
	@within swan
	@private

	Union of the fields and the indexer of the given table.
]=]
type identifier<T> = keyof<T> | indexer<T>

-- CONSTANTS --
local BINARY_OPS = {
	concat = function(a, b) return a ..b end,
	add    = function(a, b) return a + b end,
	sub    = function(a, b) return a - b end,
	mul    = function(a, b) return a * b end,
	div    = function(a, b) return a / b end,
	idiv   = function(a, b) return a //b end,
	mod    = function(a, b) return a % b end,
	pow    = function(a, b) return a ^ b end,
}

-- VARIABLES --
local batching = false
local batched : {[state] : {any}} = {} -- {[state] : {[1] : {[callback] = true}, [2] : old_value, [3] : state_i}}

local current_callback : callback? = nil
local effects : {[callback] : number} = {}

-- UTILS --
local function is_function<T>(v : T) : T
	local vt = type(v)
	assert(vt == "function", `Expected type 'function', got '{vt}'`)
	return v
end

local function noop() end

-- STATE_MT --
local state_mt = {}
function state_mt.__call<T>(self : state<T>, new_value : T?, force : boolean?) : T
	local old_value = self.value
	local callbacks = self.callbacks

	if not (new_value or force) then
		if current_callback and not callbacks[current_callback] then
			effects[current_callback] += 1
			callbacks[current_callback] = effects[current_callback]
		end
	elseif old_value ~= new_value or self.always_force or force then
		self.value = new_value

		for callback, state_i in callbacks do
			if not effects[callback] then
				callbacks[callback] = nil
				continue
			end

			if batching then
				local state_batch = batched[self]
				if state_batch then
					local x = state_batch[1]
					if not x[callback] then
						x[callback] = true
					end

					state_batch[2] = old_value
				else
					batched[self] = {{[callback] = true}, old_value, state_i}
				end
			else
				callback(old_value, state_i)
			end
		end
	end

	return self.value
end

function state_mt.__unm(v : state<number>) : state<number>
	return swan.derive(function()
		return -(v :: any)()
	end) :: state<number>
end

for op_name, op in BINARY_OPS :: {[string] : any} do
	state_mt["__"..op_name] = function(a, b)
		return swan.derive(
			if getmetatable(a :: any) == state_mt then
				function()
					return op(a(), b)
				end
			else
				function()
					return op(a, b())
				end
		)
	end
end
-- MODULE --

--[=[
	Creates and returns a [state](/docs/concepts#state).
	@tag constructor

	```lua
	local ammo = swan.state(100)
	local message = swan.state("Hello, World!", true)

	print(ammo(), message.value) -- 100, "Hello, World!"
	```
]=]
function swan.state<T>(initial_value : T?, always_force : boolean?) : state<T>
	return setmetatable({
		value = initial_value,
		callbacks = {},
		always_force = always_force or false
	}, state_mt) :: any
end

--[=[
	Wraps an effect, around the given callback, which sets a newly created state's value
	to be the return value of said callback.

	Returns the created state and the effect's disconnecter.

	This is useful for States which depend on the value of another State, since their value will
	be updated only when the State they depend on is also updated, and not every time it is read.

	`swan` also provides [implicit derives](/docs/concepts#implicit_derives).

	@tag constructor

	```lua
	local stamina = swan.state(100)
	local possible_jumps = swan.derive(function()
		return stamina() / 50
	end)

	print(possible_jumps()) -- 2
	stamina(50)
	print(possible_jumps()) -- 1
	```
]=]
function swan.derive<T>(callback : callback<T>) : (state<T>, disconnecter)
	local state = swan.state()
	return state, swan.effect(function()
		state(callback())
	end)
end

--[=[
	Creates an [effect](/docs/concepts#effect) and returns its disconnecter.
	@tag constructor

	```lua
	local health = swan.state(100)
	local printer_disconnecter = swan.effect(function(old_health)
		print(`old health: {old_health}, current health: {health()}`)
	end)

	health(40) -- `old health: 100, current health: 40`
	health.value = 20 -- *crickets*
	health(60) -- `old health: 20, current health: 60`
	health(60) -- *crickets*
	health(60, true) -- `old health: 60, current health: 60`

	printer_disconnecter()
	health(20) -- *crickets*

	printer_disconnecter() -- you can disconnect again, it's fine!

	local always_forces = swan.state("I always force effects", true)
	swan.effect(function()
		print(always_forces(), health.value) -- doesn't track `health`
	end)

	always_forces("I always force effects") -- "I always force effects"
	always_forces("I always force effects, again") -- "I always force effects, again"
	always_forces("I always force effects, again") -- "I always force effects, again"
	```
]=]
function swan.effect<T>(callback : callback<T>) : disconnecter
	effects[callback] = 0
	current_callback = callback
	local cleanup = callback()
	current_callback = nil

	local function disconnect()
		effects[callback] = nil
	end

	return if cleanup then
		function()
			disconnect()
			cleanup()
			cleanup = noop
		end
	else disconnect
end

--[=[
	Batches any state write operation up until the given function is done running.

	```lua
	local text = swan.state("Hey, how is it going?")

	swan.effect(function()
		print(text())
	end)
	
	swan.batch(function()
		text("Hello, World!")
		text("Bye, World!")
	end) -- the previous effect will only print "Bye, World!"

	swan.batch(function()
		text.value = "Oops"
	end) -- be careful! If the last write operation is done through .value, the effect will also trigger! -- "Oops"
	```
]=]
function swan.batch(f : () -> ...unknown) : ()
	batching = true
	f()

	for _, result in batched do
		for callback in result[1] :: {[callback] : true} do
			callback(result[2], result[3] :: number)
		end
	end

	batching = false
	table.clear(batched)
end

--[=[
	Wraps the given callbacks into effects.\
	Returns a function which disconnects all the created effects.

	```lua
	local health, stamina, ammo = swan.state(100), swan.state(100), swan.state(20)

	local info_ui_scope = swan.scope(
		function()
			print("Your health is", health())
		end,
		function()
			print("Your stamina is", stamina())
		end,
		function()
			print(`Ammo: {ammo()}/40`)
		end,
	)

	health(30) -- "Your health is 30"
	stamina(10) -- "Your health is 10"
	ammo(10) -- "Ammo: 10/40"
	
	info_ui_scope()

	health(30) -- *crickets*
	stamina(10) -- *crickets*
	ammo(10) -- *crickets*
	```
]=]
function swan.scope(... : callback) : disconnecter
	local disconnects = {}
	for _, callback in {...} do
		table.insert(disconnects, swan.effect(callback))
	end
	
	return function()
		for _, disconnect in disconnects do
			disconnect()
		end
	end
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
		swan.branch(
			role ~= "admin", function()
				assert(age() >= 18, "Your age is too low!")
			end
		)
	end) -- will detect `age`
	```
]=]
function swan.branch(... : any) : ()
	local args = table.pack(...)
	local n = args.n
	assert(n > 1, "Expected at least 2 arguments!")

	local i = 1
	while i + 1 <= n do
		if args[i] or current_callback then
			is_function(args[i + 1])()
		end

		i += 2
	end

	if i <= n then
		is_function(args[i])()
	end
end

--[=[
	Returns whether the given value is a state.
	@tag utility

	```lua
	local not_a_state = "Hey"
	print(swan.is_state(not_a_state)) -- false

	local a_state = swan.state("Cool")
	print(swan.is_state(a_state)) -- true
	```
]=]
function swan.is_state(v : any) : boolean
	return getmetatable(v) == state_mt
end

--[=[
	Disconnects all Effects.
	@tag utility

	```lua
	local money = swan.state(10000)

	swan.effect(function()
		print("Your money:", money())
	end)

	swan.effect(function()
		print("Your money (again):", money())
	end)
	
	-- ...

	money(100) -- "Your money: 100", "Your money (again): 100"
	swan.clear()
	money(10) -- *crickets*
	```
]=]
function swan.clear() : ()
	table.clear(effects)
end

return swan