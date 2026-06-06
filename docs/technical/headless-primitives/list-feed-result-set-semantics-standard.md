# List Feed And Result Set Semantics Standard

## Status

Accepted direction for Headless. Complements virtualized collection metadata,
pagination, search, and table standards. Not implemented yet.

## Source Standards

- MDN `ul`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/ul
- MDN `ol`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/ol
- MDN `li`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/li
- MDN ARIA `list` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/list_role
- MDN ARIA `listitem` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/listitem_role
- WAI-ARIA APG Feed Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/feed/
- MDN ARIA `feed` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/feed_role
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html

## Problem

Not every repeated surface is a table, menu, listbox, tree, or feed. Search
results, recent scans, delete queue entries, skipped issue groups, support
bundle sections, recommendation cards, and repair steps are often visually
similar but semantically different. If Headless exposes all repeated content as
generic containers, users lose item counts, order, grouping, and navigation
context. If it exposes everything as an interactive listbox, it creates false
selection semantics.

Headless needs a list, feed, and result-set contract.

## Decision Options

1. Leave repeated content to app widgets - 🎯 5   🛡️ 5   🧠 2, about
   80-200 LOC. Flexible, but public components will diverge.
2. Add typed collection semantics for lists, feeds, and result sets - 🎯 9
   🛡️ 9   🧠 6, about 500-1200 LOC. Best fit.
3. Force all repeated surfaces into TreeGrid - 🎯 4   🛡️ 5   🧠 4, about
   200-500 LOC. Overfits Clean Disk and hurts community reuse.

Accepted: option 2.

## Accepted Contract

Headless repeated content uses an explicit collection role:

```dart
final class RCollectionSemantics {
  final String collectionId;
  final RCollectionKind kind;
  final String? label;
  final int? totalCount;
  final int? visibleCount;
  final bool orderMatters;
  final RCollectionUpdateMode updateMode;
  final RSelectionSemantics selectionSemantics;
}
```

Items use stable collection-scoped ids:

```dart
final class RCollectionItemSemantics {
  final String itemId;
  final int? position;
  final int? setSize;
  final String? label;
  final RCollectionItemKind kind;
  final bool current;
  final bool selected;
}
```

## Collection Kinds

```text
unorderedList:
  related items where order is not meaningful

orderedList:
  steps, ranked results, ordered evidence

resultSet:
  query output with count, sort, filter, and stale state

feed:
  dynamic stream of article-like entries

queue:
  user-controlled pending items

timeline:
  chronological events

cardList:
  repeated standalone cards with actions
```

## Rules

- Use list semantics for lists, not listbox semantics, unless choosing one item
  is the primary behavior.
- Ordered lists are used when reordering changes meaning.
- Result sets expose query, count, sort, filter, and stale state outside item
  labels.
- Feeds are dynamic article streams and need position/set-size behavior.
- Queue is not delete authority. Queue item is intent only.
- Virtualized collection metadata stays valid when items unmount.
- Nested lists declare nesting, not just indentation.
- Item actions do not turn the whole list into a menu.

## Clean Disk Requirements

Clean Disk uses these semantics for:

- recent scans;
- scan target shortcuts;
- search results;
- skipped issue groups;
- delete queue;
- recommendation cards;
- repair steps;
- cleanup receipt item outcomes;
- support bundle section list;
- operation event timeline.

The central folder hierarchy remains TreeGrid, not list.

## Web Mapping

For web adapters:

- `ul`, `ol`, and `li` are preferred for static lists;
- ARIA `list` and `listitem` are fallbacks for custom render trees;
- ARIA `feed` applies only to dynamic article-like streams;
- `aria-posinset` and `aria-setsize` support virtualized or partial feeds
  where appropriate.

Flutter adapters should expose equivalent collection role, count, position,
selected/current state, and update behavior through semantics.

## Accessibility Rules

- Collection label is concise and not repeated inside every item.
- Result count is status text, not part of every item label.
- Ordered steps expose position.
- Current item and selected item are different states.
- Dynamic feed updates do not steal focus.
- Batch actions announce scope: selected, visible, filtered, or all.

## Testing Requirements

- Static list exposes list and item count.
- Ordered repair steps announce order.
- Search result set announces query and count once.
- Delete queue items are not exposed as final delete authority.
- Feed append preserves reading position.
- Virtualized result item reports correct logical position.
- Listbox role is not used for non-choice collections.

## Failure Catalog

- Recent scans are exposed as menu items.
- Search result count is repeated in every row.
- Delete queue item is treated as confirmed deletion.
- Infinite feed appends and moves screen-reader position.
- Ordered repair steps are exposed as unordered cards.
- Selection and current route are conflated.

## Release Gates

- Public repeated-content primitives choose a collection kind.
- Clean Disk design system exposes list, result set, queue, feed, and timeline
  facades.
- Result set counts and stale states are tested.
- Feed behavior is only claimed where APG feed expectations are met.
- Queue semantics are separated from destructive authority.

## Summary

Lists, feeds, result sets, queues, and timelines are different collection
types. Headless should model them explicitly so repeated UI surfaces remain
understandable, virtualizable, and safe.
