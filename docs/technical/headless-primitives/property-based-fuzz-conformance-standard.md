# Property Based Fuzz Conformance Standard

## Status

Accepted as a Headless quality-operations standard. Not implemented yet.

## Source Standards

- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- MDN ARIA reference: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Scope

This standard defines property-based and fuzz-style conformance testing for
Headless primitives.

It applies to:

- selection models;
- focus models;
- keyboard command sequences;
- virtualized range changes;
- tree expand and collapse;
- sorting and filtering;
- overlay stacks;
- command routing;
- semantic refs;
- state migration;
- localization stress inputs.

It does not replace scenario tests. It finds edge cases scenario tests miss.

## Decision Options

Option A: Handwritten scenarios only - 🎯 5   🛡️ 5   🧠 3, about
300-900 LOC.

- Clear.
- Misses state-space combinations in complex widgets.

Option B: Random tests without invariants - 🎯 4   🛡️ 4   🧠 4, about
300-800 LOC.

- Finds crashes.
- Hard to interpret and can be flaky.

Option C: Property-based tests with stable generators and shrinkers - 🎯 9
🛡️ 9   🧠 8, about 1200-2600 LOC.

- Accepted direction.
- Defines invariants, generates edge sequences, and minimizes failures.

## Accepted Direction

Headless should define conformance properties.

Property contains:

- primitive;
- invariant;
- generator;
- seed;
- shrink strategy;
- fixture profile;
- privacy profile;
- expected failure class;
- evidence output.

## Core Invariants

Examples:

- selection refs never duplicate;
- selected disabled item follows policy;
- focus target is visible or recoverable;
- active descendant points to valid owned item;
- command router never dispatches disabled command;
- Escape closes topmost overlay first;
- virtualized row identity survives scroll;
- sort does not change selected item identity;
- migration never restores destructive authority;
- semantic snapshot has no raw secrets.

## Generator Rules

Generators should produce:

- empty collections;
- huge collections;
- deep trees;
- wide rows;
- missing children;
- duplicate labels;
- long labels;
- RTL labels;
- disabled items;
- stale refs;
- random operation ordering;
- rapid capability changes.

Generated data must be synthetic and privacy-safe.

## Repro Rules

Every failure must output:

- seed;
- minimized input;
- command trace;
- semantic snapshot;
- environment profile;
- adapter id;
- invariant id.

No failure should require real filesystem paths.

## Clean Disk Requirements

Clean Disk fuzz profiles:

- huge folder tree;
- duplicate folder names;
- permission-denied branches;
- rapidly changing scan events;
- stale node selected;
- delete queue edits during scan;
- compact layout with long labels;
- fake renderer failure.

Rules:

- fuzz never performs real cleanup.
- destructive command generators use dry-run adapters only.
- synthetic paths are clearly fake.

## API Shape Sketch

```text
ConformanceProperty
  id
  primitive
  invariant
  generator
  shrinker
  environment
  privacyProfile

FuzzResult
  seed
  minimizedCase
  trace
  snapshots
  status
```

## Conformance Scenarios

- random tree operations preserve focus invariant;
- sort/filter keeps selected refs stable;
- overlay stack always exits with Escape sequence;
- generated RTL labels preserve accessible names;
- disabled command never dispatches;
- stale migration fixture drops unsafe state;
- virtualized range changes do not duplicate semantic nodes;
- minimized failure can become regression fixture.

## Failure Catalog

- random test has no invariant;
- flaky failure cannot be reproduced;
- generator uses real user paths;
- shrinker removes the important accessibility state;
- command trace missing;
- failure only says "crashed";
- destructive dry-run guard absent;
- fuzz tests bypass command router;
- generated labels become command ids;
- failure not converted into fixed regression case.

