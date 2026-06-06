# Semantics Adapter Gap Analysis Standard

## Status

Implementation standard for mapping Headless semantic intent to Flutter,
Flutter web, and optional web ARIA adapters.

## Purpose

Headless primitives need accessibility contracts that survive across Flutter
desktop, Flutter mobile, Flutter web, and future web-specific bridges. Flutter
Semantics is not a direct ARIA DOM API. Core Headless must expose platform-
neutral facts, then adapters map those facts to each runtime.

## Standards And References

- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- MDN ARIA roles:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles
- MDN `treegrid` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/treegrid_role
- MDN ARIA live regions:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions
- Flutter accessibility:
  https://docs.flutter.dev/ui/accessibility
- Flutter web accessibility:
  https://docs.flutter.dev/ui/accessibility/web-accessibility
- Flutter semantics API:
  https://api.flutter.dev/flutter/semantics/

## Core Rule

Core primitives expose semantic intent, not ARIA attributes.

Allowed core concepts:

```text
role intent
name
description
value
state facts
relationship facts
collection facts
command facts
live message facts
focus facts
```

Forbidden core concepts:

- direct `aria-*` string maps;
- DOM ids as required public API;
- browser-specific focus hacks;
- screen-reader-specific branches;
- product labels as identity.

## Semantic Fact Model

Every complex primitive should be able to produce a semantic snapshot:

```text
SemanticNodeIntent
  key
  roleIntent
  name
  description
  value
  state
  relationships
  collection
  commands
  privacyClass
```

State facts:

- focused;
- selected;
- checked;
- expanded;
- disabled;
- readonly;
- busy;
- invalid;
- sorted;
- modal;
- current.

Collection facts:

- row count;
- column count;
- row index;
- column index;
- level;
- set size;
- position in set;
- visible range.

Relationship facts:

- labelled by;
- described by;
- controls;
- owns;
- active descendant candidate;
- focus origin;
- modal parent.

## Flutter Adapter Mapping

Flutter adapter maps semantic facts to:

- `Semantics`;
- `MergeSemantics`;
- `ExcludeSemantics`;
- semantic labels;
- semantic values;
- enabled/disabled flags;
- selected/checked/expanded flags where available;
- semantic actions;
- custom semantic actions when needed;
- `SemanticsService.announce` only through status policy.

Adapter must preserve:

- focus versus selection;
- visible rows versus total logical rows;
- disabled versus absent;
- name versus description;
- status versus alert urgency;
- renderer visual state versus semantic state.

## Web ARIA Adapter Mapping

Future web adapter may map facts to:

- role;
- `aria-label` or `aria-labelledby`;
- `aria-describedby`;
- `aria-expanded`;
- `aria-selected`;
- `aria-disabled`;
- `aria-readonly`;
- `aria-rowcount`;
- `aria-colcount`;
- `aria-rowindex`;
- `aria-colindex`;
- `aria-level`;
- `aria-posinset`;
- `aria-setsize`;
- `aria-sort`;
- `aria-activedescendant`;
- `aria-live`;
- `aria-busy`;
- `aria-modal`.

The adapter chooses roving tabindex or active descendant. Core Headless only
exposes enough focus facts for either strategy.

## Known Gap Categories

Role gap:

- Flutter may not expose every ARIA role one-to-one.
- Adapter should degrade to clear labels and actions instead of fake roles.

Relationship gap:

- some ARIA relationships may not map directly to native semantics.
- adapter should keep internal relationship facts for tests and future bridges.

Virtualization gap:

- web ARIA can expose row counts and indexes;
- Flutter native semantics may not announce them the same way.
- conformance must record platform-specific behavior.

Live region gap:

- `status` and `alert` behavior varies by platform;
- repeated messages may be swallowed;
- assertive announcements can interrupt too aggressively.

Focus gap:

- screen reader virtual cursor can diverge from Flutter focus;
- adapter must not assume focus event equals spoken cursor movement.

## Privacy Boundary

Semantic labels can contain product data. Therefore:

- core diagnostics must not log semantic labels;
- conformance fixtures use synthetic labels;
- production telemetry records semantic fact types, not label text;
- support bundles redact semantic trees by default.

## Required Tests

Unit:

- semantic snapshot for every state;
- privacy classification of labels and values;
- role intent conversion;
- collection facts for virtualized rows;
- live message throttle.

Widget:

- `tester.ensureSemantics()`;
- label and action presence;
- no offscreen semantic row flood;
- focus/selection distinction;
- disabled state exposed.

Manual:

- screen reader reads expected name;
- screen reader does not announce hidden rows;
- live status does not move focus;
- virtualized tree grid exposes useful context.

## Stop Rules

- Do not place ARIA attributes in core Dart API.
- Do not claim web ARIA parity from Flutter Semantics alone.
- Do not log semantic labels in diagnostics.
- Do not expose offscreen virtualized rows as active semantics.
- Do not use status announcements as required confirmation.
