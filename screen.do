import { LayoutRect, layout } from "std/layout"

import { NativeScreen } from "./native"
import { registerLayoutInvalidator, syncUI } from "./runtime"
import { View, ViewElement, screenContent } from "./view"

readonly CONTENT_INSET = 12.0

/** A navigation-bar command. Use an SF Symbol when `symbol` is non-empty. */
export class BarButton {
  readonly title: string = ""
  readonly symbol: string = ""
  readonly onPress: (): none = (): none => {}
}

/** One adaptive UIKit screen hosted in a navigation controller. */
export class Screen {
  readonly title: string
  content: View
  private native: NativeScreen

  static constructor(
    title: string,
    children: ViewElement[],
    leadingItems: BarButton[] = [],
    trailingItems: BarButton[] = [],
  ): Screen {
    root := screenContent(children, CONTENT_INSET)
    let leadingTitles: string[] = []; let leadingSymbols: string[] = []; let leadingActions: ((): none)[] = []
    let trailingTitles: string[] = []; let trailingSymbols: string[] = []; let trailingActions: ((): none)[] = []
    for item of leadingItems {
      leadingTitles.push(item.title); leadingSymbols.push(item.symbol)
      leadingActions.push((): none => { item.onPress(); syncUI() })
    }
    for item of trailingItems {
      trailingTitles.push(item.title); trailingSymbols.push(item.symbol)
      trailingActions.push((): none => { item.onPress(); syncUI() })
    }
    let lastWidth = 0.0
    let lastHeight = 0.0
    relayout := (width: double, height: double): none => {
      lastWidth = width; lastHeight = height
      root.prepareLayout()
      layout(root.node, LayoutRect { width, height })
    }
    native := NativeScreen.create(
      title, root.native,
      leadingTitles, leadingSymbols, leadingActions,
      trailingTitles, trailingSymbols, trailingActions,
      relayout,
    )
    registerLayoutInvalidator((): none => {
      if lastWidth > 0.0 && lastHeight > 0.0 { relayout(lastWidth, lastHeight) }
    })
    return Screen { title, content: root, native }
  }

  presentAlert(title: string, message: string): none { native.presentAlert(title, message) }

  openDocument(
    typeIdentifiers: string[] = ["public.source-code", "public.plain-text"],
    handler: (path: string | none): none,
  ): none {
    native.openDocument(typeIdentifiers, (path): none => { handler(path); syncUI() })
  }

  exportDocument(
    path: string,
    suggestedName: string,
    handler: (exported: bool): none = (exported): none => {},
  ): none {
    native.exportDocument(path, suggestedName, (exported): none => { handler(exported); syncUI() })
  }

  run(): none { native.run() }
}

/** Mounts into Doof's generated iOS shell and keeps the Doof UI graph alive. */
export function runApp(screen: Screen): none { screen.run() }
