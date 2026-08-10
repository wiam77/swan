--!strict

local effect = require("./effect")
local globals = require("./globals")
local scope = require("./scope")
local swan_types = require("./swan_types")
local utils = require("./utils")

type state<T = unknown> = swan_types.state

local roblox = {}
globals.wait = task.wait

local function implicit_effect(instance: Instance, value: any, action: (...any) -> ()): any
	if utils.is_state(value) then
		return effect(function(old)
			action(value(), old)
		end)
	end

	return action(value)
end

local function apply_properties(instance: any, properties: { [any]: any }): any
	local nested_props = {}
	for property_name, value in properties do
		if property_name == "Children" then
			implicit_effect(instance, value, function(value: any, old)
				value = utils.is_proxy(value) and utils.get_real(value) or value

				if not old then
					for child_name, child in value do
						if child.Name == child.ClassName then
							child.Name = child_name
						end
						child.Parent = instance
					end
					return
				end

				for child_name, child in old do
					if value[child_name] == child then
						continue
					end
					child:Destroy()
				end

				for child_name, child in value do
					if old[child_name] == child then
						continue
					end
					if child.Name == child.ClassName then
						child.Name = child_name
					end
					child.Parent = instance
				end
			end)

			continue
		end

		if type(property_name) == "number" then
			local value_t = type(value)
			assert(value_t == "table", `Expected a table (properties) for index {property_name}, got a "{value_t}!"`)
			table.insert(nested_props, value)
			continue
		end

		local exists, property = pcall(function()
			return instance[property_name]
		end)

		assert(exists, `Property '{property_name}' doesn't exist for class '{instance.ClassName}!'`)

		local success, is_event = pcall(function()
			return property and property.Connect
		end)

		if success and is_event then
			implicit_effect(instance, value, function(value)
				property:Connect(value)
			end)
			continue
		end

		implicit_effect(instance, value, function(value)
			instance[property_name] = value
		end)
	end

	for _, v in nested_props do
		apply_properties(instance, v)
	end

	return instance
end

function roblox.create<T>(
	class_name: T | keyof<swan_types.instances>,
	properties: any | swan_types.properties<index<swan_types.instances, T>>
): index<swan_types.instances, T>
	return apply_properties(Instance.new(class_name), properties)
end

roblox.apply = apply_properties :: <T>(instance: T & Instance, properties: any | swan_types.properties<T>) -> T

function roblox.component<T, U...>(f: (U...) -> T & Instance): (U...) -> T
	return function(...: U...): T
		local args: { any } = { ... }
		local instance: Instance
		local disconnecter = scope(function()
			instance = f(table.unpack(args))
		end)
		instance.Destroying:Connect(disconnecter)
		return instance
	end
end

return roblox
