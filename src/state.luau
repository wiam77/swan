--!strict

const globals = require("./globals")
const swan_types = require("./swan_types")
const utils = require("./utils")

type state<T> = swan_types.state<T>
type proxy_state<T> = swan_types.proxy_state<T>

const state = {}

const effects = globals.effects
const batched = globals.batched
const STATE_MT = globals.STATE_MT

const function mark_dirty<T>(state: state<T>)
	if state.dirty then
		return
	end

	state.dirty = true
	for dependent in state.dependents do
		mark_dirty(dependent)
	end
end

function STATE_MT.__call<T>(self: state<T>, ...): T
	const current_value = self.value
	const subscribers = self.subscribers

	const args = { ... }
	const args_n = select("#", ...)
	local new_value: T? = args[1]
	const force: boolean? = args[2]
	const always_force = self.always_force

	if args_n == 0 then
		const current_tracker = globals.current_tracker
		if current_tracker then
			const data: any = current_tracker.data
			const data_type = type(data)
			if data_type == "function" and not subscribers[data] then
				effects[data] += 1
				subscribers[data] = effects[data]
			else
				const dependents = self.dependents
				if not dependents[data] then
					dependents[data] = true
				end
			end
		end

		const compute = self.compute
		if not (compute and self.dirty) then
			return current_value
		end

		self.dirty = false
		self(compute())
	elseif current_value ~= new_value or (always_force and force ~= false) or force then
		if utils.is_proxy(current_value) then
			new_value = utils.make_proxy(new_value, self) :: T
		end

		self.value = new_value :: T
		for dependent in self.dependents do
			mark_dirty(self)
		end

		for callback, state_i in subscribers do
			if not effects[callback] then
				subscribers[callback] = nil
				continue
			end

			if not globals.batching then
				callback(current_value, state_i)
				continue
			end

			const state_batch = batched[self]
			if not state_batch then
				batched[self] = { { [callback] = true }, current_value, state_i }
				continue
			end

			const x = state_batch[1]
			if not x[callback] then
				x[callback] = true
			end

			state_batch[2] = current_value
		end
	end

	return self.value :: T
end

function STATE_MT.__unm(v: state<number>): state<number>
	return (state.computed(function()
		return -v()
	end))
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
function state.state<T>(initial_value: T?, always_force: boolean?): state<T>
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

	self.value = fn()
	globals.current_tracker = previous_tracker
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

	self.value = utils.make_proxy(initial_value, self)
	return self
end

return state
