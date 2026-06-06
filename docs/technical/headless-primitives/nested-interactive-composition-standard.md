# Nested Interactive Composition Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- MDN ARIA roles: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles
- MDN `button` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/button_role
- MDN `link` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/link_role
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html

## Scope

This standard defines how Headless primitives compose when an interactive
surface contains other interactive controls.

It applies to:

- rows with buttons;
- cells with links;
- menu items with checkboxes;
- tabs with close buttons;
- cards with primary action and secondary actions;
- details panels with embedded controls;
- toolbar groups;
- popover triggers inside grids;
- split buttons inside rows.

It does not ban all nested interactivity. It defines ownership, focus, and
activation contracts.

## Decision Options

Option A: Allow arbitrary nesting - 🎯 3   🛡️ 3   🧠 2, about 50-150 LOC.

- Flexible.
- Produces double activation, broken semantics, and unpredictable focus.

Option B: Ban nested interactive controls - 🎯 6   🛡️ 7   🧠 3, about
150-300 LOC.

- Safe.
- Too restrictive for data grids, closeable tabs, and row actions.

Option C: Explicit interactive ownership contracts - 🎯 9   🛡️ 9   🧠 7,
about 800-1600 LOC.

- Accepted direction.
- Parent and child declare focus and activation ownership.
- Conformance can catch illegal nesting and event leaks.

## Accepted Direction

Headless must require composition contracts for nested interactive regions.

Each nested control declares:

- parent primitive;
- child primitive;
- focus participation;
- activation ownership;
- keyboard conflict policy;
- pointer event boundary;
- accessible name relationship;
- command routing relation.

## Interaction Ownership

Ownership modes:

- `parentOwns`: child is visual only and parent handles activation.
- `childOwns`: child has independent focus and command.
- `delegated`: child triggers parent command with child-specific target.
- `cellEdit`: child owns input while edit mode is active.
- `excluded`: composition is invalid.

Default:

- parent row owns selection and expansion;
- child button owns its own command;
- link owns navigation only when it truly navigates;
- menu item owns menu command, not nested arbitrary control.

## Focus Rules

Nested focus must be predictable:

- one tab stop for composite surface unless child controls are explicitly
  tabbable;
- arrow navigation can move within composite;
- Enter and Space route according to focused owner;
- Escape exits child edit mode or nested popup before parent;
- focus ring must identify actual active target;
- child controls must remain reachable by keyboard.

## Activation Rules

Rules:

- row click cannot also trigger child button click;
- child button activation cannot toggle row selection unless delegated;
- primary row action must not be hidden behind unrelated child control;
- double click and context menu policy must be explicit;
- disabled child must not make parent disabled unless policy says so;
- child hover does not imply parent selected.

## Role Rules

Do not create invalid role structures.

Examples:

- a `button` inside a `button` is invalid.
- a row can contain a cell with an action, but the row activation and cell
  action must be separate.
- a link should navigate, not mutate state.
- a menu item should not contain random tabbable descendants unless pattern
  supports it.

## Clean Disk Requirements

Clean Disk TreeGrid rows may contain:

- disclosure control;
- icon;
- name cell;
- size cell;
- percent bar;
- row overflow menu;
- reveal action;
- add-to-queue action.

Rules:

- clicking row selects row;
- clicking disclosure expands row;
- clicking action does not also select unless configured;
- keyboard row mode and cell/action mode are distinct;
- destructive commands are not direct row nested buttons in MVP.

## API Shape Sketch

```text
InteractiveComposition
  parentRef
  childRef
  ownership
  focusPolicy
  activationPolicy
  keyboardPolicy
  pointerBoundary

CompositionValidator
  validate(parent, child)
  explainViolation()
```

## Conformance Scenarios

- row button activation does not toggle row selection twice;
- child link is reachable by keyboard;
- invalid nested button composition fails development validation;
- Escape exits cell edit before collapsing parent row;
- disabled child reports disabled reason independently;
- screen reader announces correct role for child control;
- context menu target is child when invoked on child;
- row selected state and child pressed state remain separate.

## Failure Catalog

- nested button inside button;
- click bubbling triggers parent and child command;
- row selection changes when pressing child action;
- child control unreachable by keyboard;
- screen reader sees one role while visual shows another;
- renderer installs competing gesture detector;
- link mutates state without navigation semantics;
- focus ring appears on parent while child handles key;
- context menu targets wrong owner;
- invalid composition accepted silently.

