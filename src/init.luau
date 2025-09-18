--!strict
-- TODO: Make rl.t more intuitive.

local rl = {}

export type state<T> = (() -> T) & ((new_value : T, force : boolean?) -> T) & {
	value : T
}

export type callback<T> = (old_value : T, state_i : number?) -> any
type effect<T> = {owners : {number}, callback : callback<T>}

local current_effect : effect<unknown>? = nil
local connections : {{callback<unknown>}} = {}

local function newindex_err()
	error("Cannot mutate a State by editing it's .value!")
end

--[=[
	Disconnects all Effects.
]=]
function rl.cleanup() : ()
	for i, v in connections do
		table.clear(v)
	end

	table.clear(connections)
end

--[=[
	Creates a State.
	
	@param initial_value T -- Initial value.
	@param force boolean? -- Whether Effects connected to this State will trigger, despite the fact that the value didn't change.
	@return state<T> -- State. Call with no arguments for reading with tracking, call with arguments for writing (2nd argument is for forcing), read .value field for reading without tracking.
]=]
function rl.state<T>(initial_value : T, force : boolean?) : state<T>
	local children = {}
	table.insert(connections, children)
	local connections_i = #connections

	local value = initial_value
	local proxy = newproxy(true)
	local mt = getmetatable(proxy)
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
			if current_effect then
				if current_effect.owners[connections_i] then return value end
			
				current_effect.owners[connections_i] = #children + 1
				table.insert(children, current_effect.callback)
			end
		elseif value :: any ~= new_value or force == true or argv[3] == true then
			value = new_value
			for _, e in children do e(old_value, connections_i) end
		end

		return value
	end

	return proxy
end

--[=[
	Creates an Effect, a binding of the given function to the event of States read (by calling) within it being updated.
	
	@param callback callback -- The function to be bound.
	@return disconnect () -> () -- Function which disconnects the Effect from the States.
]=]
function rl.effect<T>(callback : callback<T>) : () -> ()
	if current_effect then
		print("[WARNING]: Nested effect")
	end

	local self : effect<unknown>? = {callback = callback, owners = {}, children_disconnect = {}}
	current_effect = self
	callback()
	current_effect = nil

	return function()
		if not self then
			print("[INFO]: This effect is already disconnected!")
			return
		end
		
		for connection_i, effect_i in self.owners do
			local connection_t = connections[connection_i]
			if not connection_t then
				print("[INFO]: This effect is already disconnected!")
				continue
			end
			
			table.remove(connections[connection_i], effect_i)
		end

		self = nil
	end
end

local function check<T>(v : T) : T
	local vt = type(v)
	assert(vt == "function", `Expected type 'function', got '{vt}'`)
	return v
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
		if args[i] or current_effect then
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