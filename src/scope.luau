--!strict

const globals = require("./globals")
const swan_types = require("./swan_types")

return function(fn: () -> ...unknown): swan_types.disconnecter
	const previous_scope = globals.current_scope
	const disconnecters = {}
	globals.current_scope = {
		data = disconnecters,
		previous = previous_scope,
	}

	fn()

	const function scope()
		for _, disconnecter in disconnecters do
			disconnecter()
		end
	end

	globals.current_scope = previous_scope
	if previous_scope then
		table.insert(previous_scope.data, scope)
	end

	return scope
end
