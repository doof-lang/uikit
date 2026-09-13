export import class NativeView from "native_uikit.hpp" as doof_uikit::NativeView {
  static container(): NativeView
  static scroll(): NativeView
  static spacer(): NativeView
  static text(value: string): NativeView
  static button(title: string, symbol: string, action: (): none): NativeView
  static textEditor(
    value: string,
    fontSize: double,
    tabWidth: int,
    autoIndent: bool,
    change: (value: string): none,
    selectionChange: (start: int, length: int): none,
    completions: (offset: int): string,
  ): NativeView
  append(child: NativeView): none
  detach(): none
  dispose(): none
  setFrame(x: double, y: double, width: double, height: double): none
  setDocumentSize(width: double, height: double): none
  measureWidth(maxWidth: double | none, maxHeight: double | none): double
  measureHeight(maxWidth: double | none, maxHeight: double | none): double
  setText(value: string): none
  setEnabled(value: bool): none
  setHidden(value: bool): none
  setAccessibility(label: string, hint: string, identifier: string): none
  setTextStyle(size: double, semibold: bool, secondary: bool): none
  textEditorText(): string
  setTextEditorText(value: string): none
  setTextEditorHighlights(starts: int[], lengths: int[], styles: int[]): none
  textEditorSelectionStart(): int
  textEditorSelectionLength(): int
  setTextEditorSelection(start: int, length: int, reveal: bool): none
  completeTextEditor(): none
}

export import class NativeScreen from "native_uikit.hpp" as doof_uikit::NativeScreen {
  static create(
    title: string,
    root: NativeView,
    leadingTitles: string[],
    leadingSymbols: string[],
    leadingActions: ((): none)[],
    trailingTitles: string[],
    trailingSymbols: string[],
    trailingActions: ((): none)[],
    layout: (width: double, height: double): none,
  ): NativeScreen
  run(): none
  presentAlert(title: string, message: string): none
  openDocument(typeIdentifiers: string[], handler: (path: string | none): none): none
  exportDocument(path: string, suggestedName: string, handler: (exported: bool): none): none
}
