# Input Modality Contract

## Status

Implementation contract. Not implemented yet.

## Primary Standards

- WCAG 2.2 Input Modalities:
  https://www.w3.org/TR/WCAG22/
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MDN `aria-keyshortcuts`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-keyshortcuts
- Flutter FocusableActionDetector:
  https://docs.flutter.dev/ui/interactivity/focus

## Core Decision

Every Headless primitive must support keyboard operation first. Pointer, touch,
trackpad, stylus, and shortcuts are additional input paths, not replacements.

## Input Sources

```text
InputSource
  keyboard
  pointerMouse
  pointerTouch
  pointerStylus
  trackpad
  assistiveTechnology
  programmatic
```

Events record source because focus ring, hover, drag, and announcement policy
can depend on modality.

## WCAG-Driven Rules

- Pointer cancellation: destructive pointer actions should not trigger only on
  down event.
- Dragging movements need a non-drag alternative unless dragging is essential.
- Target size should meet at least WCAG 2.2 minimum or have spacing/equivalent
  alternatives.
- Label in name: visible button/menu labels must be contained in accessible
  names.
- Concurrent input mechanisms must not be blocked unnecessarily.

## Shortcut Contract

```text
ShortcutDefinition
  commandId
  activators
  platformVariants
  enabledWhen
  visibleInMenus
  exposeToSemantics
```

MDN warns that `aria-keyshortcuts` exposes shortcuts but does not implement
behavior. In Flutter, behavior lives in `Shortcuts` and `Actions`. Web ARIA
bridge may expose shortcut facts later.

Rules:

- disabled command disables shortcut;
- shortcuts are documented or discoverable;
- do not conflict with platform/system shortcuts when avoidable;
- local component shortcuts beat global shortcuts only while focused;
- command id is stable, shortcut label is localized presentation.

## Pointer And Touch

Rules:

- activation happens on release/up where possible;
- cancel on pointer leaving activation bounds unless policy says otherwise;
- long press may open context menu on touch;
- right click opens context menu on desktop;
- touch target policy is renderer token plus component conformance;
- drag has keyboard or click alternative for SplitPane and reorder features.

## Drag Alternatives

SplitPane:

- arrow keys resize;
- Home/End min/max;
- Enter collapse/restore.

Column resize:

- keyboard resize mode;
- min/max clamp;
- Escape cancel.

Drag reorder:

- future only;
- must include keyboard reorder before stable.

## Conformance Tests

- keyboard path exists for every pointer operation;
- pointer down alone does not commit destructive action;
- disabled command disables shortcut;
- shortcut is exposed in menu presentation;
- right click and Shift + F10 both open context menu;
- split pane can resize without dragging;
- touch long press does not break keyboard flow;
- target size policy can be checked in renderer fixture.

## Stop Rules

- Do not ship pointer-only controls.
- Do not bind destructive action to pointer down.
- Do not expose `aria-keyshortcuts` without implementing shortcut behavior.
- Do not make drag essential for SplitPane or column resize.
