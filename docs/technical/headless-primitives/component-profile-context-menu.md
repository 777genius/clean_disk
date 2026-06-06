# Component Profile - ContextMenu And MenuButton

## Status

Implementation profile for `RContextMenu` and `RMenuButton`.

## Standards

- WAI-ARIA APG Menu and Menubar:
  https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- WAI-ARIA APG Menu Button:
  https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/
- MDN `menu` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/menu_role

## Purpose

Command surface for contextual and button-triggered actions.

Clean Disk use: row context actions, toolbar menus, sort/filter menus.

## Required Anatomy

- trigger or virtual anchor;
- menu surface;
- item;
- item label;
- optional icon;
- shortcut label;
- checkbox/radio indicator;
- submenu indicator;
- separator;
- group label.

## Required State

```text
openPhase
focusedItemId
activeSubmenuPath
commandStates
restoreTarget
typeaheadBuffer
```

## Keyboard Profile

MUST support:

- Up/Down item focus;
- Home/End;
- Enter activation;
- Space checkbox/radio activation;
- Right submenu open;
- Left submenu close;
- Escape close and restore focus;
- printable typeahead;
- Shift + F10/context key for context menu.

## Semantic Profile

MUST expose:

- menu;
- menuitem;
- menuitemcheckbox;
- menuitemradio;
- separator;
- disabled;
- checked;
- has popup;
- expanded.

## Command Profile

Command identity is stable. Labels are presentation.

Renderer receives `MenuCommands`, not product callbacks.

## Disabled Policy

Disabled items MAY be focusable in arrow navigation but MUST NOT activate.
Policy must be explicit.

## Conformance Gates

- keyboard open;
- right-click open;
- submenu stack;
- disabled item policy;
- command identity separate from label;
- focus restore;
- no direct renderer product callback.

## Stop Rules

- Do not put arbitrary focusable widgets inside menu.
- Do not use menu for complex forms.
- Do not use labels as command ids.
