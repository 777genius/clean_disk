# Accessibility Conformance Reporting ACR VPAT Standard

## Status

Accepted as a Headless reporting standard. Not implemented yet.

## Source Standards

- Section508.gov ACR Library: https://www.section508.gov/accessibility-conformance-reports/
- ITI VPAT: https://www.itic.org/policy/accessibility/vpat
- ETSI EN 301 549 overview: https://www.etsi.org/human-factors-accessibility/en-301-549-v3-the-harmonized-european-standard-for-ict-accessibility
- WCAG2ICT: https://w3c.github.io/wcag2ict/
- WCAG 2.2 Conformance: https://www.w3.org/WAI/WCAG22/Understanding/conformance.html

## Scope

This standard defines how Headless prepares accessibility conformance evidence
for product teams that need ACR, VPAT-style, EN 301 549, or Section 508
reporting.

It applies to:

- public Headless package claims;
- Clean Disk release evidence;
- component-level conformance summaries;
- support and procurement documentation;
- known limitations.

It does not create a legal ACR by itself. It produces structured evidence that
humans can use when preparing one.

## Decision Options

Option A: Ignore reporting until enterprise asks - 🎯 4   🛡️ 3   🧠 1,
about 0-100 LOC.

- Keeps MVP small.
- Evidence will be expensive to reconstruct later.

Option B: Write prose accessibility statement manually - 🎯 6   🛡️ 5
🧠 3, about 200-600 LOC.

- Useful for users.
- Hard to audit and version.

Option C: Generate component-level conformance evidence records - 🎯 9
🛡️ 8   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Lets products assemble ACR/VPAT inputs without Headless overclaiming.
- Preserves known limitations and test dates.

## Accepted Direction

Headless should define `AccessibilityConformanceEvidenceRecord`.

Record fields:

- component or primitive id;
- platform profile;
- requirement family;
- criterion id;
- support level;
- evidence refs;
- test date;
- tested version;
- remarks;
- known limitations;
- responsible owner.

## Support Levels

Support levels:

- `supports`: requirement is supported in tested scope.
- `supportsWithExceptions`: supported with documented limitations.
- `partiallySupports`: some behavior works, some does not.
- `doesNotSupport`: known unsupported.
- `notApplicable`: requirement does not apply.
- `notEvaluated`: no evidence yet.

The names intentionally resemble common ACR language but remain internal until
a product owner creates a formal report.

## Evidence Types

Evidence may include:

- conformance rule result;
- WCAG2ICT profile;
- accessibility-supported technology policy;
- screen reader lab record;
- semantic snapshot;
- keyboard trace;
- manual test script result;
- exception waiver.

Screenshots alone are never sufficient evidence for behavioral accessibility.

## Product Boundary

Headless can say:

- "This primitive exposes evidence records for requirement X."
- "This adapter was tested against stack Y."
- "Known limitation Z exists."

Headless must not say:

- "Your product is compliant."
- "Your legal obligations are satisfied."
- "All screen readers are supported."

Clean Disk makes its own product-level report from Headless evidence plus app
workflow evidence.

## Clean Disk Requirements

Clean Disk should generate evidence records for:

- scan-only MVP;
- cleanup beta;
- desktop release;
- remote/headless read-only mode;
- public support bundle claims.

Cleanup-specific remarks must include:

- destructive confirmation behavior;
- delete-plan validation;
- undo/Trash limitations;
- stale snapshot policy;
- privacy redaction policy.

## API Shape Sketch

```text
AccessibilityConformanceEvidenceRecord
  recordId
  subjectId
  productVersion
  platformProfile
  requirementFamily
  criterionId
  supportLevel
  evidenceRefs
  remarks
  limitations
  evaluatedAt
```

## Conformance Scenarios

Required scenarios:

- TreeGrid emits component evidence, not whole-product claim;
- known screen reader limitation appears in remarks;
- expired evidence cannot be used for release report;
- waiver changes support level from supports to supportsWithExceptions;
- Clean Disk report combines Headless and product workflow evidence;
- `notEvaluated` never appears as support.

## Failure Catalog

Failures:

- public docs imply legal compliance from component tests;
- ACR input omits known limitations;
- Headless evidence copied after major version change;
- support level says supports but stack policy is unknown;
- screenshot-only evidence used for keyboard behavior;
- product workflow lacks evidence for destructive actions.

## Release Gates

Release gate:

- release notes list accessibility claim scope;
- evidence records are versioned;
- limitations are public if they affect users;
- procurement-facing docs are reviewed separately from engineering docs;
- no unsupported critical cleanup path is reported as supported.

