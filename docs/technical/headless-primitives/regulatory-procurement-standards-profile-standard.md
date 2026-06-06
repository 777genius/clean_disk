# Regulatory Procurement Standards Profile Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG2ICT overview: https://www.w3.org/WAI/standards-guidelines/wcag/non-web-ict/
- WCAG2ICT 2.2: https://www.w3.org/TR/wcag2ict-22/
- ETSI EN 301 549: https://www.etsi.org/human-factors-accessibility/en-301-549-v3-the-harmonized-european-standard-for-ict-accessibility
- Section508.gov applicability guidance: https://www.section508.gov/buy/determine-ict-standards/
- European Commission European Accessibility Act news: https://commission.europa.eu/news-and-media/news/eu-becomes-more-accessible-all-2025-07-31_en
- WCAG 2.2 Conformance: https://www.w3.org/WAI/WCAG22/Understanding/conformance.html

## Problem

Public UI primitives are often adopted by teams that must answer procurement,
enterprise, government, or legal accessibility questions. A component can be
technically accessible and still be hard to approve because it lacks a clear
standards profile: web versus non-web software, desktop versus browser,
closed-functionality status, claimed WCAG level, EN 301 549 relevance, Section
508 relevance, and evidence boundaries.

Headless needs a profile format that separates engineering claims from legal
claims and makes evidence reusable.

## Decision Options

1. Keep only WCAG mappings - 🎯 5   🛡️ 5   🧠 2, about 60-140 LOC. Useful for
   component testing, weak for procurement.
2. Add a standards profile registry - 🎯 9   🛡️ 9   🧠 6, about 350-850 LOC.
   Best fit because it connects WCAG, WCAG2ICT, EN 301 549, Section 508, and
   product evidence without making legal promises.
3. Generate full legal compliance packets from primitives - 🎯 3   🛡️ 4
   🧠 9, about 1800-4000 LOC. Too risky for Headless core.

Accepted: option 2.

## Accepted Contract

Headless defines a standards profile:

```dart
final class RAccessibilityStandardsProfile {
  final String profileId;
  final Set<RRuntimeSurface> surfaces;
  final Set<RReferencedStandard> referencedStandards;
  final RConformanceClaimScope claimScope;
  final Set<RClosedFunctionalityStatus> closedFunctionalityStatuses;
  final Set<REvidenceArtifactKind> requiredEvidence;
  final Set<RKnownLimitationCode> knownLimitations;
}
```

The profile is an engineering artifact. Legal review owns legal conclusions.

## Profile Rules

- Claims are scoped to a surface: Flutter web, Flutter desktop, native wrapper,
  documentation, demo app, or test harness.
- Non-web desktop claims reference WCAG2ICT guidance instead of pretending WCAG
  terms map perfectly.
- Closed functionality is declared separately from ordinary desktop software.
- EN 301 549 and Section 508 are referenced as procurement profiles, not as
  automatic conformance from passing component tests.
- European Accessibility Act relevance is a product-market question, not a
  primitive-level conclusion.
- Evidence artifacts must be versioned and linked to exact component versions.

## Clean Disk Requirements

Clean Disk should eventually publish profiles for:

- desktop app local UI;
- daemon-served web UI;
- read-only remote/headless UI;
- documentation and support bundle viewer;
- optional enterprise managed mode.

The MVP can mark procurement profiles as incomplete, but it must not make broad
claims such as "WCAG compliant" without scoped evidence.

## Evidence Types

Profile evidence can include:

- WCAG mapping matrix;
- WCAG2ICT applicability notes;
- component conformance scenarios;
- accessibility tree snapshots;
- AT transcript correlation;
- manual test records;
- automated audit output;
- known limitation list;
- remediation plan;
- release version and environment.

## Non-Goals

- This standard does not give legal advice.
- It does not replace an ACR or VPAT.
- It does not certify conformance by itself.
- It does not let a component claim product conformance outside its tested
  surface.

## Testing Requirements

- Every profile references exact Headless package versions.
- Evidence artifacts are reproducible from fixtures where possible.
- Unknown applicability is represented as unknown, not as passed.
- Product docs can hide incomplete profiles from users but not from engineering
  release gates.
- CI verifies that referenced evidence artifacts exist.

## Failure Catalog

- A primitive claims EN 301 549 support without non-web evidence.
- A web demo passes axe and the desktop app inherits the same claim.
- Closed functionality is ignored in kiosk builds.
- Procurement docs are generated from stale component versions.
- Known limitations are removed from public docs but remain in issue tracker.
- Legal and engineering terms use the same word "supports" differently.

## Release Gates

- No public compliance claim without standards profile id.
- Every profile has owner, scope, evidence, and limitation fields.
- ACR/VPAT documents consume profiles but do not silently alter them.
- Major primitive releases require profile impact review.

## Summary

Headless should make accessibility claims auditable and scoped. A standards
profile keeps WCAG, WCAG2ICT, EN 301 549, Section 508, and product evidence
connected without turning engineering docs into legal conclusions.
