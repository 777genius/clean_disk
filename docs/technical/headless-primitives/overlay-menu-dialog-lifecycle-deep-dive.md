# Overlay, Menu, And Dialog Lifecycle Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Primary Standards

- WAI-ARIA APG Menu and Menubar:
  https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- WAI-ARIA APG Menu Button:
  https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/
- WAI-ARIA APG Dialog Modal:
  https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Alert Dialog:
  https://www.w3.org/WAI/ARIA/apg/patterns/alertdialog/
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- Radix Dialog and Dropdown Menu:
  https://www.radix-ui.com/primitives/docs/components/dialog
  https://www.radix-ui.com/primitives/docs/components/dropdown-menu

## Core Decision

Overlay lifecycle is shared foundation. Menu and Dialog are different behavior
models over the same overlay substrate.

```text
headless_foundation/overlay
  placement
  phase
  focus restore
  dismissal
  outside interaction

headless_foundation/menu
  menu stack
  roving item focus
  submenu policy

components/headless_dialog
  modal focus trap
  inert background policy
  dialog stack
```

## Overlay Phases

```text
closed
opening
open
closing
disposed
```

Rules:

- `closing` means close has started;
- renderer exit animation must call complete close exactly once;
- fail-safe timeout completes close if renderer fails;
- cancelled close returns to `open` without complete close;
- disposal during closing completes close safely;
- focus restore happens once after logical close.

## Dismiss Reasons

```text
DismissReason.escape
DismissReason.outsidePointer
DismissReason.focusLoss
DismissReason.itemActivated
DismissReason.parentClosed
DismissReason.routeChanged
DismissReason.ownerDisposed
DismissReason.programmatic
```

Each component defines which reasons are allowed.

Dialog destructive confirmation:

- outside pointer default: blocked;
- Escape default: allowed only if cancel action is safe;
- route changed: app policy;
- owner disposed: close fail-safe.

Menu:

- outside pointer closes;
- Escape closes and restores invoking focus;
- item activation closes unless checkbox/radio policy keeps open.

## Focus Stack

```text
FocusReturnTarget
  node
  logicalTreeGridTarget
  menuParentItem
  routeFallback
  none
```

Store logical return targets, not only Flutter `FocusNode`, because virtualized
TreeGrid rows can be unmounted.

## Menu Stack

```text
MenuStack
  rootMenu
  submenu chain
  activeItem
  pointerIntent
  keyboardIntent
```

Rules:

- disabled menu items can receive focus but not activate;
- separator is never focusable;
- submenu close returns focus to parent item;
- context menu opened by keyboard returns to invoking row/cell;
- pointer hover cannot break keyboard focus order.

## Dialog Stack

```text
DialogStack
  modal entries
  previous focus targets
  inert scopes
  escape policies
```

Rules:

- modal dialog traps Tab and Shift + Tab;
- background is inert by policy;
- nested dialog closes back to previous dialog;
- initial focus is explicit;
- destructive confirmation defaults to least destructive initial focus;
- content description is optional and should be omitted for complex structured
  content.

## Renderer Boundary

Renderer may:

- animate entry/exit;
- draw backdrop;
- draw surface;
- position arrow;
- style focus/hover;
- call component commands from render request.

Renderer must not:

- own open state;
- call app callbacks directly;
- create a second root gesture path;
- skip complete close;
- trap focus independently from component.

## State Machine Tests

| Case | Required |
| --- | --- |
| open -> closing -> closed | complete close exactly once |
| close cancelled | no complete close |
| renderer disposed while closing | fail-safe completes |
| Escape menu | closes and restores focus |
| Escape dialog | follows dismiss policy |
| submenu Escape | returns to parent item |
| nested dialog close | returns to previous dialog |
| virtualized invoking row unmounted | restore logical target or fallback |

## Stop Rules

- Do not use Navigator/Route for menu overlays.
- Do not let renderer own focus trap.
- Do not make all dialogs outside-click dismissible.
- Do not store only mounted FocusNode as return target.
- Do not mix tooltip and interactive popover behavior into menu/dialog.
