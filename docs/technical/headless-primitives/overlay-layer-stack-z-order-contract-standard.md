# Overlay Layer Stack Z Order Contract Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- MDN `dialog` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/dialog_role
- MDN `<dialog>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Element/dialog
- MDN Popover API: https://developer.mozilla.org/en-US/docs/Web/API/Popover_API
- MDN `inert`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inert
- WCAG 2.1.2 No Keyboard Trap: https://www.w3.org/WAI/WCAG22/Understanding/no-keyboard-trap.html
- WCAG 2.4.11 Focus Not Obscured Minimum: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html

## Scope

This standard covers overlay layer stacks, z-order tokens, modal and non-modal
overlay ordering, popover/dialog/sheet coexistence, portal roots, scrims,
escape handling, inertness, and focus ownership across stacked surfaces.

It extends overlay portal inertness and dialog standards. It focuses on
cross-component layer governance.

## Problem

Complex apps quickly stack overlays: command palette, tooltip, context menu,
confirmation dialog, permission repair sheet, notification drawer, and
platform prompt. If each component owns z-index and Escape behavior, focus
breaks and destructive flows can be bypassed. Headless needs a central layer
contract.

## Decision Options

1. `OverlayLayerStack` contract with typed layers and focus ownership -
   🎯 9   🛡️ 10   🧠 9, roughly 1200-2600 LOC.
   Best fit. It prevents overlay conflicts across public primitives.
2. Renderer-specific z-index constants -
   🎯 5   🛡️ 4   🧠 3, roughly 100-300 LOC.
   Easy, but behavior still diverges across components and platforms.
3. Always close all overlays on Escape -
   🎯 4   🛡️ 5   🧠 2, roughly 100-300 LOC.
   Simple, but wrong for nested menus, editing, confirmation, and dialogs.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- layer id;
- layer kind;
- modality;
- owner primitive id;
- focus owner;
- escape policy;
- outside interaction policy;
- inertness policy;
- restore focus target;
- stacking order;
- dismissal reason.

Renderer owns:

- actual z-index values;
- portal implementation;
- scrim visuals;
- shadows;
- animation;
- platform-specific overlay host.

Application owns:

- product flow;
- destructive confirmation policy;
- permission prompt orchestration;
- route transitions;
- audit and telemetry.

## Layer Kinds

Kinds:

- tooltip;
- hoverPreview;
- popover;
- menu;
- contextMenu;
- commandPalette;
- drawer;
- sheet;
- nonModalDialog;
- modalDialog;
- alertDialog;
- platformPromptProxy;
- notificationDrawer;
- appDefined.

Layer kind determines defaults, not product authority.

## Modality Rules

Modal layer:

- blocks background interaction;
- owns focus;
- requires focus return policy;
- requires visible close/cancel path where applicable;
- marks outside content inert where adapter supports it.

Non-modal layer:

- does not trap focus unless explicitly configured;
- can close on outside interaction by policy;
- must not hide the focused component with no reveal path;
- can coexist with background commands only by command routing policy.

## Escape And Outside Interaction

Escape resolves from top layer down:

1. active text edit or IME composition;
2. nested menu/submenu;
3. popover/tooltip if dismissible;
4. command palette;
5. modal dialog by dialog policy;
6. app route only if no overlay consumes it.

Outside pointer interaction:

- does not commit destructive action;
- may dismiss non-modal overlays;
- cannot dismiss high-risk confirmation unless policy allows;
- must not pass through to risky background command.

## Z Order Tokens

Headless exposes semantic order, not numeric z-index.

Layer groups:

- base;
- sticky;
- floating;
- popover;
- menu;
- modal;
- alert;
- systemBridge.

Renderer maps groups to platform-specific stacking. Numeric values are not
public API.

## Clean Disk Usage

Potential stacked surfaces:

- row action menu;
- details popover;
- command palette;
- delete confirmation;
- permission repair sheet;
- operation center drawer;
- notification inbox;
- settings dialog.

Rules:

- delete confirmation is top modal layer;
- command palette cannot sit above active destructive confirmation;
- tooltip does not appear over modal confirmation unless owned by it;
- notification drawer cannot steal focus from modal review;
- layer stack events route through command arbitration.

## Community API Sketch

```dart
final class ROverlayLayer {
  const ROverlayLayer({
    required this.id,
    required this.kind,
    required this.modality,
    required this.focusPolicy,
    required this.dismissPolicy,
  });

  final String id;
  final ROverlayLayerKind kind;
  final ROverlayModality modality;
  final RFocusPolicy focusPolicy;
  final RDismissPolicy dismissPolicy;
}
```

## Conformance Scenarios

- Escape closes topmost eligible layer only;
- modal layer makes background inert;
- focus returns to invoker or logical fallback;
- command palette cannot cover delete confirmation;
- tooltip does not trap focus;
- outside click does not activate background risky command;
- focus remains visible with sticky overlays;
- z-order tokens are renderer-owned, not hardcoded per component.

## Failure Catalog

- Every component invents z-index.
- Escape closes modal and background route at once.
- Tooltip appears above destructive dialog.
- Non-modal popover traps focus.
- Outside click both dismisses overlay and clicks background delete.
- Renderer owns focus trap.
- Numeric z-index becomes public API.

