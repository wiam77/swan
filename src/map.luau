--!strict

const effect = require("./effect")
const state = require("./state")
const swan_types = require("./swan_types")
const utils = require("./utils")

type indexof<T> = swan_types.indexof<T>
type valueof<T> = swan_types.valueof<T>
type proxy_state<T> = swan_types.proxy_state<T>

const swan = {}

-- Luau FIXME: fn's parameters' types should be provided by us, not the user.

--[=[
	@within swan

	Takes a source proxy state and a mapping function.\
	Returns a proxy state whose keys are the result of the
	mapping function over the source's keys.

	This returned state keeps up-to-date with the source through an effect.

	```lua
	const numbers = swan.proxy {
		1337,
		42,
		67,
		420,
		69,
	}

	const sum = swan.map(numbers, function(k: number, v: number)
		return k + v
	end)

	print(sum()[1]) -- 1338
	numbers()[1] = 2
	print(sum()[1]) -- 3
	```
]=]
function swan.map<P, UV, PT, U>(
	source: P | proxy_state<PT>,
	fn: (k: indexof<PT>, v: valueof<PT>) -> () | (k: indexof<PT>, v: valueof<PT>) -> UV | valueof<U>
): proxy_state<{ [indexof<PT>]: UV }>
	source = source :: proxy_state<PT>

	const self = state.proxy(table.clone(utils.get_real(source.value) :: PT))
	const self_proxy: any = self()

	effect(function(old: any)
		const p: any = utils.get_real((source :: proxy_state<PT>)())
		if not old then
			for k, v in p do
				self_proxy[k] = (fn :: any)(k, v)
			end
			return
		end

		for k, v in p do
			if old[k] ~= v then
				self_proxy[k] = (fn :: any)(k, v)
			end
		end
	end)

	return self
end

return swan.map
