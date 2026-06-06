# Responsive Card Grid Alternate View Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- MDN CSS grid layout: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Grid_layout
- MDN CSS container queries: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Containment/Container_queries
- MDN CSS subgrid: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Grid_layout/Subgrid
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- WCAG 1.4.12 Text Spacing: https://www.w3.org/WAI/WCAG22/Understanding/text-spacing.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html

## Scope

This standard covers alternate card-grid renderers for the same collection
model used by tables, tree tables, search results, details lists, and compact
layouts.

It does not replace TreeGrid. It defines how a card/grid view can be a renderer
adapter over the same state and command model.

## Problem

Compact layouts often cannot show all columns. A card-grid view can be easier
to scan on narrow screens, but it must not lose semantic parity with the table
view. If the card renderer hides warnings, changes selection scope, or changes
focus order, users receive a different product with different safety behavior.

## Decision Options

1. `CollectionAlternateView` contract over shared row models -
   🎯 9   🛡️ 9   🧠 8, roughly 900-1900 LOC.
   Best fit. It lets the community build card, list, and table renderers over
   the same Headless state.
2. Per-screen responsive card widgets -
   🎯 6   🛡️ 5   🧠 4, roughly 300-900 LOC.
   Fast, but semantics and commands drift across breakpoints.
3. Keep table only and force horizontal scroll everywhere -
   🎯 6   🛡️ 7   🧠 2, roughly 100-300 LOC.
   Safe for data integrity, but poor for compact usability and WCAG reflow
   goals outside inherently two-dimensional tables.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- collection identity;
- item ids;
- row/card role mapping;
- selection state;
- focus model;
- action availability;
- critical facts list;
- alternate view capability;
- semantic parity assertions.

Renderer owns:

- card layout;
- CSS grid or Flutter layout;
- responsive breakpoints;
- media/icon placement;
- compact metadata layout;
- overflow handling;
- animation.

Application owns:

- which views are available;
- default view by form factor;
- product-critical facts;
- query execution;
- command behavior;
- persistence.

## Semantic Parity Rule

If table and card views represent the same result set, they must preserve:

- item id;
- selection state;
- focus target;
- command availability;
- stale state;
- disabled state;
- warning/risk state;
- approximate/exact value markers;
- result count;
- query/snapshot version.

They may differ in:

- visual density;
- number of visible secondary facts;
- wrapping behavior;
- grouping layout;
- media placement;
- action overflow placement.

## Critical Fact Policy

Each collection declares critical facts:

- identity label;
- primary value;
- status/warning;
- stale marker;
- risk marker;
- selection affordance;
- primary command;
- details affordance.

Renderer cannot hide critical facts unless:

- the fact is available through an equivalent accessible label;
- the fact is available in immediate details;
- product policy marks it optional for the current surface.

For Clean Disk, cleanup warnings and stale state are critical wherever queue or
delete commands are present.

## Layout Rules

Cards should use stable constraints:

- min and max inline size;
- predictable row height or bounded variable height;
- no content overlap at supported text scaling;
- long names and paths use ellipsis or line wrapping by policy;
- actions do not shift layout on hover;
- focus ring remains visible.

Web adapter:

- container queries are preferred for component-local responsiveness;
- CSS grid is appropriate for card grids;
- subgrid can align repeated card internals where supported;
- DOM order must match focus and reading order.

Flutter adapter:

- use slivers or virtualized list/grid for large result sets;
- do not mount thousands of cards at once;
- preserve stable keys and semantics ids;
- avoid rebuilds from progress events unrelated to visible cards.

## Collection Role Choice

Possible semantics:

- list of cards;
- grid of cards;
- feed of result cards;
- table alternative;
- grouped card collection.

Rules:

- use list semantics for one-dimensional navigation;
- use grid semantics only when directional navigation is meaningful;
- do not use data grid semantics just because visuals use CSS grid;
- card view must expose result count and item position for large sets.

## Clean Disk Usage

Compact layout may use card rows for:

- scan targets;
- cleanup candidates;
- recommendation cards;
- search result cards;
- receipt item summaries.

The folder tree/table remains the primary desktop workflow. Compact card view
is allowed only as an alternate renderer over the same query/session state.

Rules:

- card view cannot sort/filter locally;
- card view cannot queue hidden stale items;
- delete confirmation uses validated plan, not card state;
- details view must expose exact values hidden by compact card.

## Community API Sketch

```dart
final class RAlternateViewContract {
  const RAlternateViewContract({
    required this.collectionId,
    required this.viewKind,
    required this.criticalFacts,
    required this.parityPolicy,
  });

  final String collectionId;
  final RCollectionViewKind viewKind;
  final Set<String> criticalFacts;
  final RSemanticParityPolicy parityPolicy;
}
```

## Conformance Scenarios

- switching table to card preserves selected ids;
- hidden columns with critical warnings remain exposed;
- focus order follows visual/reading order;
- result count and item position are available;
- compact layout works at large text without overlap;
- card grid virtualizes large result sets;
- actions are keyboard reachable;
- card view disables stale risky commands.

## Failure Catalog

- Card renderer drops stale warning visible in table.
- DOM order differs from visual/focus order.
- Cards mount entire 100k result set.
- Hover-only actions are not keyboard accessible.
- Text scaling overlaps action buttons.
- Card view performs local sort on partial data.
- Selection in card view uses separate ids from table.

