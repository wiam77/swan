--!strict

local swan_types = require("./swan_types")

return {
	wait = nil :: ((number?) -> number)?,

	current_callback = nil :: swan_types.callback_node?,
	current_scope = nil :: swan_types.scope_node?,

	batching = false :: boolean,
	BATCHED = {} :: { [swan_types.state]: { any } }, -- {[state] : {[1] : {[callback] = true}, [2] : old_value, [3] : state_i}}

	STATE_MT = {} :: { [string]: any },

	EFFECTS = {} :: { [swan_types.callback]: number },

	--[=[
		@prop SWAN_PROXY_ID string
		@within swan
		@private

		Identifier used by `swan` to detect whether a table is a proxy or not.
	]=]
	SWAN_PROXY_ID = "_SWAN_PROXY_ID",

	--[=[
		@prop SWAN_REAL_ID string
		@within swan
		@private

		Identifier used by `swan` to access the "real" value of a proxy table.
	]=]
	SWAN_REAL_ID = "_SWAN_REAL_ID",

	BINARY_OPS = {
		concat = function(a, b)
			return a .. b
		end,
		add = function(a, b)
			return a + b
		end,
		sub = function(a, b)
			return a - b
		end,
		mul = function(a, b)
			return a * b
		end,
		div = function(a, b)
			return a / b
		end,
		idiv = function(a, b)
			return a // b
		end,
		mod = function(a, b)
			return a % b
		end,
		pow = function(a, b)
			return a ^ b
		end,
	} :: { [string]: (any, any) -> unknown },
}
