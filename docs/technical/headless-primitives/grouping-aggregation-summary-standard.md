# Grouping Aggregation Summary Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Grid and Table Properties: https://www.w3.org/WAI/ARIA/apg/practices/grid-and-table-properties/
- WAI tables tutorial: https://www.w3.org/WAI/tutorials/tables/
- MDN `rowgroup` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/rowgroup_role
- MDN `<tbody>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/tbody
- MDN `<colgroup>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/colgroup
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html

## Scope

This standard covers group rows, aggregate rows, subtotal rows, group headers,
collapsed group summaries, grouped cards, grouped result sets, and aggregate
facts inside large virtualized collections.

It does not cover tree hierarchy itself. Grouping is a data projection.
Hierarchy is an identity and navigation model.

## Problem

Clean Disk will naturally need grouping: by folder category, file kind, size
bucket, modified recency, skipped reason, provider, or recommendation source.
That grouping can appear next to a real folder tree. If Headless mixes group
rows with tree nodes, users and code can confuse a projection row with a real
filesystem target.

## Decision Options

1. Separate `GroupProjection` model over collection rows -
   🎯 9   🛡️ 9   🧠 8, roughly 900-1900 LOC.
   Best fit. It keeps grouping reusable for TreeGrid, table, list, and card
   views while preserving Clean Disk identity boundaries.
2. Encode groups as fake tree nodes -
   🎯 4   🛡️ 4   🧠 4, roughly 300-700 LOC.
   Cheap, but dangerous. Fake nodes can accidentally become selectable cleanup
   targets.
3. Render group headings as visual-only separators -
   🎯 5   🛡️ 5   🧠 3, roughly 200-500 LOC.
   Looks fine, but loses keyboard navigation, count facts, collapse state, and
   screen reader structure.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- group id;
- group label;
- group description;
- group level;
- group row semantics;
- aggregate facts;
- expanded/collapsed state;
- child count facts;
- sort/group order facts;
- selection policy;
- focus policy;
- virtualized row index mapping.

Renderer owns:

- group header visuals;
- sticky group header appearance;
- indentation;
- aggregate chip layout;
- collapse affordance visuals;
- compact card grouping.

Application owns:

- grouping dimension;
- aggregate calculation;
- query execution;
- group labels;
- permission/risk meaning;
- delete and queue policy.

## Group Identity Rules

Group id must be:

- stable within a snapshot and query version;
- separate from item ids;
- separate from filesystem node ids;
- not localized;
- not derived from display order alone.

Group rows may be selectable only when the application provides explicit group
selection semantics. Group selection is not item selection unless it carries a
declared scope.

## Group Types

Supported concepts:

- static group;
- query group;
- aggregate group;
- virtual group;
- expandable group;
- collapsed summary group;
- mixed-source group;
- permission-limited group.

Each group declares:

- whether it contains real rows;
- whether child count is known;
- whether aggregate values are exact;
- whether collapse hides selected children;
- whether group actions affect children;
- whether the group is stale.

## Aggregation Facts

Aggregate value must distinguish:

- sum;
- count;
- min;
- max;
- average;
- median;
- percentile;
- exclusive estimate;
- approximate estimate;
- unknown.

For Clean Disk:

- logical size sum is not reclaimable size;
- allocated size sum is not exclusive reclaim;
- group total may double-count hardlinks or shared extents unless accounting
  fact says otherwise;
- skipped children must be visible in aggregate evidence.

## Accessibility Rules

Group rows should expose:

- row or heading semantics depending on collection pattern;
- level when nested;
- expanded state when collapsible;
- count and aggregate summary in description;
- disabled or stale state when group cannot drive actions.

For web adapters:

- use `rowgroup` only when it represents table/grid row grouping;
- do not use `rowgroup` as a generic card grouping shortcut;
- maintain `aria-rowindex` and `aria-rowcount` for virtualized rows;
- avoid fake `rowspan` unless supported by the actual grid/table structure.

For Flutter adapters:

- expose group label and child count through semantics;
- make collapsed state operable by keyboard;
- do not hide selected descendants from selection summary.

## Grouping And Tree Hierarchy

Group row:

- describes a projection;
- may contain items from many folders;
- has group id;
- may be rebuilt by query.

Tree node:

- describes domain hierarchy;
- has node id;
- has path or opaque filesystem identity;
- can be used for details and maybe cleanup after validation.

Stop rule:

- never use a group id as a delete target id.

## Clean Disk Usage

Accepted group projections:

- by file kind;
- by cleanup category;
- by app/tool owner;
- by skipped reason;
- by risk tier;
- by modified recency;
- by provider state;
- by target volume.

MVP can skip grouping UI, but TreeTable API must preserve room for group
rows, group metadata, and aggregate rows without breaking row identity.

## Community API Sketch

```dart
sealed class RCollectionRowKind {
  const RCollectionRowKind();
}

final class RDataRowKind extends RCollectionRowKind {
  const RDataRowKind(this.itemId);
  final String itemId;
}

final class RGroupRowKind extends RCollectionRowKind {
  const RGroupRowKind(this.groupId);
  final String groupId;
}

final class RAggregateFact {
  const RAggregateFact({
    required this.key,
    required this.value,
    required this.method,
    required this.confidence,
  });

  final String key;
  final Object? value;
  final RAggregateMethod method;
  final RConfidence confidence;
}
```

## Conformance Scenarios

- group row has label and level;
- collapse state is keyboard-operable;
- virtualized row indices stay valid with collapsed groups;
- group id is not used as item id;
- aggregate fact exposes estimate and confidence;
- selected hidden children remain in selection summary;
- group action carries explicit scope;
- screen reader can distinguish group row from data row.

## Failure Catalog

- Group rows implemented as fake folders.
- Group total presented as exact reclaimable space.
- Collapsing a group silently deselects children.
- Group header is visual-only and not reachable by keyboard.
- Virtual row count ignores collapsed rows.
- Group id is localized display text.
- Bulk action on group bypasses application policy.

