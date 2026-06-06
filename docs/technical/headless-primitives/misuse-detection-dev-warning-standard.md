# Misuse Detection And Dev Warning Standard

## Status

Accepted as a Headless developer experience and safety standard. Not
implemented yet.

## Source Standards

- WAI-ARIA APG Read Me First: https://www.w3.org/WAI/ARIA/apg/practices/read-me-first/
- ARIA in HTML: https://www.w3.org/TR/html-aria/
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing
- ACT Rules Format 1.1: https://www.w3.org/TR/act-rules-format/

## Scope

This standard defines how Headless detects invalid or dangerous component usage
early in development.

It applies to:

- runtime debug warnings;
- static lints;
- conformance runner diagnostics;
- public examples;
- design-system wrappers;
- Clean Disk UI integration.

It does not replace tests. It catches mistakes before tests or screen reader
audits are run.

## Decision Options

Option A: Trust developers to read docs - 🎯 3   🛡️ 3   🧠 1, about
0-100 LOC.

- Zero complexity.
- Public UI kits fail this way all the time.

Option B: Add warnings only in conformance runner - 🎯 6   🛡️ 6   🧠 4,
about 400-900 LOC.

- Useful for CI.
- Too late for everyday development.

Option C: Layered misuse diagnostics: lint, debug warning, conformance rule -
🎯 9   🛡️ 9   🧠 7, about 1000-2200 LOC.

- Accepted direction.
- Same misuse has one stable code across IDE, runtime, and CI.

## Accepted Direction

Headless should define `HeadlessDiagnostic`.

Diagnostic fields:

- stable code;
- severity;
- primitive id;
- condition;
- user impact;
- standards refs;
- fix hint;
- suppressibility;
- evidence requirement;
- privacy class.

## Diagnostic Severities

Severities:

- `info`: improvement or migration hint.
- `warning`: likely accessibility or behavior issue.
- `error`: invalid component contract.
- `releaseBlocker`: critical safety or conformance issue.

Release blockers cannot be suppressed without a waiver id.

## Misuse Classes

Classes:

- missing accessible name;
- role without behavior;
- conflicting native and ARIA semantics;
- missing keyboard path;
- focus trap without escape;
- tooltip used as required label;
- interactive child in forbidden slot;
- disabled command still invokable;
- visible state differs from semantic state;
- destructive action missing validated plan;
- user data in test fixture.

## Warning Timing

Warnings may run:

- at construction time for static contract issues;
- after first layout for geometry and focus issues;
- after semantic snapshot for accessibility facts;
- in conformance runner for cross-platform checks;
- in CI for release policies.

Warnings must avoid noisy per-frame output.

## Clean Disk Requirements

Clean Disk should fail fast on:

- unnamed icon buttons;
- row action without keyboard command;
- cleanup queue item without current node identity;
- stale delete plan confirmation;
- progress status without visible status text;
- path leaked into support fixture;
- TreeTable row without stable id.

## API Shape Sketch

```text
HeadlessDiagnostic
  code
  severity
  primitiveId
  messageKey
  standardsRefs
  fixHintKey
  suppressible
  waiverRequired
  evidenceRequired
```

## Conformance Scenarios

Required scenarios:

- missing label emits same diagnostic in runtime and CI;
- false positive can be suppressed only with reason;
- destructive release blocker cannot be ignored by design-system wrapper;
- diagnostics are localized at presentation edge;
- diagnostic does not include raw path;
- public docs list stable diagnostic codes.

## Failure Catalog

Failures:

- warning text changes and breaks documentation links;
- runtime warning leaks private data;
- linter and runtime use different codes for same issue;
- suppressions hide release blockers;
- warning fires on every frame;
- dev warning suggests ARIA where native element is better.

## Release Gates

Release gate:

- critical diagnostics exist before component beta;
- release build strips noisy debug detail but preserves safe telemetry class;
- suppression requires owner and expiry;
- public examples have zero warnings;
- Clean Disk release has no Headless release blockers.

