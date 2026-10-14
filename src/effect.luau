--!strict

const globals = require("./globals")
const swan_types = require("./swan_types")

type callback<T, U...> = swan_types.callback<T, U...>
type disconnecter = swan_types.disconnecter

const effects = globals.effects
const function noop(): () end

const swan = {}

--[=[
	@within swan

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
function swan.effect<T, U...>(callback: callback<T, U...>): disconnecter
	const previous_tracker = globals.current_tracker
	effects[callback] = 0
	globals.current_tracker = {
		data = callback,
		previous = previous_tracker,
	}

	const cleanup_data = { callback() }
	globals.current_tracker = previous_tracker

	local function disconnecter()
		effects[callback] = nil
		disconnecter = noop
	end

	if not cleanup_data then
		return disconnecter
	end

	const cleanup: any = cleanup_data[1]
	if not cleanup :: any then
		return disconnecter
	end

	local function maid()
		disconnecter()
		cleanup(select(2, unpack(cleanup_data)))
		maid = noop
	end

	if globals.current_scope then
		table.insert(globals.current_scope.data, maid)
	end

	return maid
end

return swan.effect
