export type state<T> = {
  (new_value: T, force?: boolean): T
  (): T
  readonly value: T
}

export type callback<T> = (old_value: T, state_i?: number) => any

/**
 * Disconnects all Effects.
 */
export function cleanup(): void

/**
 * Creates a State.
 * 
 * @param value T -- Initial value.
 * @param force? boolean -- Whether Effects connected to this State will trigger, despite the fact that the value didn't change.
 * @returns state<T> -- State. Call with no arguments for reading with tracking, call with arguments for writing (2nd argument is for forcing), read .value field for reading without tracking.
 */
export function state<T>(value: T, force?: boolean): state<T>

/**
 * Batches any State write operation up until the function is done running.
 * @param f () => any -- The function.
 */
export function batch(f: () => any): void

/**
 * Creates an Effect, a binding of the given function to the event of States read (by calling) within it being updated.
 * 
 * @param callback callback<T> -- The function to be bound.
 * @returns () => void -- Function which disconnects the Effect from the States.
 */
export function effect<T>(callback: callback<T>): () => void

/**
 * Returns a function which calls the given functions.
 * Any non-function or function which precedes a "true" value by 2 indices is going to be skipped (the second happens because of derives).
 * This is intended to be used for disconnecting Effects in bulk.
 * @param ... () => () -- The functions.
 * @returns () => () -- The function caller.
 */
export function scope<T>(...t : T[]): () => void

/**
 * Wraps an Effect around the given callback which sets a newly created State's value
 * to be the return value of the callback.
 * Returns the created State, the Effect's disconnect function and a flag which can be ignored.
 * This is useful for States which depend on the value of another State, since their value will
 * be updated only when the State they depend on is also updated, and not every time it is read,
 * as how would happen with a function which's return value depends on a State.
 * @param callback () => U -- the callback
 * @returns state<U> -- the State that was created
 * @returns () => void -- the created Effect's disconnect function
 * @returns true -- a flag used internally by rl.scope(); can be ignored.
 */
export function derive<T, U>(callback: () => U) : [state<U>, () => void, true]

/**
 * Branching function to be used within Effects.
 * Pass a condition to be checked, and after it a function to be run if it's successful.
 * The last value, if a function, and if not after a condition, will be threated as the "else" branch.
 */
export function branch(...a : any) : void

/**
 * Creates an effect for every function or State within the given table, which updates the key to either the return value of the function, or the value of the State.
 * Each Effect's disconnect function gets put in the table as t["disconnect_"..key], when key is a string, or as t["disconnect"_..i], where i is the numerical index at which the key was iterated over.
 * @param t {[K] : V} -- The table.
 * @return {[K] : V} -- The same table.
 * @returns () => void -- Function which disconnects and eliminates each disconnect function of the created Effects.
 */
export function mirror<K, V>(t : Map<K, V>): [Map<K, V>, () => void]