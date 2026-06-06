# Toolbar And Command Bar Accessibility Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Toolbar Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/toolbar/
- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MDN `toolbar` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/toolbar_role
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Flutter Focus: https://docs.flutter.dev/ui/interactivity/focus
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers compact command surfaces: top toolbars, row action bars,
floating command bars, table header command groups, and details pane command
groups. It does not cover menu bars, navigation tabs, or context menus.

For Clean Disk this applies to scan, pause, cancel, refresh, search, filter,
sort, settings, reveal, add to queue, remove from queue, and destructive
confirmation command surfaces.

## Decision Options

1. Headless `CommandBar` plus `Toolbar` semantics adapter - 🎯 9   🛡️ 9   🧠 6, roughly 500-900 LOC.
   Best fit. The behavior model stays command-centric while adapters emit
   platform toolbar semantics when the visual surface is a compact group of 3
   or more controls.
2. Treat every command surface as a menu or menubar - 🎯 4   🛡️ 6   🧠 7, roughly 800-1400 LOC.
   Useful only for menu-like navigation. It is too heavy for persistent scan
   controls and can create misleading semantics for buttons that are always
   visible.
3. Plain row of independent buttons - 🎯 6   🛡️ 7   🧠 3, roughly 150-300 LOC.
   Acceptable for 1-2 controls. It does not scale to dense productivity
   toolbars because it creates too many tab stops and loses grouping intent.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- command identity, enabled state, pending state, destructive state, shortcut
  metadata, and accessible command labels;
- roving focus state for toolbar groups;
- group orientation and wrapping policy;
- keyboard command dispatch;
- disabled command discoverability policy;
- command ordering, grouping, separators, and overflow placement;
- semantics facts for toolbar, group, button, toggle, split button, and
  menu-button adapters.

Renderer owns:

- visual density, icons, color, spacing, hover and pressed styles;
- overflow affordance visuals;
- tooltip visuals;
- shortcut glyph formatting;
- platform-specific menu styling.

Application owns:

- command authorization and side effects;
- confirmation policy for destructive commands;
- command analytics and audit events;
- localized display labels and hints.

## Required API Shape

`CommandDescriptor` must include:

- stable command id;
- visible label text when present;
- accessible label override only when no visible label exists;
- optional description;
- icon slot id;
- shortcut set;
- enabled, disabled reason, loading, pressed, checked, selected, and danger
  states;
- command kind: action, toggle, radio option, menu trigger, split action,
  navigation, text input, or separator;
- privacy class for label, hint, and status text;
- confirmation requirement: none, soft, explicit, validated plan.

`CommandBarController` must expose:

- focused command id;
- last focused command id per bar;
- overflow state;
- command invocation stream;
- command availability updates;
- focus movement commands;
- shortcut registration and conflict results.

## Keyboard Contract

MUST:

- expose one tab stop for a toolbar group when it contains 3 or more
  interactive controls;
- move between toolbar controls with arrow keys according to orientation;
- support `Home` and `End` for first and last command when enabled by the
  primitive config;
- remember the last focused command when focus returns to the toolbar unless
  product config requests first enabled command;
- activate buttons with `Enter` and `Space`;
- keep text fields and arrow-key-heavy controls at the end of a toolbar group
  or split them into a separate group;
- preserve visible focus on the toolbar group and on the focused command;
- route shortcuts through Flutter `Shortcuts` and `Actions`, not through ad hoc
  widget callbacks.

SHOULD:

- keep disabled destructive commands focusable when discoverability is important,
  but announce disabled state and reason;
- avoid wrapping focus in toolbars unless the product explicitly chooses wrap;
- expose shortcut hints separately from accessible names so names stay stable;
- provide a documented focus shortcut only for high-frequency product surfaces.

MUST NOT:

- put every icon button in the global tab sequence inside a dense toolbar;
- use a toolbar role for fewer than 3 controls unless a platform adapter has a
  good reason;
- make a search box the first item in a horizontal toolbar that also uses left
  and right arrows for command navigation;
- hide disabled commands without an alternative discoverability path when the
  command is core to the workflow.

## Semantics Contract

Web adapter:

- maps compact command groups to `role="toolbar"`;
- sets `aria-orientation` for vertical toolbars;
- uses `aria-labelledby` when a visible group label exists;
- uses `aria-label` only when no visible label exists;
- emits roving `tabindex` or active descendant according to the focus strategy
  selected by the primitive;
- does not put separators in the accessibility tree unless they carry useful
  structure for the platform.

Flutter adapter:

- uses `Focus`, `FocusTraversalGroup`, `Actions`, and `Shortcuts` for command
  dispatch;
- uses `Semantics` labels, values, hints, button/toggled/checked/enabled
  states, and custom actions where available;
- keeps icon-only controls labeled through the shared command descriptor;
- uses `ExcludeSemantics` only for decorative icons inside a labeled command.

## Clean Disk Mapping

Top app bar:

- Scan is a primary action outside the dense toolbar group when visually
  prominent.
- Pause, cancel, refresh, search, filter, sort, and settings form command
  groups.
- Search remains a text input and should not be trapped inside arrow navigation
  unless it is last in that group.

Tree row actions:

- reveal, queue, remove, and more actions are not a toolbar per row in the
  accessibility tree by default;
- row action surfaces use context menu or action list semantics to avoid
  hundreds of repeated toolbar landmarks.

Delete queue:

- remove item, confirm checkbox, and move to trash commands are separate command
  groups;
- destructive command stays disabled until a fresh validated delete plan exists.

## Conformance Tests

Minimum tests:

- tab enters the toolbar once and returns to last focused command;
- arrow keys move focus without changing command state;
- `Enter` and `Space` invoke the focused command exactly once;
- disabled command announces disabled reason when focusable;
- search/text input inside toolbar receives text editing keys;
- shortcut conflict report is deterministic;
- icon-only command has a non-empty accessible name;
- visible label appears inside accessible name when a label is visible;
- web adapter emits toolbar role and orientation only when appropriate;
- Flutter semantics tree contains command labels and states without duplicate
  decorative icon names.

## Failure Catalog

- Overusing toolbar landmarks creates noisy navigation.
- Putting every button in tab order makes dense apps exhausting.
- Diverging visible and accessible labels breaks speech control.
- Putting text input before arrow-navigated buttons causes key conflicts.
- Shortcut handlers in renderers bypass command authorization.
- Disabled destructive commands with no reason look broken instead of safely
  blocked.
