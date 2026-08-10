--!strict

export type disconnecter = () -> ()

export type cleanup<T...> = (T...) -> ...unknown

export type callback<T = unknown, U... = ()> =
	((old_value: T?, state_i: number?) -> (cleanup<U...>, U...))
	| ((old_value: T?, state_i: number?) -> ())
	| ((old_value: T?, state_i: number?) -> nil) -- "nil" should be "false?"

export type state<T = unknown> = {
	value: T,
	always_force: boolean,
	read callbacks: { [callback<T>]: number },
} & (() -> T) & ((new_value: T, force: boolean?) -> T)

export type proxy_base<T> = setmetatable<T, {
	_is_swan_proxy: true,
	_swan_real: T,
	__index: T,
	__newindex: ({}, any, any) -> (),
}>

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

export type callback_node = {
	value: callback,
	previous: callback_node?,
}

export type scope_node = {
	disconnecters: { disconnecter },
	previous: scope_node?,
}

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

export type function properties(instance: type): type
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

			self:setproperty(k, types.optional(t or (types.unionof(vr, state(vr)))))
		end

		instance = instance:readparent() :: type
	end

	return self
end

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

return nil
