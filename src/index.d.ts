// TODO: Roblox type declarations

declare namespace swan {
  type cleanup<T extends unknown[]> = (...args : T) => unknown[]
  type callback<T = unknown, U extends unknown[] = []> = ((old_value?: T, state_i?: number) => cleanup<U> | void)
  type disconnecter = () => void
  type state<T = unknown> = {
    (new_value: T, force?: boolean): T
    (): T
    value: T
    always_force: boolean
    readonly callbacks: Map<callback<T>, number>
  }

  type proxy<T extends Map<unknown, unknown>> = T
  type proxy_state<T extends Map<unknown, unknown>> = state<proxy<T>>

  function state<T>(initial_value: T, always_force?: boolean): state<T>
  function proxy_state<T extends Map<unknown, unknown>>(initial_value : T) : proxy_state<T>
  function effect<T, U extends unknown[]>(callback: callback<T, U>): disconnecter
  function block_effect<T, U extends unknown[]>(callback: callback<T, U>): disconnecter
  function derived<T>(f: () => T): [state<T>, disconnecter]
  function scope(f: () => unknown[]): disconnecter

  namespace utils {
    function batch(f: () => unknown[]): void
    function branch(...a: any): void
    function is_state<T>(v : T): boolean
    function is_proxy<T>(v : T): boolean
    function is_proxy_state<T>(v : T): boolean
    function get_real<T extends Map<unknown, unknown>>(proxy : proxy<T>): T
    function state_get_real<T extends Map<unknown, unknown>>(proxy_state : proxy_state<T>): T
    function clear<T>(state?: state<T>): void
  }
}

export = swan
