# Async Collection Cursor Window Contract Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Grid and Table Properties: https://www.w3.org/WAI/ARIA/apg/practices/grid-and-table-properties/
- MDN `aria-busy`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy
- MDN `status` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html

## Scope

This standard covers async collection data windows, backend cursors, page
ranges, stale cursors, query windows, visible windows, prefetch windows,
partial rows, placeholder rows, and cursor invalidation contracts.

It extends async loading, pagination, virtualized metadata, and viewport
virtualization standards. It focuses on the contract between a Headless
collection and an app-owned data source.

## Problem

Clean Disk cannot send the whole scan tree to Flutter. The UI must ask for
children, top files, search results, and details by pages/windows. If Headless
assumes all rows are local, it will sort/filter incorrectly, select placeholder
rows, or treat stale pages as cleanup authority.

## Decision Options

1. `AsyncCollectionWindow` contract with cursor, version, and stale facts -
   🎯 10   🛡️ 9   🧠 9, roughly 1000-2300 LOC.
   Best fit. It matches large data apps and Clean Disk's Rust-owned tree.
2. Local in-memory collection model only -
   🎯 5   🛡️ 5   🧠 4, roughly 300-900 LOC.
   Fine for small lists, but wrong for million-row trees and web/daemon
   boundaries.
3. App manually patches rows into Headless without a cursor contract -
   🎯 5   🛡️ 5   🧠 5, roughly 400-1000 LOC.
   Flexible, but stale behavior and authority rules become inconsistent.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- collection ref;
- requested window;
- loaded window;
- visible window;
- cursor facts;
- version facts;
- placeholder facts;
- busy/stale state;
- retry/cancel command;
- selection compatibility rules;
- status announcement policy.

Renderer owns:

- loading row visuals;
- skeleton visuals;
- scroll extent illusion;
- prefetch indicators;
- error row visuals;
- compact loading presentation.

Application owns:

- data loading;
- cursor format;
- cache policy;
- query execution;
- sorting/filtering;
- row identity;
- delete/queue authority.

## Window Types

Window kinds:

- visibleWindow;
- overscanWindow;
- prefetchWindow;
- requestedWindow;
- loadedWindow;
- pinnedWindow;
- anchorWindow;
- searchResultWindow.

Rules:

- visible window is not complete result set;
- overscan rows are not automatically focusable;
- prefetched rows are not announced unless surfaced;
- loaded window can be stale;
- anchor window may be needed to preserve scroll position.

## Cursor Facts

Cursor fact includes:

- cursor id or token;
- query id;
- snapshot/version id;
- sort/filter descriptor id;
- parent item ref if hierarchical;
- offset/range when applicable;
- direction;
- expiry/stale marker;
- privacy class.

Cursor token is opaque to Headless. It is not displayed, logged, localized, or
used as item identity.

## Row Facts

Loaded row includes:

- stable item id;
- row kind;
- semantic level;
- position facts;
- selected/disabled/stale facts;
- capability facts;
- approximate/exact value markers;
- placeholder flag;
- error flag.

Placeholder rows:

- can preserve scroll shape;
- cannot be selected by default;
- cannot be queued;
- cannot be used as command target;
- must be replaced or removed by versioned update.

## Stale And Version Rules

Invalidate windows when:

- query changes;
- sort changes;
- filter changes;
- snapshot changes;
- permissions change;
- session changes;
- daemon reconnects with incompatible version;
- cursor expires.

Late responses:

- ignored if request id is old;
- downgraded if version is stale and product allows read-only display;
- never overwrite newer authoritative row state;
- never re-enable risky commands.

## Accessibility Rules

For web adapters:

- use total row/column count when known;
- use unknown count when not known;
- expose row indices for mounted rows when using virtualized grid/table;
- use busy intent while coherent updates are pending;
- announce loading completion in coarse messages.

For Flutter adapters:

- keep semantic indices stable within loaded projection;
- avoid rebuilding unrelated visible rows;
- expose loading/error rows as rows only when they are navigable;
- preserve focus when a window refreshes.

## Clean Disk Usage

Rust owns:

- full scan tree;
- sort/filter/search indexes;
- details queries;
- top file/folder queries;
- cursor/page contracts.

Flutter owns:

- visible row cache;
- view model mapping;
- selection state by stable refs;
- display preferences.

Rules:

- Flutter must not sort/filter full tree locally;
- stale pages are read-only;
- selection survives paging by item refs;
- cleanup queue requires current validation outside Headless;
- support bundles do not dump cursor payloads.

## Community API Sketch

```dart
final class RAsyncCollectionWindow {
  const RAsyncCollectionWindow({
    required this.collection,
    required this.request,
    required this.state,
    required this.rows,
    required this.cursor,
  });

  final RCollectionRef collection;
  final RWindowRequest request;
  final RWindowState state;
  final List<RCollectionRow> rows;
  final RCursorFact? cursor;
}
```

## Conformance Scenarios

- stale cursor cannot load risky command authority;
- late response does not overwrite newer window;
- placeholder row cannot be selected by default;
- visible window is not announced as total result set;
- sort change invalidates old cursor;
- focus survives refresh when focused item still exists;
- unknown row count is exposed as unknown, not zero;
- cursor token is absent from diagnostics.

## Failure Catalog

- Cursor token used as row id.
- Visible rows treated as all rows.
- Placeholder row can be queued.
- Old page response restores stale command availability.
- Local Flutter sort runs over partial rows.
- Unknown total displayed as zero.
- Cursor payload leaked in logs.

