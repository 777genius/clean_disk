# Viewport Virtualization Accessibility And Performance Playbook

## Status

Compliance playbook for large virtualized primitives such as `RTreeGrid`,
`RGrid`, long menus, and large command lists.

## Standards And References

- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN `treegrid` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/treegrid_role
- MDN `row` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Roles/row_role
- Flutter performance profiling:
  https://docs.flutter.dev/perf/ui-performance
- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing

## Core Principle

Virtualization is allowed only if it preserves logical interaction. The user
must not be able to tell, through keyboard, assistive technology, selection, or
commands, that most rows are not currently mounted.

## Required Separation

Virtualized primitives must keep separate models:

- source model: immutable or versioned application data;
- logical collection model: ids, indexes, hierarchy, sort/filter projection;
- viewport model: visible range, overscan, scroll anchor;
- focus model: active logical item and optional active cell;
- selection model: selected logical ids or ranges;
- semantic model: bounded facts exposed to the platform;
- renderer model: mounted widgets only.

The renderer model is never authority for focus, selection, checked state, or
command targets.

## Index And Count Rules

For tree/grid-like components:

- total row count may be known, approximate, loading, or unknown;
- visible row index must refer to logical row position, not mounted widget
  index;
- hidden collapsed descendants must not inflate visible count;
- filtered-out rows must not be focus targets;
- row ids must remain stable through scroll;
- row labels must not be used as ids.

When a platform bridge supports ARIA-style facts, it should be able to map:

- row count;
- column count;
- row index;
- column index;
- row level;
- set size and position if meaningful;
- expanded state only on expandable rows;
- selected state separate from focus.

## Focus Continuity Rules

When a focused row leaves the viewport:

- logical focus remains on the same item;
- mounted focus can move to a safe root sentinel if needed;
- returning the item to view restores visual focus;
- commands still target the logical item if valid;
- if the item disappears, focus resolves to nearest valid fallback.

Fallback order:

1. same logical id after data refresh;
2. nearest visible sibling;
3. nearest visible ancestor;
4. first visible row;
5. component root;
6. application-defined fallback.

## Scroll To Target Contract

Complex primitives need a first-class `scrollToKey` effect. It must:

- resolve logical id to current visible index;
- expand ancestors only if policy allows;
- support alignment: start, center, end, nearest;
- return failure reason if target is filtered, collapsed, missing, or denied;
- avoid synchronous full-tree materialization.

## Semantic Boundedness

Virtualization must not publish all rows to the semantics tree. A component
should expose only:

- visible rows;
- a small overscan range if needed by platform behavior;
- root summary;
- focused logical item;
- live status for loading or result count changes.

Screen readers must not be fed stale offscreen rows that can no longer receive
commands.

## Performance Budgets

Suggested first budgets for Clean Disk-scale fixtures:

```text
visible rows: 30-120
overscan rows: 10-60
target fixture: 50k visible rows
viewport rebuild per progress event: 0 full row rebuilds
row build cost: stable under sort/filter paging
semantic nodes: visible range bounded
```

These numbers are starting budgets, not public guarantees. Public guarantees
must come after benchmarks on macOS, Windows, Linux, and web.

## Event Throttling

High-frequency streams must be coalesced before reaching virtualized widgets.

Allowed:

- progress snapshots at UI cadence;
- viewport changes on animation frame or scheduler cadence;
- selection changes batched by user gesture;
- row data pages loaded by query.

Forbidden:

- one widget rebuild per scanned filesystem entry;
- one semantics update per progress tick;
- rebuilding the whole row projection on every scroll pixel;
- Flutter-side sorting of the full disk tree.

## Required Evidence

Automated:

- built row count stays bounded;
- semantics node count stays bounded;
- keyboard navigation across viewport boundary;
- focus restore after data refresh;
- selection remains stable after sort/filter;
- progress footer updates do not rebuild row viewport.

Manual:

- screen reader reads row position without claiming mounted count as total;
- fast scroll remains responsive;
- keyboard user can reach offscreen items through navigation;
- context menu restore works after unmount/remount;
- reduced motion does not break scroll-to-target.

## Stop Rules

- Do not make mounted widget index part of public API.
- Do not keep full product tree in Flutter for convenience.
- Do not expose all virtual rows to semantics.
- Do not treat scroll position as cleanup authority.
- Do not add renderer caches that outlive snapshot/query versions.
