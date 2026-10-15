--!strict
--[[
Luau FIXME:
	- When creating a state, if its variable type is annotated,
	and the type of the value passed to swan.state() doesn't match,
	there should be a type error:
	const health : swan.state<number> = swan.state("i'm not a number") -- doesn't error
]]

const state = require("@self/state")
const swan_types = require("@self/swan_types")

--- @class swan

export type state<T = unknown> = swan_types.state<T>
export type proxy_state<T> = swan_types.proxy_state<T>

const swan = {
	state = state.state,
	computed = state.computed,
	proxy = state.proxy,

	effect = require("@self/effect"),
	scope = require("@self/scope"),
	utils = require("@self/utils"),
}

if not game then
	return swan
end

const roblox = require("@self/roblox")
swan.apply = roblox.apply
swan.create = roblox.create
swan.component = roblox.component
swan.tween = roblox.tween

return swan
