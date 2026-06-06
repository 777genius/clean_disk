# Headless Collection Foundation RFC

## Status

Accepted design direction. Not implemented yet.

## Problem

Current Headless already has useful `ListboxController`, item identity,
typeahead, and listbox navigation. TreeGrid, DataGrid, TreeView, ContextMenu,
CommandMenu, virtual lists, and future rich selectors need a more generic
collection foundation.

If every component owns its own selection, focus identity, disabled policy, and
range math, the public UI kit will drift into incompatible behaviors.

## Standards And References

- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Listbox:
  https://www.w3.org/WAI/ARIA/apg/patterns/listbox/
- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- React Aria Collections:
  https://react-spectrum.adobe.com/react-aria/collections.html
- TanStack Table state model:
  https://tanstack.com/table/v8/docs/overview

## Accepted Direction

Create collection primitives inside `headless_foundation`, not inside
`components/headless_tree_grid`.

```text
headless_foundation/lib/src/collection/
  collection_key.dart
  collection_item.dart
  collection_text_value.dart
  collection_disabled_policy.dart
  collection_selection.dart
  collection_selection_controller.dart
  collection_range.dart
  collection_typeahead.dart
  collection_registry.dart
  collection_state.dart
```

This is not a visual component. It is reusable state and behavior for
components that present keyed items.

## Top Options

1. Generic collection foundation - 🎯 9   🛡️ 9   🧠 8,
   roughly 900-1800 LOC.

   Best long-term option. Reuses identity, selection, disabled policy,
   typeahead, and range math across Listbox, Menu, Tree, Grid, and TreeGrid.

2. Extend existing listbox foundation - 🎯 7   🛡️ 7   🧠 5,
   roughly 500-1000 LOC.

   Faster, but risks making listbox carry responsibilities that do not belong
   to it: multi-axis selection, grid focus, query-scoped selection, and virtual
   ranges.

3. Keep per-component implementations - 🎯 3   🛡️ 4   🧠 4,
   roughly 300-900 LOC per component.

   Short-term cheap, ecosystem expensive. It creates inconsistent keyboard and
   selection behavior.

Accepted: option 1.

## Core Contracts

```text
CollectionKey
  stable logical id
  not equal to index

CollectionItem
  key
  textValue
  disabled
  selectable
  metadata

CollectionSelection
  none
  single(key)
  multiple(keys, anchor)
  queryScope(token, exclusions)

CollectionRange
  anchor key
  extent key
  ordered keys or resolver

CollectionState
  focused key
  highlighted key
  selected model
  disabled keys
  loading keys
```

`queryScope(token, exclusions)` matters for huge virtualized collections. A
component must not need to store one million selected keys just to represent
"all filtered rows selected".

## Key Invariants

- Keys are stable while the logical collection version is stable.
- Indexes are view coordinates and never identity.
- Selection and focus are independent.
- Disabled can mean not activatable, not selectable, or not focusable. These
  are separate policies.
- Typeahead uses normalized text values, not localized display widgets.
- Range selection uses visible order from a resolver, not raw indexes.
- Controlled state is never overwritten by internal state.
- External controllers are not disposed by components.

## Disabled Policy

APG notes that disabled items inside composite widgets are sometimes focusable.
The foundation should model this explicitly:

```text
DisabledFocusPolicy.skip
DisabledFocusPolicy.focusableButInactive

DisabledSelectionPolicy.notSelectable
DisabledSelectionPolicy.keepExistingSelection

DisabledActivationPolicy.block
```

Menus usually allow disabled items to be focusable through arrow navigation.
Data grids and TreeGrid rows often skip disabled rows for selection but may
still allow focus so users can discover unavailable actions.

## Selection Scope

Selection must record what the user intended:

```text
visibleOnly
loadedOnly
currentPage
filteredQuery
allCollection
explicitKeys
```

Clean Disk rule: selection is UI intent only. It is not cleanup queue and not
delete authority.

## Events And Reducer

Collection state changes should be reducer-friendly:

```text
CollectionEvent.focus(key)
CollectionEvent.highlight(key)
CollectionEvent.toggleSelection(key)
CollectionEvent.selectRange(anchor, extent)
CollectionEvent.clearSelection()
CollectionEvent.selectScope(scope)
CollectionEvent.itemsChanged(version)
```

Effects:

- request focus;
- scroll key into view;
- announce selection count;
- normalize stale focus/selection after items change.

## Conformance Tests

Minimum tests:

- stable key does not drift after reorder;
- index-based identity is rejected in debug;
- focus and selection can diverge;
- disabled policy is applied consistently;
- range selection works with gaps and unloaded items;
- query-scope selection does not allocate every selected key;
- controlled selection does not mutate internally;
- typeahead uses text values and ignores disabled policy according to config.

## Clean Disk Usage

Clean Disk's scan table uses:

- node id as `CollectionKey`;
- visible page order from Rust as collection order;
- local selection for current UI state;
- cleanup queue as separate application state;
- DeletePlan as daemon-validated authority.

## Stop Rules

- Do not add file-system concepts.
- Do not depend on Flutter Material.
- Do not put renderer contracts here.
- Do not make collection fetch data itself.
- Do not make selection equal to destructive authority.
