# Conformance Runner Architecture Standard

## Status

Implementation standard for an executable Headless conformance runner.

## Purpose

Public primitives need evidence that behavior matches the spec. Documentation
is not enough. The conformance runner turns keyboard, focus, semantics,
renderer, performance, and privacy requirements into repeatable tests.

## Standards And References

- ARIA-AT:
  https://w3c.github.io/aria-at/
- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing
- Flutter performance profiling:
  https://docs.flutter.dev/perf/ui-performance
- Flutter DevTools Performance view:
  https://docs.flutter.dev/tools/devtools/performance

## Runner Layers

```text
spec fixtures
  -> scenario DSL
  -> component harness
  -> renderer harness
  -> platform adapter
  -> evidence reporter
```

Spec fixtures:

- synthetic data;
- expected behavior;
- expected semantic facts;
- privacy classification;
- performance budget.

Scenario DSL:

- steps;
- commands;
- keyboard input;
- pointer input;
- focus assertions;
- semantics assertions;
- viewport assertions;
- diagnostics assertions.

Component harness:

- mounts primitive;
- provides controller;
- records state snapshots;
- dispatches commands;
- captures effects.

Renderer harness:

- applies Material/Cupertino/custom renderer;
- checks capability declarations;
- verifies visual state hooks exist;
- does not inspect private renderer internals.

Platform adapter:

- Flutter widget test;
- Flutter integration test;
- Flutter web browser test;
- manual AT evidence entry.

Evidence reporter:

- pass/fail;
- skipped with reason;
- standard clause id;
- fixture id;
- renderer id;
- platform id;
- sanitized diagnostics.

## Scenario Categories

Behavior:

- command changes expected state;
- disabled command does nothing;
- controlled state handshake;
- effect ordering.

Keyboard:

- default APG keys;
- remapped keys;
- conflict resolution;
- text input guard;
- modal precedence.

Focus:

- initial focus;
- roving/logical focus;
- focus restore;
- focus visible;
- no hidden focus target.

Semantics:

- labels;
- roles or role intents;
- selected/expanded/disabled state;
- collection facts;
- live region messages;
- hidden virtual rows absent.

Renderer:

- required slots;
- missing capability diagnostics;
- token state resolution;
- high contrast profile;
- reduced motion profile.

Performance:

- visible row count bounded;
- semantic node count bounded;
- rebuild count bounded;
- scroll-to-target latency budget;
- progress event coalescing.

Privacy:

- diagnostics redacted;
- no raw labels in logs;
- fixture data synthetic;
- support export scrubbed.

## Evidence Levels

```text
level 0: docs only
level 1: reducer tests
level 2: widget tests with semantics
level 3: renderer tests with accessibility guidelines
level 4: integration performance smoke
level 5: manual screen-reader evidence
level 6: external audit or community interop evidence
```

Stable public primitive should require at least level 3. TreeGrid, Dialog, and
Menu should target level 5 before strong accessibility claims.

## Clause Traceability

Every scenario should link to:

- component profile clause;
- keyboard command matrix row;
- state machine transition;
- WCAG mapping if applicable;
- APG/MDN reference if applicable;
- known limitation if skipped.

This keeps implementation, docs, and release notes aligned.

## Failure Taxonomy

```text
specFailure
implementationFailure
rendererFailure
adapterGap
platformInteropGap
testHarnessGap
fixtureGap
documentationGap
knownLimitation
```

Only `knownLimitation` can be accepted for beta, and only if public docs state
the limitation.

## CI Policy

Fast CI:

- reducer tests;
- widget tests;
- semantics snapshots;
- diagnostics privacy checks.

Nightly CI:

- large fixtures;
- performance smoke;
- renderer matrix;
- web adapter checks.

Manual release gate:

- screen reader lab scenarios;
- high contrast pass;
- reduced motion pass;
- keyboard-only sweep.

## Output Format

```text
component:
version:
renderer:
platform:
scenario:
standard references:
result:
evidence level:
known gaps:
sanitized diagnostics:
```

## Stop Rules

- Do not publish stable primitive without conformance matrix.
- Do not let examples be the only tests.
- Do not hide skipped scenarios.
- Do not store real user data in fixtures.
- Do not let renderer-specific snapshots become the spec.
