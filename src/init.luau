--!strict

const state = require("@self/state")
const swan_types = require("@self/swan_types")

--- @class swan

export type state<T = unknown> = swan_types.state<T>
export type proxy<T> = swan_types.proxy<T>
export type proxy_state<T> = swan_types.proxy_state<T>

const swan = {
	state = state.state,
	computed = state.computed,
	proxy = state.proxy,

	effect = require("@self/effect"),
	map = require("@self/map"),
	scope = require("@self/scope"),
	utils = require("@self/utils"),
}

if not game then
	return swan
end

const roblox = require("@self/roblox")
swan.apply = roblox.apply
swan.create = roblox.create
swan.tween = roblox.tween

return swan
