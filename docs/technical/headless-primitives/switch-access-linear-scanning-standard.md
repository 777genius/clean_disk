# Switch Access And Linear Scanning Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.1.2 No Keyboard Trap: https://www.w3.org/WAI/WCAG22/Understanding/no-keyboard-trap.html
- WCAG 2.2.1 Timing Adjustable: https://www.w3.org/WAI/WCAG22/Understanding/timing-adjustable.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- WCAG 2.5.5 Target Size: https://www.w3.org/WAI/WCAG22/Understanding/target-size.html
- WCAG 2.5.8 Target Size Minimum: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- WCAG 2.5.7 Dragging Movements: https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html
- Apple Switch Control on Mac: https://support.apple.com/guide/mac-help/use-switch-control-mh43607/mac
- Android Switch Access: https://support.google.com/accessibility/android/answer/6122836
- WCAG2ICT: https://w3c.github.io/wcag2ict/

## Problem

Switch access users often interact through one or two switches that emulate
keyboard input and scan focusable items sequentially. A UI can technically pass
keyboard support and still be awful for switch users if it has tiny targets,
unstable focus order, hover-only affordances, timeouts, drag-only actions, or
hidden controls that require many scans.

Headless needs a linear scanning contract in addition to normal keyboard
navigation.

## Decision Options

1. Treat switch access as ordinary keyboard support - 🎯 4   🛡️ 4   🧠 2,
   about 0-80 LOC. Cheap, but misses scanning cost and discoverability.
2. Add a switch scanning profile to every interactive primitive - 🎯 9   🛡️ 9
   🧠 6, about 350-800 LOC across foundations plus primitive adapters. Best
   balance for public Headless.
3. Build a separate switch-only runtime mode - 🎯 5   🛡️ 7   🧠 9, about
   1200-2400 LOC. Powerful but fragments behavior and is too early.

Accepted: option 2.

## Accepted Contract

Every primitive that exposes actions must publish a linear scan model:

```dart
final class RLinearScanNode {
  final RSemanticId id;
  final RScanRole role;
  final String? visibleLabel;
  final bool isFocusable;
  final bool isActionable;
  final bool isDestructive;
  final bool isPrimary;
  final int logicalOrder;
  final RTargetGeometry? targetGeometry;
}
```

This model is not a renderer tree. It is an interaction graph used by
conformance tests, diagnostics, and optional platform adapters.

## Linear Scanning Rules

- Every pointer action has a keyboard or command equivalent unless the function
  is inherently path based.
- Scan order follows meaningful reading and task order.
- Hidden destructive actions are not first-class scan targets until revealed by
  an explicit user step.
- Target geometry meets the active target size profile or publishes an
  exception.
- Drag, resize, reorder, and split pane actions must have discrete alternatives.
- Long repeated scan paths should expose grouped commands or command palette
  access.
- A focused item remains visually obvious under high contrast and text scaling.
- Auto-advancing UI pauses or remains adjustable when scanning is likely.

## Clean Disk Requirements

Clean Disk must support switch-access-safe operation for:

- scan target selection;
- starting, pausing, and canceling a scan;
- expanding and collapsing the tree;
- selecting items and adding them to the cleanup queue;
- opening details;
- reviewing a delete plan;
- confirming or aborting move-to-trash.

The cleanup flow must not require drag and drop, hover, precise pointer motion,
or a timed response.

## Scanning Cost Budget

Headless primitives should expose estimated scan cost:

```dart
final class RScanCost {
  final int focusableCount;
  final int primaryActionDistance;
  final int destructiveActionDistance;
  final bool hasGroupNavigation;
  final bool hasBypassAction;
}
```

Large surfaces should provide bypass actions and grouped navigation so a user
does not scan hundreds of rows to reach global commands.

## Interaction Patterns

- TreeGrid: row focus, then row action menu, then cell mode only when requested.
- ContextMenu: first item is safe and reversible where possible.
- Dialog: focus starts on the least destructive meaningful action or primary
  content, not on the destructive confirmation.
- SplitPane: expose step increase, step decrease, collapse, expand, and reset.
- Tabs: support arrow keys, but keep linear tab order predictable.
- Toolbar: roving focus may exist, but tab order enters and leaves the toolbar
  cleanly.

## Testing Requirements

- A linear scan fixture traverses every primitive with one switch action and
  records order.
- Tests verify that all visible commands have a scan path.
- Tests verify that destructive actions require an explicit confirmation step.
- Tests verify no keyboard trap under overlays, virtualized rows, and nested
  widgets.
- Tests run under large target, text scale 2.0, high contrast, and compact
  layout profiles.

## Failure Catalog

- Row actions exist only on hover.
- Drag is the only way to reorder or move content.
- The visual focus ring is clipped by a scroll container.
- Virtualization reuses a focused row id for a different item.
- A timeout expires while a switch user scans a dialog.
- A destructive button is the first focusable item in a confirmation dialog.
- Scan order jumps between left sidebar, grid, footer, and right panel without
  a meaningful task path.

## Release Gates

- Every primitive with commands must export a linear scan model.
- Every drag gesture must document its keyboard alternative.
- Every timeout must document pause, extend, or disable behavior.
- Large surfaces must define bypass and group navigation.

## Summary

Switch access is not just keyboard support. Headless must make sequential access
efficient, predictable, and safe for dense apps like Clean Disk.
