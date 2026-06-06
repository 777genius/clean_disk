# Inline Annotation Highlight And Revision Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN `mark`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/mark
- MDN `ins`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/ins
- MDN `del`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/del
- MDN HTML inline text semantics: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- WCAG 1.4.3 Contrast Minimum: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html

## Problem

Search results, diffs, scan comparisons, cleanup receipts, rule explanations,
and support evidence often need inline annotations: highlighted matches,
inserted/deleted facts, stale values, redacted spans, warnings, and confidence
markers. If annotations are only color or style, users miss meaning. If every
annotation is announced aggressively, dense views become unusable.

Headless needs a typed inline annotation model.

## Decision Options

1. Let renderers style spans directly - 🎯 4   🛡️ 4   🧠 2, about
   60-180 LOC. Easy but loses semantics and copy behavior.
2. Add typed inline annotation tokens - 🎯 9   🛡️ 9   🧠 6, about
   450-1100 LOC. Best fit.
3. Build a full rich-text editor model - 🎯 3   🛡️ 5   🧠 10, about
   2500-8000 LOC. Too broad for Headless primitives.

Accepted: option 2.

## Accepted Contract

Inline text can carry semantic annotations:

```dart
final class RInlineAnnotation {
  final TextRange range;
  final RInlineAnnotationKind kind;
  final String? accessiblePrefix;
  final String? accessibleSuffix;
  final String? reasonCode;
  final RCopyBehavior copyBehavior;
  final RPrivacyClass privacyClass;
}
```

Annotations are metadata over text. They do not become command identity.

## Annotation Kinds

```text
searchMatch:
  user query or filter match

inserted:
  value added compared with baseline

deleted:
  value removed compared with baseline

changed:
  value changed but not a pure insertion or deletion

redacted:
  hidden private content

warning:
  inline risk or issue marker

confidence:
  evidence confidence marker

stale:
  value is old or snapshot-relative
```

## Rules

- Color is not the only annotation signal.
- Copy behavior is explicit: copy raw, copy visible, copy redacted, or block.
- Search highlight does not change selection or command target.
- Diff annotations must have accessible boundaries only when needed.
- Repeated highlights should not be announced on every character.
- Redaction markers must not preserve raw hidden text in diagnostics.
- Annotations can be flattened for plain-text export, but meaning is retained.
- Annotation ids are stable inside one text model, not global identity.

## Clean Disk Requirements

Clean Disk uses annotations for:

- search result highlights in paths and names;
- compare view added/removed/changed folders;
- stale scan labels;
- redacted support-bundle paths;
- warning fragments in details;
- confidence evidence in reclaim estimates;
- cleanup receipt outcome diffs;
- protocol/debug diffs in development builds.

## Web Mapping

For web adapters:

- `mark` can represent relevant highlighted text such as search matches;
- `ins` and `del` can represent inserted and deleted content when comparison
  meaning matters;
- redaction should be visible text, not hidden raw content;
- additional offscreen text for insert/delete boundaries must be used
  carefully to avoid verbosity.

Flutter adapters need semantic spans or separate accessible labels that retain
the same meaning.

## Accessibility Rules

- Users can discover annotation meaning from legend or details.
- Search result count and navigation announce current match position.
- Diff annotations have non-color cues.
- Redacted spans announce redacted or hidden by policy.
- Screen-reader verbosity can be controlled for dense annotated text.
- Highlight contrast meets text contrast requirements.

## Copy And Export Rules

```text
copyRaw:
  original text can be copied

copyVisible:
  visual text, including redaction markers

copyRedacted:
  privacy-safe replacement only

copyWithAnnotations:
  text plus explicit markers

copyBlocked:
  copy disabled by policy
```

Clean Disk support exports default to redacted or annotated copies, not raw
paths.

## Testing Requirements

- Search highlight is visible and has non-color semantics.
- Redacted span does not leak raw text in copy or snapshots.
- Diff insertion/deletion has accessible meaning where important.
- Copy policy is respected.
- Highlight survives text scaling and bidi text.
- Screen-reader output is not flooded by repeated matches.
- Export includes annotation meaning.

## Failure Catalog

- Search highlight is color only.
- Deleted value is rendered with strikethrough but not announced.
- Redacted span still contains raw path in semantics tree.
- Copy selection includes hidden raw value.
- Diff view announces "insertion start" hundreds of times.
- Highlight contrast fails in dark theme.

## Release Gates

- Inline annotations use typed model.
- Clean Disk search and compare views map highlights through annotations.
- Redaction policy is tested for copy, semantics, and diagnostics.
- Diff views expose meaning without excessive verbosity.
- Annotation fixtures cover bidi, long paths, redaction, and dense matches.

## Summary

Inline annotations carry meaning beyond styling. Headless should model search
matches, diffs, redaction, warnings, confidence, and stale values with explicit
copy and accessibility behavior.
