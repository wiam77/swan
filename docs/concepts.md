# rl concepts
## Effect
An Effect is the binding of a function to an event triggered when States read (with tracking) within it are written.

## Tracking
Tracking, or registering, is the process done internally by `rl` for assigning States to Effects, so that the latters' functions can be ran when the formers' values are written.\
This works by calling an Effect's function once when created to check which States are read (with tracking) within it.\
But this introduces a problem: when branching within the function, only the branch which satisfies the condition is going to be checked.\
That could be solved by reading all the States that are going to be used before any branch, but it misses the point of the library.\
Instead, `rl` solves this by providing the `b` (branch) function, which works like standard branching, but runs all branches when it's doing the tracking process, so that all States are correctly assigned.

## State
A State is a container for a value.\
Internally, it is an userdata that has a metatable with the `__index` and `__newindex` metamethods, which permit reading and writing the value with special mechanisms.\
Call it with no arguments for reading with tracking.\
Call with arguments for writing, where the first argument is the new value, and the second one is whether to force for this specific call.\
Access the `.value` field for reading without tracking. Note that this is read-only, and attempting to modify it will cause an error.

## Forcing
Forcing is when you write a new value to a State, and always trigger its Effects, even when the new value is the same as the old one.\
States, when created, can be opted in to always force their values; you can overwrite this in individual write operations.
