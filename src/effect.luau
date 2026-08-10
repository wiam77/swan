--!strict

local globals = require("./globals")
local swan_types = require("./swan_types")

local function noop(): () end

return function<T, U...>(callback: swan_types.callback<T, U...>): swan_types.disconnecter
	globals.current_callback = {
		value = callback,
		previous = globals.current_callback,
	}

	globals.EFFECTS[callback] = 0
	local cleanup_data = { callback() }
	globals.current_callback = (globals.current_callback :: swan_types.callback_node).previous

	local function disconnecter()
		globals.EFFECTS[callback] = nil
		disconnecter = noop
	end

	if not cleanup_data then
		return disconnecter
	end

	local cleanup: any = cleanup_data[1]
	if not cleanup :: any then
		return disconnecter
	end

	local function maid()
		disconnecter()
		cleanup(select(2, unpack(cleanup_data)))
		maid = noop
	end

	if globals.current_scope then
		table.insert(globals.current_scope.disconnecters, maid)
	end

	return maid
end
