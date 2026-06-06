# Headless Tree Foundation RFC

## Status

Accepted design direction. Not implemented yet.

## Problem

TreeView and TreeGrid need expansion state, depth, parent/child navigation,
lazy child loading, and visible row projection. These are tree mechanics and
should not be tied to table/grid rendering.

## Standards And References

- WAI-ARIA APG Tree View:
  https://www.w3.org/WAI/ARIA/apg/patterns/treeview/
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN ARIA tree role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/tree_role
- Flutter `TreeView` from `two_dimensional_scrollables`:
  https://pub.dev/documentation/two_dimensional_scrollables/latest/two_dimensional_scrollables/TreeView-class.html

## Accepted Direction

Create reusable tree mechanics in `headless_foundation`:

```text
headless_foundation/lib/src/tree/
  tree_node_key.dart
  tree_node_state.dart
  tree_expansion_state.dart
  tree_expansion_controller.dart
  tree_projection.dart
  tree_navigation.dart
  tree_loading_state.dart
  tree_semantic_level.dart
```

## Top Options

1. Dedicated tree foundation - 🎯 9   🛡️ 8   🧠 7,
   roughly 600-1200 LOC.

   Best reuse. Supports `RTreeView`, `RTreeGrid`, nested menus, file pickers,
   navigation trees, and outline views.

2. Use Flutter `TreeView` controller directly - 🎯 6   🛡️ 6   🧠 5,
   roughly 300-700 LOC.

   Good for layout, but not enough for Headless semantics, controlled state,
   renderer contracts, app-owned async loading, or shared conformance.

3. Keep expansion only in app state - 🎯 5   🛡️ 5   🧠 4,
   roughly 300-700 LOC.

   Works for one screen, weak for community primitives.

Accepted: option 1.

## Core Contracts

```text
TreeNodeKey
TreeNodeDepth
TreeNodeParentKey

TreeNodeState
  key
  parentKey
  depth
  expandable
  expanded
  loading
  disabled
  childCountKnown
  childCount

TreeVisibleNode
  key
  depth
  visibleIndex
  ancestorKeys
  isLastChild facts if caller provides them
```

## Expansion Model

Expansion is controlled by stable keys:

```text
TreeExpansionState
  expandedKeys
  loadingKeys
  failedKeys

TreeExpansionCommand.toggle(key)
TreeExpansionCommand.expand(key)
TreeExpansionCommand.collapse(key)
TreeExpansionCommand.expandRecursive(key)
TreeExpansionCommand.collapseRecursive(key)
```

The foundation emits commands and state. It does not fetch children unless a
future optional async adapter is explicitly used.

## Lazy Loading

Lazy loading state is first-class:

- collapsed but loadable;
- expanding and loading;
- expanded with loaded children;
- failed expansion;
- stale children;
- unknown child count.

Do not fake a loading row as a real child with product identity. It should be a
synthetic view row with a clear semantic state.

## Navigation Rules

Tree navigation should support:

- Right Arrow expands collapsed parent;
- Right Arrow on expanded parent can move to first child by policy;
- Left Arrow collapses expanded parent;
- Left Arrow on child moves to parent by policy;
- Up/Down move visible nodes;
- Home/End move first/last visible node;
- typeahead optional via collection text values.

TreeGrid composes these rules with grid focus.

## Semantic Intent

Expose:

- level/depth;
- expanded/collapsed;
- parent/child facts where known;
- selected;
- disabled;
- loading;
- row position if known;
- set size if known.

Do not expose ARIA directly from foundation. Web adapters can map to
`aria-level`, `aria-expanded`, `aria-setsize`, and `aria-posinset` where safe.

## Conformance Tests

- expansion by key survives reorder;
- non-expandable nodes never report expanded;
- lazy loading row is not confused with real child;
- collapse removes descendants from visible projection;
- focus is normalized when focused descendant becomes hidden;
- parent navigation works across loaded gaps;
- disabled policy is configurable;
- controlled expansion does not mutate internally.

## Clean Disk Usage

Clean Disk uses Rust-owned tree pages. Flutter should not flatten the whole scan
tree. Tree foundation receives visible node facts and expansion intent; Rust
returns pages.

## Stop Rules

- Do not fetch disk data here.
- Do not store path strings as tree identity.
- Do not assume all descendants are loaded.
- Do not make expansion equal to selection.
