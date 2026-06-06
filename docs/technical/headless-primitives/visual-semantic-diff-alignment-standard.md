# Visual Semantic Diff Alignment Standard

## Status

Accepted as a Headless runtime interoperability standard. Not implemented yet.

## Source Standards

- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- MDN ARIA reference: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference
- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- WCAG 1.4.11 Non-text Contrast: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Scope

This standard defines how visual regression testing and semantic regression
testing align.

It applies to:

- component screenshots;
- semantic snapshots;
- design token changes;
- high contrast states;
- selected and focused rows;
- disabled and readonly states;
- chart renderers;
- compact and wide layouts;
- public release gates.

It does not replace visual or semantic tests. It links them so one cannot pass
while the other silently regresses.

## Decision Options

Option A: Visual diffs only - 🎯 3   🛡️ 3   🧠 2, about 100-300 LOC.

- Catches layout changes.
- Misses accessibility regressions.

Option B: Semantic diffs only - 🎯 5   🛡️ 5   🧠 4, about 300-800 LOC.

- Catches role and state changes.
- Misses visual focus, contrast, and layout issues.

Option C: Paired visual and semantic diff scenarios - 🎯 9   🛡️ 9   🧠 7,
about 900-1800 LOC.

- Accepted direction.
- Every important visual state has a semantic expectation.
- Every important semantic state has visual evidence where relevant.

## Accepted Direction

Headless conformance scenarios should pair:

- screenshot or render evidence;
- semantic snapshot;
- interaction trace;
- token state;
- adapter id;
- environment profile;
- expected allowed diff.

## Alignment Rules

Rules:

- selected state must be visible and semantic;
- focused state must be visible and semantic;
- disabled state must be visible and semantic;
- danger state must not be color-only;
- high contrast mode must preserve semantic states;
- compact layout must preserve command identity;
- hidden visual content must not remain semantic unless intentionally offscreen
  and reachable.

## Diff Classification

Diff classes:

- `visualOnlyAllowed`;
- `semanticOnlyAllowed`;
- `pairedExpected`;
- `pairedUnexpected`;
- `semanticMissing`;
- `visualMissing`;
- `privacyRisk`;
- `adapterGap`.

Release review decides whether a diff is acceptable.

## Clean Disk Requirements

Clean Disk paired scenarios:

- selected folder row;
- focused row action;
- stale delete plan;
- disabled move-to-trash button;
- progress footer running;
- permission warning;
- high contrast dark theme;
- compact delete queue.

Rules:

- neon selection must correspond to selected semantic state.
- warning color must have text/icon semantics.
- disabled destructive button must have visible and semantic reason.

## API Shape Sketch

```text
PairedDiffScenario
  id
  environment
  visualArtifact
  semanticSnapshot
  interactionTrace
  tokenState
  allowedDiffs

DiffAlignmentResult
  visualDiff
  semanticDiff
  classification
  decision
```

## Conformance Scenarios

- visual selected row also has selected semantic state;
- semantic focus has visible focus ring;
- color-only warning fails alignment;
- compact layout preserves command ids;
- high contrast screenshot preserves focus and selection;
- hidden stale content is absent from semantic tree;
- chart visual series has semantic data fallback;
- privacy leak in screenshot or semantic snapshot blocks report.

## Failure Catalog

- screenshot passes while selected semantic state missing;
- semantic state exists but no visible focus;
- color-only danger state;
- hidden overlay remains in accessibility tree;
- compact renderer changes command id;
- high contrast removes border used for focus;
- visual chart changes without data fallback;
- semantic snapshot contains redacted text but screenshot leaks raw path;
- visual diff accepted without semantic review;
- adapter gap not linked to paired scenario.

