# Machine Readable Metadata And Provenance Standard

## Status

Accepted direction for Headless. Complements technical identifiers, evidence,
privacy, and export standards. Not implemented yet.

## Source Standards

- MDN `data`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/data
- MDN data attributes: https://developer.mozilla.org/en-US/docs/Web/HTML/How_to/Use_data_attributes
- MDN microdata: https://developer.mozilla.org/en-US/docs/Web/HTML/Guides/Microdata
- W3C PROV Overview: https://www.w3.org/TR/prov-overview/
- W3C PROV Data Model: https://www.w3.org/TR/prov-dm/
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html

## Problem

Accessible UI needs human-readable semantics. Automation, exports, support
bundles, audit trails, and tests need machine-readable facts. Mixing these
concerns creates dangerous patterns: localized labels become identifiers,
DOM attributes leak private paths, test ids become product authority, and
support exports cannot prove where a value came from.

Headless needs a metadata and provenance boundary.

## Decision Options

1. Use ad hoc `data-*` and test ids everywhere - 🎯 3   🛡️ 3   🧠 2,
   about 50-150 LOC. Easy, but leaky and ungoverned.
2. Add typed metadata and provenance descriptors - 🎯 9   🛡️ 9   🧠 7,
   about 600-1400 LOC. Best fit.
3. Force W3C PROV directly into every component API - 🎯 4   🛡️ 7   🧠 10,
   about 2000-6000 LOC. Too heavy for core UI APIs.

Accepted: option 2.

## Accepted Contract

Headless exposes metadata through typed descriptors:

```dart
final class RMachineMetadata {
  final String metadataId;
  final RMetadataKind kind;
  final Map<String, RMetadataValue> values;
  final RPrivacyClass privacyClass;
  final RProvenanceRef? provenanceRef;
  final RExportPolicy exportPolicy;
}
```

Provenance is referenced, not fully embedded in every primitive.

```dart
final class RProvenanceRef {
  final String sourceId;
  final String activityId;
  final String? generatedAtIso8601;
  final RProvenanceConfidence confidence;
}
```

## Metadata Kinds

```text
semanticFact:
  stable fact needed by adapter, test, or export

testLocator:
  non-authoritative test hook

supportEvidence:
  support-safe fact

exportFact:
  fact intended for generated artifact

automationHint:
  non-authoritative automation affordance

analyticsTag:
  privacy-budgeted instrumentation tag
```

## Rules

- Machine metadata is not user-facing label.
- Test locator is not domain identity.
- Metadata must have privacy class.
- Raw paths, tokens, query text, and user names are blocked by default.
- Provenance references point to product evidence, not renderer internals.
- Export policy says omit, include redacted, include support-safe, or include
  full with consent.
- Metadata schema is versioned.
- Unknown metadata kind fails closed for export and telemetry.

## Clean Disk Requirements

Clean Disk metadata appears in:

- scan snapshot node refs;
- query cursors;
- receipt evidence refs;
- support bundle fields;
- command ids;
- policy codes;
- test locators;
- export facts;
- chart projection ids.

Headless must never turn raw path or delete target into a DOM attribute or
test locator.

## Web Mapping

For web adapters:

- `data-*` can carry non-sensitive adapter metadata only;
- `data` element can pair visible text with machine-readable value where safe;
- microdata is optional and generally not needed for local app UIs;
- JSON-LD or structured export belongs to artifact/export layer, not every
  widget.

Flutter adapters should keep metadata in widget/view models and expose only
safe test hooks.

## Provenance Mapping

Headless does not implement W3C PROV. It can model enough to map outward:

```text
entity:
  displayed fact or artifact

activity:
  scan, query, cleanup validation, export

agent:
  app process, daemon, user intent, adapter

generatedAt:
  timestamp from product layer
```

The product can convert these to full PROV-like export where needed.

## Accessibility Rules

- Machine metadata does not replace accessible names.
- Hidden metadata is not announced as content.
- Support-safe evidence is available through details, not forced into labels.
- Automation hooks do not create extra focusable elements.
- Metadata does not alter reading order.

## Testing Requirements

- Raw path is absent from DOM attributes and test locators.
- Metadata privacy class is required.
- Unknown export policy omits metadata.
- Localized label change does not break test locator.
- Receipt export includes provenance refs.
- Support bundle uses support-safe metadata only.
- Accessibility snapshots exclude private metadata.

## Failure Catalog

- Node id is raw path.
- Test id becomes cleanup authority.
- Localized label used as command id.
- Support export cannot explain source of reclaim estimate.
- DOM `data-path` leaks user directory.
- Analytics tag includes query text.
- Unknown metadata kind exported by default.

## Release Gates

- Public Headless APIs separate label, identity, locator, and provenance.
- Metadata descriptors require privacy class.
- Clean Disk export and support bundle use versioned metadata schemas.
- DOM/web adapter has no private metadata leaks.
- Provenance refs connect receipts to product evidence.

## Summary

Machine-readable metadata is useful only when governed. Headless should carry
typed, privacy-classed metadata and provenance references without making DOM
attributes, test ids, or localized labels authoritative.
