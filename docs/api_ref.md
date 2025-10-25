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
type callback<T> = (old_value : T, state_i : number?) -> any
```

## Functions
### state
Creates a new [state](https://pesde.dev/packages/wiam/rl/latest/any/docs/concepts#state), with the given initial value, and whether to always [force](https://pesde.dev/packages/wiam/rl/latest/any/docs/concepts#forcing), and returns it.

```luau
function state<T>(value : T?, force : boolean?) : state<T>

-- Example
local health = state(100)
local stamina = state(100, true)
```

### derive
Wraps an Effect around the given callback which sets a newly created State's value
to be the return value of the callback.
Returns the created State, the Effect's disconnect function and a flag which can be ignored.

This is useful for States which depend on the value of another State, since their value will
be updated only when the State they depend on is also updated, and not every time it is read,
as how would happen with a function which's return value depends on a State.

```luau
function derive<T, U>(callback : () -> U) : (state<U>, () -> (), true)

-- Example
-- without derive() (normal function)
local half_health = function()
	print("some computation")
	return health() / 2
end

print(half_health()) -- "some computation" 50
print(half_health()) -- "some computation" 50
health(50)
print(half_health()) -- "some computation" 25
print(half_health()) -- "some computation" 25

-- with derive()
local derive_half_health = derive(half_health) -- "some computation"

print(derive_half_health()) -- 25
print(derive_half_health()) -- 25
health(20) -- "some computation"
print(derive_half_health()) -- 10
print(derive_half_health()) -- 10
```

### effect
Creates a new [effect](https://pesde.dev/packages/wiam/rl/latest/any/docs/concepts#effect), with the given [callback](https://pesde.dev/packages/wiam/rl/latest/any/docs/api_ref#callback) function, and returns its disconnect function.

```luau
function effect<T>(callback : callback<T>) : () -> ()

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

### batch
Batches any State write operation up until the function is done running.

```luau
function batch(f : () -> any) : ()

-- Example
batch(function()
	health(420)
	health(1337, true)
	health(69)
end)

-- "new health: 69"

```

### scope
Returns a function which calls the given functions.
Any non-function or function which precedes a "true" value by 2 indices is going to be skipped (the second happens because of derives).
This is intended to be used for disconnecting Effects in bulk.

```luau
function scope<T>(... : T) : () -> ()

-- Example
-- without scope
local disconnect_health = effect(function()
	print(`your health is : {health()}`)
end)

local disconnect_stamina = effect(function()
	print(`your stamina is : {stamina()}`)
end)

-- ...

disconnect_health()
disconnect_stamina()

-- with scope
local vitals_scope = scope(
	effect(function()
		print(`your health is : {health()}`)
	end),
	effect(function()
		print(`your stamina is : {stamina()}`)
	end)
)

-- ...

vitals_scope()
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
function mirror<K, V>(t : {[K] : V}) : ({[K] : V}, () -> ())

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
