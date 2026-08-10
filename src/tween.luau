--!strict

local easing = require("./easing")
local effect = require("./effect")
local globals = require("./globals")
local state = require("./state")
local swan_types = require("./swan_types")

return function<T>(
	target: swan_types.state<T & swan_types.animatable>,
	duration: number,
	easing_fn: swan_types.default_easing_fn | swan_types.easing_fn,
	options: {
		easing_dir: swan_types.easing_dir?,
		delay: number?,
		bounces: number?,
		on_complete: () -> ()?,
	}?
): swan_types.state<T>
	local wait = globals.wait
	assert(wait, "The wait function (swan.wait) was not provided.")

	globals.wait = globals.wait :: (number?) -> number
	easing_fn = (easing.defaults[easing_fn :: swan_types.default_easing_fn] or easing_fn :: swan_types.easing_fn) :: any

	local target_value = target.value
	local data_type = typeof(target_value)
	local tweened = state.state(target_value)

	local opts = options or {} :: any
	local easing_dir: swan_types.easing_dir? = opts.easing_dir
	local easing_power: number = (easing.powers :: any)[easing_fn] -- should be `number?`

	local first = true
	effect(function()
		local goal = target()
		if first then
			first = false
			return
		end

		if opts.delay then
			wait(opts.delay)
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

				tweened(easing.apply(start_value, goal, t, easing_fn, data_type))
				wait()
			end
		end

		if opts.on_complete :: any then
			opts.on_complete()
		end
	end)

	return tweened
end
