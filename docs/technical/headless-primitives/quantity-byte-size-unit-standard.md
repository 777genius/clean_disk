# Quantity Byte Size And Unit Standard

## Status

Accepted direction for Headless. Extends the locale unit and quantity formatting
standard. Not implemented yet.

## Source Standards

- MDN Internationalization guide: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Internationalization
- MDN `Intl.NumberFormat`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat
- Unicode CLDR: https://cldr.unicode.org/
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 1.4.4 Resize Text: https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html
- WCAG 3.1.4 Abbreviations: https://www.w3.org/WAI/WCAG22/Understanding/abbreviations.html

## Problem

Disk tools live or die by size truth. The same visible `38.7 GB` can mean
logical size, allocated size, apparent size, compressed size, exclusive reclaim,
shared extent estimate, quota usage, cloud local bytes, or rounded chart label.
If Headless treats size as a string, it loses sorting, accessibility precision,
export fidelity, and safety language.

Headless needs a byte-size and unit quantity standard.

## Decision Options

1. Pass formatted strings - 🎯 3   🛡️ 3   🧠 1, about 20-80 LOC. Too weak.
2. Use generic typed quantity model only - 🎯 7   🛡️ 7   🧠 4, about
   250-600 LOC. Good start, but storage needs stronger accounting semantics.
3. Add storage-specific quantity facts on top of typed quantities - 🎯 9
   🛡️ 9   🧠 6, about 450-1100 LOC. Best fit.

Accepted: option 3.

## Accepted Contract

Storage quantities carry value, meaning, exactness, and display policy:

```dart
final class RStorageQuantity {
  final BigInt bytes;
  final RStorageQuantityKind kind;
  final RQuantityExactness exactness;
  final RByteUnitSystem unitSystem;
  final RoundingPolicy roundingPolicy;
  final String? accessibleValue;
  final RPrivacyClass privacyClass;
}
```

Headless does not calculate reclaim truth. It renders the facts supplied by the
application or domain model.

## Quantity Kinds

```text
logicalSize:
  bytes reported as file content length or apparent size

allocatedSize:
  storage blocks consumed according to platform scan

exclusiveReclaim:
  estimated bytes likely freed by deleting this item

sharedSize:
  bytes shared through hardlinks, clones, dedupe, snapshots, or provider state

localCloudBytes:
  bytes currently resident on this machine

remoteCloudBytes:
  bytes known to exist remotely, not necessarily local

quotaUsage:
  bytes counted against a user or volume quota

rate:
  bytes per second or items per second
```

## Unit Rules

- Unit system is explicit: decimal `KB/MB/GB/TB` or binary
  `KiB/MiB/GiB/TiB`.
- Product defaults may favor decimal units for user readability.
- Details, receipts, support bundles, and exports preserve raw bytes.
- Do not mix bytes and file counts in one value slot.
- Do not sort by formatted text.
- Do not compare rounded display strings.
- Percent values keep numerator and denominator facts.
- Rate values include window or sample source where relevant.

## Exactness Rules

```text
exact:
  source provides precise integer value for stated meaning

rounded:
  display rounded from exact or high-confidence value

estimated:
  value has known uncertainty

lowerBound:
  actual value is at least this amount

upperBound:
  actual value is no more than this amount

unknown:
  no defensible numeric value
```

Unknown is a valid state. It must not render as zero.

## Clean Disk Requirements

Clean Disk must display:

- total scanned size;
- largest folder size;
- cleanup candidate size;
- selected node size;
- exact bytes in details;
- chart segment percent;
- reclaim estimate with confidence;
- skipped bytes if available;
- scan throughput;
- file and folder counts.

Cleanup UI must distinguish `size on disk` from `likely reclaim`. A delete
button label cannot promise exact freed bytes without evidence.

## Accessibility Rules

- Compact cells may show `38.7 GB`; accessible value may include
  `38.7 gigabytes, exact 41,570,752,512 bytes`.
- Estimated reclaim should announce uncertainty.
- Abbreviations such as GB and KiB need glossary support where audience needs
  it.
- Braille output can use compact display with details on demand.
- Screen-reader progress announcements should throttle byte-rate updates.

## Chart Rules

- Chart labels receive bounded storage quantities, not formatted strings.
- Treemap area is based on a declared quantity kind.
- Legend and details must use same quantity kind unless clearly labeled.
- Shared or unknown reclaim must not be visually implied as safe-to-delete.

## Testing Requirements

- Large values beyond JavaScript safe integer survive web DTO mapping.
- Sort uses raw bytes.
- Exact bytes remain available when display is rounded.
- Unknown value does not render as zero.
- Decimal and binary units are not mixed silently.
- RTL locale and compact locale formatting do not corrupt value semantics.
- Accessible value includes meaning and uncertainty.

## Failure Catalog

- `38.7 GB` sorted lexicographically before `9 GB`.
- Reclaim estimate shown as exact freed bytes.
- Shared APFS clone counted twice in cleanup total.
- Unknown size shown as `0 B`.
- Chart area uses logical size while details label says reclaim.
- JS number loses precision for large byte count.

## Release Gates

- Storage quantities use typed model, not strings.
- Byte values cross protocol as string or safe integer wrapper.
- Clean Disk delete queue labels show reclaim confidence.
- Unit system and exactness are visible in details and exports.
- Quantity fixtures cover huge, unknown, shared, and estimated values.

## Summary

Storage quantities must carry meaning, exactness, raw bytes, and display policy.
Headless renders them, but domain accounting remains outside the UI layer.
