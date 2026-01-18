# swan
`swan` is a simple state management library for Luau.

# Installation
## Pesde
```console
# pesde add wiam/swan && pesde install
```

## Wally
Add the following to your `wally.toml`, in the `[dependencies]` section:
```toml
swan = "wiam77/swan@<version>"
```

Then run:
```console
# wally install
```

## npm
```console
# npm install @rbxts/swan
```

# Documentation
You can read `swan`'s documentation [here](https://pesde.dev/packages/wiam/swan/latest/any/docs).

# Demo
```luau
--!strict

local swan = require("path/to/swan")

local name = swan.state("john", true)
local login_year = swan.state(2020)

local login_disconnect = swan.effect(function(last_login : number?)
	print(`{name.value}, it's been {login_year() - (last_login or 0)} years!`)
end)

login_year(2025) -- "john, it's been 5 years!"
login_year(2025) -- doesn't print because value didn't change
login_year(2025, true) -- "john, it's been 0 years!" - this prints since it's forced

name("doe") -- doesn't print because we are reading with name.value, and not name()

swan.effect(function(old_name : string?)
	print(`hey {old_name}, your name has been changed to '{name()}'`)
end)

name("jane") -- "hey doe, your name has been changed to jane"
name("jane") -- "hey jane, your name has been changed to jane" - this one is forced by default

login_disconnect()
login_year(2026) -- doesn't print because the effect was disconnected

swan.cleanup() -- disconnect all effects
```