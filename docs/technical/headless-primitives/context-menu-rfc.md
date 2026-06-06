# Headless ContextMenu And Command Menu RFC

## Status

Accepted design direction. Not implemented yet.

## Problem

Dense productivity UIs need contextual commands on rows, cells, folders, panes,
and toolbar buttons. Clean Disk needs row actions such as reveal, add to queue,
copy path, expand, collapse, and details. The Headless community needs menus
that work with keyboard, pointer, context-click, and nested submenus.

## Standards And References

- WAI-ARIA APG Menu and Menubar:
  https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- WAI-ARIA APG Menu Button:
  https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/
- MDN `menu` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/menu_role
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- Radix Dropdown Menu:
  https://www.radix-ui.com/primitives/docs/components/dropdown-menu
- React Aria Menu:
  https://react-spectrum.adobe.com/react-aria/Menu.html

## Accepted Direction

Create one command/menu foundation and two public components:

```text
headless_foundation/menu
  command item model
  submenu state
  menu stack
  roving focus/typeahead
  close policy

components/headless_context_menu
  RContextMenu

components/headless_menu_button
  RMenuButton
```

Current Headless menu/listbox/overlay foundation should be reused and extended,
not forked.

## Top Options

1. Shared command menu foundation plus ContextMenu/MenuButton - 🎯 9   🛡️ 8
   🧠 8, roughly 900-1700 LOC.

   Best for community and Clean Disk. Reuses overlay/listbox behavior and
   creates one command model.

2. ContextMenu only - 🎯 7   🛡️ 7   🧠 6, roughly 500-1000 LOC.

   Useful for Clean Disk rows, but later duplicates menu button behavior.

3. Use Flutter popup/menu widgets directly - 🎯 4   🛡️ 5   🧠 3,
   roughly 100-300 LOC.

   Too weak for Headless renderer contracts and cross-platform custom UI.

Accepted: option 1.

## Command Item Model

```text
CommandItem
  id
  label
  description
  shortcutLabel
  icon token
  role: normal | checkbox | radio | submenu | separator
  disabled
  destructive
  checked
  groupId
  submenuId
```

Do not use localized labels as command identity.

## Keyboard Model

Menu behavior:

- opening menu places focus on first enabled item or configured item;
- arrow up/down move within menu;
- Home/End move first/last item;
- printable character typeahead;
- Right opens submenu;
- Left closes submenu;
- Enter activates or opens submenu;
- Escape closes current menu and restores invoking context;
- Tab closes menu and exits menu system;
- disabled menu items may be focusable but not activatable.

Context invocation:

- right click;
- long press where platform expects it;
- keyboard context menu key;
- Shift + F10.

## Accessibility Model

Expose:

- menu;
- menuitem;
- menuitemcheckbox;
- menuitemradio;
- separator;
- has popup;
- expanded;
- checked;
- disabled;
- destructive semantic hint where platform supports custom action label;
- labelled by trigger or explicit label.

## Overlay And Focus Rules

- use `headless_foundation` overlay;
- never use Navigator/Route for menu;
- focus is restored to invoking row/cell/trigger;
- submenu open/close has explicit lifecycle;
- pointer hover can preview submenu but keyboard remains authoritative;
- menu stack closes predictably on outside click, Escape, command activation,
  or owning widget disposal.

## Clean Disk Usage

TreeGrid rows should expose context menu commands through app-owned command
adapters:

- reveal in Finder/Explorer;
- copy path;
- add/remove queue;
- expand/collapse;
- rescan subtree later;
- show details.

Headless only emits command ids. Scan feature decides what each command means.

## Conformance Tests

- right click opens at pointer position;
- Shift + F10 opens at focused row/cell;
- keyboard navigation matches APG;
- disabled items focus policy works;
- nested submenu focus restore;
- Escape closes and restores focus;
- command activation closes according to policy;
- separator is not focusable;
- renderer does not call app callback directly.

## Stop Rules

- Do not put interactive arbitrary widgets inside `menu` role. Use dialog or
  popover patterns if content is complex.
- Do not use display text as command id.
- Do not let row UI bypass the normal command/use-case flow.
- Do not make context menu depend on TreeGrid.
