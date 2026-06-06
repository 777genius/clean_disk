# Assistive Technology Compatibility Lifecycle Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- ARIA-AT: https://w3c.github.io/aria-at/
- WAI-ARIA APG Read Me First: https://www.w3.org/WAI/ARIA/apg/practices/read-me-first/
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- WCAG 2.2 Conformance: https://www.w3.org/WAI/WCAG22/Understanding/conformance.html
- Accessibility supported technology policy standard: accessibility-supported-technology-policy-standard.md
- Assistive technology transcript correlation standard: assistive-technology-transcript-correlation-standard.md
- Assistive technology workaround governance standard: assistive-technology-workaround-governance-standard.md

## Problem

Assistive technology compatibility changes over time. Browser versions, screen
reader releases, OS updates, Flutter engine updates, and platform accessibility
API changes can all alter behavior. A one-time support matrix is not enough.
Headless needs a lifecycle standard for support claims, regressions, known
workarounds, deprecations, and compatibility evidence.

## Decision Options

1. Retest manually before major releases - 🎯 5   🛡️ 5   🧠 3, about 80-180
   LOC. Better than nothing, weak for public ecosystem.
2. Maintain AT compatibility lifecycle records - 🎯 9   🛡️ 9   🧠 7, about
   450-1000 LOC. Best fit for Headless.
3. Pin users to exact screen reader and browser versions - 🎯 2   🛡️ 4
   🧠 5, about 150-300 LOC. Unrealistic and hostile.

Accepted: option 2.

## Accepted Contract

Headless tracks compatibility as lifecycle data:

```dart
final class RAssistiveTechnologyCompatibilityRecord {
  final String recordId;
  final RPrimitiveId primitiveId;
  final RAdapterId adapterId;
  final RAtStack stack;
  final RCompatibilityStatus status;
  final String testedVersionRange;
  final DateTime testedAt;
  final Set<RKnownInteropIssue> knownIssues;
  final Set<RWorkaroundId> activeWorkarounds;
  final Set<REvidenceArtifactRef> evidence;
}
```

This record is separate from marketing docs and from raw test output.

## Lifecycle States

```text
candidate:
  appears to work but not claimed

supported:
  tested and in support policy

degraded:
  workflow works with documented limitations

blocked:
  workflow cannot be completed

unknown:
  not recently tested or evidence expired

deprecated:
  support is being removed with migration notes
```

Unknown is not equivalent to supported.

## Compatibility Rules

- Support claims include AT, browser, OS, adapter, and primitive versions.
- Evidence expires after a defined time or major dependency release.
- Workarounds have owner, reason, removal condition, and blast radius.
- A regression in a critical workflow blocks release unless explicitly waived.
- Compatibility bugs are linked to semantic facts, not only spoken phrases.
- User-facing docs avoid overpromising exact speech output.

## Clean Disk Requirements

Clean Disk needs lifecycle records for:

- TreeGrid navigation;
- search field;
- scan progress;
- details panel;
- cleanup queue;
- destructive confirmation;
- settings and permission repair.

MVP can support a narrow stack, but the claim must be explicit.

## Evidence Expiration

Evidence becomes stale when:

- Flutter version changes major accessibility behavior;
- browser major version changes relevant tree behavior;
- OS accessibility API changes;
- primitive semantic API changes;
- workaround is added or removed;
- critical bug is filed against the stack;
- more than the configured evidence age has passed.

## Testing Requirements

- Compatibility matrix generated from records.
- CI validates record schema and referenced evidence.
- Manual test cadence for claimed stacks.
- Regression tests compare semantic snapshots across releases.
- Workaround tests fail when the workaround no longer applies.
- Public changelog includes compatibility-impacting changes.

## Failure Catalog

- Support matrix says "VoiceOver" but does not specify Safari, Chrome, web, or
  native desktop.
- Evidence from six releases ago remains active.
- Workaround for one screen reader breaks another.
- Spoken transcript changed but semantic output did not, and release is blocked
  for the wrong reason.
- Semantic output changed and transcript still sounds similar, hiding a real
  regression.
- Unknown stack is documented as supported.

## Release Gates

- Critical primitives cannot claim support without fresh compatibility records.
- Workarounds require governance and expiration.
- Major releases include compatibility impact notes.
- Unsupported stacks are documented without blame or vague language.

## Summary

Assistive technology support is a lifecycle, not a checkbox. Headless should
track supported, degraded, blocked, unknown, and deprecated stacks with evidence
and expiration.
