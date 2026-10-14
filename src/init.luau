--!strict
--[[
Luau FIXME:
	- When creating a state, if its variable type is annotated,
	and the type of the value passed to swan.state() doesn't match,
	there should be a type error:
	const health : swan.state<number> = swan.state("i'm not a number") -- doesn't error
]]

const state = require("@self/state")
const swan_types = require("@self/swan_types")

--- @class swan

--[=[
	@type disconnecter () -> ()
	@within swan

	Function which disconnects an effect from its states.
]=]
export type disconnecter = swan_types.disconnecter

--[=[
	@type cleanup<T...> (T...) -> ...unknown
	@within swan

	Function which gets called when its effect is disconnected.
]=]
export type cleanup<T...> = swan_types.cleanup<T...>

--[=[
	@type callback<T=unknown,U...=()> ((old_value: T?, state_i: number?) -> (cleanup<U...>, U...))\n| ((old_value: T?, state_i: number?) -> ())\n| ((old_value: T?, state_i: number?) -> nil) -- "nil" should be "false?"
	@within swan

	Function which gets called when its effect is triggered.
]=]
export type callback<T = unknown, U... = ()> = swan_types.callback<T, U...>

--[=[
	@type state<T=unknown> setmetatable<{ value: T, always_force: boolean?, dirty: boolean, compute: ((() -> T) | (() -> ()))?, read subscribers: { [callback<T>]: number }, read dependents: { [state]: true } }, { __call: ((self: state<T>) -> T) & ((self: state<T>, new_value: T, force: boolean?) -> T), __unm: (state<T>) -> state<T>, __concat: (state_or_concatenable<T>, state_or_concatenable<T>) -> state<T>, __add: (state_or_number<T>, state_or_number<T>) -> state<T>, __sub: (state_or_number<T>, state_or_number<T>) -> state<T>, __mul: (state_or_number<T>, state_or_number<T>) -> state<T>, __div: (state_or_number<T>, state_or_number<T>) -> state<T>, __idiv: (state_or_number<T>, state_or_number<T>) -> state<T>, __mod: (state_or_number<T>, state_or_number<T>) -> state<T>, __pow: (state_or_number<T>, state_or_number<T>) -> state<T>>
	@within swan

	The [state](/docs/concepts#state) type.
]=]
export type state<T = unknown> = swan_types.state<T>

--[=[
	@type proxy_base<T> setmetatable<T, {[SWAN_PROXY_ID] : true, [SWAN_REAL_ID] : T, __index : T, __newindex : ({}, any, any) -> ()}>
	@within swan

	The proxy table type. Learn more [here](/docs/concepts#table-states).
]=]
export type proxy_base<T> = swan_types.proxy_base<T>

--[=[
	@type proxy typefunction(t: type) -> type
	@within swan

	Type function which recursively creates a proxy out of [`proxy_base`](/api/swan#proxy_base<T>).
]=]
export type proxy<T> = swan_types.proxy<T>

--[=[
	@type proxy_state<T> state<proxy<T>>
	@within swan

	A state which holds a proxy.
]=]
export type proxy_state<T> = swan_types.proxy_state<T>

--[=[
	@type animatable number | vector | Vector2 | Vector2int16 | Vector3 | Vector3int16 | UDim | UDim2 | CFrame
	@within swan

	Value that can be animated with `swan.tween()`.
]=]
export type animatable = swan_types.animatable

--[=[
	@type easing_fun (a : number, b: number, t : number) -> number
	@within swan

	A function which computes an easing curve, for tweening.

	Takes the start value `a` (t=0), end value `b` (t=1) and
	normalized progress `t` (0..1).
]=]
export type easing_fn = swan_types.easing_fn

--[=[
	@type default_easing_fn "linear" | "quadratic" | "sine" | "exponential" | "circular" | "back" | "elastic" | "bounce"
	@within swan

	Name for the default easing functions provided by `swan`.
]=]
export type default_easing_fn = swan_types.default_easing_fn

--[=[
	@type easing_dir "in" | "out" | "in-out"
	@within swan

	Defines the linearity of a tween.

	Ease-in: slow -> fast\
	Ease-out: fast -> slow\
	Ease-in-out: slow -> fast -> slow
]=]
export type easing_dir = swan_types.easing_dir

const swan = {
	--[=[
		Creates and returns a [state](/docs/concepts#state).

		```lua
		const ammo = swan.state(100)
		const message = swan.state("Hello, World!", true)

		print(ammo(), message.value) -- 100, "Hello, World!"
		```
	]=]
	state = state.state,

	--[=[
		Takes the given function and

		This is useful for states which depend on the value of another state, since their value will
		be updated only when the state they depend on is also updated, and not every time it is read.

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
	computed = state.computed,

	--[=[
        Creates and returns a [proxy state](/docs/concepts#table_states).

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
	proxy = state.proxy,

	--[=[
		Creates an [effect](/docs/concepts#effect) and returns its disconnecter.

		```lua
		const health = swan.state(100)
		const printer_disconnecter = swan.effect(function(old_health)
			print(`old health: {old_health}, current health: {health()}`)
		end)

		health(40) -- `old health: 100, current health: 40`
		health.value = 20 -- *crickets*
		health(60) -- `old health: 20, current health: 60`
		health(60) -- *crickets*
		health(60, true) -- `old health: 60, current health: 60`

		printer_disconnecter()
		health(20) -- *crickets*

		printer_disconnecter() -- you can disconnect again, it's fine!

		const always_forces = swan.state("I always force effects", true)
		swan.effect(function()
			print(always_forces(), health.value) -- doesn't track `health`
		end)

		always_forces("I always force effects") -- "I always force effects"
		always_forces("I always force effects, again") -- "I always force effects, again"
		always_forces("I always force effects, again") -- "I always force effects, again"

		const kill = swan.effect(function()
			return print, "Why did you kill me :("
		end)

		kill() -- "Why did you kill me :("
		```
    ]=]
	effect = require("@self/effect"),

	--[=[
		Collects the disconnecters of all the effects that were ran within the given function,
		and returns an "omni-disconnecter" which calls all of them.
		Works with nested effects and scopes too.

		```lua
		const root = scope(function()
			effect(function()
				effect(function()
					return print, "1.1"
				end)
				return print, "1"
			end)

			scope(function()
				effect(function()
					return print, "_1"
				end)
			end)

			effect(function()
				return print, "2"
			end)
		end)

		root() -- 1.1 1 _1 2
		```
	]=]
	scope = require("@self/scope"),

	--[=[
		Creates and returns a "tween state" which depends on the given target state.
		Whenever the target changes, the created state will tween towards the new value,
		depending on the given parameters.

		The options table parameter takes the following options:
		```agda
		{
			easing_dir : easing_dir? -- The direction of the tween.
			delay : number? -- Time (seconds) to wait before tweening towards the target once it changes.
			bounces : number? -- Number of times the tween will repeat back and forth.
			on_complete : () -> ()? -- Callback that gets called when the tween is done (after every bounce).
		}
		```

		```lua
		const frame_pos = state(UDim2.fromScale(0, 0))
		const frame : Frame = swan.create("Frame", {
			Position = swan.tween(frame_pos, 1, "linear")
		})

		frame_pos(UDim2.fromScale(0.5, 0.5)) -- the frame's position will linearly tween to (0.5, 0.5) in 1 second
		```

		@param duration number -- How long each tween should take.
		@param easing_fun default_easing_fun | easing_fun -- Either the name of a default easing function, or a custom one.
	]=]
	tween = require("@self/tween"),

	utils = require("@self/utils"),
}

if game then
	const roblox = require("@self/roblox")

	--[=[
		@type instances {[string]: Instance}
		@within swan
		@tag roblox

		List of valid instance types to be passed to [`swan.create`](/api/swan#create) and
		[`swan.apply`](/api/swan#apply) in the form of [ClassName] : Type.
	]=]
	export type instances = swan_types.instances

	--[=[
		@type class_name keyof<swan.instances>
		@within swan
		@tag roblox

		Name of a valid instance (ClassName) to be passed to [`swan.create`](/api/swan#create) and
		[`swan.apply`](/api/swan#apply) in the form of [ClassName] : Type.
	]=]
	export type class_name = swan_types.class_name

	--[=[
		@type properties typefunction(instance: type) -> type
		@within swan
		@tag roblox

		Type function which takes an Instance type and returns a properties table for said Instance.
	]=]
	export type properties<T> = swan_types.properties<T>

	--[=[
		@type constructor (properties: properties<T>) -> T
		@within swan
		@tag roblox

		A function which constructs a Instance of the given type,
		by applying the given properties.
		Returned by [`swan.create`](/api/swan#create) and [`swan.apply`](/api/swan#apply).
	]=]
	export type constructor<T = Instance> = swan_types.constructor<T>

	--[=[
		@function create
		@within swan
		@tag roblox

		Returns a constructor
		Creates an Instance, applying the given properties.

		Depending on the key, the properties table has the following behaviour:
		- **Property**: either provide the value directly or a state holding it.\
		If you do the latter, `swan` will implicitly create an effect which updates the property for you.
		- **Event**: give a callback function which will be automatically connected to the Event and have its arguments passed.
		- **"Children"**: either a table, where the values are Instances and the keys are names for said Instances,
		if their name is unset (Name = ClassName); or a state containing said table.
		If it's the latter, `swan` will implicitly create an effect which automatically destroys/parents Instances
		that were removed/added to the table.
		- **number**: a nested Properties table, useful for [components](/api/swan#component).

		@param class_name T | class_name -- The class name of the Instance you want to create.
		@param properties any | props<T> -- Table of properties to be applied to the Instance.
		@return index<instances, T> -- The created Instance.

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
	swan.create = roblox.create

	--[=[
		@function apply
		@within swan
		@tag roblox

		Same as [`swan.create()`](/api/swan#create), except that you pass an existing Instance,
		to which the passed properties will be applied, instead of creating a new one.
	]=]
	swan.apply = roblox.apply

	--[=[
	@function component
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
	]=]
	swan.component = roblox.component
end

return swan
