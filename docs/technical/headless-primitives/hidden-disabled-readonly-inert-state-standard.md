# Hidden Disabled Readonly And Inert State Standard

## Status

Implementation standard for unavailable, hidden, readonly, inert, collapsed,
and disabled states across Headless primitives.

## Purpose

Unavailable state is one of the easiest ways to create false accessibility.
`disabled`, `aria-disabled`, `readonly`, `aria-hidden`, `hidden`, `inert`, and
collapsed visual state mean different things. Headless needs a single state
taxonomy so renderers and adapters do not accidentally create focusable hidden
controls or commandable disabled actions.

## Standards And References

- MDN `aria-hidden`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-hidden
- MDN `inert`:
  https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inert
- MDN ARIA attributes:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Dialog Modal:
  https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/

## Core Rule

Visual availability, semantic availability, focusability, and commandability
are separate facts.

```text
visible
  != exposed to accessibility tree
  != focusable
  != commandable
  != editable
```

## State Taxonomy

Hidden:

- not visible and not available;
- usually not in semantics;
- not focusable;
- not commandable.

Collapsed:

- parent is visible;
- child content not displayed;
- child content not focusable;
- parent exposes expanded/collapsed state.

Disabled:

- visible but action unavailable;
- not commandable by any input method;
- focusability depends on component pattern.

Readonly:

- visible and focusable by policy;
- value can be read and selected;
- editing command unavailable.

Inert:

- subtree is not interactive;
- used for background content under modal or inactive app regions;
- not focusable or clickable.

Unavailable reason:

- product/application explanation for disabled or readonly state;
- presentation decides how to display it.

## Focus Rules

Focusable disabled:

- allowed in menu/menu-like navigation when pattern expects disabled items to
  be discoverable;
- command remains unavailable;
- semantic state must say unavailable.

Non-focusable disabled:

- appropriate for ordinary button/action controls;
- keyboard navigation skips it;
- explanation must be available elsewhere if needed.

Hidden/inert:

- never has active focus;
- closing/hiding a focused subtree must restore focus first;
- virtualized unmount uses logical focus fallback.

## Web Adapter Mapping

Possible mappings:

- native `disabled` for real form controls when appropriate;
- `aria-disabled` for custom controls that remain perceivable;
- `readonly` or `aria-readonly` for read-only editable/grid cells;
- `hidden` or display none for removed content;
- `aria-hidden` only for content that must be hidden from accessibility tree;
- `inert` for modal background or inactive subtree where supported.

Warnings:

- do not put `aria-hidden="true"` on focusable elements;
- `aria-hidden` on a parent hides descendants;
- `aria-hidden` does not visually hide content;
- `inert` removes descendants from focus and accessibility tree.

## Flutter Adapter Mapping

Flutter adapter should expose:

- enabled/disabled semantics where available;
- readonly semantic facts where possible;
- excluded semantics only for redundant or hidden content;
- hit testing disabled for inert areas;
- focus traversal policy that skips unavailable targets unless pattern allows.

Renderer state must match command state.

## Command Rules

Disabled command:

- does not run by pointer;
- does not run by keyboard;
- does not run by semantic action;
- does not run by controller command unless low-level test bypass is explicit;
- reports unavailable reason where appropriate.

Readonly value:

- copy/select may be allowed;
- edit/delete/mutate unavailable;
- status explains why if user attempts mutation.

## Clean Disk Safety

For Clean Disk:

- stale delete button is disabled and not commandable;
- protected system item can stay focusable/readable but not queued by command;
- permission-denied nodes are visible with reason, not silently hidden;
- modal confirmation makes background inert;
- hidden filtered rows cannot remain destructive targets.

## Required Tests

Automated:

- disabled command cannot run through pointer/keyboard/semantics;
- hidden focused subtree restores focus;
- inert background blocks shortcut;
- readonly cell copy allowed/edit blocked;
- aria-hidden equivalent never contains focusable target in web adapter;
- disabled menu item focus policy matches component spec.

Manual:

- screen reader hears disabled or readonly state;
- keyboard user can discover unavailable reason where needed;
- modal background is not reachable;
- hidden/collapsed content is not announced.

## Stop Rules

- Do not use visual opacity as disabled state.
- Do not use `aria-hidden` on focusable content.
- Do not let disabled commands run through alternate input.
- Do not hide permission errors as empty state.
- Do not make modal background interactive.
