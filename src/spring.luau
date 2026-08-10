--!strict

local swan_types = require("./swan_types")

return function<T>(target: swan_types.state<T & swan_types.animatable>) end
