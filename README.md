# rl
`rl` is a simple reactive library for Luau, inspired by [Vide](https://centau.github.io/vide)'s sources and effects system.

# Installation
## Pesde
```console
# pesde add wiam/rl && pesde install
```

## Wally
Add the following to your `wally.toml`, in the `[dependencies]` section:
```toml
rl = "wiam77/rl@<version>"
```

Then run:
```console
# wally install
```

## npm
```console
# npm install @rbxts/rl
```

# Documentation
You can read `rl`'s documentation [here](https://pesde.dev/packages/wiam/rl/latest/any/docs).

# Demo
```luau
--!strict

local rl = require("path/to/rl")

local name = rl.state("john", true)
local login_year = rl.state(2020)

local login_disconnect = rl.effect(function(last_login : number?)
	print(`{name.value}, it's been {login_year() - (last_login or 0)} years!`)
end)

login_year(2025) -- "john, it's been 5 years!"
login_year(2025) -- doesn't print because value didn't change
login_year(2025, true) -- "john, it's been 0 years!" - this prints since it's forced

name("doe") -- doesn't print because we are reading with name.value, and not name()

rl.effect(function(old_name : string?)
	print(`hey {old_name}, your name has been changed to '{name()}'`)
end)

name("jane") -- "hey doe, your name has been changed to jane"
name("jane") -- "hey jane, your name has been changed to jane" - this one is forced by default

login_disconnect()
login_year(2026) -- doesn't print because the effect was disconnected

rl.cleanup() -- disconnect all effects
```