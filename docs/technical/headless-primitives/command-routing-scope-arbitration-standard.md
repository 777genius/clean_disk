# Command Routing Scope And Arbitration Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Menu and Menubar Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/menubar/
- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- MDN `aria-keyshortcuts`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-keyshortcuts
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- WCAG 2.1.4 Character Key Shortcuts: https://www.w3.org/WAI/WCAG22/Understanding/character-key-shortcuts.html

## Scope

This standard defines how Headless routes commands through focus scopes,
overlays, menus, tables, text fields, command palettes, and app shells.

It applies to:

- keyboard shortcuts;
- toolbar buttons;
- menu items;
- context menu commands;
- command palette actions;
- native app menu commands;
- row actions;
- overlay dismiss commands;
- undo and redo;
- destructive action guards.

It does not execute product commands. It determines which command is eligible,
where it is routed, and why it is blocked.

## Decision Options

Option A: Direct callbacks from every control - 🎯 4   🛡️ 4   🧠 2, about
100-250 LOC.

- Simple.
- Cannot resolve conflicts between text editing, table navigation, menus, and
  app shortcuts.

Option B: One global command bus - 🎯 5   🛡️ 5   🧠 4, about 300-700 LOC.

- Centralized.
- Too blunt for nested scopes, overlays, modal stacks, and focus ownership.

Option C: Scoped command router with arbitration rules - 🎯 9   🛡️ 9
🧠 7, about 900-1800 LOC.

- Accepted direction.
- Commands resolve from focused scope outward.
- Disabled reasons, capability gates, and provenance stay attached.

## Accepted Direction

Headless must define a scoped command router.

Routing order:

1. active text editor or IME composition;
2. active modal overlay;
3. focused composite widget;
4. focused item or row;
5. nearest command scope;
6. route scope;
7. window scope;
8. app scope;
9. native shell scope.

Each stage can handle, pass, block, or defer.

## Command Resolution

Command resolution returns:

- command id;
- target scope;
- target reference;
- enabled state;
- disabled reason;
- capability requirement;
- policy requirement;
- provenance requirement;
- fallback command;
- user-facing status.

Renderer buttons and menu items display this resolution. They do not compute it
themselves.

## Arbitration Rules

Rules:

- text editing shortcuts win inside editable text;
- IME composition blocks conflicting shortcuts;
- modal overlay owns Escape unless nested overlay policy says otherwise;
- command palette owns its query input while open;
- focused grid owns arrow key navigation;
- app-level shortcuts cannot bypass disabled focused command;
- destructive commands route to review or confirmation flow;
- hidden commands cannot be invoked by shortcut.

## Repeat And Reentry Rules

Commands declare:

- repeatable;
- idempotent;
- submitting behavior;
- cancellation behavior;
- debounce or throttle;
- stale resolution behavior.

Default:

- non-repeatable command disables while submitting;
- destructive command requires fresh resolution immediately before dispatch;
- stale command resolution cannot dispatch.

## Menu And Toolbar Rules

Menus and toolbars must render the same command facts:

- label key;
- shortcut;
- enabled state;
- checked or selected state;
- submenu state;
- danger hint;
- disabled reason;
- capability repair action.

Native menu, context menu, toolbar, and command palette should not each invent
different command ids.

## Clean Disk Requirements

Clean Disk command router must cover:

- scan;
- pause;
- cancel;
- refresh;
- reveal in Finder or Explorer;
- copy path;
- sort and filter;
- add to queue;
- remove from queue;
- validate delete plan;
- move to Trash;
- export report;
- open settings.

Rules:

- move-to-trash command is never handled by row renderer directly;
- stale delete plan blocks command at router;
- shortcut and button share same command resolution;
- remote read-only policy disables destructive command everywhere.

## API Shape Sketch

```text
CommandRouter
  resolve(commandId, scope, provenance)
  dispatch(commandId, scope, provenance)
  registerScope(scope)
  invalidate(scope, reason)

CommandResolution
  state
  targetRef
  disabledReason
  capability
  policy
  fallback
```

## Conformance Scenarios

- Ctrl+C in text input copies text, not selected row path;
- Escape closes topmost dialog before app-level cancel;
- disabled toolbar command is also disabled in native menu;
- context menu command uses same id as command palette;
- destructive shortcut opens confirmation, not direct delete;
- command resolution updates after capability changes;
- hidden command cannot be invoked by automation;
- IME composition blocks conflicting character shortcut.

## Failure Catalog

- button callback bypasses command router;
- shortcut enabled while menu item disabled;
- text input loses standard editing shortcut;
- Escape closes route behind modal;
- row renderer performs destructive action directly;
- command ids differ across surfaces;
- stale command resolution dispatches after reconnect;
- disabled reason missing from menu;
- automation invokes hidden command;
- native menu bypasses app policy.

