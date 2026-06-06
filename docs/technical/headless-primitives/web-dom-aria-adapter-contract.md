# Web DOM ARIA Adapter Contract

## Status

Future adapter contract for mapping Headless semantic intent to web DOM and
ARIA. This is not an MVP requirement for Clean Disk, but it constrains public
Headless APIs so web support remains possible.

## Purpose

Flutter web Semantics can be enough for many apps, but a public Headless UI kit
may eventually need a DOM/ARIA bridge for stronger web interoperability. The
core API must not block that path.

## Standards And References

- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MDN ARIA roles:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles
- MDN `aria-activedescendant`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-activedescendant
- MDN `<dialog>`:
  https://developer.mozilla.org/en-US/docs/Web/HTML/Element/dialog
- MDN Popover API:
  https://developer.mozilla.org/en-US/docs/Web/API/Popover_API

## Core Rule

The web adapter maps Headless semantic facts to DOM/ARIA. Core Headless must
not expose DOM ids, ARIA strings, or browser-only concepts as required
contracts.

## Adapter Responsibilities

The web adapter may own:

- DOM role mapping;
- `aria-*` attribute mapping;
- DOM id generation;
- active descendant strategy;
- roving tabindex strategy;
- inert background handling;
- popover/dialog integration;
- live region DOM container;
- browser accessibility tree diagnostics.

Core Headless owns:

- semantic role intent;
- focus facts;
- relationship facts;
- collection facts;
- command model;
- state machines;
- privacy classes.

## Focus Strategy Options

Roving tabindex:

- DOM focus moves to active item;
- can work well for simple visible composites;
- virtualization must handle unmounted focus target.

Active descendant:

- DOM focus remains on root;
- active item is identified by generated id;
- can work well for virtualized composites;
- requires stable mounted descendant or equivalent strategy.

Adapter chooses strategy per component and platform evidence. Core exposes
enough facts for both.

## DOM Id Policy

Generated ids:

- are adapter-owned;
- are stable for mounted semantic node lifetime;
- never contain product labels;
- never contain raw row keys unless explicitly hashed;
- are not persisted;
- are not used by application code.

## ARIA Attribute Mapping

TreeGrid likely maps:

- `role="treegrid"`;
- `role="row"`;
- `role="gridcell"`;
- `aria-rowcount`;
- `aria-colcount`;
- `aria-rowindex`;
- `aria-colindex`;
- `aria-level`;
- `aria-expanded`;
- `aria-selected`;
- `aria-sort`;
- `aria-activedescendant` if active-descendant strategy is used.

Dialog likely maps:

- `role="dialog"` or `role="alertdialog"`;
- `aria-modal`;
- `aria-labelledby`;
- `aria-describedby`;
- inert background or equivalent.

Menu likely maps:

- `role="menu"`;
- `role="menuitem"`;
- `aria-haspopup`;
- `aria-expanded`;
- `aria-disabled`;
- checked state for check/radio items.

Status likely maps:

- `role="status"` or `role="alert"` by severity;
- `aria-live`;
- `aria-atomic`;
- `aria-busy`.

## Native HTML Preference

Use native web platform semantics when they meet the contract:

- real buttons for actions;
- native dialog where it satisfies modal and focus requirements;
- text inputs for editable text;
- native focus where compatible.

Do not use ARIA to recreate native behavior poorly.

## Flutter Web Caveat

If Flutter owns the DOM, direct DOM ARIA manipulation may be brittle. The
adapter must be designed as optional future work and tested against Flutter web
rendering behavior. If direct DOM control is not stable, keep Flutter Semantics
as the supported web path and document the gap.

## Evidence

Automated:

- DOM role/attribute snapshot in web harness;
- active descendant target exists;
- id redaction;
- virtual row bounded DOM;
- dialog inert/focus trap;
- live region stable container.

Manual:

- NVDA + Firefox;
- NVDA + Chrome;
- VoiceOver + Safari;
- VoiceOver + Chrome;
- keyboard-only web run.

## Stop Rules

- Do not make ARIA strings required in core public API.
- Do not expose generated DOM ids to apps.
- Do not use ARIA where native semantics solve the problem.
- Do not claim DOM ARIA support through Flutter Semantics without evidence.
- Do not let direct DOM patching fight Flutter's renderer.
