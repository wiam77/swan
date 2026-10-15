--!strict

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
	@type state<T=unknown> setmetatable<{ value: T, always_force: boolean?, dirty: boolean, compute: ((() -> T) | (() -> ()))?, read subscribers: { [callback<T>]: number }, read dependents: { [state]: true } }, { __call: ((self: state<T>) -> T) & ((self: state<T>, new_value: T, force: boolean?) -> T), __unm: (state<T>) -> state<T>, __concat: (state_or_concatenable<T>, state_or_concatenable<T>) -> state<T>, __add: (state_or_number<T>, state_or_number<T>) -> state<T>, __sub: (state_or_number<T>, state_or_number<T>) -> state<T>, __mul: (state_or_number<T>, state_or_number<T>) -> state<T>, __div: (state_or_number<T>, state_or_number<T>) -> state<T>, __idiv: (state_or_number<T>, state_or_number<T>) -> state<T>, __mod: (state_or_number<T>, state_or_number<T>) -> state<T>, __pow: (state_or_number<T>, state_or_number<T>) -> state<T>>
	@within swan

	The [state](/docs/concepts#state) type.
]=]
export type state<T = unknown> = setmetatable<{
	value: T,
	always_force: boolean?,
	dirty: boolean,
	compute: ((() -> T) | (() -> ()))?,

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
type simple_state<T = unknown> = setmetatable<{
	value: T,
	always_force: boolean?,
	dirty: boolean,
	compute: ((() -> T) | (() -> ()))?,

	read subscribers: { [callback<T>]: number },
	read dependents: { [simple_state]: true },
}, {
	__call: (self: simple_state<T>, new_value: T?, force: boolean?) -> T,
}>

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
	@private

	Type function which recursively creates a proxy out of [`proxy_base`](/api/swan#proxy_base<T>).
]=]
export type function proxy(t: type): type
	for k, v in t:properties() do
		const value = v.read :: type
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
	GuiLabel: GuiLabel,
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

-- For some reason this doesn't work with a normal type (simple_state<T> resolves to simple_state<unknown>)
type function implicit_property(callback: type?, property: type): type
	return types.optional(callback or types.unionof(property, simple_state(property)))
end

-- FIXME: Roblox's LSP emits the "code too complex to typecheck"
-- error when trying to evaluate this type

--[=[
	@type properties typefunction(instance: type) -> type
	@within swan
	@tag roblox
	@private

	Type function which takes an Instance type and returns a properties table for said Instance.

	Depending on the key, the properties table has the following behaviour:
	- **Property**: either provide the value directly or a state holding it.\
	If you do the latter, `swan` will implicitly create an effect which updates the property for you.
	- **Event**: give a callback function which will be automatically connected to the Event and have its arguments passed.
	- **"Children"**: either a table, where the values are Instances and the keys are names for said Instances,
	if their name is unset (Name = ClassName); or a state containing said table.
	If it's the latter, `swan` will implicitly create an effect which automatically destroys/parents Instances
	that were removed/added to the table.
	- **number**: a nested Properties table, useful for [components](/api/swan#component).
]=]
export type function properties(instance: type): type
	const tag = instance.tag
	assert(tag == "extern", `Expected type to be extern (Instance), got {tag}!`)

	const self = types.newtable()
	self:setindexer(types.number, self)

	while instance do
		for property_field, p in instance:properties() do
			const property = p.read or p.write :: type
			const property_type = property.tag
			if property_type == "function" then
				continue
			end

			local callback: type?
			const connector = property_type == "table" and property:readproperty(types.singleton("Connect"))
			if connector then
				callback = (connector:parameters().head :: { type })[2]
			end

			self:setproperty(property_field, implicit_property(callback, property))
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
