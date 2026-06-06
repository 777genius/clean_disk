# Screen Reader Rotor And Quick Navigation Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- WAI-ARIA APG Landmarks Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/landmarks/
- WCAG 2.4.1 Bypass Blocks: https://www.w3.org/WAI/WCAG22/Understanding/bypass-blocks.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 3.2.3 Consistent Navigation: https://www.w3.org/WAI/WCAG22/Understanding/consistent-navigation.html
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- Apple VoiceOver on Mac: https://support.apple.com/guide/voiceover/welcome/mac
- Android TalkBack: https://support.google.com/accessibility/android/answer/6283677

## Problem

Screen-reader users do not only tab through a UI. They often use rotor, quick
navigation, headings, landmarks, form controls, links, tables, and custom
navigation modes. A dense app can have valid focus behavior but still be slow if
its regions, headings, and grouped controls are not useful for quick navigation.

Headless needs a quick-navigation contract that complements focus and keyboard
standards.

## Decision Options

1. Let each primitive expose normal roles and hope quick navigation works -
   🎯 5   🛡️ 5   🧠 2, about 0-120 LOC. Too weak for app-scale composition.
2. Add a semantic navigation index shared by landmarks, headings, controls, and
   collections - 🎯 9   🛡️ 9   🧠 6, about 400-950 LOC. Best fit for Headless.
3. Implement screen-reader-specific rotor adapters - 🎯 4   🛡️ 6   🧠 9, about
   1800-3500 LOC. Too platform-specific as a baseline.

Accepted: option 2.

## Accepted Contract

Headless exposes semantic navigation facts:

```dart
final class RQuickNavigationNode {
  final RSemanticId id;
  final RQuickNavKind kind;
  final String label;
  final int order;
  final int? headingLevel;
  final bool isFocusable;
  final bool isRegionBoundary;
  final bool isVirtualized;
  final RSemanticId? ownerCollectionId;
}
```

This index is used by tests, diagnostics, and adapters. It does not replace the
actual accessibility tree.

## Navigation Kinds

Supported kinds:

- app landmark;
- navigation landmark;
- main landmark;
- search region;
- heading;
- form field;
- command;
- table or grid;
- row group;
- status region;
- alert;
- dialog;
- details or inspector region;
- destructive action region.

Primitives may add extension kinds through stable typed identifiers.

## Rules

- Landmarks and headings represent real structure, not visual decoration.
- Repeated regions need distinct labels.
- The main workflow must be reachable without traversing every command.
- Virtualized rows cannot pretend the whole dataset is in the accessibility
  tree.
- Quick-navigation order follows task order, not paint order when panels are
  responsive.
- Hidden panels are not quick-navigation targets unless they are logically
  open.
- Dialogs expose a local navigation scope and restore the prior scope on close.

## Clean Disk Requirements

Clean Disk must expose quick navigation targets for:

- scan targets;
- main folder tree;
- search and filters;
- selected item details;
- cleanup queue;
- scan progress;
- warnings and skipped items;
- confirmation dialogs.

The folder tree can expose current visible rows and collection metadata, but not
millions of hidden rows as separate quick-navigation nodes.

## Virtualized Collection Policy

For large collections:

```dart
final class RVirtualQuickNavigationSummary {
  final RSemanticId collectionId;
  final int? totalRowCount;
  final int visibleRowCount;
  final List<RQuickNavigationNode> visibleAnchors;
  final bool supportsSearch;
  final bool supportsJumpToIndex;
}
```

Quick navigation gives anchors and commands, while row traversal remains owned by
the collection primitive.

## Testing Requirements

- Snapshot quick-navigation index for wide and compact layouts.
- Test duplicate landmark labels.
- Test route changes and restored focus.
- Test dialogs and nested overlays.
- Test virtualized TreeGrid with visible row anchors only.
- Test high zoom layout where regions move below the grid.

## Failure Catalog

- Every card becomes a region and rotor navigation becomes noisy.
- Main TreeGrid has no useful heading or landmark.
- Compact layout changes order unpredictably.
- Hidden queue panel remains in quick navigation.
- Dialog opens but quick navigation still exposes background actions.
- Virtualized collection exposes stale rows that are no longer mounted.

## Release Gates

- Every app-shell primitive must publish quick-navigation facts.
- Region labels must be unique inside their scope.
- Virtualized surfaces must publish collection summaries instead of fake full
  row lists.
- Conformance reports include quick-navigation snapshots.

## Summary

Good screen-reader UX needs fast structural navigation, not only tab order.
Headless should standardize quick-navigation facts so dense apps remain
traversable and predictable.
