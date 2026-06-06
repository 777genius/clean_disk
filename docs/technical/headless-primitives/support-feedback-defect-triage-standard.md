# Support Feedback And Defect Triage Standard

## Status

Accepted as a Headless assurance standard. Not implemented yet.

## Source Standards

- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- ARIA-AT: https://w3c.github.io/aria-at/
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Scope

This standard defines how Headless turns user feedback, bug reports, support
bundles, and accessibility defects into reproducible conformance work.

It applies to:

- accessibility bugs;
- keyboard bugs;
- focus bugs;
- localization bugs;
- renderer bugs;
- privacy incidents;
- performance regressions;
- Clean Disk support bundles;
- community adapter issues.

It does not define customer support operations. It defines the technical triage
contract for reusable primitives.

## Decision Options

Option A: Handle issues manually in repository discussion - 🎯 5   🛡️ 5
🧠 2, about 100-300 LOC process cost.

- Simple.
- Bugs repeat because repros are not converted into fixtures.

Option B: Ask users for screenshots and logs - 🎯 5   🛡️ 4   🧠 3, about
200-500 LOC.

- Helpful.
- Privacy risk and weak for accessibility semantics.

Option C: Privacy-safe defect bundle to conformance fixture pipeline - 🎯 9
🛡️ 9   🧠 8, about 1000-2200 LOC.

- Accepted direction.
- Defects become sanitized evidence, minimized repros, and regression tests.

## Accepted Direction

Headless should define a defect triage pipeline:

1. classify defect;
2. collect safe evidence;
3. redact sensitive data;
4. map to primitive contract;
5. reproduce with fixture;
6. add conformance scenario;
7. fix or document adapter gap;
8. update release gate evidence.

## Defect Classes

Classes:

- `accessibilityRole`;
- `accessibleName`;
- `keyboardNavigation`;
- `focusLoss`;
- `liveAnnouncement`;
- `screenReaderInterop`;
- `localizationOverflow`;
- `bidiCorruption`;
- `privacyLeak`;
- `performanceRegression`;
- `adapterParityGap`;
- `documentationMismatch`;
- `unknown`.

Each class has required evidence and privacy policy.

## Evidence Collection

Safe evidence:

- primitive type;
- adapter id;
- version;
- scenario id;
- semantic snapshot;
- lint findings;
- redacted screenshot;
- keyboard trace;
- focus trace;
- locale;
- text scale bucket;
- capability manifest.

Sensitive evidence requires explicit user approval and redaction:

- raw paths;
- filenames;
- queries;
- logs;
- support bundles;
- screenshots containing personal content.

## Repro Fixture Rules

A defect is not closed until one is true:

- conformance fixture reproduces it;
- manual lab note explains why fixture is impossible;
- defect is external platform bug with evidence;
- report is invalid with documented reason.

The preferred outcome is a minimized fixture with no user data.

## Community Issue Rules

Community reports should ask for:

- primitive name;
- adapter;
- platform;
- assistive technology if relevant;
- input method;
- reduced reproduction;
- safe semantic snapshot if available;
- redaction confirmation.

Do not ask users to upload full private app state by default.

## Clean Disk Requirements

Clean Disk support loop:

- support bundle exports redacted Headless facts;
- scan paths are redacted or user-approved;
- TreeGrid issues include semantic snapshot and viewport state;
- cleanup safety issues include command resolution and policy result;
- accessibility issues can become Headless conformance fixtures.

Rules:

- no daemon token in support evidence.
- no raw delete target path unless explicit export profile allows it.
- defect triage can create fixture with synthetic paths.

## API Shape Sketch

```text
DefectReport
  id
  class
  primitive
  adapter
  version
  evidence
  privacyProfile
  reproductionStatus
  conformanceLink

DefectTriagePolicy
  requiredEvidence(class)
  redact(report)
  fixtureFrom(report)
```

## Conformance Scenarios

- screen reader bug creates manual lab note or fixture;
- keyboard bug produces command trace;
- privacy leak report redacts raw path before storage;
- localization overflow report adds stress corpus case;
- adapter parity gap updates manifest;
- support bundle excludes daemon token;
- reproduced defect links to conformance scenario;
- external platform bug is documented with workaround or gap.

## Failure Catalog

- closing accessibility bug without fixture or lab note;
- support bundle leaks raw paths by default;
- screenshot is only evidence for semantic defect;
- community issue asks for private full state;
- adapter bug fixed but parity manifest unchanged;
- regression test uses user data;
- defect class unknown forever;
- support report cannot map to primitive version;
- privacy incident treated as ordinary bug;
- Clean Disk issue fixed locally but Headless conformance not updated.

