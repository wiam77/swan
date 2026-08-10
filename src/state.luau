--!strict

local effect = require("./effect")
local globals = require("./globals")
local swan_types = require("./swan_types")
local utils = require("./utils")

local state = {}

function globals.STATE_MT.__call<T>(self: swan_types.state<T>, ...): T
	local old_value = self.value
	local callbacks = self.callbacks

	local args = { ... }
	local argsn = select("#", ...)
	local new_value: T? = args[1]
	local force: boolean? = args[2]
	local always_force = self.always_force

	if argsn == 0 then -- if reading (state())
		local cc = globals.current_callback and globals.current_callback.value
		if cc and not callbacks[cc] then -- if within effect and not already registered to it
			globals.EFFECTS[cc] += 1
			callbacks[cc] = globals.EFFECTS[cc]
		end
	elseif old_value ~= new_value or (always_force and force ~= false) or force then -- if writing (state(v))
		if utils.is_proxy(old_value) then
			new_value = utils.make_proxy(new_value, self)
		end
		self.value = new_value

		for callback, state_i in callbacks do
			if not globals.EFFECTS[callback] then
				callbacks[callback] = nil
				continue
			end

			if globals.batching then
				local state_batch = globals.BATCHED[self]
				if state_batch then
					local x = state_batch[1]
					if not x[callback] then
						x[callback] = true
					end

					state_batch[2] = old_value
				else
					globals.BATCHED[self] = { { [callback] = true }, old_value, state_i }
				end
			else
				callback(old_value, state_i)
			end
		end
	end

	return self.value
end

function globals.STATE_MT.__unm(v: swan_types.state<number>): swan_types.state<number>
	return (state.derived(function()
		return -v()
	end))
end

for op_name, op in globals.BINARY_OPS do
	globals.STATE_MT["__" .. op_name] = function(a: any, b: any)
		return state.derived(if utils.is_state(a)
			then function()
				return op(a(), b)
			end
			else function()
				return op(a, b())
			end)
	end
end

function state.state<T>(initial_value: T?, always_force: boolean?): swan_types.state<T>
	return setmetatable({
		value = initial_value,
		always_force = always_force,
		callbacks = {},
	}, globals.STATE_MT) :: any
end

function state.derived<T>(f: (() -> T) | (() -> ())): (swan_types.state<T>, swan_types.disconnecter)
	local s = state.state()
	return s, effect(function()
		s(f())
	end)
end

return state
