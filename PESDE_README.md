# r
`r` is a simple reactive library for Luau, inspired by [Vide](https://centau.github.io/vide)'s sources and effects system.

# API Reference
You can read `r`'s API reference [here](https://pesde.dev/packages/wiam/rl/latest/any/docs/api_ref).

# Demo
```luau
--!strict

local r = require("./src")
local v = r.v
local e = r.e

local name = v("john", true)
local login_year = v(2020)

local login_d = e(function(last_login : number)
	print(`{name.value}, it's been {login_year() - (last_login or 0)} years!`)
end)

login_year(2025) -- "wiam, it's been 5 years!"
login_year(2025) -- doesn't print because value didn't change
login_year(2025, true) -- "wiam, it's been 0 years!" - this prints since it's forced

name("doe") -- doesn't print because we are reading with name.value, and not name()

e(function(old_name : string)
	print(`hey {old_name}, your name has been changed to '{name()}'`)
end)

name("jane") -- "hey doe, your name has been changed to jane"
name("jane") -- "hey jane, your name has been changed to jane" - this one is forced by default

login_d()
login_year(2026) -- doesn't print because the effect was disconnected

r.d() -- disconnect all effects
```
