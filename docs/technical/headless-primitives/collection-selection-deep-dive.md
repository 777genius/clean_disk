# Collection And Selection Deep Dive

## Status

Implementation-ready design constraints. Not implemented yet.

## Primary Standards

- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Listbox:
  https://www.w3.org/WAI/ARIA/apg/patterns/listbox/
- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- MDN `aria-selected`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-selected
- React Aria Collections:
  https://react-spectrum.adobe.com/react-aria/collections.html

## Core Principle

Collection is not a widget. It is the stable identity and interaction substrate
for listbox, menu, tree, grid, treegrid, command palette, and virtualized
collections.

## Identity Contract

```text
CollectionKey
  value: Object
  namespace: optional String
  version: optional collection version

CollectionIndex
  visible coordinate only
  never stable identity

CollectionVersion
  changes when logical identity/order source changes
```

Rules:

- keys must be unique within a collection version;
- keys must not be localized labels;
- keys must not be row indexes when sorting/filtering/pagination exists;
- keys can be reused only when they mean the same logical item in the same
  collection namespace;
- stale keys are normalized through policy, not silently ignored.

Clean Disk mapping:

- Rust node id becomes collection key;
- path is display data, not identity;
- scan snapshot id can namespace keys;
- stale snapshot cannot become cleanup authority.

## Selection Model

```text
SelectionState
  mode: none | single | multiple
  scope:
    explicitKeys(Set<CollectionKey>)
    visibleRange(anchor, extent)
    currentPage(queryId, pageId)
    loadedRows(queryId)
    filteredQuery(queryId, exclusions)
  anchorKey
  focusedKey
  lastUserAction
```

Why query scope matters:

- "Select all filtered results" can represent millions of rows.
- Flutter must not allocate every key for backend-owned data.
- Destructive workflows need to know whether the user selected visible rows,
  loaded rows, or all query results.

Clean Disk rule:

```text
selection != cleanup queue
cleanup queue != DeletePlan
DeletePlan != deletion result
```

## Focus, Highlight, Active, Selected

Do not collapse these concepts:

- focus - keyboard target;
- highlight - visual hover/active descendant for menu/listbox style components;
- active - currently pressed/activated item;
- selected - user selection state;
- queued - product-specific state outside Headless.

Headless should expose each independently in state snapshots.

## Disabled Policy Matrix

```text
DisabledFocusPolicy
  skip
  focusableButInactive

DisabledSelectionPolicy
  notSelectable
  keepExistingSelection
  clearOnDisable

DisabledActivationPolicy
  block
```

APG menu behavior allows disabled menu items to be focusable but inactive. Data
grids often skip disabled rows for selection. Therefore disabled cannot be one
boolean with one meaning.

## Range Selection

Range selection needs an ordered resolver:

```text
OrderedKeyResolver
  compare(a, b)
  keysBetween(anchor, extent, limit)
  visibleIndexOf(key)
```

Do not compute range by raw row index if the collection is virtualized or
backend-owned.

For backend-owned ranges:

```text
RangeSelectionIntent(anchorKey, extentKey, queryId, sortId, filterId)
```

Backend can validate the range against current query/snapshot.

## Typeahead

Typeahead uses stable text values:

```text
CollectionTextValue
  normalized
  locale
  source: primary | alternate
```

Rules:

- display widgets do not define typeahead;
- localization can change text, but command identity does not change;
- accents/case/width normalization must be deterministic;
- disabled item participation follows disabled focus policy.

## State Machine

```text
idle
  -> focused
  -> rangeSelecting
  -> queryScopeSelected
  -> staleAfterItemsChanged
  -> normalized
```

Events:

- `itemsChanged(version)`;
- `focusRequested(key)`;
- `selectionToggled(key)`;
- `rangeSelectionStarted(anchor)`;
- `rangeSelectionExtended(extent)`;
- `selectionScopeRequested(scope)`;
- `disabledPolicyChanged(policy)`;
- `collectionDisposed`.

Effects:

- scroll key into view;
- announce selected count;
- normalize stale selected keys;
- request focus;
- reject invalid selection scope.

## Public API Shape

```dart
final class CollectionController<TKey> extends ChangeNotifier {
  ValueListenable<CollectionState<TKey>> get state;

  void focus(TKey key);
  void toggleSelection(TKey key);
  void selectRange({required TKey anchor, required TKey extent});
  void selectScope(CollectionSelectionScope<TKey> scope);
  void clearSelection();
}
```

Use immutable state snapshots. Internal mutable registries are allowed only
behind the controller.

## Conformance Matrix

| Case | Required |
| --- | --- |
| reorder | selected keys remain selected by identity |
| filter | stale visible index does not corrupt selection |
| disabled item | focus/selection/activation policies differ |
| large select all | no huge Set allocation required |
| controlled state | internal reducer emits intent, parent owns value |
| typeahead | uses text values, not rendered widgets |
| disposal | external controller is not disposed |

## Stop Rules

- Do not model selection as `Set<int>` indexes.
- Do not use labels as keys.
- Do not let collection fetch backend data.
- Do not put product queue/delete semantics here.
- Do not expose renderer types from collection foundation.
