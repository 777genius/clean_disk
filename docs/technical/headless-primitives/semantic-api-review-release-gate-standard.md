# Semantic API Review And Release Gate Standard

## Status

Accepted as a Headless assurance standard. Not implemented yet.

## Source Standards

- Semantic Versioning: https://semver.org/
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/

## Scope

This standard defines release gates for public Headless APIs.

It applies to:

- primitive APIs;
- renderer contracts;
- token contracts;
- command contracts;
- semantic refs;
- state envelopes;
- conformance scenarios;
- adapter manifests;
- extension APIs.

It does not define product release management. It defines what must be true
before Headless claims a stable API.

## Decision Options

Option A: Release when code compiles and demos work - 🎯 3   🛡️ 3
🧠 2, about 100-300 LOC process cost.

- Fast.
- Public UI kit will accumulate breaking accessibility and behavior changes.

Option B: Manual maintainer judgment - 🎯 6   🛡️ 6   🧠 5, about
400-1000 LOC process cost.

- Useful.
- Inconsistent without checklists and evidence.

Option C: Semantic release gates with evidence artifacts - 🎯 9   🛡️ 9
🧠 8, about 1200-2600 LOC.

- Accepted direction.
- Review is based on API, semantics, accessibility, privacy, and migration
  evidence.

## Accepted Direction

Every stable primitive release must pass semantic gates:

- API compatibility;
- role and state compatibility;
- keyboard compatibility;
- focus compatibility;
- token compatibility;
- privacy compatibility;
- migration availability;
- conformance coverage;
- adapter parity claim;
- documentation coverage.

## Change Classes

Change classes:

- `patch`: bug fix without contract change.
- `minor`: additive API or behavior with compatible default.
- `major`: breaking API, semantic, keyboard, or accessibility change.
- `security`: urgent privacy or safety fix.
- `experimental`: non-stable surface change.

Accessibility behavior can be a breaking change even when Dart signatures stay
the same.

## Review Checklist

Review must ask:

- Did any role change?
- Did any accessible name policy change?
- Did keyboard behavior change?
- Did focus order change?
- Did disabled or readonly behavior change?
- Did state persistence format change?
- Did token resolution change?
- Did privacy classification change?
- Did adapter parity level change?
- Does migration exist?

## Evidence Artifacts

Required artifacts by risk:

- semantic snapshot diff;
- keyboard scenario trace;
- focus trace;
- accessibility lint report;
- adapter parity report;
- localization stress result;
- privacy review;
- migration fixture;
- manual screen reader lab for high-risk primitives.

## Clean Disk Requirements

Clean Disk depends on stable Headless contracts for:

- TreeGrid;
- command router;
- dialog confirmation;
- progress footer;
- details inspector;
- disk map abstraction;
- cleanup queue.

Rules:

- breaking semantic change in TreeGrid blocks Clean Disk upgrade.
- renderer-only visual change still needs no-overflow and contrast checks.
- destructive action contract change is major or security.

## API Shape Sketch

```text
SemanticReleaseGate
  changeClass
  affectedContracts
  requiredEvidence
  migrationRequired
  adapterParityImpact
  privacyImpact
  decision

ReleaseEvidenceBundle
  snapshots
  lintReports
  parityReports
  stressResults
  migrationFixtures
```

## Conformance Scenarios

- role change triggers major review;
- keyboard shortcut change updates command docs;
- token rename includes migration;
- privacy class change blocks release until reviewed;
- adapter parity downgrade updates docs;
- TreeGrid stable release requires semantic snapshots;
- experimental API is not used in stable design system wrapper;
- security fix can bypass warning period but not evidence logging.

## Failure Catalog

- breaking accessibility change shipped as patch;
- Dart API stable but semantics changed silently;
- migration not tested with old state fixture;
- privacy class change ignored;
- adapter parity claim not updated;
- docs claim stable while API experimental;
- token rename breaks third-party renderer;
- command id changed without deprecation;
- screen reader lab skipped for high-risk change;
- Clean Disk upgrades Headless without gate result.

