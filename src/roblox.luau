--!strict

const TweenService = game:GetService("TweenService")

const effect = require("./effect")
const scope = require("./scope")
const state = require("./state")
const swan_types = require("./swan_types")
const utils = require("./utils")

type state<T> = swan_types.state<T>
type proxy_state<T> = swan_types.proxy_state<T>
type dynamic_children = swan_types.proxy<swan_types.dynamic_children_base>

type class_name = swan_types.class_name
type properties<T> = swan_types.properties<T>
type constructor<T = Instance> = swan_types.constructor<T>
type class_constructor<class_name> = swan_types.class_constructor<class_name>

type convert_vector = swan_types.convert_vector
type convert_vector_name = swan_types.convert_vector_name

type animatable = swan_types.animatable
type animatable_name = swan_types.animatable_name

type on_complete = swan_types.on_complete

const roblox = {}
const constructor_cache: { [class_name]: constructor } = {}

const function apply_internal<T>(instance: T & Instance, properties: properties<T>): T
	const nested_properties = {}
	for property_key, property_value in properties :: any do
		const is_number = type(property_key) == "number"
		if is_number and utils.is_proxy_state(property_value) then
			effect(function(old: dynamic_children?)
				const children: dynamic_children = utils.get_real(property_value())
				if not old then
					for child_name, child in children do
						const child_type = typeof(child)
						assert(child_type == "Instance", `Expected proxy to contain only Instances, got {child_type}!`)

						if child.Name == child.ClassName then
							child.Name = child_name :: string
						end
						child.Parent = instance
					end

					return
				end

				for child_name, child in old do
					if children[child_name] == child then
						continue
					end

					child.Parent = nil
				end

				for child_name, child in children do
					if old[child_name] == child then
						continue
					end

					if child.Name == child.ClassName then
						child.Name = child_name :: string
					end
					child.Parent = instance
				end
			end)
			continue
		end

		const property_type = typeof(property_value)
		if is_number and property_type == "table" then
			table.insert(nested_properties, property_value)
			continue
		end

		if is_number and property_type == "Instance" then
			property_value.Parent = instance
			continue
		end

		if is_number then
			effect(function(old, index)
				property_value(instance, old, index)
			end)
			continue
		end

		instance = instance :: any

		const instance_property = instance[property_key]
		const success, is_event = pcall(function()
			return instance_property and instance_property.Connect
		end)

		if success and is_event then
			instance_property:Connect(function(...)
				property_value(instance, ...)
			end)
			continue
		end

		if not utils.is_state(property_value) then
			instance[property_key] = property_value
			continue
		end

		effect(function()
			instance[property_key] = property_value()
		end)
	end

	for _, properties: properties<T> in nested_properties do
		apply_internal<<T>>(instance, properties)
	end

	return instance
end

const function apply<T>(instance: T & Instance, properties: properties<T>): T
	instance.Destroying:Connect(scope(apply_internal, instance, properties))
	return instance
end

--[=[
	@within swan
	@tag roblox

	Same as [`swan.create()`](/api/swan#create), except that you pass an existing Instance,
	to which the returned function applies the passed properties, instead of creating a new one.

	@param instance T | Instance -- Instance to which the returned function ("constructor") will apply properties.
	@return constructor<T>
]=]
function roblox.apply<T>(instance: T | Instance): constructor<T>
	return function(properties: properties<T>)
		return apply(instance, properties)
	end
end

--[=[
	@within swan
	@tag roblox

	Returns a constructor for the given Instance class.

	@param class_name T | class_name -- The class name of the Instance you want to create.
	@return class_constructor<T>

	:::info
	The type of the passed properties to the constructor is not validated at runtime
	since that should already happen at edit time through types.
	:::

	```lua
	const bullets = state(100)
	const main_frame = create "Frame" {
		BackgroundColor3 = Color3.new(),
		Size = UDim2.fromScale(1, 1),

		create "UIGridLayout" {
			CellSize = UDim2.fromOffset(100, 100)
		},

		create "TextLabel" {
			Text = "Bullets: "..bullets
		},

		create "TextButton" {
			Text = "Shoot",
			MouseButton1Down = function()
				bullets(bullets.value - 1)
			end
		}
	}
	```
]=]
function roblox.create<T>(class_name: T | class_name): class_constructor<T>
	local constructor = constructor_cache[class_name] :: class_constructor<T>?
	if constructor then
		return constructor
	end

	const instance = Instance.new(class_name)
	constructor = function(properties: properties<T>)
		return apply<<T>>(instance:Clone(), properties)
	end

	constructor_cache[class_name] = constructor :: constructor
	return constructor
end

const convert_vectors: { [convert_vector_name]: true } = {
	Vector2 = true,
	Vector2int16 = true,
	Vector3int16 = true,
}

const type_to_value_instance: { [swan_types.animatable_name]: string } = {
	number = "NumberValue",
	Color3 = "Color3Value",
	vector = "Vector3Value",
	Vector2 = "Vector3Value",
	Vector2int16 = "Vector3Value",
	Vector3 = "Vector3Value",
	Vector3int16 = "Vector3Value",
	UDim = "UIPadding",
	UDim2 = "Frame",
	CFrame = "CFrameValue",
}

const function convert_vector3(
	vector: Vector3,
	to: convert_vector_name
): Color3 | vector | Vector2 | Vector2int16 | Vector3int16
	const x, y, z = vector.X, vector.Y, vector.Z
	return if to == "Vector2"
		then Vector2.new(x, y)
		else if to == "Vector2int16"
			then Vector2int16.new(x, y)
			else if to == "Vector3int16" then Vector3int16.new(x, y, z) else nil :: never
end

const function play_tween(goal: animatable, info: TweenInfo, on_complete: on_complete?, self: state<animatable>): Tween
	const goal_type = typeof(goal) :: animatable_name
	const instance: any = Instance.new(type_to_value_instance[goal_type])
	const property = if goal_type == "UDim" then "PaddingTop" else if goal_type == "UDim2" then "Size" else "Value"

	instance[property] = self.value

	local property_changed: () -> ()
	if convert_vectors[goal_type :: convert_vector_name] then
		goal = goal :: Vector3
		goal = Vector3.new(goal.X, goal.Y, goal.Z)

		property_changed = function()
			self(convert_vector3(instance[property], goal_type :: convert_vector_name))
		end
	else
		property_changed = function()
			self(instance[property])
		end
	end

	instance:GetPropertyChangedSignal(property):Connect(property_changed)
	const tween = TweenService:Create(instance, info, {
		[property] = goal,
	})

	if on_complete then
		tween.Completed:Connect(on_complete)
	end

	tween:Play()
	return tween
end

-- TODO: Make it so the target's and initial_value's types must match.

--[=[
	@within swan
	@tag roblox

	Takes a target state or raw value, and returns a state whose value will be interpolated towards
	the target's new value (in case its a state) or towards the target directly (if its a raw value)
	for "one-shot" tweens.

	After the target, you can provide an initial value for the tween state.
	If not provided and the target is a state, it will default to the
	target's current value, otherwise, an error will occur.

	The interpolation is configured through the use of the given TweenInfo.

	The last argument is a function which gets called whenever the state finishes the interpolation,
	as in, it reaches its goal, which means that it doesn't fire when an already playing tween
	stops in favor of a new one.

	```lua
	const target_size = swan.state(UDim2.fromScale(0.2, 0.2))
	swan.create "Frame" {
		AnchorPoint = Vector2.one * 0.5,
		Position = swan.tween(
			TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, true),
			UDim2.fromScale(0.8, 0.8),
			UDim2.fromScale(0.2, 0.2),
			function()
				print("Finished tweening position!")
			end
		),
		Size = swan.tween(TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), target_size),
	}

	task.wait(1)
	target_size(UDim2.fromScale(0.4, 0.4)) -- After 2 seconds: "Finished tweening position!"
	```

	@param target (T & animatable) | state<T & animatable>
	@param info TweenInfo
	@param on_complete on_complete?
	@return state<T>
]=]
function roblox.tween<T>(
	info: TweenInfo,
	target: T | state<T>,
	initial_value: (T & animatable)?,
	on_complete: on_complete?
): state<T>
	local self: state<T>

	if not utils.is_state(target) then
		assert(initial_value, "One-shot tweens expect an initial value!")

		self = state.state<<T>>(initial_value)
		play_tween(target :: animatable, info, on_complete, self)
		return self
	end

	local current_tween: Tween? = nil
	target = target :: any
	initial_value = initial_value or target.value
	self = state.state<<T>>(initial_value)

	effect(function(old_value)
		const goal = target()
		if not (old_value or goal ~= initial_value) then
			return
		end

		if current_tween then
			current_tween:Pause()
		end

		current_tween = play_tween(goal, info, on_complete, self)
	end)

	return self
end

return roblox
