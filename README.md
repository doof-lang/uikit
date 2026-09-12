# std/uikit

Doof-first UIKit APIs for iPhone and iPad applications. The package borrows the
retained view, reactive value, and `std/layout` conventions that work well in
`std/appkit`, but models UIKit on its own terms: adaptive screens, navigation
bar actions, safe areas, document pickers, touch input, and the generated iOS
application shell.

It deliberately does not provide desktop-shaped windows, application menus, or
synchronous modal file panels. `Screen.openDocument` and
`Screen.exportDocument` are callback-based because UIKit presentation is
asynchronous.

## First screen

```doof
import { BarButton, Screen, Text, TextEditor, runApp } from "std/uikit"

function main(): none {
  let source = "function main(): none {}"
  editor := <TextEditor value=>source onChange=>{ source = value }/>
  screen := <Screen
    title="Editor"
    trailingItems={[
      BarButton { title: "Add", symbol: "plus", onPress: (): none => editor.setText(source + "\n") },
    ]}>
    <Text value="Doof source" semibold=true/>
    {editor}
  </Screen>
  runApp(screen)
}
```

Build through Doof's existing UIKit-owned shell:

```sh
doof build ios.do --target ios-app --ios-destination simulator
```

`runApp` attaches the screen to that shell, marshals native work onto the UIKit
main thread, and keeps the Doof view graph alive while UIKit owns the event
loop. Layout is recomputed within the current safe area as iPad multitasking,
rotation, navigation bars, and window sizes change.

## Current surface

- `Screen`, `BarButton`, `runApp`
- `View`, `Row`, `Column`, `ScrollView`, `Spacer`
- `Text`, `Button`
- `TextEditor`, UTF-8 selections, and semantic highlights
- async document import/export and alerts on `Screen`

The native bridge uses ARC and is available for both iOS simulator and device
builds. UIKit and Objective-C types remain private to the bridge.
