# Headless SplitPane RFC

## Status

Accepted design direction. Not implemented yet.

## Problem

Clean Disk's wide layout needs resizable left, center, and right panes. The
Headless community also needs a robust `RSplitPane` for IDE-like apps,
dashboards, inspectors, file managers, and admin tools.

## Standards And References

- WAI-ARIA APG Window Splitter:
  https://www.w3.org/WAI/ARIA/apg/patterns/windowsplitter/
- MDN `separator` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/separator_role
- Flutter Focus:
  https://docs.flutter.dev/ui/interactivity/focus
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Accepted Direction

Create `components/headless_split_pane` and renderer contracts:

```text
components/headless_split_pane
  RSplitPane
  RSplitPaneController
  SplitPaneLayoutState
  SplitPaneResizePolicy
  SplitPaneKeyboardPolicy

headless_contracts
  RSplitPaneRenderer
  RSplitPaneHandleRenderer
  RSplitPaneTokenResolver
```

## Top Options

1. Headless SplitPane with focusable separator semantics - 🎯 9   🛡️ 9
   🧠 7, roughly 600-1200 LOC.

   Best option. Matches APG Window Splitter and is broadly useful.

2. App-only draggable divider - 🎯 5   🛡️ 5   🧠 4,
   roughly 200-500 LOC.

   Faster, but weak keyboard and accessibility.

3. Use a third-party Flutter splitter directly - 🎯 6   🛡️ 6   🧠 4,
   roughly 100-300 LOC.

   Useful to inspect, but risky as core design-system behavior.

Accepted: option 1.

## Core Contracts

```text
SplitPaneId
SplitPaneAxis.horizontal | vertical
SplitPaneSize.pixels | fraction
SplitPaneBounds(min, max, collapsed)
SplitPanePrimaryPane
SplitPaneHandleId

SplitPaneState
  primarySize
  secondarySize
  collapsed
  lastExpandedSize
```

## Keyboard Model

APG Window Splitter maps:

- Left/Right move vertical splitter;
- Up/Down move horizontal splitter;
- Enter toggles collapse/restore;
- Home moves to primary pane minimum;
- End moves to primary pane maximum;
- F6 may cycle panes.

Headless should expose step policy:

```text
SplitPaneStep.small
SplitPaneStep.large
SplitPaneStep.toMin
SplitPaneStep.toMax
SplitPaneStep.toggleCollapse
```

## Accessibility Model

Focusable splitter maps to semantic intent:

- role separator;
- orientation;
- value min/max/now;
- value text if percent is not meaningful;
- label from primary pane;
- controls primary pane;
- disabled state if locked.

Flutter renderer maps these facts to `Semantics` where possible. Web bridge can
map to ARIA values later.

## Renderer Rules

Renderer owns:

- handle visuals;
- hover/focus/drag states;
- hit target padding;
- divider thickness;
- cursor feedback.

Component owns:

- drag gesture interpretation;
- keyboard commands;
- controlled state;
- semantics;
- bounds and collapse policy.

## Clean Disk Usage

Wide layout:

- left scan targets pane;
- center tree table pane;
- right details/delete queue pane;
- bottom status footer outside split panes.

Compact layout should avoid permanent split panes and use stacked panels.

## Conformance Tests

- drag updates size within min/max;
- keyboard arrows update size;
- Enter collapse/restore;
- Home/End bounds;
- controlled mode;
- external controller is not disposed;
- separator semantic value updates;
- touch target policy passes.

## Stop Rules

- Do not put layout-specific Clean Disk panes into Headless.
- Do not make mouse drag the only resize path.
- Do not allow splitter value to escape min/max.
- Do not make renderer own state mutation.
