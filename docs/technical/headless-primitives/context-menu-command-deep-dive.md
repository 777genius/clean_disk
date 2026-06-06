# ContextMenu And Command Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Primary Standards

- WAI-ARIA APG Menu and Menubar:
  https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- WAI-ARIA APG Menu Button:
  https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/
- MDN `menu` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/menu_role
- MDN `menuitem` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/menuitem_role
- React Aria Menu:
  https://react-spectrum.adobe.com/react-aria/Menu.html

## Core Decision

Menu is a command surface. It is not a layout container for arbitrary widgets.

## Command Identity

```text
CommandId
  namespace
  value
  version optional

CommandPresentation
  label
  description
  icon token
  shortcut label

CommandState
  enabled
  checked
  selected
  destructive
  hidden
```

Labels are presentation only. They never identify commands.

## Item Types

```text
CommandMenuItem
  action
  checkbox
  radio
  submenu
  separator
  groupLabel
```

Rules:

- separator is not focusable;
- disabled item may be focusable but not activatable;
- checkbox/radio item may optionally keep menu open;
- submenu item exposes has-popup and expanded facts;
- destructive is semantic/display hint, not permission.

## Invocation Context

```text
CommandContext
  source: pointer | keyboard | programmatic
  target: logical row/cell/control key
  pointer position optional
  selection snapshot
  capability snapshot
```

Clean Disk context menu for TreeGrid rows must include logical row key. If row
widget unmounts, command can still resolve through application state.

## Keyboard Map

Menu opened from button:

- Enter/Space opens and focuses first item;
- optional Up opens last item;
- optional Down opens first item.

Menu open:

- Up/Down moves item focus;
- Home/End first/last;
- printable char typeahead;
- Enter activates or opens submenu;
- Space activates checkbox/radio policy;
- Right opens submenu;
- Left closes submenu;
- Escape closes and restores invoking context;
- Tab closes menu and exits.

Context menu:

- right click opens at pointer;
- keyboard context key opens at focused target;
- Shift + F10 opens at focused target.

## State Machine

```text
closed
openingRoot
rootOpen
submenuOpening
submenuOpen
closingSubmenu
closingAll
closed
```

Each stack level has:

- menu id;
- focused item id;
- anchor;
- restore target;
- pointer grace area for submenu;
- open reason.

## Renderer Boundary

Renderer may:

- draw menu surface;
- draw item rows;
- draw submenu indicator;
- draw check/radio marks;
- draw shortcuts;
- animate open/close.

Renderer must not:

- invoke product command callback directly;
- own checked state;
- own disabled logic;
- create focus independently;
- include arbitrary focusable content inside menu.

## Clean Disk Command Routing

```text
RContextMenu
  emits CommandIntent(commandId, context)

ScanStore
  maps command id to use case

Use case
  checks capabilities and current snapshot
```

Commands:

- reveal;
- copy path;
- add/remove cleanup queue;
- expand/collapse;
- show details;
- rescan subtree future.

## Conformance Tests

- right-click opens context menu;
- Shift + F10 opens from focused row;
- disabled item focusable policy;
- separator skipped;
- submenu opens/closes and returns focus;
- command identity independent from label;
- checkbox/radio state updates controlled;
- Escape restores logical target;
- renderer never calls product callback directly.

## Stop Rules

- Do not put forms or text fields inside menu.
- Do not use localized labels as command ids.
- Do not bypass application command policy.
- Do not let context menu depend on TreeGrid internals.
