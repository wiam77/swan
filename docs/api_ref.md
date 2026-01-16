# rl API Reference
## Types
### callback
Function which gets called when its [effect](https://pesde.dev/packages/wiam/rl/latest/any/docs/intro#effect) is triggered.
Takes the previous value of the state which triggered the effect, as well as its "index", determined by the order in which it appears within the function.

```luau
type callback<T = unknown> = (old_value : T?, state_i : number?) -> ...unknown
```

### state\<T>
The [state](https://pesde.dev/packages/wiam/rl/latest/any/docs/intro#state) type.

```luau
type state<T = unknown> = {
	value : T,
	always_force : boolean,
	read callbacks : {[callback<T>] : number}
} & ( |	(() -> T)
      |	((new_value : T?, force : boolean?) -> T))
```

## Functions
### state
Returns a new [state](https://pesde.dev/packages/wiam/rl/latest/any/docs/intro#state), with the given initial value, and whether to always [force](https://pesde.dev/packages/wiam/rl/latest/any/docs/intro#forcing).

```luau
function state<T>(value : T?, always_force : boolean?) : state<T>

local health = state(100)
local stamina = state(100, true)
```

### effect
Creates a new [effect](https://pesde.dev/packages/wiam/rl/latest/any/docs/intro#effect), with the given [callback](https://pesde.dev/packages/wiam/rl/latest/any/docs/api_ref#callback), and returns its disconnect function.

```luau
function effect<T>(callback : callback<T>) : () -> ()

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

### derive
Wraps an Effect around the given Callback which sets a newly created State's value
to be the return value of the Callback.
Returns the created State and the Effect's disconnect function.

This is useful for States which depend on the value of another State, since their value will
be updated only when the State they depend on is also updated, and not every time it is read,
as how would happen with a function which's return value depends on a State.

```luau
function derive<T>(callback : () -> T) : (state<T>, () -> ())

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

### batch
Batches any State write operation up until the function is done running.

```luau
function batch(f : () -> ...unknown) : ()

batch(function()
	health(420)
	health(1337, true)
	health(69)
end)

-- "new health: 69"
```

### scope
Wraps the given callbacks into Effects.
Returns a function which disconnects all the created Effects.

```luau
function scope(... : callback) : () -> ()

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
	function()
		print(`your health is : {health()}`)
	end,
	function()
		print(`your stamina is : {stamina()}`)
	end
)

-- ...

vitals_scope()
```

### branch
`if`-like function to be used within effects. Learn more about it in the [tracking section of the intro page](https://pesde.dev/packages/wiam/rl/latest/any/docs/intro#tracking).
Pass a condition to be checked, and after it a function to be run if it's successful.
The last value, if a function, and if not after a condition, will be threated as the "else" branch.

```luau
function branch(... : any) : ()

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
Iterates over the given table and creates an Effect for each key that is
either a function or a State, updating the key's value to be the return value of the
function, or the State's value.
Returns table containing each key's Effect's disconnect function.

```luau
type function indexer(t : type) : type
	return (t:indexer() :: any).index
end

type identifier<T> = keyof<T> | indexer<T>

function mirror<T>(t : T) : (T, {[identifier<T>] : () -> ()})

local name = state("john")
local data, data_disconnects = mirror {
	username = name
}

print(data.username) -- "john"
name("joe")
print(data.username) -- "joe"
data_disconnects.username()

name("doe")
print({data.username}) -- "joe"; didn't update because we disconnected the Effect.
```

### cleanup
Disconnects all [effects](https://pesde.dev/packages/wiam/rl/latest/any/docs/intro#effect).

```luau
function cleanup() : ()

cleanup()
health(77) -- doesn't print because no effect is connected to this state (we just disconnected)
```
