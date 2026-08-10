--!strict

local globals = require("./globals")
local swan_types = require("./swan_types")
local utils = require("./utils")

return function<T>(initial_value: T & { [any]: any }, always_force: boolean?): swan_types.proxy_state<T>
	local self: any = setmetatable({
		always_force = always_force,
		callbacks = {},
	}, globals.STATE_MT)

	self.value = utils.make_proxy(initial_value, self)
	return self
end
