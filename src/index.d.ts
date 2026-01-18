declare namespace swan {
  type callback<T = unknown> = (old_value?: T, state_i?: number) => unknown

  type state<T = unknown> = {
    (new_value: T, force?: boolean): T
    (): T
    value: T
    always_force: boolean
    readonly callbacks: Map<callback<T>, number>
  }

  /**
   * Creates a State.
   * @param initial_value? T -- The initial value for the State, can be nil.
   * @param always_force? boolean -- Whether Effects connected to this State will always trigger, even when the value didn't change.
   * @returns state<T> -- The created State. Call with no arguments for reading with tracking,
   * call with arguments for writing (2nd argument is for forcing),
   * read .value field for reading without tracking,
   * write .value field for writing without triggering Effects.
   */
  function state<T>(initial_value: T, always_force?: boolean): state<T>

  /**
   * Creates an Effect, a binding of the given function to the event of States read (by calling) within it being updated.
   * 
   * @param callback callback<T> -- The function to be bound.
   * @returns () => void -- Function which disconnects the Effect from the States.
   */
  function effect<T>(callback: callback<T>): () => void

  /**
   * Wraps an Effect around the given Callback which sets a newly created State's value
   * to be the return value of the Callback.
   * Returns the created State and the Effect's disconnect function.
   *
   * This is useful for States which depend on the value of another State, since their value will
   * be updated only when the State they depend on is also updated, and not every time it is read,
   * as how would happen with a function which's return value depends on a State.
   *
   * @param callback () => T -- The callback.
   * @returns state<T> -- The State that was created.
   * @returns () => void -- The created Effect's disconnect function.
   */
  function derive<T>(callback: () => T): [state<T>, () => void]

  /**
   * Batches any State write operation up until the function is done running.
   *
   * @param f () => unknown[] -- The function.
   */
  function batch(f: () => unknown[]): void

  /**
   * Wraps the given callbacks into Effects.
   * Returns a function which disconnects all the created Effects.
   *
   * @param ...args { [K in keyof T]: callback<T[K]> } -- The callbacks.
   * @returns () => void -- The disconnecter.
   */
  function scope<T extends any[]>(...args: { [K in keyof T]: callback<T[K]> }): () => void

  /**
   * Branching function to be used within Effects.
   * Pass a condition to be checked, and after it a function to be run if it's successful.
   * The last value, if a function, and if not after a condition, will be threated as the "else" branch.
   *
   * @param ...a any -- The values and the branches.
   */
  function branch(...a: any): void

  /**
   * Iterates over the given map and creates an Effect for each key that is
   * either a function or a State, updating the key's value to be the return value of the
   * function, or the State's value.
   * Returns a map containing each key's Effect's disconnect function.
   *
   * @param t T -- The table to iterate.
   * @return T -- The given table.
   * @return {[identifier<T>] : () -> ()} -- The table containing the disconnect functions.
   */
  function mirror<K, V>(t: Map<K, V>): [Map<K, V>, Map<K, () => void>]

  /**
   * Disconnects all Effects.
   */
  function cleanup(): void
}

export = swan