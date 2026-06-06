# Receipt Report And Document Semantics Standard

## Status

Accepted direction for Headless. Complements export, print, operation history,
and support-bundle standards. Not implemented yet.

## Source Standards

- W3C WAI Page Structure Tutorial: https://www.w3.org/WAI/tutorials/page-structure/
- MDN `article`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/article
- MDN ARIA `article` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/article_role
- MDN `header`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/header
- MDN `footer`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/footer
- MDN `time`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/time
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html

## Problem

Receipts, reports, support bundles, scan summaries, cleanup outcomes, and
export previews need to be readable documents, not just app panels. They need
title, scope, authoring app, creation time, version, sections, evidence,
privacy markings, and machine-readable facts. If Headless only renders cards,
exported artifacts lose structure and trust.

Headless needs document semantics for durable UI artifacts.

## Decision Options

1. Treat reports and receipts as normal panels - 🎯 4   🛡️ 4   🧠 2,
   about 80-200 LOC. Fast but weak for export and support.
2. Add document artifact semantics - 🎯 9   🛡️ 9   🧠 6, about 450-1100
   LOC. Best fit.
3. Build full document generation framework - 🎯 4   🛡️ 6   🧠 10, about
   2500-8000 LOC. Too broad for Headless core.

Accepted: option 2.

## Accepted Contract

Document-like surfaces expose artifact metadata:

```dart
final class RDocumentArtifactSemantics {
  final String artifactId;
  final RDocumentArtifactKind kind;
  final String title;
  final String? subtitle;
  final String? createdAtIso8601;
  final String? sourceVersion;
  final RPrivacyClass privacyClass;
  final List<RDocumentSectionSemantics> sections;
}
```

Headless renders and preserves structure. Product code supplies authority,
evidence, redaction, signatures, and persistence.

## Artifact Kinds

```text
receipt:
  durable outcome of an operation

report:
  generated user-facing summary

supportBundlePreview:
  reviewable diagnostic export

scanSnapshotSummary:
  read-only scan artifact

cleanupPlanPreview:
  current validated plan, not a receipt

auditView:
  ordered evidence for command or workflow
```

## Rules

- Receipt is not the same as preview.
- Report title, time, and scope are explicit.
- Sections use heading semantics.
- Artifact version and app/source version are visible where relevant.
- Privacy class is part of artifact metadata.
- Redacted artifact must say it is redacted.
- Exported structure matches on-screen structure.
- Machine-readable facts are attached separately from localized prose.

## Clean Disk Requirements

Clean Disk document artifacts include:

- cleanup receipt;
- scan summary report;
- support bundle preview;
- remote/headless read-only report;
- delete plan preview;
- repair diagnostics report;
- benchmark report.

Only cleanup receipt and operation journal can prove side effects. A report is
informational unless tied to durable operation evidence.

## Receipt Required Sections

```text
summary:
  operation, status, time, actor, scope

items:
  item outcomes and errors

evidence:
  identity validation, capabilities, policy decisions

recovery:
  restore, reveal, retry, or support actions

privacy:
  redaction and export policy
```

## Web Mapping

For web adapters:

- `article` can represent standalone receipts or reports;
- `header` and `footer` can hold artifact metadata and provenance;
- `time` carries machine-readable timestamps;
- section headings provide navigation;
- print/export adapters preserve structure.

Flutter adapters should maintain an equivalent document outline model and
artifact metadata for export.

## Accessibility Rules

- Artifact title is the first navigable heading.
- Receipt status is clear without color.
- Timestamps have accessible absolute form.
- Redaction status is announced.
- Long item lists use table or result-set semantics.
- Export controls do not appear as artifact evidence.

## Testing Requirements

- Receipt view has title, time, status, and sections.
- Preview and receipt are distinguishable.
- Exported artifact preserves headings and metadata.
- Redacted artifact does not expose raw paths.
- Screen reader can navigate sections.
- Artifact source version appears in support export.
- Print view does not drop evidence sections.

## Failure Catalog

- Delete plan preview is labeled receipt.
- Report omits time zone or source version.
- Redacted support preview still includes raw paths in semantics.
- Exported PDF loses section headings.
- Receipt status is color only.
- Restore action appears as evidence line.

## Release Gates

- Document artifact semantics exist before cleanup receipt UI.
- Clean Disk receipt uses artifact kind `receipt`.
- Support preview uses explicit privacy class.
- Export adapters preserve artifact metadata.
- Tests distinguish preview, report, receipt, and audit view.

## Summary

Receipts and reports are document artifacts. Headless should preserve title,
sections, metadata, timestamps, privacy class, and export structure while
product code owns authority and evidence.
