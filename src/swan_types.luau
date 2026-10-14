--!strict

export type disconnecter = () -> ()

export type cleanup<T...> = (T...) -> ...unknown

export type callback<T = unknown, U... = ()> =
	((old_value: T?, state_i: number?) -> (cleanup<U...>, U...))
	| ((old_value: T?, state_i: number?) -> ())
	| ((old_value: T?, state_i: number?) -> false?)

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

export type function proxy(t: type): type
	for k, v in t:properties() do
		local value = v.read :: type
		if (value):is("table") then
			t:setproperty(k, proxy(value))
		end
	end

	return proxy_base(t)
end

export type proxy_state<T> = state<proxy<T>>

export type node<T = unknown> = {
	data: T,
	previous: node<T>?,
}

export type scope_node = node<{ disconnecter }>

export type animatable =
	number
	| Color3
	| vector
	| Vector2
	| Vector2int16
	| Vector3
	| Vector3int16
	| UDim
	| UDim2
	| CFrame

export type easing_fn = (a: number, b: number, t: number) -> number

export type default_easing_fn =
	"linear"
	| "quadratic"
	| "sine"
	| "exponential"
	| "circular"
	| "back"
	| "elastic"
	| "bounce"

export type easing_dir = "in" | "out" | "in-out"

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

export type class_name = keyof<instances>

export type function properties(instance: type): type
	local tag = instance.tag
	assert(tag == "extern", `Expected type to be extern (Instance), got {tag}!`)

	local self = types.newtable()
	self:setindexer(types.number, self)

	while instance do
		for k, v in instance:properties() do
			local vr = v.read :: type
			local vt = vr.tag
			local t: type?
			if vt == "function" then -- Method
				continue
			elseif vt == "table" then -- Event
				t = ((vr:readproperty(types.singleton("Connect")) :: type):parameters().head :: { type })[2]
			end

			self:setproperty(k, types.optional(t or (types.unionof(vr, simple_state(vr)))))
		end

		instance = instance:readparent() :: type
	end

	return self
end

export type constructor<T = Instance> = (properties: properties<T>) -> T
export type class_constructor<class_name> = constructor<index<instances, class_name>>

return nil
