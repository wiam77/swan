--!strict

const globals = require("./globals")
const swan_types = require("./swan_types")

type disconnecter = swan_types.disconnecter

const swan = {}

--[=[
	@within swan

	Collects the disconnecters of all the effects that were ran within the given function,
	and returns an "omni-disconnecter" which calls all of them.
	Works with nested effects and scopes too.

	Arguments after the function will be passed to it.

	```lua
	const root = scope(function(message)
		effect(function()
			effect(function()
				return print, "1.1"
			end)
			return print, "1"
		end)

		scope(function()
			effect(function()
				return print, "_1"
			end)
		end)

		effect(function()
			return print, "2"
		end)

		print(message)
	end, "Hello, World!")

	root() -- "Hello, World!" 1.1 1 _1 2 -- effects' disconnection is the last thing to happen, even if they appear before other code within the function
	```
]=]
function swan.scope<T...>(fn: (T...) -> ...unknown, ...: T...): disconnecter
	const previous_scope = globals.current_scope
	const disconnecters = {}
	globals.current_scope = {
		data = disconnecters,
		previous = previous_scope,
	}

	fn(...)

	const function self()
		for _, disconnecter in disconnecters do
			disconnecter()
		end
	end

	globals.current_scope = previous_scope
	if previous_scope then
		table.insert(previous_scope.data, self)
	end

	return self
end

return swan.scope
