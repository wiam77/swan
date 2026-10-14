--!strict

const easing = require("./easing")
const effect = require("./effect")
const globals = require("./globals")
const state = require("./state")
const swan_types = require("./swan_types")

type state<T> = swan_types.state<T>
type easing_dir = swan_types.easing_dir

const swan = {}

--[=[
	@within swan

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

	@param target state<T & animatable> -- The state this tween state always tries to reach.
	@param duration number -- How long each tween should take.
	@param easing_fn default_easing_fn | easing_fn -- Either the name of a default easing function, or a custom one.
]=]
function swan.tween<T>(
	target: state<T & swan_types.animatable>,
	duration: number,
	easing_fn: swan_types.default_easing_fn | swan_types.easing_fn,
	options: {
		easing_dir: easing_dir?,
		delay: number?,
		bounces: number?,
		on_complete: () -> ()?,
	}?
): state<T>
	const wait = globals.wait
	assert(wait, "The wait function (swan.wait) was not provided.")

	globals.wait = globals.wait :: (number?) -> number
	easing_fn = (easing.defaults[easing_fn :: swan_types.default_easing_fn] or easing_fn :: swan_types.easing_fn) :: any

	const target_value = target.value
	const data_type = typeof(target_value)
	const tweened = state.state(target_value)

	const opts = options or {} :: any
	const easing_dir: swan_types.easing_dir? = opts.easing_dir
	const easing_power: number = (easing.powers :: any)[easing_fn] -- should be `number?`

	local first = true
	effect(function()
		const goal = target()
		if first then
			first = false
			return
		end

		if opts.delay then
			wait(opts.delay)
		end

		const start_value = tweened.value
		for current_bounce = 0, opts.bounces or 0 do
			const start_time = os.clock()
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

return swan.tween
