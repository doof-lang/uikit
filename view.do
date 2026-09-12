import {
  AlignItems,
  FlexDirection,
  LayoutConstraints,
  LayoutEdges,
  LayoutNode,
  LayoutRect,
  LayoutSize,
  LayoutStyle,
  layout,
  measureLayout,
} from "std/layout"

import { NativeView } from "./native"
import { bindBool, syncUI } from "./runtime"

readonly KIND_CONTAINER = 0
readonly KIND_LEAF = 1
readonly KIND_SCROLL = 2
readonly GAP = 8.0

export interface ViewElement { asView(): View }

class ViewReference { view: weak View }

export class View {
  native: NativeView
  node: LayoutNode
  private readonly kind: int
  private let children: View[] = []
  private let attached = true
  private let hiddenState = false
  private let disposed = false

  append(child: View): View {
    if kind == KIND_LEAF { panic("leaf controls cannot contain children") }
    if kind == KIND_SCROLL && children.length > 0 { panic("ScrollView accepts exactly one child") }
    children.push(child)
    child.attached = true
    native.append(child.native)
    syncUI()
    return this
  }

  detach(): View { attached = false; native.detach(); syncUI(); return this }

  dispose(): none {
    if disposed { return }
    disposed = true
    attached = false
    node.onPlace = none
    node.measure = none
    for child of children { child.dispose() }
    children = []
    while node.children.length > 0 { try! node.children.pop() }
    native.dispose()
    syncUI()
  }

  hidden(value: bool | ((): bool)): View {
    bindBool(value, (next): none => { hiddenState = next; native.setHidden(next) })
    return this
  }

  enabled(value: bool | ((): bool)): View {
    bindBool(value, (next): none => native.setEnabled(next))
    return this
  }

  accessibility(label: string = "", hint: string = "", identifier: string = ""): View {
    native.setAccessibility(label, hint, identifier)
    return this
  }

  asView(): View => this
  isIncluded(): bool => attached && !hiddenState

  prepareLayout(): none {
    if disposed { return }
    while node.children.length > 0 { try! node.children.pop() }
    if kind == KIND_SCROLL { return }
    for child of children {
      child.prepareLayout()
      if child.isIncluded() { node.children.push(child.node) }
    }
  }

  private place(x: double, y: double, width: double, height: double): none {
    native.setFrame(x, y, width, height)
    if kind == KIND_SCROLL && children.length == 1 {
      child := children[0]
      child.prepareLayout()
      measured := measureLayout(child.node, LayoutConstraints { minWidth: width, maxWidth: width })
      documentHeight := if measured.height > height then measured.height else height
      native.setDocumentSize(width, documentHeight)
      layout(child.node, LayoutRect { width, height: documentHeight })
    }
  }
}

function createView(native: NativeView, style: LayoutStyle, kind: int, measured: bool = false): View {
  node := LayoutNode { style }
  if measured {
    node.measure = (constraints): LayoutSize => LayoutSize {
      width: native.measureWidth(constraints.maxWidth, constraints.maxHeight),
      height: native.measureHeight(constraints.maxWidth, constraints.maxHeight),
    }
  }
  view := View { native, node, kind }
  owner := ViewReference { view }
  node.onPlace = (placement): none => {
    _ := owner.view?.place(
      placement.layoutBounds.x,
      placement.layoutBounds.y,
      placement.layoutBounds.width,
      placement.layoutBounds.height,
    ) else { }
  }
  return view
}

export function measuredControl(native: NativeView): View {
  return createView(native, LayoutStyle { shrink: 0.0 }, KIND_LEAF, true)
}

export function growingControl(native: NativeView, minHeight: double = 80.0): View {
  return createView(native, LayoutStyle { grow: 1.0, minHeight }, KIND_LEAF)
}

function container(children: ViewElement[], direction: FlexDirection, gap: double, grow: double): View {
  if gap < 0.0 { panic("container gap cannot be negative") }
  if grow < 0.0 { panic("container grow cannot be negative") }
  style := LayoutStyle {
    direction,
    gap,
    grow,
    alignItems: if direction == .Row then AlignItems.Center else AlignItems.Stretch,
  }
  if grow > 0.0 { style.flexBasis = 0.0 }
  view := createView(NativeView.container(), style, KIND_CONTAINER)
  for child of children { view.append(child.asView()) }
  return view
}

export function Row(children: ViewElement[] = [], gap: double = GAP, grow: double = 0.0): View {
  return container(children, .Row, gap, grow)
}

export function Column(children: ViewElement[] = [], gap: double = GAP, grow: double = 0.0): View {
  return container(children, .Column, gap, grow)
}

export function ScrollView(children: ViewElement[] = []): View {
  if children.length != 1 { panic("ScrollView requires exactly one child") }
  view := createView(NativeView.scroll(), LayoutStyle { grow: 1.0, minHeight: 80.0 }, KIND_SCROLL)
  view.append(children[0].asView())
  return view
}

export function Spacer(grow: double = 1.0): View {
  if grow <= 0.0 { panic("Spacer grow must be positive") }
  return createView(NativeView.spacer(), LayoutStyle { grow, flexBasis: 0.0 }, KIND_LEAF)
}

export function screenContent(children: ViewElement[], padding: double): View {
  view := createView(NativeView.container(), LayoutStyle {
    direction: .Column,
    gap: GAP,
    padding: LayoutEdges.all(padding),
  }, KIND_CONTAINER)
  for child of children { view.append(child.asView()) }
  return view
}
