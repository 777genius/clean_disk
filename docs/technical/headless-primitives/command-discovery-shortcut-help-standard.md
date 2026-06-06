# Command Discovery Shortcut Help Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `aria-keyshortcuts`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-keyshortcuts
- WCAG 2.1.4 Character Key Shortcuts: https://www.w3.org/WAI/WCAG22/Understanding/character-key-shortcuts.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WAI-ARIA APG Menu and Menubar Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Flutter focus system: https://docs.flutter.dev/ui/interactivity/focus

## Scope

This standard covers shortcut display, command discovery, keyboard help dialogs,
command palettes, menu shortcut labels, tooltip shortcut hints, conflict
warnings, disabled shortcut behavior, remapping entry points, and accessibility
help surfaces.

It complements the keyboard shortcut conflict standard. That file decides
conflicts. This file makes commands discoverable and explainable.

## Decision Options

1. `CommandDiscoveryRegistry` shared by menu, toolbar, palette, help, and
   `aria-keyshortcuts` adapters - 🎯 9   🛡️ 9   🧠 8, roughly 900-2000 LOC.
   Best fit. It prevents shortcut docs from drifting away from real commands.
2. Write shortcut labels manually inside each renderer -
   🎯 4   🛡️ 5   🧠 3, roughly 200-800 LOC.
   Fast, but stale labels and inaccessible shortcuts are almost guaranteed.
3. Do not expose shortcut metadata until later -
   🎯 3   🛡️ 4   🧠 2, roughly 0-200 LOC.
   Simpler now, but poor for desktop productivity and public Headless quality.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- command id;
- command label;
- command description;
- shortcut binding;
- platform display string;
- availability;
- disabled reason;
- danger state;
- scope;
- remap/disable policy;
- `aria-keyshortcuts` export when suitable;
- help grouping;
- privacy class for command context.

Renderer owns:

- visual shortcut label;
- keyboard help layout;
- command palette presentation;
- tooltip hint layout;
- high contrast styling.

Application owns:

- command execution;
- platform-specific bindings;
- user remapping persistence;
- capability and policy gating;
- localization.

## Discovery Surfaces

Menu:

- shows shortcuts for commands;
- disabled commands retain reason where discoverability matters;
- destructive commands show consequence through label/description.

Tooltip:

- may show shortcut hint;
- must not be the only place shortcut is documented;
- must follow tooltip standard.

Keyboard help dialog:

- lists commands by scope;
- includes how to disable/remap single-character shortcuts;
- searchable if large;
- uses dialog standard.

Command palette:

- exposes command labels and shortcuts;
- respects current scope and disabled reasons;
- must not bypass app policy.

Accessibility help:

- documents keyboard model;
- documents bypass navigation;
- documents screen reader caveats where known.

## Shortcut Rules

Single-character shortcuts:

- must be turn-off-able, remappable, or active only on focus according to WCAG;
- should be avoided globally;
- are risky with speech input.

Disabled command:

- shortcut must be disabled too;
- help may show disabled reason;
- renderer cannot execute command path.

Destructive command:

- shortcut may open review/confirmation;
- shortcut must not directly commit destructive action;
- stale validation disables command.

## `aria-keyshortcuts` Mapping

Use when:

- shortcut activates or focuses a specific element;
- mapping is stable in current scope;
- shortcut is not misleading due to platform conflict.

Do not use when:

- shortcut is global and context-dependent without clear target;
- shortcut is hidden experimental behavior;
- shortcut could expose sensitive command context.

Always keep:

- visible shortcut hint where useful;
- help surface;
- actual Flutter/JS binding in sync with metadata.

## Clean Disk Usage

Commands:

- start scan;
- pause/resume;
- cancel scan;
- search;
- sort/filter;
- reveal in Finder/Explorer;
- add/remove from queue;
- open details;
- move to trash review.

Risk rule:

- move-to-trash shortcut can open cleanup workflow;
- it must not execute move-to-trash directly.

## Conformance Scenarios

- shortcut shown in menu matches actual binding;
- disabled command shortcut does nothing and exposes reason;
- keyboard help lists current scope commands;
- single-character shortcuts can be disabled/remapped or are focus-scoped;
- `aria-keyshortcuts` is present only where accurate;
- command palette cannot run stale destructive command;
- platform display string changes for macOS/Windows/Linux;
- help surface does not include raw paths or tokens.

## Failure Catalog

- Shortcut label says `Cmd+F` but binding is `Ctrl+F`.
- Disabled button still runs through keyboard shortcut.
- Single-letter shortcut breaks speech input.
- Shortcut directly deletes selected items.
- Help dialog is not keyboard reachable.
- Command palette bypasses policy checks.
