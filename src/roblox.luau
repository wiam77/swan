--!strict

const effect = require("./effect")
const globals = require("./globals")
const scope = require("./scope")
const swan_types = require("./swan_types")
const utils = require("./utils")

type state<T = unknown> = swan_types.state
type constructor<T = Instance> = swan_types.constructor<T>
type class_constructor<class_name> = swan_types.class_constructor<class_name>

const roblox = {}
if not globals.wait then
	globals.wait = task.wait
end

const constructor_cache: { [swan_types.class_name]: swan_types.constructor } = {}

const function implicit_effect(instance: Instance, value: any, action: (...any) -> ()): any
	if utils.is_state(value) then
		return effect(function(old)
			action(value(), old)
		end)
	end

	return action(value)
end

const function apply<T>(instance: T & Instance, properties: swan_types.properties<T>): T
	const nested_props = {}
	for property_name, value in properties :: any do
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
			const value_t = type(value)
			assert(value_t == "table", `Expected a table (properties) for index {property_name}, got a "{value_t}!"`)
			table.insert(nested_props, value)
			continue
		end

		instance = instance :: any

		const exists, property = pcall(function()
			return instance[property_name]
		end)

		assert(exists, `Property '{property_name}' doesn't exist for class '{instance.ClassName}!'`)

		const success, is_event = pcall(function()
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
		apply<<T>>(instance, v :: any)
	end
	return instance
end

function roblox.apply<T>(instance: T | Instance): constructor<T>
	return function(properties: swan_types.properties<T>)
		return apply(instance, properties)
	end
end

function roblox.create<T>(class_name: T | swan_types.class_name): class_constructor<T>
	local constructor = constructor_cache[class_name] :: class_constructor<T>?
	if constructor then
		return constructor
	end

	const instance = Instance.new(class_name)
	constructor = function(properties: swan_types.properties<T>)
		return apply<<T>>(instance, properties)
	end

	constructor_cache[class_name] = constructor :: constructor
	return constructor
end

function roblox.component<T, U...>(fn: (U...) -> T & Instance): (U...) -> T
	return function(...: U...): T
		const args: { any } = { ... }
		local instance: Instance
		const disconnecter = scope(function()
			instance = fn(table.unpack(args))
		end)

		instance.Destroying:Connect(disconnecter)
		return instance :: T
	end
end

return roblox
