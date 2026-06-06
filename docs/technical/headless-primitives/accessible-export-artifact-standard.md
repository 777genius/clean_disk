# Accessible Export Artifact Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- W3C WCAG PDF techniques: https://www.w3.org/WAI/GL/WCAG-PDF-TECHS-20010903/
- WCAG techniques: https://w3c.github.io/wcag/techniques/
- WAI tables tutorial: https://www.w3.org/WAI/tutorials/tables/
- ISO PDF/UA overview: https://www.iso.org/standard/64599.html
- WCAG 1.1.1 Non-text Content: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 3.1.1 Language of Page: https://www.w3.org/WAI/WCAG22/Understanding/language-of-page.html

## Problem

Exported reports are product UI after they leave the app. A screen can be
accessible while its PDF, CSV, HTML, image, or print output is not. Disk usage
tools often export tables, charts, receipts, and support bundles that need
headings, table headers, reading order, alt text, language, metadata, and
privacy redaction.

Headless needs export artifact contracts, not just on-screen component
contracts.

## Decision Options

1. Treat exports as app-specific files - 🎯 5   🛡️ 5   🧠 2, about 0-100 LOC.
   Fine for MVP, weak for public component reuse.
2. Add accessible export artifact descriptors - 🎯 9   🛡️ 9   🧠 6, about
   350-900 LOC. Best fit.
3. Build full PDF/UA generator in Headless - 🎯 3   🛡️ 5   🧠 10, about
   3000-8000 LOC. Too broad and dependency-heavy.

Accepted: option 2.

## Accepted Contract

Headless exports semantic artifact plans:

```dart
final class RAccessibleExportPlan {
  final RExportFormat format;
  final String title;
  final String languageTag;
  final List<RExportHeading> headings;
  final List<RExportTable> tables;
  final List<RExportAltText> nonTextAlternatives;
  final RReadingOrder readingOrder;
  final RRedactionProfile redactionProfile;
}
```

Export adapters map this plan to PDF, HTML, CSV, Markdown, or platform print.

## Rules

- PDF exports aim for tagged PDF and PDF/UA-compatible structure where the
  chosen library supports it.
- CSV exports include headers, encoding, delimiter policy, and data dictionary
  when needed.
- HTML exports preserve landmarks, headings, table headers, and language.
- Image exports include text alternative or companion data table.
- Print snapshots preserve reading order and do not rely only on color.
- Receipts and support bundles apply privacy redaction before export.
- Exported destructive operation receipts distinguish estimate from fact.

## Clean Disk Requirements

Clean Disk may export:

- scan summary report;
- top folders CSV;
- cleanup receipt;
- support bundle summary;
- comparison report;
- disk usage map image with data table.

All exports that users may share must avoid raw secrets and must identify stale,
historical, or current data status.

## Format Boundaries

```text
PDF:
  semantic structure required, visual layout secondary

CSV:
  machine-readable table with headers and schema notes

HTML:
  accessible document with headings, landmarks, and tables

image:
  visual snapshot plus alt text or companion table

supportBundle:
  privacy-first evidence package
```

## Testing Requirements

- Export plan snapshot contains title, language, headings, and table headers.
- CSV fixture opens with headers and stable column ids.
- PDF adapter reports whether tagging is supported.
- Image export includes alt text or companion table.
- Redaction test with synthetic paths and tokens.
- Screen-reader smoke test for HTML export.

## Failure Catalog

- PDF is a screenshot with no text layer.
- CSV columns have localized headers only and no stable ids.
- Chart export lacks data table.
- Cleanup receipt hides that reclaim size was an estimate.
- Support bundle contains full path despite redaction profile.
- Export language metadata is missing.

## Release Gates

- Any export feature requires an export plan.
- PDF accessibility claim requires adapter evidence.
- Privacy redaction runs before writing artifact.
- Export format limitations are visible in diagnostics.

## Summary

Exports are part of the product surface. Headless should provide semantic export
plans so PDF, CSV, HTML, image, and support artifacts remain accessible and
privacy-aware.
