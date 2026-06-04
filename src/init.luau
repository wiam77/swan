--!strict
--[[
TODO:
	- NOTE: The problems below cannot currently be solved as they depend on features and bug-fixes
	not yet implemented in Luau.

	- Remove the need for `proxy_base_hack`.

	- When creating a state, if its variable type is annotated,
	and the type of the value passed to swan.state() doesn't match,
	there should be a type error:
	local health : swan.state<number> = swan.state("i'm not a number") -- doesn't error

	- String and boolean states get implicitly typed as state<unknown>:
	local message = swan.state("Hello, World!") -- message's type is `unknown`, not `string`.
	local active = swan.state(true) -- active's type is `unknown`, not `boolean`.

	This can be fixed by casting the passed value to the desired type:
	local message = swan.state("Hello, World!" :: string)
	local active = swan.state(true :: boolean)

	- Typings for implicit deriveds.
	local a = swan.state(100)
	local b = a + 1 -- Errors

	The error can be suppressed by casting to any:
	local a = swan.state(100)
	local b : swan.state<number> = a + 1 :: any
]]--

--- @class swan
local swan = {}

--- @class utils
local utils = {}
swan.utils = utils

-- TYPES --
--[=[
	@type cleanup<T...> (T...) -> ...unknown
	@within swan

	Function which gets called when its effect is disconnected.
]=]
export type cleanup<T...> = (T...) -> ...unknown

--[=[
	@type disconnecter () -> ()
	@within swan

	Function which disconnects an effect from its states.
]=]
export type disconnecter = () -> ()

--[=[
	@type state<T> {value : T, always_force : boolean, callbacks : {[callback<T>] : number}} & ((() -> T) | ((new_value : T?, force : boolean?) -> T))
	@within swan

	The [state](/docs/concepts#state) type.
]=]
export type state<T = unknown> = {
	value : T,
	always_force : boolean,
	read callbacks : {[callback<T>] : number}
} & ( &	(() -> T)
      &	((new_value : T, force : boolean?) -> T))

--[=[
	@type proxy_base<T> setmetatable<T, {[SWAN_PROXY_ID] : true, [SWAN_REAL_ID] : T, __index : T, __newindex : ({}, any, any) -> ()}>
	@within swan

	The proxy table type. Learn more [here](/docs/concepts#table-states).
]=]
type proxy_base<T> = setmetatable<T, {
	_is_swan_proxy : true,
	_swan_real : T,
	__index : T,
	__newindex : ({}, any, any) -> (),
}>

--[=[
	@type proxy_base_hack<T> setmetatable<{}, {[SWAN_PROXY_ID] : true, [SWAN_REAL_ID] : T, __index : T, __newindex : ({}, any, any) -> ()}>
	@within swan
	@private

	A hack to provide better types.
]=]
type proxy_base_hack<T> = setmetatable<{}, {
	_is_swan_proxy : true,
	_swan_real : T,
	__index : T,
	__newindex : ({}, any, any) -> ()
}>

--[=[
	@type proxy typefunction
	@within swan

	Type function which recursively creates a proxy out of [`proxy_base`](/api/swan#proxy_base<T>).
]=]
export type function proxy(t : type) : type
	for k, v in t:properties() do
		local value = v.read :: type
		if (value):is("table") then
			t:setproperty(k, proxy(value))
		end
	end

	return proxy_base(t)
end

--[=[
	@type proxy_state<T> state<proxy<T>>
	@within swan

	A state which holds a proxy.
]=]
export type proxy_state<T> = state<proxy<T>>

type callback_node = {
	value : callback,
	previous : callback_node?
}

type scope_node = {
	disconnecters : {disconnecter},
	previous : scope_node?
}

--[=[
	@type easing_fun (a : number, b: number, t : number) -> number
	@within swan

	A function which computes an easing curve, for tweening.

	Takes the start value `a` (t=0), end value `b` (t=1) and
	normalized progress `t` (0..1).
]=]
export type easing_fun = (a : number, b: number, t : number) -> number

--[=[
	@type easing_dir "in" | "out" | "in-out"
	@within swan

	Defines the linearity of a tween.

	Ease-in: slow -> fast\
	Ease-out: fast -> slow\
	Ease-in-out: slow -> fast -> slow
]=]
export type easing_dir = "in" | "out" | "in-out"

--[=[
	@type tweenable number | vector | Vector2 | Vector2int16 | Vector3 | Vector3int16 | UDim | UDim2 | CFrame
	@within swan

	Value that can be tweened with `swan.tween()`.
]=]
export type tweenable = number | vector | Vector2 | Vector2int16 | Vector3 | Vector3int16 | UDim | UDim2 | CFrame

-- CONSTANTS --
--[=[
	@prop SWAN_PROXY_ID string
	@within swan
	@private

	Identifier used by `swan` to detect whether a table is a proxy or not.
]=]
local SWAN_PROXY_ID = "_is_swan_proxy"

--[=[
	@prop SWAN_REAL_ID string
	@within swan
	@private

	Identifier used by `swan` to access the "real" value of a proxy table.
]=]
local SWAN_REAL_ID = "_swan_real"

local BINARY_OPS : {[string] : (any, any) -> unknown} = {
	concat = function(a, b) return a ..b end,
	add    = function(a, b) return a + b end,
	sub    = function(a, b) return a - b end,
	mul    = function(a, b) return a * b end,
	div    = function(a, b) return a / b end,
	idiv   = function(a, b) return a //b end,
	mod    = function(a, b) return a % b end,
	pow    = function(a, b) return a ^ b end,
}

-- VARIABLES --
local batching : boolean = false
local batched : {[state] : {any}} = {} -- {[state] : {[1] : {[callback] = true}, [2] : old_value, [3] : state_i}}

local current_callback : callback_node? = nil
local current_scope : scope_node? = nil

local effects : {[callback] : number} = {}
local block_effects : {[callback] : thread} = {}

-- UTILITIES --
local function deep_clone<K, V>(t : {[K] : V}) : {[K] : V}
	if type(t) ~= "table" then return t end

	local clone : any = {}
	for k, v : any in t do
		clone[k] = deep_clone(v)
	end

	return clone
end

local function make_proxy(real : any, state : state, root_old : any, self_old : any) : ...unknown
	if type(real) ~= "table" or utils.is_proxy(real) then return real end
	if not root_old then
		root_old = deep_clone(real)
		self_old = root_old
	end

	local proxified = {}
	for k, v in real do
		proxified[k] = make_proxy(v, state, root_old, self_old[k])
	end

	local callbacks = state.callbacks
	return setmetatable({}, {
		[SWAN_PROXY_ID] = true,
		[SWAN_REAL_ID] = real,
		__index = proxified,
		__newindex = function(_, k, v)
			if proxified[k] == v and not state.always_force then return end
			proxified[k] = v
			real[k] = v

			for callback, state_i in callbacks do
				(callback )(root_old, state_i)
			end

			self_old[k] = v
		end
	})
end

local function assert_is_function<T>(v : T) : T
	local vt = type(v)
	assert(vt == "function", `Expected a 'function', got a '{vt}', with value '{v}'!`)
	return v
end

local function noop() : () end

-- MODULE --
--* STATE_MT *--
local state_mt = {}

function state_mt.__call<T>(self : state<T>, ...) : T
	local old_value = self.value
	local callbacks = self.callbacks

	local args = {...}
	local argsn = select("#", ...)
	local new_value : T? = args[1]
	local force : boolean? = args[2]
	local always_force = self.always_force

	if argsn == 0 then -- if reading (state())
		local cc = current_callback and current_callback.value
		if cc and not callbacks[cc] then -- if within effect and not already registered to it
			effects[cc] += 1
			callbacks[cc] = effects[cc]
		end
	elseif old_value ~= new_value or (always_force and force ~= false) or force then -- if writing (state(v))
		if utils.is_proxy(old_value) then new_value = make_proxy(new_value, self) end
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

function state_mt.__unm(v : state<number>) : state<number>
	return (swan.derived(function()
		return -v()
	end)) -- between parentheses because of weird bug.
end

for op_name, op in BINARY_OPS do
	state_mt["__"..op_name] = function(a : any, b : any)
		return swan.derived(
			if utils.is_state(a) then
				function()
					return op(a(), b)
				end
			else
				function()
					return op(a, b())
				end
		)
	end
end

--* CONSTRUCTORS *--
--[=[
	Creates and returns a [state](/docs/concepts#state).

	```lua
	local ammo = swan.state(100)
	local message = swan.state("Hello, World!", true)

	print(ammo(), message.value) -- 100, "Hello, World!"
	```
]=]
function swan.state<T>(initial_value : T?, always_force : boolean?) : state<T>
	return setmetatable({
		value = initial_value,
		always_force = always_force,
		callbacks = {}
	}, state_mt) :: any
end

--[=[
	Creates and returns a [proxy state](/docs/concepts#table_states).

	```lua
	local profile = swan.proxy_state {
		name = "john",
		age = 20,
	}

	swan.effect(function(old_profile)
		local new_profile = profile()

		if old_profile and old_profile.name ~= new_profile.name then
			print(`{old_profile.name} changed their name to {new_profile.name}`)
		end
	end)

	profile().name = "doe"
	```
]=]
function swan.proxy_state<T>(initial_value : T & {[any] : any}, always_force : boolean?) : proxy_state<T>
	local self : any = setmetatable({
		always_force = always_force,
		callbacks = {}
	}, state_mt)
	self.value = make_proxy(initial_value, self)
	return self
end

local function effect_base(original : any, callback : any)
	current_callback = {
		value = callback,
		previous = current_callback
	}

	effects[callback] = 0
	local cleanup_data = {original()}
	current_callback = (current_callback :: callback_node).previous

	local function disconnecter()
		effects[callback] = nil
		disconnecter = noop
	end

	if not cleanup_data then return disconnecter end

	local cleanup : any = cleanup_data[1]
	if not cleanup :: any then return disconnecter end

	local function maid()
		disconnecter()
		cleanup(select(2, unpack(cleanup_data)))
		maid = noop
	end

	if current_scope then
		table.insert(current_scope.disconnecters, maid)
	end

	return maid
end

--[=[
	Creates an [effect](/docs/concepts#effect) and returns its disconnecter.

	```lua
	local health = swan.state(100)
	local printer_disconnecter = swan.effect(function(old_health)
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

	local always_forces = swan.state("I always force effects", true)
	swan.effect(function()
		print(always_forces(), health.value) -- doesn't track `health`
	end)

	always_forces("I always force effects") -- "I always force effects"
	always_forces("I always force effects, again") -- "I always force effects, again"
	always_forces("I always force effects, again") -- "I always force effects, again"

	local kill = swan.effect(function()
		return print, "Why did you kill me :("
	end)

	kill() -- "Why did you kill me :("
	```
]=]
function swan.effect<T, U...>(callback : callback<T, U...>) : disconnecter
	return effect_base(callback, callback)
end

--[=[
	Creates an effect which cancels its previously running "instance" (thread).\
	This is useful for when the callback yields.

	Here's a simple comparison between normal effects and block effects, using some pseudo-code:
	```lua
	local equipped = swan.state(false)
	swan.effect(function()
		label.Text = equipped() and "Equipped!" or "Unequipped!"

		task.wait(1)
		label.Text = item_name
	end)
	```
	[video](/unwanted.mkv)

	*replacing `effect` with `block_effect`: [video](/correct.mkv)

	The difference is subtle, but in the first example, when the user spam clicks the item, its equip status is not shown when he stops.
]=]
function swan.block_effect<T, U...>(callback : callback<T, U...>) : disconnecter
	local original : any = callback
	callback = function(...)
		local old = block_effects[original]
		if old then coroutine.close(old) end

		local new = coroutine.create(original)
		coroutine.resume(new, ...)
		block_effects[original] = new
	end

	return effect_base(original, callback)
end

--[=[
	Wraps an effect, around the given function, which sets a newly created state's value
	to be the return value of said function.

	Returns the created state and the effect's disconnecter.

	This is useful for states which depend on the value of another state, since their value will
	be updated only when the state they depend on is also updated, and not every time it is read.

	`swan` also provides [implicit deriveds](/docs/concepts#implicit_deriveds).

	```lua
	local stamina = swan.state(100)
	local possible_jumps = swan.derived(function()
		return stamina() / 50
	end)

	print(possible_jumps()) -- 2
	stamina(50)
	print(possible_jumps()) -- 1
	```
]=]
function swan.derived<T>(f : (() -> T) | (() -> ())) : (state<T>, disconnecter)
	local s = swan.state()
	return s, swan.effect(function()
		s(f())
	end)
end

--[=[
	Collects the disconnecters of all the effects that were ran within the given function,
	and returns an "omni-disconnecter" which calls all of them.
	Works with nested effects and scopes too.

	```lua
	local root = scope(function()
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
function swan.scope(f : () -> ...unknown) : disconnecter
	current_scope = {
		disconnecters = {},
		previous = current_scope
	}

	f()

	local disconnecters = (current_scope :: scope_node).disconnecters
	local function self()
		for _, disconnecter in disconnecters do
			disconnecter()
		end
	end

	current_scope = (current_scope :: scope_node).previous
	if current_scope then
		table.insert(current_scope.disconnecters, self)
	end
	return self
end

--* TWEENING *--
local easing_powers = {
	linear = 1,
	quadratic = 2,
	sine = 1,
	exponential = 2,
	circular = 2,
	back = 3,
	elastic = 3,
	bounce = 2,
}

--[=[
	@type default_easing_fun "linear" | "quadratic" | "sine" | "exponential" | "circular" | "back" | "elastic" | "bounce"
	@within swan

	Name for the default easing functions provided by `swan`.
]=]
export type default_easing_fun = keyof<typeof(easing_powers)>

local function vector_decomposer(v)
	return {v.X, v.Y, v.Z}
end

local component_handlers : any = { -- {[1] = decomposeer, [2] = recomposer}
	number = {
		function(v) return {v} end,
		function(c) return c[1] end,
	},
	vector = {
		vector_decomposer,
		function(c) return vector.create(c[1], c[2], c[3]) end,
	},
	Vector2 = {
		vector_decomposer,
		function(c) return Vector2.new(c[1], c[2]) end,
	},
	Vector2int16 = {
		vector_decomposer,
		function(c) return Vector2int16.new(c[1], c[2]) end,
	},
	Vector3 = {
		vector_decomposer,
		function(c) return Vector3.new(c[1], c[2], c[3]) end,
	},
	Vector3int16 = {
		vector_decomposer,
		function(c) return Vector3int16.new(c[1], c[2]) end,
	},
	UDim = {
		function(v) return {v.Scale, v.Offset} end,
		function(c) return UDim.new(c[1], c[2]) end,
	},
	UDim2 = {
		function(v) return {v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset} end,
		function(c) return UDim2.new(c[1], c[2], c[3], c[4]) end,
	},
	CFrame = {
		function(v)
			return {v:GetComponents()}
		end,
		function(c)
			return CFrame.fromMatrix(
				Vector3.new(c[1], c[2], c[3]),
				Vector3.new(c[4], c[5], c[6]),
				Vector3.new(c[7], c[8], c[9]),
				Vector3.new(c[10], c[11], c[12])
			)
		end
	}
}

local default_easing_funs : {[default_easing_fun] : easing_fun} = {
	linear = function(a, b, t)
		return a * (1 - t) + b * t
	end,
	quadratic = function(a, b, t)
		return a + (b - a) * t*t
	end,
	sine = function(a, b, t)
		return a + (b - a) * (1 - math.cos(t * math.pi / 2))
	end,
	exponential = function(a, b, t)
		return a + (b - a) *
			if t == 0 then 0
			else if t == 1 then 1
			else (2 ^ (10 * (t - 1)))
	end,
	circular = function(a, b, t)
		return a + (b - a) * (1 - math.sqrt(1 - math.min(1, math.max(0, t*t))))
	end,
	back = function(a, b, t)
		return a + (b - a) * (t*t * ((1.70158 + 1) * t - 1.70158))
	end,
	elastic = function(a, b, t)
		if t == 0 then return a end
		if t == 1 then return b end

		local p = 0.3
		local eased = 2^(-10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1

		return a + (b - a) * eased
	end,
	bounce = function(a, b, t)
		return a + (b - a) *
			if t < 1/2.75 then 7.5625 * t*t
			else if t < 2/2.75 then 7.5625 * (t - 1.5/2.75)^2 + 0.75
			else if t < 2.5/2.75 then 7.5625 * (t - 2.25/2.75)^2 + 0.9375
			else 7.5625 * (t - 2.625/2.75)^2 + 0.984375
	end,
}

local function apply_easing<T>(start_value : T, goal_value : T, t : number, easing_fun : easing_fun, data_type : string)
	local handlers = component_handlers[data_type]
	local decomposer = handlers[1]
	local start_components = decomposer(start_value)
	local goal_components = decomposer(goal_value)

	for i, v in start_components do
		goal_components[i] = easing_fun(v, goal_components[i], t)
	end

	return handlers[2](goal_components)
end

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
	local frame_pos = state(UDim2.fromScale(0, 0))
	local frame : Frame = swan.create("Frame", {
		Position = swan.tween(frame_pos, 1, "linear")
	})

	frame_pos(UDim2.fromScale(0.5, 0.5)) -- the frame's position will linearly tween to (0.5, 0.5) in 1 second
	```

	@param duration number -- How long each tween should take.
	@param easing_fun default_easing_fun | easing_fun -- Either the name of a default easing function, or a custom one.
]=]
function swan.tween<T>(target : state<T & tweenable>, duration : number, easing_fun : default_easing_fun | easing_fun,
	options : {
		easing_dir : easing_dir?,
		delay : number?,
		bounces : number?,
		on_complete : () -> ()?
	}?) : state<T>
	assert(swan.wait, "The wait function (swan.wait) was not provided.")

	local target_value = target.value
	local data_type = typeof(target_value)
	local tweened = swan.state(target_value)

	local easing_f = default_easing_funs[easing_fun :: default_easing_fun] or (easing_fun :: easing_fun)
	local opts = options or {} :: any
	local easing_dir : easing_dir? = opts.easing_dir
	local easing_power : number = easing_powers[easing_fun] -- should be `number?`

	local first = true
	swan.effect(function()
		local goal = target()
		if first then
			first = false
			return
		end

		if opts.delay then
			(swan.wait :: any)(opts.delay)
		end

		local start_value = tweened.value
		for current_bounce = 0, opts.bounces or 0 do
			local start_time = os.clock()
			local progress = 0

			while progress < 1 do
				progress = math.min((os.clock() - start_time) / duration, 1)

				local t = progress
				if easing_power then
					if easing_dir == "in" then
						t ^= easing_power
					elseif easing_dir == "out" then
						t = 1 - (1 - t) ^ easing_power
					elseif easing_dir == "in-out" then
						if t < 0.5 then
							t = 0.5 * (2 * t) ^ easing_power
						else
							t = 1 - 0.5 * (2 - 2 * t) ^ easing_power
						end
					end
				end

				if current_bounce % 2 == 1 then
					t = 1 - t
				end

				tweened(apply_easing(start_value, goal, t, easing_f, data_type));
				(swan.wait :: any)()
			end
		end

		if opts.on_complete :: any then
			opts.on_complete()
		end
	end)

	return tweened
end

--* SWAN UTILITIES *--
--[=[
	Batches any state write operation up until the given function is done running.

	```lua
	local text = swan.state("Hey, how is it going?")

	swan.effect(function()
		print(text())
	end)

	utils.batch(function()
		text("Hello, World!")
		text("Bye, World!")
	end) -- the previous effect will only print "Bye, World!"

	utils.batch(function()
		text.value = "Oops"
	end) -- be careful! If the last write operation is done through .value, the effect will also trigger! -- "Oops"
	```
]=]
function utils.batch(f : () -> ...unknown) : ()
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
	[Branching](/docs/concepts#branching) function to be used within effects.

	Pass a condition to be checked, and after it a function to be run if it's successful.
	The last value, if a function, and if not after a condition, will be threated as the "else" branch.

	@param ... any -- The values and the branches.

	```lua
	local age = swan.state(16)
	local role = "admin"

	local bad_validator = swan.effect(function()
		if role ~= "admin" then -- admins can bypass the age verification
			assert(age() >= 18, "Your age is too low!")
		end
	end) -- won't detect `age` since in the first run, the condition was false, and age() wasn't called.

	local validator = swan.effect(function()
		utils.branch(
			role ~= "admin", function()
				assert(age() >= 18, "Your age is too low!")
			end
		)
	end) -- will detect `age`
	```
]=]
function utils.branch(... : any) : ()
	local args = table.pack(...)
	local n = args.n
	assert(n > 1, `Expected at least 2 arguments, got {n}: {...}!`)

	local i = 1
	while i + 1 <= n do
		if args[i] or current_callback then
			assert_is_function(args[i + 1])()
		end

		i += 2
	end

	if i <= n then
		assert_is_function(args[i])()
	end
end

--[=[
	Returns whether the given value is a state.

	```lua
	local not_a_state = "Hey"
	print(utils.is_state(not_a_state)) -- false

	local a_state = swan.state("Cool")
	print(utils.is_state(a_state)) -- true
	```
]=]
function utils.is_state<T>(v : T) : boolean
	return getmetatable(v) == state_mt
end

--[=[

	Returns whether the given value is a proxy.

	```lua
	local not_a_proxy = "Hey"
	print(utils.is_proxy(not_a_proxy)) -- false

	local a_proxy_state = swan.proxy_state({
		hello = "world"
	})
	print(utils.is_proxy(a_proxy_state())) -- true
	```
]=]
function utils.is_proxy<T>(v : T) : boolean
	local mt = getmetatable(v)
	return mt and (mt :: any)[SWAN_PROXY_ID] or false
end

--[=[

	Returns whether the given value is a state holding a proxy.

	```lua
	local not_a_proxy_state = "Hey"
	print(utils.is_proxy_state(not_a_proxy_state)) -- false
	not_a_proxy_state = swan.state("Hey")
	print(utils.is_proxy_state(not_a_proxy_state)) -- false

	local a_proxy_state = swan.proxy_state({
		hello = "world"
	})
	print(utils.is_proxy_state(a_proxy_state)) -- true
	```
]=]
function utils.is_proxy_state<T>(v : T) : boolean
	return utils.is_state(v) and utils.is_proxy((v :: any).value) or false
end

--[=[
	Returns the "real" value of a proxy.

	```lua
	local todos = swan.proxy_state {
		"go outside",
		"touch grass",
		"write more todos"
	}

	print(todos(), todos()[1]) -- {}, "go outside"
	print(swan.get_real(todos())) --[[ {
		"go outside",
		"touch grass",
		"write more todos"
	}
	]]--
	```
]=]
function utils.get_real<T>(pr : proxy_base_hack<T>) : T
	return (getmetatable(pr) :: any)[SWAN_REAL_ID]
end

--[=[
	Returns the "real" value of a state's proxy.

	```lua
	local todos = swan.proxy_state {
		"go outside",
		"touch grass",
		"write more todos"
	}

	print(todos(), todos()[1]) -- {}, "go outside"
	print(swan.state_get_real(todos)) --[[ {
		"go outside",
		"touch grass",
		"write more todos"
	}
	]]--
	```
]=]
function utils.state_get_real<T>(proxy_state : state<proxy_base_hack<T>>) : T
	return utils.get_real(proxy_state())
end

--[=[
	Disconnects all the effects from a specific state or in general.

	```lua
	local money = swan.state(10000)
	local health = swan.state(100)

	swan.effect(function()
		print("Your money:", money())
		print("Your health:", health())
	end)

	swan.effect(function()
		print("Your money (again):", money())
	end)

	money(100) -- "Your money: 100", "Your health: 50", "Your money (again): 100"
	health(50) -- "Your money: 100", "Your health: 50"

	swan.clear(health)
	health(200) -- *crickets*
	money(50) -- "Your money: 50", "Your health: 200", "Your money (again): 50"

	swan.clear()
	money(10) -- *crickets*
	```
]=]
function utils.clear<T>(state : state<T>?) : ()
	table.clear(state and state.callbacks or effects)
end

if not Instance then return swan end

--[=[
	@prop wait (number?) -> number
	@within swan

	A wait function that needs to be provided for `swan.tween()` to work.
]=]
swan.wait = task.wait :: ((number?) -> number)?

--* ROBLOX *--
local function implicit_effect(instance : Instance, value : any, action : (...any) -> ()) : any
	if utils.is_state(value) then
		return swan.effect(function(old)
			action(value(), old)
		end)
	end

	return action(value)
end

local function apply_properties(instance : any, properties : {[any] : any}) : any
	local nested_props = {}
	for property_name, value in properties do
		if property_name == "Children" then
			implicit_effect(instance, value, function(value : any, old)
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
					if value[child_name] == child then continue end
					child:Destroy()
				end

				for child_name, child in value do
					if old[child_name] == child then continue end
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

--[=[
	@type valid_instances table
	@within swan
	@tag roblox

	List of valid instance types to be passed to [`swan.create`](/api/swan#create)) and [`swan.apply`](/api/swan#apply)
	in the form of [Name] : Type.
]=]
export type valid_instances = {
	Part : Part,
	Model : Model
}

-- TODO: make invalid properties error
--[=[
	@type props typefunction
	@within swan
	@tag roblox

	Typefunction which takes an Instance type and results a properties table for said Instance.
]=]
export type function props(instance : type) : type
	local self = types.newtable()
	self:setindexer(types.number, self)

	while instance do
		for k, v in instance:properties() do
			local vr = v.read :: type
			local vt = vr.tag
			local t : type?
			if vt == "function" then -- Method
				continue
			elseif vt == "table" then -- Event
				t = ((vr:readproperty(types.singleton("Connect")) :: type):parameters().head :: {type})[2]
			end

			self:setproperty(k, types.optional(t or (types.unionof(vr, state(vr)))))
		end

		instance = instance:readparent() :: type
	end

	return self
end

--[=[
	@tag roblox

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

	@param class_name T | keyof<valid_instances> -- The class name of the Instance you want to create.
	@param properties any | props<T> -- Table of properties to be applied to the Instance.
	@return index<valid_instances, T> -- The created Instance.

	```lua
	local bullets = state(100)
	local main_frame = create("Frame", {
		BackgroundColor3 = Color3.new(),
		Size = UDim2.fromScale(1, 1),
		Children = {
			create("UIGridLayout", {
				CellSize = UDim2.fromOffset(100, 100)
			}),
			bullets_label = create("TextLabel", {
				Text = "Bullets: "..bullets :: string -- implicit derived
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
function swan.create<T>(class_name : T | keyof<valid_instances>, properties : any | props<index<valid_instances, T>>) : index<valid_instances, T>
	return apply_properties(Instance.new(class_name), properties)
end

--[=[
	@function apply
	@within swan
	@tag roblox

	Same as [`swan.create()`](/api/swan#create), except that you pass an Instance, to which the
	passed properties will be applied, instead of creating a new one.
]=]
swan.apply = apply_properties :: <T>(instance : T & Instance, properties : any | props<T>) -> T

--[=[
	@tag roblox

	Wraps a function, which returns an Instance, into a scope, so that when the
	Instance is destroyed, the scope is disconnected.\
	Returns the wrapped function.

	```lua
	local item = component(function(name : string)
		local equipped = state(false :: boolean)
		local self : TextButton = create("TextButton", {
			Text = name,

			MouseButton1Click = function()
				equipped(not equipped.value)
			end,
		})

		swan.block_effect(function()
			self.Text = equipped() and "Equipped!" or "Unequipped!"

			task.wait(1)
			self.Text = name

			return print, `The item "{name}" was destroyed.`
		end)

		return self
	end)

	local ak47 = item "ak47"
	ak47:Destroy() -- "The item "ak47" was destroyed."
	```
]=]
function swan.component<T, U...>(f : (U...) -> T & Instance) : (U...) -> T
	return function(... : U...) : T
		local args : {any} = {...}
		local instance : Instance
		local disconnecter = swan.scope(function()
			instance = f(table.unpack(args))
		end)
		instance.Destroying:Connect(disconnecter)
		return instance
	end
end

-- This type is at the end of the file because it is breaking syntax highlighting.
--[=[
	@type callback ((old_value : T?, state_i : number?) -> cleanup) | ((old_value : T?, state_i : number?) -> nil | ())
	@within swan

	Function which gets called when its effect is triggered.\
	`old_value` is the state's previous value, which is going to be the same as the current one when an effect is forced.\
	`state_i` is the order of appearance of the state within the callback.

	Can return a cleanup function followed by any value to be passed to it.
]=]
export type callback<T = unknown, U... = ()> = ((old_value : T?, state_i : number?) -> (cleanup<U...>, U...))
                                             | ((old_value : T?, state_i : number?) -> ())
                                             | ((old_value : T?, state_i : number?) -> nil) -- "nil" should be "false?"

return swan
