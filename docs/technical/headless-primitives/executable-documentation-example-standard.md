# Executable Documentation Example Standard

## Status

Accepted as a Headless quality-operations standard. Not implemented yet.

## Source Standards

- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- ARIA-AT: https://w3c.github.io/aria-at/
- Flutter widget testing: https://docs.flutter.dev/testing
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html

## Scope

This standard defines how Headless documentation examples become executable
fixtures, tests, and conformance evidence.

It applies to:

- README examples;
- API docs;
- cookbook examples;
- migration examples;
- accessibility examples;
- conformance examples;
- Clean Disk design-system wrapper examples.

It does not require every prose paragraph to execute. It requires examples that
teach behavior to remain correct.

## Decision Options

Option A: Static examples in docs - 🎯 4   🛡️ 4   🧠 2, about 100-300 LOC.

- Good for readability.
- Examples rot and drift from real behavior.

Option B: Snapshot examples only - 🎯 6   🛡️ 5   🧠 4, about 300-800 LOC.

- Catches visual drift.
- Does not prove keyboard, focus, semantics, or command behavior.

Option C: Executable examples with semantic assertions - 🎯 9   🛡️ 9
🧠 7, about 900-1800 LOC.

- Accepted direction.
- Public examples double as regression fixtures.
- Docs stay honest for community users.

## Accepted Direction

Every behavior-critical example should have:

- source fixture;
- rendered preview;
- keyboard scenario;
- semantic snapshot;
- accessibility lint result;
- expected command trace;
- docs link;
- version tag.

Documentation should import or generate from the fixture where practical.

## Example Classes

Classes:

- `minimal`;
- `common`;
- `advanced`;
- `accessibility`;
- `migration`;
- `adapter`;
- `failureMode`;
- `CleanDiskUsage`;
- `antiPattern`.

Anti-pattern examples must be clearly marked and must not be copy-pasteable as
recommended code.

## Assertion Rules

Executable examples should assert:

- role;
- accessible name;
- focus order;
- keyboard command;
- disabled reason;
- live announcement policy;
- localization stress variant;
- high contrast variant where relevant;
- reduced motion variant where relevant.

Visual assertion alone is insufficient for behavior examples.

## Privacy Rules

Docs examples must use synthetic data:

- no real paths;
- no real user names;
- no secrets;
- no daemon tokens;
- no production scan data.

Clean Disk examples use synthetic filesystem fixtures.

## Clean Disk Requirements

Clean Disk wrapper examples:

- TreeGrid with synthetic folders;
- details inspector;
- cleanup queue disabled state;
- progress footer;
- disk map fallback;
- permission degraded banner;
- confirmation dialog.

Rules:

- examples follow saved design references where UI is shown.
- examples do not import feature stores directly into design-system docs.
- examples prove command routing, not direct callbacks.

## API Shape Sketch

```text
ExecutableExample
  id
  class
  fixturePath
  docPath
  scenarioIds
  semanticAssertions
  visualAssertions
  privacyProfile
  version

ExampleRunner
  render(example)
  assertBehavior(example)
  publishDocs(example)
```

## Conformance Scenarios

- docs example keyboard path passes test;
- README TreeGrid example has semantic snapshot;
- migration example compiles against current API;
- anti-pattern example cannot be mistaken as recommended code;
- Clean Disk synthetic path redacts correctly;
- high contrast variant for selected row remains valid;
- docs link to exact version of example fixture;
- example failure blocks release of changed primitive.

## Failure Catalog

- README example compiles nowhere;
- example shows direct callback bypassing command router;
- visual example has no accessible name assertion;
- docs use raw local path;
- migration docs drift from actual API;
- anti-pattern copied as normal example;
- example screenshot passes while keyboard test fails;
- code snippet uses deprecated API without warning;
- generated docs omit disabled reason;
- public docs overstate adapter support.

