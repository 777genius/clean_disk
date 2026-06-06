# Tree Data Loading Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Primary Standards

- WAI-ARIA APG Tree View:
  https://www.w3.org/WAI/ARIA/apg/patterns/treeview/
- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN `tree` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/tree_role
- MDN `treeitem` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/treeitem_role

## Core Decision

Tree foundation handles tree state and visible projection. It does not fetch
data by itself in Clean Disk. Data loading is an application or backend adapter
responsibility.

## Node States

```text
TreeNodeLoadState
  unknown
  notLoadable
  unloaded
  loading
  loaded
  failed
  stale

TreeNodeExpandState
  leaf
  collapsed
  expanding
  expanded
  collapsing
```

Rules:

- `leaf` is distinct from `collapsed`;
- `unloaded` is distinct from `collapsed`;
- failed expansion does not pretend node is leaf;
- stale children stay visible only if policy allows stale display.

## Expansion Events

```text
ExpandRequested(key)
CollapseRequested(key)
ToggleRequested(key)
ChildrenLoadingStarted(key, requestId)
ChildrenLoaded(key, requestId, childKeys)
ChildrenLoadFailed(key, requestId, reason)
ChildrenInvalidated(key)
AncestorCollapsed(key)
```

Request id prevents late async responses from corrupting newer state.

## Visible Projection

```text
VisibleTreeRow
  key
  depth
  parentKey
  visibleIndex
  expandState
  loadState
  semanticPosition
  syntheticKind: none | loading | error | placeholder
```

Synthetic rows are display rows, not product nodes.

## Clean Disk Backend-Owned Tree

Clean Disk does not load all descendants into Flutter.

```text
Expansion intent
  Flutter -> application use case -> daemon query

Page data
  daemon -> app DTO -> view model -> Headless visible rows
```

Tree foundation can track local expansion intent, but daemon snapshot is the
source of truth for visible pages.

## Stale Expansion Policy

When a scan snapshot changes:

```text
ExpansionStalePolicy
  preserveMatchingKeys
  collapseAll
  preservePathIfIdentityMatches
```

Clean Disk default:

- preserve matching node ids inside same snapshot family;
- do not preserve across incompatible snapshot;
- never preserve delete authority from old snapshot.

## Parent Navigation

Tree foundation needs parent resolver:

```text
TreeParentResolver
  parentOf(key)
  firstChildOf(key)
  nextSiblingOf(key)
  previousSiblingOf(key)
```

For backend-owned data, resolver may return unknown. Keyboard policy must fail
softly: no movement plus optional request to load.

## Semantic Facts

Expose:

- level;
- expanded/collapsed/leaf;
- loading;
- failed load;
- position in set if known;
- set size if known;
- parent relationship if known.

Do not fake `setsize` when the backend does not know it.

## Error Handling

Expansion failure should expose:

- visible error row if product wants it;
- retry command;
- semantic "loading failed";
- no child rows until successful load;
- stale request ignored if request id no longer current.

## Test Matrix

| Case | Required |
| --- | --- |
| expand unloaded | loading state appears, request emitted |
| late load response | ignored if request id stale |
| collapse while loading | descendants hidden, response policy applied |
| failed load | node remains expandable, error state visible |
| snapshot change | expansion normalized by policy |
| parent navigation unknown | no crash, optional load intent |
| synthetic loading row | not treated as selected product row |

## Stop Rules

- Do not represent loading/error rows as real product nodes.
- Do not fetch backend data from foundation directly for Clean Disk.
- Do not store path strings as identity.
- Do not assume all descendants are loaded.
