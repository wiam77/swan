--!strict

local rl = {}

export type state<T> = (() -> T) & ((new_value : T, force : boolean?) -> T) & {
	value : T
}

export type callback<T> = (old_value : T, state_i : number?) -> any

local batching = false
-- {[state] : {{[callback] = true}, old_value, state_i}}
local batched : {[state<unknown>] : {any}} = {}

local current_callback : callback<unknown>? = nil
local effects : {[callback<unknown>] : number} = {}

local function newindex_err()
	error("Cannot mutate a State by editing it's .value!")
end

local function check<T>(v : T) : T
	local vt = type(v)
	assert(vt == "function", `Expected type 'function', got '{vt}'`)
	return v
end

local warn = warn or function(msg : string) : ()
	print(`\x1b[33m{msg}\x1b[0m`)
end

--[=[
	Disconnects all Effects.
]=]
function rl.cleanup() : ()
	table.clear(effects)
end

--[=[
	Creates a State.
	
	@param value T -- Initial value.
	@param force boolean? -- Whether Effects connected to this State will trigger, despite the fact that the value didn't change.
	@return state<T> -- State. Call with no arguments for reading with tracking, call with arguments for writing (2nd argument is for forcing), read .value field for reading without tracking.
]=]
function rl.state<T>(value : T?, force : boolean?) : state<T>
	local callbacks : {[callback<unknown>] : number} = {}
	local self = newproxy(true)
	local mt = getmetatable(self)
	mt.__newindex = newindex_err
	mt.__index = function(_, k)
		assert(k == "value", `Expected key 'value', got '{k}'!`)
		return value
	end
	
	mt.__call = function(... : T) : T
		local argv = {...}
		local old_value = value
		local new_value = argv[2]

		if #argv == 1 then
			if current_callback and not callbacks[current_callback] then
				effects[current_callback] += 1
				callbacks[current_callback] = effects[current_callback]
			end
		elseif value :: any ~= new_value or force == true or argv[3] == true then
			value = new_value

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

		return value
	end

	return self
end

--[=[
	Batches any State write operation up until the function is done running.

	@param f () -> any -- The function.
]=]
function rl.batch(f : () -> any) : ()
	batching = true
	f()

	for _, result in batched do
		for callback in result[1] do
			callback(result[2], result[3])
		end
	end

	batching = false
	table.clear(batched :: {any})
end

--[=[
	Creates an Effect, a binding of the given function to the event of States read (by calling) within it being updated.
	
	@param callback callback<T> -- The function to be bound.
	@return disconnect () -> () -- Function which disconnects the Effect from the States.
]=]
function rl.effect<T>(callback : callback<T>) : () -> ()
	if current_callback then
		warn("Nested effect")
	end

	effects[callback] = 0
	current_callback = callback
	callback()
	current_callback = nil

	return function()
		if not effects[callback] then
			warn("This effect is already disconnected!")
			return
		end
		
		effects[callback] = nil
	end
end

--[=[
	Returns a function which calls the given functions.
	Any non-function or function which precedes a "true" value by 2 indices is going to be skipped (the second happens because of derives).
	This is intended to be used for disconnecting Effects in bulk.

	@param ... () -> () -- The functions.
	@return f () -> () -- The function caller.
]=]
function rl.scope<T>(... : T) : () -> ()
	local t = {...}
	return function()
		for i = 1, #t do
			local v = t[i]
			if type(v) ~= "function" or t[i + 2] == true then continue end
			v()
		end
	end
end

--[=[
	Wraps an Effect around the given callback which sets a newly created State's value
	to be the return value of the callback.
	Returns the created State, the Effect's disconnect function and a flag which can be ignored.

	This is useful for States which depend on the value of another State, since their value will
	be updated only when the State they depend on is also updated, and not every time it is read,
	as how would happen with a function which's return value depends on a State.

	@param callback () -> U -- the callback
	@return derived_state state<U> -- the State that was created
	@return disconnect () -> -- the created Effect's disconnect function
	@return flag true -- a flag used internally by rl.scope(); can be ignored.
]=]
function rl.derive<T, U>(callback : () -> U) : (state<U>, () -> (), true)
	local cache = rl.state()
	return cache, rl.effect(function()
		cache(callback())
	end), true
end

--[=[
	Branching function to be used within Effects.
	Pass a condition to be checked, and after it a function to be run if it's successful.
	The last value, if a function, and if not after a condition, will be threated as the "else" branch.
]=]
function rl.branch(...) : ()
	local args = table.pack(...)
	local n = args.n
	assert(n >= 2, "Expected 2 or more arguments!")

	local i = 1
	while i + 1 <= n do
		if args[i] or current_callback then
			check(args[i + 1])()
		end

		i += 2
	end

	if i <= n then
		check(args[i])()
	end
end

--[=[
	Creates an effect for every function or State within the given table, which updates the key to either the return value of the function, or the value of the State.
	Each Effect's disconnect function gets put in the table as t["disconnect_"..key], when key is a string, or as t["disconnect"_..i], where i is the numerical index at which the key was iterated over.

	@param t {[K] : V} -- The table.
	@return t {[K] : V} -- The same table.
	@return disconnect_all () -> () -- Function which disconnects and eliminates each disconnect function of the created Effects.
]=]
function rl.mirror<K, V>(t : {[K] : V}) : ({[K] : V}, () -> ())
	local disconnects : {[number | string] : () -> ()} = {}

	for k, v in t do
		local v_type = type(v)
		if v_type == "function" or (v_type == "table" and (v :: {[any] : any}).value) then
			local disconnect = rl.effect(function()
				t[k] = v()
			end)

			local k_type = type(k)
			if k_type == "string" then
				disconnects[k] = disconnect
			else
				table.insert(disconnects :: {any}, disconnect)
			end
		end
	end

	for name, disconnect in disconnects do
		t["disconnect_"..name] = disconnect
	end

	return t, function()
		for name, disconnect in disconnects do
			disconnect()
			t["disconnect_"..name] = nil
		end
	end
end

return rl