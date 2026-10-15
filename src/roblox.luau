--!strict

const TweenService = game:GetService("TweenService")

const effect = require("./effect")
const scope = require("./scope")
const state = require("./state")
const swan_types = require("./swan_types")
const utils = require("./utils")

type state<T = unknown> = swan_types.state<T>

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

const function implicit_effect(instance: Instance, value: any, action: (...any) -> ()): any
	if not utils.is_state(value) then
		return action(value)
	end

	return effect(function(old)
		action(value(), old)
	end)
end

const function apply<T>(instance: T & Instance, properties: properties<T>): T
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

	```lua
	const bullets = state(100)
	const main_frame = create("Frame", {
		BackgroundColor3 = Color3.new(),
		Size = UDim2.fromScale(1, 1),
		Children = {
			create("UIGridLayout", {
				CellSize = UDim2.fromOffset(100, 100)
			}),
			bullets_label = create("TextLabel", {
				Text = "Bullets: "..bullets :: string
			}),
			shoot_button = create("TextButton", {
				Text = "Shoot",
				MouseButton1Down = function()
					bullets(bullets.value - 1)
				end
			})
		}
	})
	```
]=]
function roblox.create<T>(class_name: T | class_name): class_constructor<T>
	local constructor = constructor_cache[class_name] :: class_constructor<T>?
	if constructor then
		return constructor
	end

	const instance = Instance.new(class_name)
	constructor = function(properties: properties<T>)
		return apply<<T>>(instance, properties)
	end

	constructor_cache[class_name] = constructor :: constructor
	return constructor
end

--[=[
	@within swan
	@tag roblox

	Wraps a function, which returns an Instance, into a scope, so that when the
	Instance is destroyed, the scope is disconnected.\
	Returns the wrapped function.

	```lua
	const item = component(function(name: string)
		const equipped = state(false)
		const self: TextButton = create("TextButton", {
			Text = name,

			MouseButton1Click = function()
				equipped(not equipped.value)
			end,
		})

		swan.effect(function()
			self.Text = equipped() and "Equipped!" or "Unequipped!"

			task.wait(1)
			self.Text = name

			return print, `The item "{name}" was destroyed.`
		end)

		return self
	end)

	const ak47 = item "ak47"
	ak47:Destroy() -- "The item "ak47" was destroyed."
	```

	@param fn (U...) -> T & Instance
	@return (U...) -> T
]=]
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

local function convert_vector3(
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

local function play_tween(goal: animatable, info: TweenInfo, on_complete: on_complete?, self: state<animatable>): Tween
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
