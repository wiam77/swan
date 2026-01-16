--!strict
--[[
TODO:
	When creating a State, if its variable type is annotated,
	and the type of the value passed to rl.state() doesn't match,
	there should be a type error:
	local health : rl.state<number> = rl.state("i'm not a number") -- doesn't error

	When modifying a State, if the value passed to state() doesn't match its type,
	there should be a type error:
	local health : rl.state<number> = rl.state(100)
	health("i'm not a number")

	- The 2 bugs above could be fixed by using the commented out state<T> type.
]]--

local rl = {}

export type callback<T = unknown> = (old_value : T?, state_i : number?) -> ...unknown

-- Currently broken, might get fixed in the future.
-- export type state<T = unknown> = setmetatable<{
-- 	value : T,
-- 	read callbacks : {[callback<T>] : number},
-- 	read always_force : boolean
-- }, {
-- 	__call : (() -> T)
-- 	       & ((new_value : T?, force : boolean?) -> T)
-- }>

export type state<T = unknown> = {
	value : T,
	always_force : boolean,
	read callbacks : {[callback<T>] : number}
} & ( |	(() -> T)
      |	((new_value : T?, force : boolean?) -> T))

local function is_function<T>(v : T) : T
	local vt = type(v)
	assert(vt == "function", `Expected type 'function', got '{vt}'`)
	return v
end

local warn = warn or function(msg : string) : ()
	print(`\x1b[33m{msg}\x1b[0m`)
end

local batching = false
local batched : {[state] : {any}} = {} -- {[state] : {[1] : {[callback] = true}, [2] : old_value, [3] : state_i}}

local current_callback : callback? = nil
local effects : {[callback] : number} = {}

local function state__call<T>(self : state<T>, new_value : T?, force : boolean?) : T
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

--[=[
	Creates a State.
	
	@param initial_value T? -- The initial value for the State, can be nil.
	@param always_force boolean? -- Whether Effects connected to this State will always trigger, even when the value didn't change.
	@return state<T> -- The created State. Call with no arguments for reading with tracking,
	call with arguments for writing (2nd argument is for forcing),
	read .value field for reading without tracking,
	write .value field for writing without triggering Effects.
]=]
function rl.state<T>(initial_value : T?, always_force : boolean?) : state<T>
	return setmetatable({
		value = initial_value,
		callbacks = {},
		always_force = always_force or false
	}, {
		__call = state__call
	}) :: any
end

--[=[
	Creates an Effect, a binding of the given function to the event of States read (by calling) within it being updated.
	
	@param callback callback<T> -- The function to be bound.
	@return () -> () -- Function which disconnects the Effect from the States.
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
	Wraps an Effect, around the given Callback, which sets a newly created State's value
	to be the return value of the Callback.
	Returns the created State and the Effect's disconnect function.

	This is useful for States which depend on the value of another State, since their value will
	be updated only when the State they depend on is also updated, and not every time it is read,
	as how would happen with a function which's return value depends on a State.

	@param callback () -> T -- The callback.
	@return state<T> -- The State that was created.
	@return () -> () -- The created Effect's disconnect function.
]=]
function rl.derive<T>(callback : () -> T) : (state<T>, () -> ())
	local state = rl.state()
	return state, rl.effect(function()
		state(callback())
	end)
end

--[=[
	Batches any State write operation up until the given function is done running.

	@param f () -> ...unknown -- The function.
]=]
function rl.batch(f : () -> ...unknown) : ()
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
	Wraps the given Callbacks into Effects.
	Returns a function which disconnects all the created Effects.

	@param ... () -> () -- The Callbacks.
	@return () -> () -- The disconnecter.
]=]
function rl.scope(... : callback) : () -> ()
	local disconnects = {}
	for _, callback in {...} do
		table.insert(disconnects, rl.effect(callback))
	end
	
	return function()
		for _, disconnect in disconnects do
			disconnect()
		end
	end
end

--[=[
	Branching function to be used within Effects.
	Pass a condition to be checked, and after it a function to be run if it's successful.
	The last value, if a function, and if not after a condition, will be threated as the "else" branch.

	@param ... any -- The values and the branches.
]=]
function rl.branch(... : any) : ()
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

type function indexer(t : type) : type
	return (t:indexer() :: any).index
end

-- couldn't think of a better name
type identifier<T> = keyof<T> | indexer<T>

--[=[
	Iterates over the given table and creates an Effect for each key that is
	either a function or a State, updating the key's value to be the return value of the
	function, or the State's value.
	Returns table containing each key's Effect's disconnect function.

	@param t T -- The table to iterate.
	@return T -- The given table.
	@return {[identifier<T>] : () -> ()} -- The table containing the disconnect functions.
]=]
function rl.mirror<T>(t : T) : (T, {[identifier<T>] : () -> ()})
	local disconnects : {[identifier<T>] : () -> ()} = {}
	for k, v in (t :: {[identifier<T>] : unknown}) do
		local mt = getmetatable(v :: any)
		if type(v) ~= "function" and not (mt and mt.__call == state__call) then continue end
		disconnects[k] = rl.effect(function()
			(t :: {[identifier<T>] : unknown})[k] = (v :: () -> ())()
		end)
	end

	return t, disconnects
end

--[=[
	Disconnects all Effects.
]=]
function rl.cleanup() : ()
	table.clear(effects)
end

return rl