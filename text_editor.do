import { NativeView } from "./native"
import { bindString, initialString, syncUI } from "./runtime"
import { TextStyle } from "./types"
import { View, ViewElement, growingControl } from "./view"

export class TextEditorSelection { start: int; length: int }
export class TextEditorHighlight { start: int; length: int; style: TextStyle }

/** Touch-, pointer-, and hardware-keyboard-aware UIKit source editor. */
export class TextEditor implements ViewElement {
  private native: NativeView
  private content: View

  static constructor(
    value: string | ((): string) = "",
    onChange: (value: string): none = (value): none => {},
    onSelectionChange: (selection: TextEditorSelection): none = (selection): none => {},
    fontSize: double = 15.0,
    tabWidth: int = 2,
    autoIndent: bool = true,
    minHeight: double = 160.0,
    accessibilityLabel: string = "Source editor",
    accessibilityHint: string = "",
    accessibilityIdentifier: string = "",
  ): TextEditor {
    if fontSize <= 0.0 { panic("TextEditor fontSize must be positive") }
    if tabWidth <= 0 { panic("TextEditor tabWidth must be positive") }
    if minHeight <= 0.0 { panic("TextEditor minHeight must be positive") }
    native := NativeView.textEditor(
      initialString(value), fontSize, tabWidth, autoIndent,
      (next): none => { onChange(next); syncUI() },
      (start, length): none => { onSelectionChange(TextEditorSelection { start, length }); syncUI() },
    )
    content := growingControl(native, minHeight)
      .accessibility(accessibilityLabel, accessibilityHint, accessibilityIdentifier)
    bindString(value, (next): none => native.setTextEditorText(next))
    return TextEditor { native, content }
  }

  asView(): View => content
  text(): string => native.textEditorText()
  setText(value: string): none { native.setTextEditorText(value) }

  selection(): TextEditorSelection => TextEditorSelection {
    start: native.textEditorSelectionStart(),
    length: native.textEditorSelectionLength(),
  }

  setSelection(selection: TextEditorSelection, reveal: bool = true): none {
    validateRange(selection.start, selection.length, "selection")
    native.setTextEditorSelection(selection.start, selection.length, reveal)
  }

  setHighlights(highlights: TextEditorHighlight[]): none {
    let starts: int[] = []; let lengths: int[] = []; let styles: int[] = []
    for highlight of highlights {
      validateRange(highlight.start, highlight.length, "highlight")
      starts.push(highlight.start); lengths.push(highlight.length); styles.push(highlight.style.value)
    }
    native.setTextEditorHighlights(starts, lengths, styles)
  }

  private validateRange(start: int, length: int, kind: string): none {
    sourceLength := text().length
    if start < 0 || length < 0 || start > sourceLength || length > sourceLength - start {
      panic("TextEditor ${kind} range is out of bounds")
    }
  }
}
