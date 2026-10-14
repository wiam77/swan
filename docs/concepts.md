---
sidebar_position: 2
---

# Concepts
## States
A state is the unit of reactivity wrapping a value. Internally it's an object with the fields:
- **.value:** The state's current value. Read and write this if you don't intend to track this state or trigger effects.
- **.always_force:** Whether every write operation for this state is automatically forced.
- **.dirty:** Boolean which indicates whether or not a computed that depends on this state should re-compute.
- **.compute:** Function whose return value is bound to a computed state.
- **.subscribers:** Set of functions bound to this state (effects).
- **.dependents:** Set of states depending on this one.

and has a metatable which implements:
- **__call()**: For reading, with tracking.
- **__call(value, force)**: For writing, triggering effects, optionally forcing.
- as well as **__concat()** and **every mathematical metamethod**, for [implicit computeds](/docs/concepts#implicit-computeds).

## Implicit computeds
Computeds are a way of making a state's value depend on another's.
`swan` lets you do this by using either [`swan.computed()`](/api/swan#computed), for complex operations, or by directly using Luau operators on them.

Using operators such as `..`, `+`, `/` etc. on a string or number state will automatically
create a new computed state whose value will be the result of said operation on the initial state.

Here is a simple example:
```lua
local ammo = swan.state(20)
local ammo_ui = "Ammo: " .. ammo

print(ammo_ui()) -- "Ammo: 20"
ammo(10)
print(ammo_ui()) -- "Ammo: 10"

local xp = swan.state(300)
local bars = xp / 10 :: any

print(bars()) -- 30
xp(500)
print(bars()) -- 50
```

## Table states
If you store a table within a [state](/docs/concepts#state), `swan` will detect changes only when the table itself (the identity) changes.\
If you instead would like to react to the internal changes of a table,
including nested ones, you can use [`swan.proxy()`](/api/swan#proxy).

:::info
Given the way `swan` does this, which involves creating a proxy table with some metamethods,
functions like pretty printers might not show the contents of the table, but they are there!\
To circumvent this behaviour, you can use [`utils.get_real()`](/api/utils#get_real).
:::

## Effects
An effect is a binding which will automatically trigger its [function](/api/swan#callback) whenever one of its tracked states get updated (or forced).

## Forcing
By default, effects only trigger when one of their tracked states change values, but this can be changed by forcing.

## Tracking
Tracking is the mechanism used internally by `swan` to determine which states get bound to an effect.

## Branching
Given the way tracking works, which involves triggering effects once when they are made,
states read within alternate branches of an if statement don't get tracked.\
To solve this, you can read the states at the top-level of the effect's callback function.

## Roblox
Despite being a runtime-agnostic library, `swan` provides [some functionality](/api/swan#roblox) to facilitate development on Roblox.
