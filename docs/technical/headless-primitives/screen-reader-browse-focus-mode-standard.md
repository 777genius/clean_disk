# Screen Reader Browse And Focus Mode Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN `application` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/application_role
- MDN `document` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/document_role
- MDN `feed` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/feed_role
- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- ARIA-AT: https://w3c.github.io/aria-at/

## Scope

This standard defines how Headless primitives behave with screen reader browse,
virtual cursor, forms, focus, and application-like modes.

It applies to:

- TreeGrid;
- data grids;
- command palettes;
- menus;
- dialogs;
- document-like details panes;
- logs;
- feeds;
- help panels;
- rich content inside composite widgets.

It does not prescribe a specific screen reader. It defines mode-aware
semantics and testing obligations.

## Decision Options

Option A: Use application role for the whole app - 🎯 2   🛡️ 2   🧠 2,
about 50-150 LOC.

- Gives keyboard control to app.
- Breaks browse mode and can make reading content harder.

Option B: Avoid all application-like semantics - 🎯 6   🛡️ 6   🧠 4,
about 200-500 LOC.

- Safer for content reading.
- Complex widgets may not receive expected keyboard behavior.

Option C: Mode-aware semantics per primitive and content island - 🎯 9
🛡️ 9   🧠 8, about 1000-2200 LOC.

- Accepted direction.
- Composite widgets use appropriate roles.
- Document-like regions remain readable.
- `application` role is exceptional and tightly scoped.

## Accepted Direction

Headless must not apply `application` role broadly.

Each primitive declares:

- reading mode expectation;
- focus mode expectation;
- keyboard ownership;
- browseable content regions;
- escape path;
- screen reader test matrix;
- mode transition notes.

## Mode Concepts

Concepts:

- `browseMode`: screen reader virtual cursor reads page content.
- `focusMode`: keyboard input goes to focused widget.
- `formsMode`: screen reader passes input to form controls.
- `applicationMode`: screen reader treats region like app control area.
- `documentIsland`: readable content inside an application-like widget.

Headless should design for transitions between these states without requiring
users to know implementation details.

## Application Role Rules

Use application-like semantics only when:

- native HTML or normal ARIA patterns cannot express behavior;
- keyboard model is app-like and documented;
- there is a clear entry and exit path;
- child content that should be read has document semantics;
- screen reader lab evidence exists.

Do not use application role:

- for ordinary app shell;
- for TreeGrid by default;
- to capture shortcuts globally;
- to hide bad focus design;
- for content-heavy details panels.

## Document Island Rules

When rich readable content appears inside a composite:

- expose it as document-like region where platform supports it;
- allow focus entry;
- allow return to parent widget;
- preserve reading order;
- avoid trapping virtual cursor;
- label the region.

Clean Disk examples:

- details inspector notes;
- help panel;
- receipt explanation;
- diagnostics report preview.

## Grid And TreeGrid Rules

TreeGrid should:

- expose row and cell semantics;
- support keyboard focus movement;
- avoid forcing whole app into application mode;
- provide details path for long cell content;
- not rely on browse mode for row navigation;
- preserve accessible row summary.

Screen reader behavior varies. Conformance must include manual lab scenarios
for VoiceOver, NVDA, and at least one browser combination where feasible.

## Clean Disk Requirements

Clean Disk must support:

- navigating tree table by keyboard;
- reading selected row details;
- using command palette without losing route context;
- reading cleanup receipt text;
- reading logs without progress spam;
- exiting menus and dialogs predictably.

Rules:

- do not put entire Clean Disk UI under application role;
- details and receipts must remain readable;
- TreeGrid keyboard model must be documented and testable.

## API Shape Sketch

```text
ScreenReaderModeContract
  primitiveType
  expectedMode
  keyboardOwnership
  browseableRegions
  entryCommand
  exitCommand
  testScenarios

DocumentIsland
  label
  ownerPrimitive
  focusEntry
  returnTarget
```

## Conformance Scenarios

- screen reader user can read receipt text in details pane;
- entering TreeGrid does not trap user in app-wide mode;
- dialog close returns focus to safe target;
- command palette Escape exits popup before route-level command;
- log region can be read without every progress update;
- document island inside composite has label and return path;
- TreeGrid row summary is announced in focus navigation;
- application role, if used, has explicit evidence and scope.

## Failure Catalog

- entire app marked as application;
- screen reader browse shortcuts disabled everywhere;
- rich text inside widget unreadable;
- no escape path from focus mode;
- TreeGrid exposes only visual text with no row structure;
- details pane treated as inert visual content;
- screen reader lab skipped for complex widget;
- document region steals app shortcuts;
- live log spam prevents reading;
- role choice made by renderer without Headless contract.

