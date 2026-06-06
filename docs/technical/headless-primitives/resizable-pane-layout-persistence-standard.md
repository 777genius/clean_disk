# Resizable Pane Layout Persistence Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Window Splitter Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/windowsplitter/
- MDN `separator` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/separator_role
- MDN `aria-valuenow`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-valuenow
- MDN `aria-valuetext`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-valuetext
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.5.7 Dragging Movements: https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html

## Scope

This standard covers persisted split pane sizes, collapsible panes, responsive
pane fallback, layout presets, splitter normalization, multi-window layout
state, and migration of saved workbench layouts.

It extends SplitPane RFC and deep dive. It focuses on persistence and adaptive
layout behavior, not basic splitter mechanics.

## Problem

Resizable panels are useful in Clean Disk: targets, tree, details, queue, and
status regions compete for space. But persisted sizes can become invalid when
the window changes, text scale increases, a pane becomes unavailable, or an app
version changes. A bad persisted layout can hide critical warnings or strand
keyboard focus.

## Decision Options

1. Versioned `PaneLayoutPreset` with normalization and capability gates -
   🎯 9   🛡️ 9   🧠 8, roughly 800-1800 LOC.
   Best fit. It makes layout persistence safe for desktop, compact, and
   multi-window use.
2. Persist raw pixel widths -
   🎯 5   🛡️ 5   🧠 2, roughly 100-300 LOC.
   Easy, but breaks across windows, monitors, zoom, text scale, and schema
   changes.
3. Do not persist pane sizes -
   🎯 7   🛡️ 8   🧠 1, roughly 0-80 LOC.
   Safe for MVP, but public Headless should still define the contract before
   apps start inventing incompatible persistence.

Accepted direction: option 1 as contract, option 3 acceptable for Clean Disk
MVP until layout persistence is needed.

## Primitive Boundary

Headless owns:

- pane ids;
- splitter ids;
- size units;
- min/max constraints;
- collapse state;
- last expanded size;
- layout preset schema;
- normalization result;
- keyboard resize policy;
- persistence eligibility;
- semantic value facts.

Renderer owns:

- splitter visuals;
- drag handle affordance;
- transition visuals;
- compact layout visuals;
- pane shadows/dividers;
- resize cursor.

Application owns:

- where layout is persisted;
- user profile scope;
- route/window scope;
- product-critical pane policy;
- migration policy;
- enterprise overrides.

## Layout State Model

State includes:

- layout id;
- schema version;
- breakpoint class;
- window scope;
- pane sizes;
- collapsed panes;
- locked panes;
- last expanded sizes;
- text scale bucket;
- density bucket;
- migration state.

State must not include:

- selected item authority;
- delete confirmation state;
- daemon token;
- raw private paths;
- localized pane labels as ids.

## Normalization Rules

On restore:

- validate schema version;
- drop unknown pane ids;
- restore required panes;
- clamp sizes to current min/max;
- resolve min/max conflicts deterministically;
- unhide product-critical pane when risky actions exist;
- downgrade invalid preset to default;
- report migration as non-blocking status.

Normalization must be pure and testable.

## Responsive Rules

Wide layout may use split panes.

Compact layout may replace panes with:

- stacked sections;
- collapsible panels;
- sheets;
- tabs if product flow allows;
- route-level details.

Rules:

- compact fallback preserves access to critical facts;
- hidden details pane cannot hide warning facts;
- keyboard path remains available;
- focus moves to a valid replacement when pane disappears.

## Splitter Accessibility Rules

Persisted layout must not weaken basic splitter semantics:

- focusable splitter when user-resizable;
- separator role where platform supports it;
- accessible name tied to primary pane;
- value min/max/now/text;
- keyboard resize;
- single-pointer or command alternative for drag resize;
- visible focus.

## Clean Disk Usage

Wide:

- left scan targets pane;
- center tree table;
- right details/queue pane;
- bottom status outside split group.

Compact:

- no permanent sidebar;
- details below tree or in collapsible panel;
- delete queue collapsible;
- status footer sticky but not covering focus.

Rules:

- details/warnings remain reachable if right pane is collapsed;
- delete queue pane collapse does not cancel queue;
- pane layout preference cannot override safety policy;
- per-window layout state is separate from scan session state.

## Community API Sketch

```dart
final class RPaneLayoutPreset {
  const RPaneLayoutPreset({
    required this.id,
    required this.schemaVersion,
    required this.panes,
    required this.splitters,
    required this.scope,
  });

  final String id;
  final int schemaVersion;
  final Map<String, RPaneState> panes;
  final Map<String, RSplitterState> splitters;
  final RLayoutScope scope;
}
```

## Conformance Scenarios

- invalid persisted size clamps to current constraints;
- required pane is restored after stale preset;
- keyboard resize works after restore;
- compact fallback keeps details reachable;
- hidden pane does not hide destructive warning;
- focus moves safely when pane disappears;
- per-window layout does not overwrite another window;
- migration reports unknown pane ids without crashing.

## Failure Catalog

- Raw pixel width breaks on smaller window.
- Collapsed details pane hides delete warning.
- Splitter is pointer-only.
- Persisted layout stores route/private data.
- Unknown pane id crashes restore.
- Focus remains in removed pane.
- Layout preference disables critical status footer.

