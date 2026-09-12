import { NativeView } from "./native"
import { bindString, initialString, syncUI } from "./runtime"
import { View, measuredControl } from "./view"

export function Text(
  value: string | ((): string),
  fontSize: double = 15.0,
  semibold: bool = false,
  secondary: bool = false,
  accessibilityLabel: string = "",
  accessibilityHint: string = "",
  accessibilityIdentifier: string = "",
): View {
  if fontSize <= 0.0 { panic("Text fontSize must be positive") }
  native := NativeView.text(initialString(value))
  native.setTextStyle(fontSize, semibold, secondary)
  bindString(value, (next): none => native.setText(next))
  return measuredControl(native).accessibility(accessibilityLabel, accessibilityHint, accessibilityIdentifier)
}

export function Button(
  title: string | ((): string),
  symbol: string = "",
  onPress: (): none = (): none => {},
  enabled: bool | ((): bool) = true,
  accessibilityLabel: string = "",
  accessibilityHint: string = "",
  accessibilityIdentifier: string = "",
): View {
  native := NativeView.button(initialString(title), symbol, (): none => { onPress(); syncUI() })
  bindString(title, (next): none => native.setText(next))
  return measuredControl(native)
    .enabled(enabled)
    .accessibility(accessibilityLabel, accessibilityHint, accessibilityIdentifier)
}
