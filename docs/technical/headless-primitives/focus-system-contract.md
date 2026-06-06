# Focus System Contract

## Status

Implementation contract. Not implemented yet.

## Primary Standards

- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WCAG 2.2 Focus Not Obscured and Focus Appearance:
  https://www.w3.org/TR/WCAG22/
- Flutter Focus:
  https://docs.flutter.dev/ui/interactivity/focus
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Core Decision

Headless components must model logical focus separately from Flutter
`FocusNode` ownership.

Flutter focus is the platform mechanism. Headless logical focus is the
component state.

## Focus Types

```text
PlatformFocus
  Flutter FocusNode/FocusScopeNode

LogicalFocus
  row key
  cell key
  menu item id
  dialog action id
  splitter handle id

VisualFocus
  focus ring state exposed to renderer

AccessibilityFocus
  screen-reader/accessibility focus when platform exposes it
```

Do not assume these are always identical.

## Composite Focus Rule

APG recommends one tab stop for composite widgets. Therefore:

- TreeGrid root has one entry focus point by default;
- menu manages item focus internally;
- dialog traps focus internally;
- split pane handle is focusable;
- tooltip never receives focus;
- status region never receives focus.

## Focus Return Target

```text
FocusReturnTarget
  focusNode
  logicalTarget(componentId, key)
  routeFallback
  none
```

Virtualized widgets must store logical return targets because the original
row/cell widget may unmount.

## Focus Visibility

WCAG 2.2 implications:

- focused component must not be entirely obscured by app-created content;
- focus indicator should be visually clear and high contrast;
- overlay and sticky footer/header must not hide focus without a way to reveal
  it;
- scroll-to-focused target is an effect, not renderer state.

## Focus State Machine

```text
unfocused
  -> focusedByKeyboard
  -> focusedByPointer
  -> focusedByProgram
  -> focusRestoring
  -> focusLost
```

`focusedByKeyboard` should expose stronger focus ring policy than pointer focus
if the design system supports modality-aware focus visuals.

## Flutter Implementation Rules

- own internal `FocusNode` only when caller does not provide one;
- dispose internal nodes only;
- use `FocusScope` for dialog/menu scopes;
- use `FocusableActionDetector` where focus, hover, and actions are all needed;
- use `Shortcuts` to map keys to intents;
- use `Actions` to dispatch component commands;
- never make renderer create a parallel focus tree for root behavior.

## Conformance Tests

- external FocusNode is not disposed;
- internal FocusNode is disposed;
- Tab enters composite once;
- focus returns after menu/dialog close;
- virtualized row focus returns by logical target;
- focus ring appears for keyboard focus;
- focus is not hidden by overlay/sticky footer in reference fixture;
- disabled focus policy is respected.

## Stop Rules

- Do not use `FocusNode` as domain identity.
- Do not let renderer own root focus.
- Do not create multiple tab stops in composite widgets by default.
- Do not move focus to tooltip or status updates.
