# Accessibility Inspector Debug Evidence Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- Chrome DevTools accessibility reference: https://developer.chrome.com/docs/devtools/accessibility/reference
- Chrome full accessibility tree: https://developer.chrome.com/blog/full-accessibility-tree/
- Apple Accessibility Inspector: https://developer.apple.com/documentation/accessibility/accessibility-inspector
- Microsoft accessibility testing for Windows apps: https://learn.microsoft.com/en-us/windows/apps/design/accessibility/accessibility-testing
- Accessibility Insights for Windows automated checks: https://accessibilityinsights.io/docs/windows/getstarted/automatedchecks/
- Android accessibility testing: https://developer.android.com/guide/topics/ui/accessibility/views/testing-views
- axe-core: https://www.deque.com/axe/axe-core/

## Problem

Accessibility bugs often cannot be diagnosed from widget code alone. Developers
need inspector evidence: computed names, roles, states, properties, bounds,
actions, accessibility tree position, platform events, automated rule output,
and manual AT observations. Without a shared evidence format, public Headless
issues become vague screenshots and impossible-to-reproduce reports.

## Decision Options

1. Ask contributors for screenshots and reproduction steps - 🎯 4   🛡️ 4
   🧠 2, about 0-80 LOC. Too weak for a serious UI kit.
2. Standardize inspector evidence packets - 🎯 9   🛡️ 9   🧠 6, about
   350-850 LOC. Best fit for community debugging.
3. Build a full cross-platform inspector app - 🎯 5   🛡️ 7   🧠 10, about
   3000-7000 LOC. Useful later, not needed first.

Accepted: option 2.

## Accepted Contract

Headless defines a debug evidence packet:

```dart
final class RAccessibilityDebugEvidence {
  final String evidenceId;
  final RPlatformFamily platformFamily;
  final String inspectorTool;
  final String componentVersion;
  final RSemanticId? semanticId;
  final RExposedAccessibilityNode exposedNode;
  final List<RAutomatedRuleFinding> automatedFindings;
  final List<RManualObservation> manualObservations;
  final RPrivacyRedactionProfile redactionProfile;
}
```

Evidence packets are redacted by default.

## Required Evidence Fields

For a component issue, collect:

- component name and version;
- adapter and renderer;
- platform and browser or OS version;
- computed accessible name;
- role or control type;
- state and value;
- actions or control patterns;
- bounds and visibility;
- relation to label or description;
- automated findings;
- manual AT notes where relevant.

## Clean Disk Requirements

Clean Disk needs inspector evidence for:

- TreeGrid rows and cells;
- selected row state;
- cleanup queue buttons;
- Move to Trash confirmation;
- scan progress status;
- skipped warning count;
- disk usage map alternative summary.

Bug reports must not include real file paths unless the user explicitly exports
an unredacted support bundle.

## Automated Tool Policy

- Automated tools are useful but incomplete.
- axe, Accessibility Insights, platform scanners, and DevTools findings are
  evidence, not final judgment.
- Manual review is required for keyboard model, screen-reader flow, destructive
  action clarity, and complex virtualized collections.
- False positives and false negatives are tracked as tool limitations.

## Privacy Rules

- Redact file paths, user names, search text, clipboard content, and raw screen
  reader transcripts by default.
- Store node ids and semantic ids instead of raw labels where possible.
- Screenshots are optional and sensitive.
- Evidence retention is time-limited in support workflows.

## Testing Requirements

- Evidence packet schema test.
- Redaction test with synthetic sensitive path data.
- Fixture for Chrome DevTools accessibility output.
- Fixture for Apple Accessibility Inspector notes.
- Fixture for Windows UIA or Accessibility Insights output.
- CI check that evidence examples do not contain real local paths.

## Failure Catalog

- Issue report says "screen reader broken" with no role/name/state facts.
- Automated audit passes and manual keyboard trap remains.
- Screenshot contains private folder names.
- Inspector shows correct role but wrong action set and the report ignores it.
- Evidence from one browser is generalized to all browsers.
- Tool-specific rule id is treated as a Headless semantic id.

## Release Gates

- Public issue template asks for evidence packet fields.
- Conformance reports include inspector evidence for critical primitives.
- Support exports apply redaction before writing files.
- Automated findings are separated from manual observations.

## Summary

Inspector evidence turns accessibility bugs into reproducible engineering data.
Headless should standardize what to capture, how to redact it, and how to avoid
overtrusting automated tools.
