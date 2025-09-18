# rl API Reference
## Types
### state\<T>
The [state](https://pesde.dev/packages/wiam/rl/latest/any/docs/concepts#state) type.

```luau
type state<T> = (() -> T) & ((value : T, force : boolean?) -> T) & {
	value : T
}
```

### callback
Function which gets called when its [effect](https://pesde.dev/packages/wiam/rl/latest/any/docs/concepts#effect) is triggered.
Takes the previous value of the state which triggered the effect, as well as its "index", determined by the order in which it appears within the function.

```luau
type callback = (old_value : any, state_i : number?) -> any
```

## Functions
### state
Creates a new [state](https://pesde.dev/packages/wiam/rl/latest/any/docs/concepts#state), with the given initial value, and whether to always [force](https://pesde.dev/packages/wiam/rl/latest/any/docs/concepts#forcing), and returns it.

```luau
function state<T>(initial_value : T, force : boolean?) : state<T>

-- Example
local health = s(100)
local stamina = s(100, true)
```

### effect
Creates a new [effect](https://pesde.dev/packages/wiam/rl/latest/any/docs/concepts#effect), with the given [callback](https://pesde.dev/packages/wiam/rl/latest/any/docs/api_ref#callback) function, and returns its disconnect function.

```luau
function effect(callback : callback) : () -> ()

-- Example
effect(function()
	print(`new health: {health()}`)
end)

health(10) -- "new health: 10"
health(10) -- doesn't print because the new value is the same as the current one
health(10, true) -- "new health: 10"; this prints because we forced it

local disconnect = effect(function()
	print(`new stamina: {stamina()}`)
end)

stamina(90) -- "new stamina: 90"
stamina(90) -- "new stamina: 90"; this prints because `stamina` is always forced.
disconnect()

stamina(40) -- doesn't print because we disconnected the effect.
```

### branch
Alternative `if`-like function to be used within effects. Learn more about it in the [tracking section of the Concepts page](https://pesde.dev/packages/wiam/rl/latest/any/docs/concepts#tracking).
Pass a condition to be checked, and after it a function to be run if it's successful.
The last value, if a function, and if not after a condition, will be threated as the "else" branch.

```luau
function branch(...) : ()

-- Example
-- A single effect for the same functionality as the examples above, thanks to the use of state_i and the branching function.
effect(function(_, state_i)
	branch(
		state_i == 1, function()
			print(`new health: {health()}`)
		end,
		state_i == 2, function()
			print(`new stamina: {stamina()}`)
		end
	)
end)
```

### mirror
Takes a table and for every function or state, creates an effect which automatically updates the element to be either the function's return value, or, if a state, to its value.
The created effects' disconnect functions are put at t\["disconnect"..k], where k is either the key, if it's a string, or the index at which it was iterated over.
Returns the given table, as well as a function which disconnects all created effects.

```luau
function rl.mirror<K, V>(t : {[K] : V}) : ({[K] : V}, () -> ())

-- Example
local name = state("john")
local data = mirror {
	username = name,
}

print(data.username) -- "john"
name("joe")
print(data.username) -- "joe"
data.disconnect_username()

name("doe")
print({data.username}) -- "joe"; didn't update because we disconnected the effect
```

### cleanup
Disconnects all [effects](https://pesde.dev/packages/wiam/rl/latest/any/docs/concepts#effect).

```luau
function cleanup() : ()

-- Example
cleanup()
health(77) -- doesn't print because no effect is connected to this state (we just disconnected)
```
