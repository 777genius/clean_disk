# Column View Preset Layout Personalization Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Grid and Table Properties: https://www.w3.org/WAI/ARIA/apg/practices/grid-and-table-properties/
- MDN `aria-sort`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-sort
- MDN `aria-colcount`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-colcount
- MDN `aria-colindex`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-colindex
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 3.2.4 Consistent Identification: https://www.w3.org/WAI/WCAG22/Understanding/consistent-identification.html

## Scope

This standard covers column visibility, column order, column width, pinning,
sort state display, density presets, saved views, per-user table preferences,
and layout personalization for data-heavy Headless primitives.

It extends the column operations RFC. It focuses on persistence, API shape, and
semantic stability.

## Problem

Column personalization is useful, but it can break accessibility and product
safety if the saved state hides important facts or changes focus order
unexpectedly. Clean Disk can allow users to hide "Modified" or resize "Name",
but it must not hide stale/delete warnings or use display column order as
domain command meaning.

## Decision Options

1. Versioned `ColumnViewPreset` contract owned by grid foundation -
   🎯 9   🛡️ 9   🧠 8, roughly 900-1900 LOC.
   Best fit. It separates stable column descriptors from user preferences and
   supports public Headless use.
2. Store raw UI state in app preferences -
   🎯 5   🛡️ 5   🧠 3, roughly 200-500 LOC.
   Quick, but brittle across schema changes, localization, and accessibility
   changes.
3. No personalization until after V1 -
   🎯 7   🛡️ 8   🧠 2, roughly 0-100 LOC now.
   Acceptable for MVP, but V1 descriptors still need extension points to avoid
   breaking changes.

Accepted direction: option 1 as future contract, option 3 for MVP delivery.

## Primitive Boundary

Headless owns:

- column descriptor ids;
- default column order;
- default visibility;
- width policy;
- min and max width;
- pinned side;
- semantic importance;
- hideability;
- sort display facts;
- preference validation;
- migration result.

Renderer owns:

- column chooser visuals;
- resize handles;
- drag/reorder visuals;
- pinned divider visuals;
- density appearance;
- saved view menu visuals.

Application owns:

- persistence;
- user profile scope;
- enterprise policy;
- route-specific defaults;
- product-critical column policy;
- backend query mapping.

## Column Descriptor Rules

Column descriptor must include:

- stable column key;
- localized label;
- accessible label override if needed;
- data role;
- width policy;
- visibility policy;
- hideability;
- sort capability;
- resize capability;
- pin capability;
- semantic importance;
- privacy class.

Column key must not be:

- localized label;
- index in current order;
- backend raw field if backend field is unstable;
- renderer widget key.

## Preset Model

Preset contains:

- preset id;
- schema version;
- target primitive id;
- column order;
- visible columns;
- widths;
- pinned columns;
- density;
- sort display preference;
- compact fallback policy;
- created/updated timestamps;
- migration state.

Preset must not contain:

- selected row ids;
- cleanup queue ids;
- raw daemon token;
- private search text unless policy allows;
- localized labels as authority.

## Migration Rules

When descriptors change:

- unknown saved columns are ignored and reported;
- required columns are restored;
- removed columns do not crash the grid;
- renamed labels do not break saved order;
- incompatible preset falls back to default;
- migration can be surfaced as non-blocking status.

Risk policy:

- hiding a product-critical warning column is blocked;
- hiding a low-importance convenience column is allowed;
- unknown importance fails closed for risky screens.

## Accessibility Rules

Column personalization must preserve:

- row/cell identity;
- focus order;
- header association;
- sort state on one sorted header where applicable;
- virtualized `aria-colindex` and `aria-colcount`;
- keyboard access to resize/reorder controls if those features exist.

Column chooser:

- exposes checked state for visible columns;
- explains disabled required columns;
- provides reset to default;
- does not depend on drag alone for reorder.

## Clean Disk Usage

MVP:

- fixed columns: name, size, percent, items, modified;
- backend sort by typed field;
- no reorder, pinning, or persisted width preferences.

Future:

- user can hide low-priority columns;
- warning/status column remains required when risky actions exist;
- saved compact and wide presets;
- per-route default views for scan, search, history, compare, and receipts.

Rules:

- column visibility is UI preference only;
- hidden warnings must still affect command enablement;
- hidden columns do not hide facts from confirmation UI;
- sort/filter semantics remain application/Rust contracts.

## Community API Sketch

```dart
final class RColumnDescriptor {
  const RColumnDescriptor({
    required this.key,
    required this.label,
    required this.role,
    required this.width,
    required this.visibility,
    required this.importance,
  });

  final String key;
  final String label;
  final RColumnRole role;
  final RColumnWidthPolicy width;
  final RColumnVisibilityPolicy visibility;
  final RSemanticImportance importance;
}

final class RColumnViewPreset {
  const RColumnViewPreset({
    required this.id,
    required this.schemaVersion,
    required this.visibleColumns,
    required this.columnOrder,
    required this.widths,
  });

  final String id;
  final int schemaVersion;
  final Set<String> visibleColumns;
  final List<String> columnOrder;
  final Map<String, double> widths;
}
```

## Conformance Scenarios

- hidden column is removed from focus order;
- required column cannot be hidden;
- reset restores default order and visibility;
- stale preset migrates or falls back;
- sort state remains on correct header after reorder;
- virtualized column indices remain valid;
- compact layout exposes same critical facts;
- hidden warning still blocks destructive command.

## Failure Catalog

- Column id is localized label.
- Saved preset hides required warning facts.
- Reorder changes backend sort meaning.
- Drag is the only way to reorder columns.
- Removed column crashes saved view restore.
- Hidden column still receives keyboard focus.
- Preset stores private query or daemon token.

