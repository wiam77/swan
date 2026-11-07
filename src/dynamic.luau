--!strict

const effect = require("./effect")
const state = require("./state")
const swan_types = require("./swan_types")
const utils = require("./utils")

type indexof<T> = swan_types.indexof<T>
type valueof<T> = swan_types.valueof<T>

type state<T> = swan_types.state<T>
type proxy_state<T> = swan_types.proxy_state<T>

const dynamic = {}

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
function dynamic.map<P, UV, PT, U>(
	source: P | proxy_state<PT>,
	fn: (k: indexof<PT>, v: valueof<PT>) -> () | (k: indexof<PT>, v: valueof<PT>) -> UV | valueof<U>
): proxy_state<{ [indexof<PT>]: UV }>
	source = source :: proxy_state<PT>

	const self = state.proxy(table.clone(utils.get_real(source.value) :: PT))
	const self_proxy: any = self()

	effect(function(old: any)
		const source_real: any = utils.get_real((source :: proxy_state<PT>)())
		if not old then
			for k, v in source_real do
				self_proxy[k] = (fn :: any)(k, v)
			end
			return
		end

		for k, v in source_real do
			if old[k] ~= v then
				self_proxy[k] = (fn :: any)(k, v)
			end
		end
	end)

	return self
end

--[=[
	@within swan

	Maps a source proxy state to a table of stable objects.
	The constructor runs once per key in the source.

	The constructor receives a state wrapping the value of the pair,
	which is updated automatically when it changes.
]=]
function dynamic.keys<K, V, M>(
	source: proxy_state<{ [K]: V }>,
	constructor: (value_state: state<V>, key: K) -> (M, ...() -> ...unknown) -- using a variadic because (() -> ...unknown)? doesn't allow "nothingness" (requires an explicit value)
): proxy_state<{ [K]: M }>
	const cache: { any } = {} -- { [K]: { [1]: state<V>, [2]: M, [3]: cleanup? } }
	const result = state.proxy({} :: { [K]: M })
	const result_proxy: swan_types.proxy<{ any }> = result()

	effect(function()
		const source_real = utils.get_real(source()) :: { [K]: V }
		for k, v in source_real do
			const cached = cache[k]
			if cached then
				cached[1](v)
				continue
			end

			const value_state = state.state(v)
			const mapped, cleanup = constructor(value_state, k)
			result_proxy[k] = mapped
			cache[k] = {
				value_state,
				mapped,
				cleanup,
			}
		end

		for k, cached in cache do
			if source_real[k] then
				continue
			end

			const cleanup = cached[3]
			if cleanup then
				cleanup()
			end

			cache[k] = nil
			result_proxy[k] = nil
		end
	end)

	return result
end

--[=[
	@within swan

	Maps a source proxy state to a table of stable objects.
	The constructor runs once per key in the source.

	The constructor receives a state wrapping the key of the pair,
	which is updated automatically when it changes.

	Repeated values may cause undefined behaviour.
]=]
function dynamic.values<K, V, M>(
	source: proxy_state<{ [K]: V }>,
	constructor: (key_state: state<K>, value: V) -> (M, ...() -> ...unknown) -- using a variadic because (() -> ...unknown)? doesn't allow "nothingness" (requires an explicit value)
): proxy_state<{ [K]: M }>
	const cache: { any } = {} -- { [V]: { [1]: state<K>, [2]: M, [3]: cleanup? } }
	const result = state.proxy({} :: { [K]: M })
	const result_proxy: swan_types.proxy<{ any }> = result()

	effect(function()
		const source_real = utils.get_real(source()) :: { [K]: V }
		for k, v in source_real do
			const cached = cache[v]
			if cached then
				cached[1](k)
				continue
			end

			const key_state = state.state(k)
			const mapped, cleanup = constructor(key_state, v)
			result_proxy[k] = mapped
			cache[v] = {
				key_state,
				mapped,
				cleanup,
			}
		end

		for v, cached in cache do
			const k = cached[1].value
			if source_real[k] then
				continue
			end

			const cleanup = cached[3]
			if cleanup then
				cleanup()
			end

			cache[v] = nil
			result_proxy[k] = nil
		end
	end)

	return result
end

return dynamic
