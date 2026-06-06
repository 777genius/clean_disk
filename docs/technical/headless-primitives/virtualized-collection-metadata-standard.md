# Virtualized Collection Metadata Standard

## Status

Accepted as a Headless runtime interoperability standard. Not implemented yet.

## Source Standards

- WAI-ARIA APG Grid and Table Properties: https://www.w3.org/WAI/ARIA/apg/practices/grid-and-table-properties/
- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- MDN `aria-rowcount`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-rowcount
- MDN `aria-rowindex`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-rowindex
- MDN `aria-colcount`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-colcount
- MDN `aria-colindex`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-colindex
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html

## Scope

This standard defines metadata for virtualized, paged, filtered, sorted, and
partially loaded collections.

It applies to:

- TreeGrid;
- data grids;
- listbox;
- command palette results;
- search results;
- paginated tables;
- large logs;
- disk usage maps with projections.

It does not define data fetching. It defines what collection facts primitives
must expose to users and adapters.

## Decision Options

Option A: Expose only visible rows - 🎯 3   🛡️ 3   🧠 2, about 100-250 LOC.

- Easy.
- Assistive tech and automation cannot understand total position or partial
  state.

Option B: App-specific metadata per data surface - 🎯 5   🛡️ 5   🧠 4,
about 300-900 LOC.

- Flexible.
- TreeGrid, listbox, search, and charts drift.

Option C: Shared collection metadata contract - 🎯 9   🛡️ 9   🧠 7, about
900-1800 LOC.

- Accepted direction.
- Visible range, total count, unknown totals, row index, and partial state are
  explicit.

## Accepted Direction

Headless should define `CollectionMetadata`.

It includes:

- total item count;
- known or unknown total;
- visible range;
- loaded range;
- filtered count;
- selected count;
- group count;
- sort order;
- page cursor;
- row and column index origin;
- snapshot version;
- partial state;
- privacy class.

## Count Rules

Counts can be:

- exact;
- estimated;
- unknown;
- lower bound;
- upper bound;
- partial;
- stale.

Do not expose unknown totals as exact row counts.

If total is unknown, adapter should avoid misleading `aria-rowcount` values or
use pattern-supported unknown representation where available.

## Index Rules

Indexes must be:

- stable within current query view;
- based on semantic collection order;
- not visible widget index;
- updated after sort or filter;
- associated with snapshot version.

Visible index can be 0-based internally, but accessibility index may need
1-based mapping depending on platform.

## Virtualization Rules

Virtualization must publish:

- mounted range;
- overscan range;
- semantic visible range;
- focusable range;
- load pending range;
- anchor item ref;
- stable item refs.

Mounted range is not the same as collection truth.

## Partial Loading Rules

Partial state includes:

- loading children;
- load failed;
- permission limited;
- stale page;
- cancelled query;
- gap in range;
- unknown descendants.

UI must distinguish "no items" from "not loaded" and "not permitted".

## Clean Disk Requirements

Clean Disk TreeGrid metadata:

- total scanned nodes can be huge;
- visible table range is small;
- child count may be known or lazy;
- skipped nodes affect quality;
- sort and filter happen in Rust;
- Flutter must not sort full tree locally.

Rules:

- row count display must not claim exact total when query is partial.
- selected rows are tracked by refs outside visible range.
- accessibility row index reflects current query order.

## API Shape Sketch

```text
CollectionMetadata
  totalCount
  totalKind
  filteredCount
  visibleRange
  loadedRange
  selectedCount
  sort
  snapshotVersion
  partialState

VirtualRange
  start
  end
  refs
  indexOrigin
```

## Conformance Scenarios

- virtualized grid exposes row positions in current query;
- unknown total is not announced as exact count;
- filtering updates filtered count and row indexes;
- selection outside visible range remains counted;
- load failure is not empty state;
- tree branch with unknown children announces loading or unknown state;
- mounted row index is not used as semantic row index;
- snapshot change invalidates collection metadata.

## Failure Catalog

- screen reader sees only 20 rows out of 100,000 with no total context;
- unknown total shown as exact;
- row index equals widget index after scroll;
- filtered count stale after query change;
- selected count loses offscreen items;
- permission-limited branch appears empty;
- Flutter sorts visible page only and changes semantic order;
- row count leaks private full dataset when policy forbids it;
- partial load state hidden behind spinner forever;
- chart projection has no collection metadata.

