class ReactiveRuntime {
  private let bindings: ((): none)[] = []
  private let invalidators: ((): none)[] = []
  private let syncing = false

  bindString(getter: (): string, apply: (value: string): none): none {
    let previous = getter()
    apply(previous)
    bindings.push((): none => {
      next := getter()
      if next != previous { previous = next; apply(next) }
    })
  }

  bindBool(getter: (): bool, apply: (value: bool): none): none {
    let previous = getter()
    apply(previous)
    bindings.push((): none => {
      next := getter()
      if next != previous { previous = next; apply(next) }
    })
  }

  addInvalidator(invalidator: (): none): none { invalidators.push(invalidator) }

  sync(): none {
    if syncing { return }
    syncing = true
    for binding of bindings { binding() }
    for invalidator of invalidators { invalidator() }
    syncing = false
  }
}

readonly runtime = ReactiveRuntime {}

export function registerLayoutInvalidator(invalidator: (): none): none { runtime.addInvalidator(invalidator) }
export function syncUI(): none { runtime.sync() }

export function initialString(value: string | ((): string)): string {
  direct := value as string else {
    getter := value as ((): string) else { panic("Reactive string value is invalid") }
    return getter()
  }
  return direct
}

export function bindString(value: string | ((): string), apply: (value: string): none): none {
  direct := value as string else {
    getter := value as ((): string) else { panic("Reactive string value is invalid") }
    runtime.bindString(getter, apply)
    return
  }
  apply(direct)
}

export function bindBool(value: bool | ((): bool), apply: (value: bool): none): none {
  direct := value as bool else {
    getter := value as ((): bool) else { panic("Reactive boolean value is invalid") }
    runtime.bindBool(getter, apply)
    return
  }
  apply(direct)
}
