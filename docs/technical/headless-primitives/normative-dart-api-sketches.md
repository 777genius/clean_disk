# Normative Dart API Sketches

## Status

API sketch, not final source code.

## Purpose

This file captures the shape of public APIs so implementation can be discussed
before code is written.

## Collection

```dart
final class CollectionKey {
  const CollectionKey(this.value, {this.namespace});
  final Object value;
  final String? namespace;
}

final class CollectionState<TKey> {
  final TKey? focusedKey;
  final SelectionState<TKey> selection;
  final int version;
}

abstract interface class CollectionController<TKey> {
  ValueListenable<CollectionState<TKey>> get state;
  void focus(TKey key);
  void toggleSelection(TKey key);
  void selectRange({required TKey anchor, required TKey extent});
  void clearSelection();
}
```

## TreeGrid

```dart
final class RTreeGrid<TNode, TColumn> extends StatefulWidget {
  const RTreeGrid({
    required this.rows,
    required this.columns,
    required this.rowKeyOf,
    required this.columnKeyOf,
    this.controller,
    this.focusMode = TreeGridFocusMode.rowsFirst,
    this.selectionMode = TreeGridSelectionMode.none,
    this.viewportAdapter,
    this.slots,
    super.key,
  });
}
```

Rules:

- rows can be eager or app-owned visible pages;
- controller is optional;
- external controller is not disposed;
- renderer capability is discovered through Headless theme.

## Viewport Adapter

```dart
abstract interface class TreeGridViewportAdapter {
  ValueListenable<ViewportRange> get visibleRange;
  Widget build(TreeGridViewportRequest request);
  void scrollToRow(TreeGridScrollTarget target);
  void scrollToCell(TreeGridCellKey target);
}
```

## Command Menu

```dart
final class CommandItem {
  final CommandId id;
  final String label;
  final CommandRole role;
  final bool disabled;
  final bool destructive;
  final ShortcutPresentation? shortcut;
}

typedef CommandSelected = void Function(CommandIntent intent);
```

Command id is stable. Label is localized presentation.

## Dialog

```dart
final class ConfirmDialogRequest {
  final String id;
  final String title;
  final Widget content;
  final ConfirmSeverity severity;
  final ConfirmValidationState validationState;
  final DialogAction primaryAction;
  final DialogAction cancelAction;
}
```

Headless owns dialog behavior. Application owns validation and action handling.

## SplitPane

```dart
final class RSplitPane extends StatefulWidget {
  const RSplitPane({
    required this.axis,
    required this.primary,
    required this.secondary,
    this.controller,
    this.minPrimarySize,
    this.maxPrimarySize,
    this.collapsible = false,
    super.key,
  });
}
```

## Renderer Request

```dart
final class RTreeGridRenderRequest {
  final BuildContext context;
  final TreeGridStateSnapshot state;
  final TreeGridSemanticSnapshot semantics;
  final TreeGridCommands commands;
  final RTreeGridSlots? slots;
  final RTreeGridResolvedTokens tokens;
}
```

Renderer receives commands, not product callbacks.

## Stop Rules

- Do not export reducer internals.
- Do not expose Clean Disk DTOs.
- Do not make generic type identity part of renderer capability if avoidable.
- Do not require full tree in `RTreeGrid`.
