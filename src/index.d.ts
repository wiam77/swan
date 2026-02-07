declare namespace swan {
  type cleanup = () => unknown[]
  type disconnecter = () => void
  
  type callback<T = unknown> = ((old_value?: T, state_i?: number) => cleanup | void)

  type state<T = unknown> = {
    (new_value: T, force?: boolean): T
    (): T
    value: T
    always_force: boolean
    readonly callbacks: Map<callback<T>, number>
  }

  function effect<T>(callback: callback<T>): disconnecter

  function derive<T>(callback: () => T): [state<T>, disconnecter]

  function state<T>(initial_value: T, always_force?: boolean): state<T>

  function batch(f: () => unknown[]): void

  function scope<T extends any[]>(...args: { [K in keyof T]: callback<T[K]> }): disconnecter

  function branch(...a: any): void

  function is_state(v : any): boolean

  function clear(): void
}

export = swan