--!strict

local globals = require("./globals")
local swan_types = require("./swan_types")

return function(f: () -> ...unknown): swan_types.disconnecter
	globals.current_scope = {
		disconnecters = {},
		previous = globals.current_scope,
	}

	f()

	local disconnecters = (globals.current_scope :: swan_types.scope_node).disconnecters
	local function scope()
		for _, disconnecter in disconnecters do
			disconnecter()
		end
	end

	globals.current_scope = (globals.current_scope :: swan_types.scope_node).previous
	if globals.current_scope then
		table.insert(globals.current_scope.disconnecters, scope)
	end

	return scope
end
