--!strict

--[[
Luau FIXME:
	- When creating a state, if its variable type is annotated,
	and the type of the value passed to swan.state() doesn't match,
	there should be a type error:
	const health : swan.state<number> = swan.state("i'm not a number") -- doesn't error
]]

const globals = require("./globals")
const swan_types = require("./swan_types")
const utils = require("./utils")

type callback<T = unknown, U... = ()> = swan_types.callback<T, U...>
type state<T = unknown> = swan_types.state<T>
type proxy_state<T> = swan_types.proxy_state<T>

const trigger_effect_safe = globals.trigger_effect_safe
const effects = globals.effects
const batched = globals.batched
const STATE_MT = globals.STATE_MT

const state = {}

local pending_effects: { [callback]: { any } } = {} -- {[callback] : {[1]: old_value, [2]: state_i}}
local flushing = false

const function schedule_subscribers<T>(state: state<T>, old_value: T?): ()
	const subscribers = state.subscribers
	for callback, state_i in subscribers do
		if not effects[callback] then
			subscribers[callback] = nil
			continue
		end

		if not globals.batching then
			pending_effects[callback] = { old_value, state_i }
			continue
		end

		const state_batch = batched[state]
		if not state_batch then
			batched[state] = { { [callback] = true }, old_value, state_i }
			continue
		end

		const x = state_batch[1]
		if not x[callback] then
			x[callback] = true
		end

		state_batch[2] = old_value
	end
end

const function flush_effects(): ()
	if flushing then
		return
	end

	flushing = true

	const current_pending_effects = pending_effects
	pending_effects = {}

	for callback, data in current_pending_effects do
		trigger_effect_safe(callback, data[1], data[2])
	end

	flushing = false
end

function mark_dependents_dirty<T>(state: state<T>): ()
	for dependent in state.dependents do
		if dependent.dirty then
			continue
		end

		dependent.dirty = true

		schedule_subscribers(dependent, dependent.value)
		mark_dependents_dirty(dependent)
	end
end

const function deep_clone<K, V>(t: { [K]: V }): { [K]: V }
	if type(t) ~= "table" then
		return t
	end

	const clone = {}
	for k, v in t do
		clone[k] = deep_clone(v)
	end
	return clone
end

const function track_state(state: state): ()
	const subscribers = state.subscribers
	const current_tracker = globals.current_tracker
	if not current_tracker then
		return
	end

	const data: any = current_tracker.data
	const is_effect = type(data) == "function"
	-- if is_effect and not subscribers[data] then
	-- 	effects[data] += 1
	-- 	subscribers[data] = effects[data]
	-- elseif not is_effect then
	-- 	const dependents = state.dependents
	-- 	if not dependents[data] then
	-- 		dependents[data] = true
	-- 	end
	-- end

	if is_effect and not subscribers[data] then
		effects[data] += 1
		subscribers[data] = effects[data]
		return
	end

	if is_effect then
		return
	end

	const dependents = state.dependents
	if not dependents[data] then
		dependents[data] = true
	end
end

const function make_proxy(real: any, state: state, root_old: any, self_old: any): ...unknown
	if type(real) ~= "table" or utils.is_proxy(real) then
		return real
	end

	if not root_old then
		root_old = deep_clone(real)
		self_old = root_old
	end

	const proxified = {}
	for k, v in real do
		proxified[k] = make_proxy(v, state, root_old, self_old[k])
	end

	const subscribers = state.subscribers
	return setmetatable({}, {
		[globals.SWAN_PROXY_ID] = true,
		[globals.SWAN_REAL_ID] = real,
		__index = function(_, k)
			track_state(state)
			return proxified[k]
		end,
		__newindex = function(_, k, v)
			if proxified[k] == v and not state.always_force then
				return
			end
			proxified[k] = v
			real[k] = v

			for callback, state_i in subscribers do
				trigger_effect_safe(callback, root_old, state_i)
			end

			self_old[k] = v
		end,
	})
end

function STATE_MT.__call<T>(self: state<T>, ...): T
	const args = { ... }
	const args_n = select("#", ...)
	local new_value: T? = args[1]
	const force: boolean? = args[2]
	const always_force = self.always_force
	const current_value = self.value

	if args_n == 0 then
		track_state(self)

		const compute = self.compute
		if not (compute and self.dirty) then
			return current_value
		end

		const previous_tracker = globals.current_tracker
		globals.current_tracker = {
			data = self,
			previous = previous_tracker,
		}

		self.dirty = nil
		self.recomputing = true

		const ok, result = xpcall<<any>>(compute, debug.traceback)
		if not ok then
			self.dirty = true
			self.recomputing = nil
			globals.current_tracker = previous_tracker
			error(result)
		end

		globals.current_tracker = nil

		self(result)
		self.recomputing = nil
		globals.current_tracker = previous_tracker
	elseif current_value ~= new_value or (always_force and force ~= false) or force then
		if utils.is_proxy(current_value) then
			new_value = make_proxy(new_value, self)
		end

		self.value = new_value :: T
		mark_dependents_dirty(self)

		if not self.recomputing then
			schedule_subscribers(self, current_value)
		end

		flush_effects()
	end

	return self.value
end

function STATE_MT.__unm(v: state<number>): state<number>
	return state.computed(function()
		return -v()
	end)
end

for op_name, op in globals.BINARY_OPS do
	STATE_MT["__" .. op_name] = function<T>(a: any, b: any)
		local fn: () -> T

		const a_is_state = utils.is_state(a)
		const b_is_state = utils.is_state(b)
		if a_is_state and not b_is_state then
			fn = function()
				return op(a(), b)
			end
		elseif b_is_state and not a_is_state then
			fn = function()
				return op(a, b())
			end
		else
			fn = function()
				return op(a(), b())
			end
		end

		return state.computed(fn)
	end
end

--[=[
	@within swan

	Creates and returns a [state](/docs/concepts#state).

	```lua
	const ammo = swan.state(100)
	const message = swan.state("Hello, World!", true)

	print(ammo(), message.value) -- 100, "Hello, World!"
	```
]=]
function state.state<T>(initial_value: T, always_force: true?): state<T>
	return setmetatable({
		value = initial_value,
		always_force = always_force,
		subscribers = {},
		dependents = {},
	}, STATE_MT) :: any
end

--[=[
	@within swan

	Takes the given function and collects its dependencies (states), just like effects,
	creating a state whose value will be the result of the function.
	Recomputations are only done once a dependency changes, and once the state is read (pulling).

	Returns the created state.

	`swan` also provides [implicit computeds](/docs/concepts#implicit_computeds).

	```lua
	const stamina = swan.state(100)
	const possible_jumps = swan.computed(function()
		return stamina() / 50
	end)

	print(possible_jumps()) -- 2
	stamina(50)
	print(possible_jumps()) -- 1
	```
]=]
function state.computed<T>(fn: (() -> T) | (() -> ())): state<T>
	const self: any = setmetatable({
		compute = fn,
		subscribers = {},
		dependents = {},
	}, STATE_MT)

	const previous_tracker = globals.current_tracker
	globals.current_tracker = {
		data = self,
		previous = previous_tracker,
	}

	const ok, result = xpcall<<any>>(fn, debug.traceback)
	globals.current_tracker = previous_tracker

	if not ok then
		error(result)
	end

	self.value = result
	return self
end

--[=[
	@within swan

	Creates and returns a [proxy state](/docs/concepts#table-states).

	```lua
	const profile = swan.proxy {
		name = "john",
		age = 20,
	}

	swan.effect(function(old_profile)
		const new_profile = profile()

		if old_profile and old_profile.name ~= new_profile.name then
			print(`{old_profile.name} changed their name to {new_profile.name}`)
		end
	end)

	profile().name = "doe"
	```
]=]
function state.proxy<T>(initial_value: T | { [any]: any }, always_force: boolean?): proxy_state<T>
	const self: any = setmetatable({
		always_force = always_force,
		subscribers = {},
		dependents = {},
	}, STATE_MT)

	self.value = make_proxy(initial_value, self)
	return self
end

return state
