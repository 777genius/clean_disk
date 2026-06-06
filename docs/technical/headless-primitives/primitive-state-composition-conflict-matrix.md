# Primitive State Composition Conflict Matrix

## Status

Implementation standard for resolving state conflicts when Headless primitives
are composed.

## Purpose

Real products combine primitives: TreeGrid inside SplitPane, ContextMenu from a
row, Dialog from a menu item, Tooltip over icon buttons, StatusRegion updates
after commands. This file defines conflict rules so composition does not create
keyboard traps, stale focus, duplicate announcements, or unsafe product actions.

## Standards And References

- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Dialog Modal:
  https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Menu Button:
  https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/
- WAI-ARIA APG Tooltip:
  https://www.w3.org/WAI/ARIA/apg/patterns/tooltip/
- MDN ARIA live regions:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions

## Conflict Categories

```text
focus conflict
selection conflict
overlay conflict
command conflict
busy conflict
disabled conflict
announcement conflict
virtualization conflict
authority conflict
```

## Global Precedence

Highest to lowest:

1. modal alert dialog;
2. modal dialog;
3. active menu/context menu;
4. active text editing scope;
5. focused composite primitive;
6. application global command scope;
7. passive tooltip/status.

Higher scopes can block lower scopes. Lower scopes must not trigger higher-risk
commands while blocked.

## Focus Conflict Matrix

TreeGrid row opens ContextMenu:

- menu receives focus;
- row logical focus is preserved;
- closing menu restores row focus if still valid.

ContextMenu opens Dialog:

- menu closes or suspends first;
- dialog captures menu origin and row logical origin;
- closing dialog restores to row or trigger fallback.

Dialog opens nested Dialog:

- parent dialog remains inert behind child;
- child close restores to parent focus target;
- parent close closes child first.

Tooltip appears over focused icon:

- tooltip never receives focus;
- trigger remains focused;
- Escape can close tooltip without activating trigger.

SplitPane resize while TreeGrid focused:

- resize handle receives focus only if user enters handle;
- TreeGrid logical focus preserved;
- pane resize must not reset TreeGrid controller state.

## Selection Conflict Matrix

Selection is local to collection primitive unless app explicitly coordinates it.

Rules:

- TreeGrid selection does not equal cleanup queue;
- menu item focus does not select TreeGrid row;
- dialog checkbox selection is separate from background TreeGrid selection;
- drag preview does not change selection until command commits;
- stale virtual row cannot remain selected silently after data version change.

## Command Conflict Matrix

`Enter`:

- in menu activates menu item;
- in dialog follows default action only if safe;
- in TreeGrid activates/toggles by focus policy;
- in text input commits edit or inserts newline by field policy.

`Escape`:

- closes tooltip/menu/dialog by stack order;
- cancels drag/resize preview;
- exits edit mode before closing outer dialog if edit owns focus;
- never triggers destructive action.

`Space`:

- toggles checkbox/button/menu item;
- selects TreeGrid row only when focus is row and policy says so;
- scrolls page only when no component handles it.

## Busy Conflict Matrix

When parent is busy:

- child interactive commands may be disabled or queued by policy;
- status announcements are throttled;
- menu opening from stale row may be blocked;
- dialog confirmation must show current validated state, not stale busy state.

When child is busy:

- parent focus remains stable;
- child status does not steal focus;
- child failure does not reset parent state unless policy says so.

## Disabled Conflict Matrix

Disabled in Headless means command is unavailable. Visual disabled is not
enough.

Rules:

- disabled command cannot run by keyboard, pointer, or semantics action;
- disabled menu item focus policy is component-specific and documented;
- disabled row may still be focusable if reading/navigation policy needs it;
- disabled destructive action must explain required condition through
  presentation layer.

## Announcement Conflict Matrix

Status and live regions:

- do not announce every focus movement;
- do not announce every scroll update;
- do not announce hidden tooltip text as status;
- suppress duplicate completion messages;
- assertive messages require severity policy.

Dialog:

- opening dialog announcement takes precedence over background status;
- background progress updates should be quiet while modal confirmation is open.

## Authority Conflict Matrix

Headless state is never product authority.

Forbidden:

- renderer button deletes data directly;
- selected row becomes delete target without app validation;
- stale context menu action targets removed row;
- dialog confirmation uses old async result;
- tooltip/status contains required destructive confirmation.

Required:

- command passes through application use case;
- app validates target and capability;
- destructive action uses current plan;
- stale target disables risky command.

## Required Tests

Automated:

- each precedence layer blocks lower-risk conflict;
- Escape stack closes correct component;
- focus restore through TreeGrid -> Menu -> Dialog;
- status throttled while modal open;
- disabled command cannot run through alternate input;
- stale selected row loses authority.

Manual:

- keyboard-only composition path;
- screen reader menu-to-dialog path;
- reduced motion overlay path;
- high contrast focus path.

## Stop Rules

- Do not allow renderer callbacks to bypass command precedence.
- Do not let tooltip own focus.
- Do not let selection imply product authority.
- Do not let disabled visual state differ from command state.
- Do not let background shortcuts run while modal dialog is active.
