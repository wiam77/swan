--!strict

const globals = require("./globals")
const swan_types = require("./swan_types")

const effects = globals.effects

const function noop(): () end
return function<T, U...>(callback: swan_types.callback<T, U...>): swan_types.disconnecter
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
