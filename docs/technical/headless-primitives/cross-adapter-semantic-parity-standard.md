# Cross Adapter Semantic Parity Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MDN ARIA reference: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Scope

This standard defines how Headless verifies that different adapters expose the
same semantic contract.

It applies to:

- Flutter Material adapter;
- Flutter custom adapter;
- web DOM adapter;
- Web Component adapter;
- chart adapters;
- TreeGrid adapters;
- test adapters;
- future native adapters.

It does not require every platform to expose identical low-level APIs. It
requires equivalent user-facing semantics or declared degradation.

## Decision Options

Option A: Trust adapter docs - 🎯 3   🛡️ 3   🧠 2, about 100-250 LOC.

- Easy.
- Semantic drift is discovered by users.

Option B: Per-adapter manual testing only - 🎯 6   🛡️ 6   🧠 5, about
400-1000 LOC.

- Better evidence.
- Expensive and hard to maintain.

Option C: Semantic parity matrix plus conformance traces - 🎯 9   🛡️ 9
🧠 8, about 1000-2400 LOC.

- Accepted direction.
- Adapters publish machine-checkable semantic facts.
- Manual labs focus on high-risk gaps instead of every behavior.

## Accepted Direction

Every adapter must publish a semantic parity manifest.

Manifest includes:

- primitive support;
- role mapping;
- state mapping;
- keyboard mapping;
- focus mapping;
- announcement mapping;
- disabled and readonly mapping;
- value and range mapping;
- error mapping;
- known degraded cases;
- tested assistive technologies.

## Parity Levels

Levels:

- `equivalent`: user-facing semantics match.
- `platformEquivalent`: different low-level API, same user experience.
- `degraded`: core use works but some semantics missing.
- `visualOnly`: not acceptable for accessible primitive claims.
- `unsupported`: adapter cannot support this primitive.
- `unknown`: not tested.

Public claims must not exceed parity evidence.

## Role And State Rules

Adapter must show how it maps:

- role;
- accessible name;
- description;
- value;
- disabled;
- readonly;
- selected;
- checked;
- expanded;
- busy;
- invalid;
- current;
- focused;
- live status.

If a state cannot be represented, adapter must provide fallback or declare
degradation.

## Keyboard Parity Rules

Keyboard behavior must match Headless command contracts:

- Tab order;
- arrow navigation;
- Home and End;
- Page Up and Page Down;
- Escape;
- Enter and Space;
- typeahead;
- edit mode;
- shortcut conflicts.

Platform-specific shortcuts can differ, but command identity and result must be
equivalent.

## Clean Disk Requirements

Clean Disk needs parity for:

- TreeGrid;
- split panes;
- dialogs;
- cleanup queue;
- progress footer;
- charts;
- context menus;
- command palette.

Rules:

- web and desktop UI can look different but expose equivalent states;
- degraded chart adapter must show accessible table fallback;
- if TreeGrid semantics are degraded on web, product claims must say so.

## API Shape Sketch

```text
SemanticParityManifest
  adapterId
  primitive
  roles
  states
  keyboard
  focus
  announcements
  parityLevel
  knownGaps
  evidenceRefs

ParityConformanceTrace
  scenarioId
  expectedFacts
  actualFacts
  result
```

## Conformance Scenarios

- selected row is exposed as selected in every supported adapter;
- disabled command has reason or equivalent status;
- progressbar value text is equivalent across adapters;
- TreeGrid arrow navigation has same command result;
- dialog modal semantics degrade explicitly if unsupported;
- chart adapter exposes data fallback;
- accessibility test trace links to adapter manifest;
- unsupported feature fails closed instead of claiming support.

## Failure Catalog

- desktop adapter supports selected state but web adapter does not declare gap;
- adapter claims TreeGrid support with visual-only table;
- keyboard shortcuts differ without command mapping;
- progress value text missing on one adapter;
- disabled reason lost in native menu adapter;
- unknown parity treated as equivalent;
- manual lab result not linked to manifest;
- renderer changes role without contract change;
- conformance tests pass only visual snapshots;
- product docs overstate accessibility support.

