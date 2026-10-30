--!strict

type Instance_ = Instance

type function get_value(v: { read: type?, write: type? }): type
	return v.read or v.write :: type
end

--[=[
	@type indexof typefunction(t: type) -> type
	@within swan
	@private

	Returns the union of the given table's indexer and keys.
]=]
export type function indexof(t: type)
	const indexer = t:indexer()
	local indices = if indexer then indexer.index else types.never
	for key in t:properties() do
		indices = types.unionof(indices, key)
	end
	return indices
end

--[=[
	@type valueof typefunction(t: type) -> type
	@within swan
	@private

	Returns the union of the given table's values.
]=]
export type function valueof(t: type): type
	local values = types.unionof()
	for _, value in t:properties() do
		values = types.unionof(values, get_value(value))
	end
	return values
end

--[=[
	@type disconnecter () -> ()
	@within swan
	@private

	Function which disconnects an effect from its states.
]=]
export type disconnecter = () -> ()

--[=[
	@type cleanup<T...> (T...) -> ...unknown
	@within swan
	@private

	Function which gets called when its effect is disconnected.
]=]
export type cleanup<T...> = (T...) -> ...unknown

type instance_callback<I, T = any, U... = ()> =
	((self: I, old_value: T?, state_i: number?) -> (cleanup<U...>, U...))
	| ((self: I, old_value: T?, state_i: number?) -> ())
	| ((self: I, old_value: T?, state_i: number?) -> false?)

--[=[
	@type callback<T=unknown,U...=()> ((old_value: T?, state_i: number?) -> (cleanup<U...>, U...)) | ((old_value: T?, state_i: number?) -> ()) | ((old_value: T?, state_i: number?) -> nil)
	@within swan
	@private

	Function which gets called when its effect is triggered.
]=]
export type callback<T = unknown, U... = ()> =
	((old_value: T?, state_i: number?) -> (cleanup<U...>, U...))
	| ((old_value: T?, state_i: number?) -> ())
	| ((old_value: T?, state_i: number?) -> false?)

--[=[
	@type state<T=unknown> setmetatable<{ value: T, always_force: true?, dirty: boolean, compute: ((() -> T) | (() -> ()))?, read subscribers: { [callback<T>]: number }, read dependents: { [state]: true } }, { __call: ((self: state<T>) -> T) & ((self: state<T>, new_value: T, force: boolean?) -> T), __unm: (state<T>) -> state<T>, __concat: (state_or_concatenable<T>, state_or_concatenable<T>) -> state<T>, __add: (state_or_number<T>, state_or_number<T>) -> state<T>, __sub: (state_or_number<T>, state_or_number<T>) -> state<T>, __mul: (state_or_number<T>, state_or_number<T>) -> state<T>, __div: (state_or_number<T>, state_or_number<T>) -> state<T>, __idiv: (state_or_number<T>, state_or_number<T>) -> state<T>, __mod: (state_or_number<T>, state_or_number<T>) -> state<T>, __pow: (state_or_number<T>, state_or_number<T>) -> state<T>>
	@within swan

	The [state](/docs/concepts#state) type.
]=]
export type state<T = unknown> = setmetatable<{
	value: T,
	always_force: true?,
	dirty: true?,
	recomputing: true?,
	read compute: ((() -> T) | (() -> ()))?,

	read subscribers: { [callback<T>]: number },
	read dependents: { [state]: true },
}, {
	__call: ((self: state<T>) -> T) & ((self: state<T>, new_value: T, force: boolean?) -> T),

	--[[
		Luau FIXME: the metamethods below should constrain this state's type (T) to be one adequate for the operation
		e.g. __unm should only accept numbers; otherwise, you can do stuff like
		state<string> + state<string> -> state<string>
		which causes runtime errors. This is currently not possible because of a Luau limitation
		where recursive types like these cannot use different parameters.

		Can't make an alias for state<T> | number because of weird bug regarding
		type functions that instantiate this type (as seen in `properties`).
	]]

	__unm: (state<T>) -> state<T>,
	__concat: (state<T> | string | number, state<T> | string | number) -> state<T>,
	__add: (state<T> | number, state<T> | number) -> state<T>,
	__sub: (state<T> | number, state<T> | number) -> state<T>,
	__mul: (state<T> | number, state<T> | number) -> state<T>,
	__div: (state<T> | number, state<T> | number) -> state<T>,
	__idiv: (state<T> | number, state<T> | number) -> state<T>,
	__mod: (state<T> | number, state<T> | number) -> state<T>,
	__pow: (state<T> | number, state<T> | number) -> state<T>,
}>

-- Used by `properties` because the normal `state` is way too complex to typecheck.
-- Luau FIXME: remove the need for this
type simple_state<T = unknown> = {
	value: T,
}

--[=[
	@type proxy_base<T> setmetatable<T, {[SWAN_PROXY_ID] : true, [SWAN_REAL_ID] : T, __index : T, __newindex : ({}, any, any) -> ()}>
	@within swan
	@private

	The [proxy table](/docs/concepts#table-states) type.
]=]
export type proxy_base<T> = setmetatable<T, {
	_is_swan_proxy: true,
	_swan_real: T,
	__index: T,
	__newindex: ({}, any, any) -> (),
}>

-- Luau FIXME: remove the need for this
export type proxy_base_hack<T> = setmetatable<{}, {
	_is_swan_proxy: true,
	_swan_real: T,
	__index: T,
	__newindex: ({}, any, any) -> (),
}>

--[=[
	@type proxy typefunction(t: type) -> type
	@within swan

	Type function which recursively creates a proxy out of [`proxy_base`](/api/swan#proxy_base<T>).
]=]
export type function proxy(t: type): type
	for k, v in t:properties() do
		const value = get_value(v)
		if value:is("table") then
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

export type node<T = unknown> = {
	data: T,
	previous: node<T>?,
}

export type scope_node = node<{ disconnecter }>

--[=[
	@type instances {[string]: Instance}
	@within swan
	@tag roblox
	@private

	List of valid instance types to be passed to [`swan.create`](/api/swan#create) and
	[`swan.apply`](/api/swan#apply) in the form of `[ClassName] : Type`.
]=]
export type instances = {
	UIAspectRatioConstraint: UIAspectRatioConstraint,
	UISizeConstraint: UISizeConstraint,
	UITextSizeConstraint: UITextSizeConstraint,
	UICorner: UICorner,
	UIDragDetector: UIDragDetector,
	UIFlexItem: UIFlexItem,
	UIGradient: UIGradient,
	UILayout: UILayout,
	UIGridStyleLayout: UIGridStyleLayout,
	UIGridLayout: UIGridLayout,
	UIListLayout: UIListLayout,
	UIPageLayout: UIPageLayout,
	UITableLayout: UITableLayout,
	UIPadding: UIPadding,
	UIScale: UIScale,
	UIStroke: UIStroke,
	CanvasGroup: CanvasGroup,
	Frame: Frame,
	ImageButton: ImageButton,
	TextButton: TextButton,
	ImageLabel: ImageLabel,
	TextLabel: TextLabel,
	ScrollingFrame: ScrollingFrame,
	TextBox: TextBox,
	VideoDisplay: VideoDisplay,
	VideoFrame: VideoFrame,
	ViewportFrame: ViewportFrame,
	BillboardGui: BillboardGui,
	ScreenGui: ScreenGui,
	AdGui: AdGui,
	SurfaceGui: SurfaceGui,
}

--[=[
	@type class_name keyof<instances>
	@within swan
	@tag roblox
	@private

	Name of a valid instance (ClassName) to be passed to [`swan.create`](/api/swan#create) and
	[`swan.apply`](/api/swan#apply) in the form of `[ClassName] : Type`.
]=]
export type class_name = keyof<instances>

export type dynamic_children_base = { [number | string]: Instance }
export type dynamic_children = proxy_state<dynamic_children_base>

-- FIXME: Roblox's LSP emits the "code too complex to typecheck"
-- error when trying to evaluate this type

--[=[
	@type properties typefunction(instance: type) -> type
	@within swan
	@tag roblox
	@private

	Type function which takes an Instance type and returns a properties table for said Instance.

	Depending on the key, the properties table has the following behaviour:
	- **Property**: either a "raw" value or a state holding it.\
	For the latter, an effect which updates the property for you will be implicitly created.
	- **Event**: callback function which will be connected to the Event and have its arguments passed.\
	The first argument is always the instance itself.
	- **number**:
	  - A nested Properties table, useful for components (functions that return instances based on some arguments).
	  Nested properties are applied first.
	  - A child instance.
	  - A proxy state containing a dictionary of Instances.\
	  The contents of the table is always reflected in the instance hierarchy, meaning that
	  added instances will be parented to the created instance, while removed ones will be unparented.\
	  The key of each Instance will be their name if none is set (Name = ClassName).
	  - A function which will get wrapped in an effect. The first argument passed is the instance being created.
]=]
export type function properties(instance: type): type
	const tag = instance.tag
	assert(tag == "extern", `Expected type to be extern (Instance), got {tag}!`)

	const original_instance = instance
	const self = types.newtable()
	self:setindexer(
		types.number,
		types.unionof(
			self,
			Instance_,
			-- Gotta inline dynamic_children because for some reason it doesn't work if directly referenced.
			state(proxy(dynamic_children_base)), -- Luau FIXME: don't allow non-Instance proxy states such as `swan.proxy<<{ string }>> {}`.
			instance_callback(instance) -- Luau FIXME: these parameters should not be `unknown`.
		)
	)

	while instance do
		for property_key, p in instance:properties() do
			const property = get_value(p)
			const property_type = property.tag
			if property_type == "function" or property_type == "intersection" then
				continue
			end

			local callback_head: { type }?
			const connector = property_type == "table" and property:readproperty(types.singleton("Connect"))
			if connector then
				callback_head = {
					original_instance,
					select(1, table.unpack((connector:parameters().head :: { type } or {})[2]:parameters().head or {})),
				}
			end

			self:setproperty(
				property_key,
				types.optional(
					if callback_head
						then types.newfunction({ head = callback_head })
						else types.unionof(property, simple_state(property))
				)
			)
		end

		instance = instance:readparent() :: type
	end

	return self
end

--[=[
	@type constructor (properties: properties<T>) -> T
	@within swan
	@tag roblox
	@private

	A function which constructs a Instance of the given class,
	by applying the given properties.
	Returned by [`swan.create`](/api/swan#create) and [`swan.apply`](/api/swan#apply).
]=]
export type constructor<T = Instance> = (properties: properties<T>) -> T

--[=[
	@type class_constructor<class_name> constructor<index<instances, class_name>>
	@within swan
	@tag roblox
	@private

	An alias for `constructor` for a class name string.
]=]
export type class_constructor<class_name> = constructor<index<instances, class_name>>

export type convert_vector = Vector2 | Vector2int16 | Vector3int16
export type convert_vector_name = "Vector2" | "Vector2int16" | "Vector3int16"

export type animatable = number | Color3 | vector | convert_vector | Vector3 | UDim | UDim2 | CFrame
export type animatable_name =
	"number"
	| "Color3"
	| "vector"
	| convert_vector_name
	| "Vector3"
	| "UDim"
	| "UDim2"
	| "CFrame"

--[=[
	@type on_complete (Enum.PlaybackState) -> ()
	@within swan
	@tag roblox
	@private

	Function which gets called whenever a tween state reaches its goal.
]=]
export type on_complete = (Enum.PlaybackState) -> ()

return nil
