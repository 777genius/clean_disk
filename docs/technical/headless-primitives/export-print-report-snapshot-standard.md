# Export Print Report And Snapshot Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN Blob: https://developer.mozilla.org/en-US/docs/Web/API/Blob
- MDN anchor `download`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/a#download
- MDN Printing: https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_media_queries/Printing
- WCAG 1.1.1 Non-text Content: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 1.4.3 Contrast Minimum: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html

## Scope

This standard defines how Headless primitives expose exportable, printable, and
shareable representations without making renderer pixels the source of truth.

It applies to:

- table exports;
- chart and visualization exports;
- details panel reports;
- operation receipts;
- diagnostic summaries;
- print views;
- snapshot URLs;
- copyable reports;
- redacted support bundles.

Headless does not write files by itself. It defines export contracts that app
adapters can fulfill.

## Decision Options

Option A: Screenshot or print current UI - 🎯 3   🛡️ 3   🧠 2, about
80-200 LOC.

- Fast.
- Inaccessible and fragile.
- Virtualized rows and hidden data are missing.

Option B: App-specific export actions - 🎯 5   🛡️ 5   🧠 4, about
300-800 LOC.

- Works for Clean Disk only.
- Repeats privacy, labels, and schema rules per feature.

Option C: Headless export projection contracts - 🎯 9   🛡️ 9   🧠 7, about
900-1700 LOC.

- Accepted direction.
- Primitives expose structured export projections.
- App adapters decide file formats and storage.
- Accessibility and privacy rules are shared.

## Accepted Direction

Every complex primitive that displays data should optionally expose an
`ExportProjection`.

The projection is structured:

- title;
- summary;
- columns;
- rows;
- groups;
- selection;
- filters;
- chart series;
- metadata;
- privacy classes;
- provenance;
- timestamp;
- schema version.

Renderer pixels are never the only export source.

## Export Types

Headless should support these semantic export intents:

- `copySelection`;
- `copySummary`;
- `downloadTable`;
- `downloadReport`;
- `printView`;
- `shareSnapshot`;
- `supportBundleItem`;
- `receiptExport`;
- `chartDataExport`;
- `chartImageExport`;

Each intent must state:

- allowed data classes;
- redaction profile;
- stable schema;
- user confirmation needs;
- failure behavior;
- supported platforms.

## Privacy Classes

Exported fields must be classified:

- `publicUi`;
- `localPath`;
- `userName`;
- `deviceName`;
- `scanMetadata`;
- `operationReceipt`;
- `diagnostic`;
- `sensitiveToken`;
- `secret`;

Default rule:

- sensitive tokens and secrets are never exportable;
- raw local paths require explicit app policy;
- support exports default to redacted paths;
- receipts can include enough evidence for support, but must be user-approved.

## Print Rules

Print projection must:

- include a document title;
- include headings;
- preserve table relationships;
- avoid relying on screen-only colors;
- include chart data summary or alt text;
- provide page-friendly layout;
- avoid printing hidden destructive controls as active controls;
- include timestamp and snapshot id when relevant.

The print view can be visually different from the screen view, but the content
meaning must match the selected export intent.

## Blob And Download Rules

Web adapters may use Blob and download links, but Headless must only request an
export through adapter capability.

Rules:

- generated filename must not leak raw sensitive path unless policy allows;
- Blob URLs must be revoked after use;
- export progress must be visible for large data;
- cancellation must be possible where practical;
- failed downloads must publish recoverable status;
- browser-only filename behavior is advisory, not guaranteed.

## Snapshot Rules

Snapshot means a stable view of data at a moment in time, not live state.

Snapshot export must include:

- snapshot id;
- source version;
- query version;
- selected projection;
- generated time;
- data freshness;
- redaction profile;
- compatibility version.

Clean Disk:

- exported scan report can be historical;
- historical nodes are not current cleanup targets;
- export must not imply current delete safety.

## Accessibility Rules

Exported reports should preserve:

- headings;
- table headers;
- row grouping;
- list structure;
- labels;
- alternative text for charts;
- status or warning messages;
- units and quantity precision.

If exporting image-only chart, Headless should also provide data table or text
summary.

## Clean Disk Requirements

Clean Disk export intents:

- scan summary;
- largest folders table;
- selected subtree details;
- cleanup queue review;
- cleanup receipt;
- support diagnostics summary;
- disk usage map data;
- benchmark or scan performance summary.

Rules:

- export never includes daemon token;
- export never includes full raw scan tree by accident;
- support export defaults to redacted paths;
- cleanup receipt export must show operation outcome and restore status;
- print view must not show disabled button as actionable.

## API Shape Sketch

```text
ExportProjection
  schemaVersion
  title
  sections
  tables
  charts
  metadata
  privacyClasses
  provenance

ExportIntent
  kind
  format
  redactionProfile
  scope
  confirmationPolicy

ExportAdapter
  canExport(intent)
  prepare(projection, intent)
  deliver(preparedExport)
```

## Conformance Scenarios

- exporting a virtualized table includes requested page or explicit full query,
  not only visible rows by accident;
- chart export includes data labels or table fallback;
- print view has title and headings;
- support export redacts raw path by default;
- Blob URL is revoked after download;
- cancelled export leaves no partial UI authority;
- stale snapshot export is labeled historical;
- filename does not include sensitive path by default.

## Failure Catalog

- screenshot used as primary report;
- virtualized hidden rows silently missing from full export;
- raw paths leaked in filename;
- chart image exported without data or alt text;
- Blob URL kept forever;
- print CSS hiding warnings;
- export action bypassing privacy policy;
- historical export presented as current cleanup authority;
- disabled destructive controls printed as live commands;
- support bundle exporting daemon credentials.

