# Native Menubar App Command Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Menu and Menubar Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- MDN `menu` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/menu_role
- MDN `menubar` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/menubar_role
- MDN `menuitem` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/menuitem_role
- MDN `aria-keyshortcuts`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-keyshortcuts
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Scope

This standard covers native app menu bars, web menubar adapters, command menu
models, platform shortcut labels, menu item disabled state, checked menu items,
radio menu groups, submenu lifecycle, and menu-to-command registry mapping.

It does not cover website navigation menus. Use disclosure navigation or side
navigation for route navigation unless the UI intentionally behaves like an app
menubar.

## Decision Options

1. `AppCommandMenuModel` shared by native menu adapters, web menubar, command
   palette, and shortcut registry - 🎯 9   🛡️ 9   🧠 8, roughly 1000-2200 LOC.
   Best fit. It gives desktop-grade command discovery without duplicating menu
   logic per platform.
2. Use platform native menus directly in app shell -
   🎯 6   🛡️ 7   🧠 5, roughly 500-1000 LOC.
   Good for one app, but weaker for Headless reuse and web parity.
3. Avoid app menus and rely on toolbar/context menus -
   🎯 4   🛡️ 5   🧠 3, roughly 0-500 LOC.
   Faster, but poor for desktop conventions and discoverability.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- menu tree model;
- command ids;
- labels;
- item kinds: command, checkbox, radio, submenu, separator;
- enabled/disabled state;
- disabled reason;
- checked state;
- shortcut display metadata;
- danger state;
- command scope;
- menu role semantics for web adapter;
- privacy class for labels and context summaries.

Renderer/adapter owns:

- native menu integration;
- web menubar rendering;
- separator visuals;
- platform shortcut glyphs;
- submenu animation;
- hover behavior.

Application owns:

- command execution;
- capability gating;
- platform command registration;
- localization;
- persistence of user menu preferences if any.

## Menu Versus Navigation

Use menubar/menu semantics when:

- items are commands;
- user expects desktop app menu behavior;
- arrow-key composite navigation is implemented;
- submenus and accelerators are present.

Do not use menubar/menu semantics when:

- items are simple page links;
- Tab navigation among links is expected;
- disclosure navigation is enough;
- screen reader reading mode should remain simple.

## Keyboard Behavior

Required for web menubar adapter:

- arrow navigation inside menubar/menu;
- Enter/Space activates item;
- Escape closes submenu;
- Home/End behavior according to orientation;
- Tab exits menu composite;
- disabled items do not execute;
- focus restoration after close.

Native menu adapter:

- should rely on platform behavior where possible;
- still uses shared command ids and enabled state;
- disabled shortcuts must not execute through Flutter shortcut layer.

## Command State Rules

Enabled:

- command can run in current scope.

Disabled:

- command cannot run;
- reason available in help/palette where possible;
- shortcut disabled too.

Checked:

- menuitemcheckbox state maps to boolean setting;
- state updates from application source of truth.

Radio:

- one selected value in group;
- group label is meaningful.

Danger:

- activation opens review/confirmation flow where policy requires;
- menu item styling alone is not enough.

## Clean Disk Menu Shape

Possible groups:

- App: About, Settings, Quit;
- File: Scan Target, Open Recent, Export Report;
- Edit: Copy Path, Copy Summary, Clear Selection;
- View: Toggle Sidebar, Toggle Details, Sort, Filter;
- Scan: Start, Pause, Cancel, Refresh;
- Cleanup: Add to Queue, Remove from Queue, Review Move to Trash;
- Help: Keyboard Shortcuts, Diagnostics, Documentation.

The exact product menu can change, but command ids and safety rules must stay
centralized.

## Privacy Rules

Menu labels should not include:

- raw full paths;
- daemon tokens;
- private query text;
- user account names;
- cleanup target names unless user explicitly invokes context menu over that
  object and app policy allows it.

Use generic labels:

- "Copy Selected Path";
- "Reveal Selected Item";
- "Export Scan Report";
- "Review Move to Trash".

## Conformance Scenarios

- native and web menu use same command ids;
- disabled command shortcut does not execute;
- checked menu item reflects current setting;
- radio group has one selected value;
- danger command opens review flow;
- menu labels are localized;
- web menubar arrow behavior matches APG expectations;
- context-sensitive menu labels do not leak paths in diagnostics.

## Failure Catalog

- Menu item and toolbar button run different code paths.
- Disabled native menu item is disabled but shortcut still runs.
- Web route navigation is implemented as menubar unnecessarily.
- Menu label includes full selected path.
- Danger menu command directly deletes.
- User remaps shortcut but menu still shows old one.
