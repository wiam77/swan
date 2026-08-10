--!strict

local swan_types = require("./swan_types")

local easing = {}

easing.powers = {
	linear = 1,
	quadratic = 2,
	sine = 1,
	exponential = 2,
	circular = 2,
	back = 3,
	elastic = 3,
	bounce = 2,
}

local function vector_decomposer(v)
	return { v.X, v.Y, v.Z }
end

local component_handlers: any = { -- {[1] = decomposeer, [2] = recomposer}
	number = {
		function(v)
			return { v }
		end,
		function(c)
			return c[1]
		end,
	},
	Color3 = {
		function(v)
			return { v.R, v.G, v.B }
		end,
		function(c)
			return Color3.new(c.R, c.G, c.B)
		end,
	},
	vector = {
		vector_decomposer,
		function(c)
			return vector.create(c[1], c[2], c[3])
		end,
	},
	Vector2 = {
		vector_decomposer,
		function(c)
			return Vector2.new(c[1], c[2])
		end,
	},
	Vector2int16 = {
		vector_decomposer,
		function(c)
			return Vector2int16.new(c[1], c[2])
		end,
	},
	Vector3 = {
		vector_decomposer,
		function(c)
			return Vector3.new(c[1], c[2], c[3])
		end,
	},
	Vector3int16 = {
		vector_decomposer,
		function(c)
			return Vector3int16.new(c[1], c[2])
		end,
	},
	UDim = {
		function(v)
			return { v.Scale, v.Offset }
		end,
		function(c)
			return UDim.new(c[1], c[2])
		end,
	},
	UDim2 = {
		function(v)
			return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }
		end,
		function(c)
			return UDim2.new(c[1], c[2], c[3], c[4])
		end,
	},
	CFrame = {
		function(v)
			return { v:GetComponents() }
		end,
		function(c)
			return CFrame.fromMatrix(
				Vector3.new(c[1], c[2], c[3]),
				Vector3.new(c[4], c[5], c[6]),
				Vector3.new(c[7], c[8], c[9]),
				Vector3.new(c[10], c[11], c[12])
			)
		end,
	},
}

easing.defaults = {
	linear = function(a: number, b: number, t: number): number
		return a * (1 - t) + b * t
	end,
	quadratic = function(a: number, b: number, t: number): number
		return a + (b - a) * t * t
	end,
	sine = function(a: number, b: number, t: number): number
		return a + (b - a) * (1 - math.cos(t * math.pi / 2))
	end,
	exponential = function(a: number, b: number, t: number): number
		return a + (b - a) * if t == 0 then 0 else if t == 1 then 1 else (2 ^ (10 * (t - 1)))
	end,
	circular = function(a: number, b: number, t: number): number
		return a + (b - a) * (1 - math.sqrt(1 - math.min(1, math.max(0, t * t))))
	end,
	back = function(a: number, b: number, t: number): number
		return a + (b - a) * (t * t * ((1.70158 + 1) * t - 1.70158))
	end,
	elastic = function(a: number, b: number, t: number): number
		if t == 0 then
			return a
		end
		if t == 1 then
			return b
		end

		local p = 0.3
		local eased = 2 ^ (-10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1

		return a + (b - a) * eased
	end,
	bounce = function(a: number, b: number, t: number): number
		return a
			+ (b - a)
				* if t < 1 / 2.75
					then 7.5625 * t * t
					else if t < 2 / 2.75
						then 7.5625 * (t - 1.5 / 2.75) ^ 2 + 0.75
						else if t < 2.5 / 2.75
							then 7.5625 * (t - 2.25 / 2.75) ^ 2 + 0.9375
							else 7.5625 * (t - 2.625 / 2.75) ^ 2 + 0.984375
	end,
} :: { [swan_types.default_easing_fn]: swan_types.easing_fn }

function easing.apply<T>(start_value: T, goal_value: T, t: number, easing_fn: swan_types.easing_fn, data_type: string): any
	local handlers = component_handlers[data_type]
	local decomposer = handlers[1]
	local start_components = decomposer(start_value)
	local goal_components = decomposer(goal_value)

	for k, v in start_components do
		goal_components[k] = easing_fn(v, goal_components[k], t)
	end

	return handlers[2](goal_components)
end

return easing
