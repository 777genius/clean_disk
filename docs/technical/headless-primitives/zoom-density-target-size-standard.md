# Zoom Density And Target Size Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- WCAG 1.4.4 Resize Text: https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html
- WCAG 2.5.5 Target Size: https://www.w3.org/WAI/WCAG22/Understanding/target-size.html
- WCAG 2.5.8 Target Size Minimum: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- WCAG 2.4.11 Focus Not Obscured Minimum: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing
- Flutter adaptive and responsive design: https://docs.flutter.dev/ui/adaptive-responsive

## Scope

This standard defines how Headless primitives handle zoom, text scaling,
density, hit targets, focus visibility, and layout pressure.

It applies to:

- dense tables;
- toolbars;
- icon buttons;
- menus;
- forms;
- split panes;
- side navigation;
- dialogs;
- charts;
- compact Clean Disk layout.

It does not mandate one visual density. It defines safe density boundaries.

## Decision Options

Option A: Fixed pixel sizes - 🎯 3   🛡️ 3   🧠 2, about 100-250 LOC.

- Looks stable in mockups.
- Breaks zoom, text scale, localization, and accessibility.

Option B: App-defined responsive breakpoints only - 🎯 5   🛡️ 5   🧠 4,
about 300-700 LOC.

- Useful but incomplete.
- Does not encode hit targets, focus visibility, or semantic target size.

Option C: Headless density contract with target-size and reflow invariants -
🎯 9   🛡️ 9   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Components expose layout pressure and target-size compliance.
- Renderers adapt visuals while preserving interaction safety.

## Accepted Direction

Headless must model density as policy, not as random spacing constants.

Density levels:

- `comfortable`;
- `regular`;
- `compact`;
- `dense`;
- `dataDense`;

Every level must define:

- minimum semantic target size;
- visual target size;
- spacing;
- row height;
- focus ring room;
- text scale behavior;
- overflow policy;
- alternative larger action path if visual target is smaller.

## Target Size Rules

Interactive controls must provide a reasonable activation target.

If visual density makes target smaller:

- semantic hit area can be larger than visual affordance;
- adjacent larger command can be provided;
- keyboard command must exist for critical actions;
- touch-only access must not rely on tiny controls;
- focus indicator must show the actual active control.

Clean Disk examples:

- row overflow menu can be visually compact but needs reliable hit area;
- delete queue remove button cannot become too small;
- table disclosure control needs keyboard and pointer target;
- compact layout toolbar icons need tooltips and accessible labels.

## Text Scaling Rules

Text scaling must not:

- clip critical labels;
- overlap adjacent controls;
- hide focus indicator;
- hide required errors;
- break route title visibility;
- make destructive confirmation unreadable.

Allowed adaptations:

- wrap;
- truncate with accessible full text;
- collapse secondary columns;
- move details below table;
- switch from labels to icons only when accessible names remain;
- increase row height;
- paginate or virtualize.

Do not scale font by viewport width. Use user text scale and design tokens.

## Reflow Rules

At high zoom or narrow width:

- no two-dimensional scrolling for ordinary page content unless component
  semantics require it, such as data grid;
- data grids may scroll horizontally but must keep keyboard access;
- sticky headers and frozen columns must not obscure focused cells;
- dialogs must fit or become scrollable internally;
- bottom bars must not cover focus target;
- destructive action footer must remain reachable.

## Density Conflict Rules

Density must yield to:

- user text scale;
- high contrast focus requirements;
- touch input mode;
- screen reader mode where target semantics need clarity;
- platform minimum target conventions;
- destructive action safety.

Data-dense tables can be compact for mouse and keyboard power users, but
should expose comfortable mode.

## Layout Pressure Reporting

Headless primitives should report:

- clipped label;
- hidden secondary text;
- target-size exception;
- focus ring clipping;
- horizontal overflow;
- vertical overflow;
- content priority collapse;
- text scale bucket;
- density fallback.

This helps app shell decide whether to switch compact/wide layout.

## Flutter Adapter Requirements

Flutter adapter should:

- use `MediaQuery.textScaler`;
- test tap target guidelines;
- test text contrast and labels;
- avoid fixed-height rows when text scaling requires more height, unless row
  exposes an accessible expanded/details path;
- ensure hit testing matches target policy;
- avoid `FittedBox` as a silent fix for text overflow.

## Web Adapter Requirements

Web adapter should:

- support browser zoom;
- support text-only resize where possible;
- avoid fixed viewport assumptions;
- avoid focus ring clipping by `overflow: hidden`;
- ensure pointer target and keyboard focus target align;
- test reflow and high zoom.

## Clean Disk Requirements

Clean Disk must validate:

- wide layout at normal density;
- compact layout;
- 200 percent text scale equivalent;
- high contrast plus selected row;
- table horizontal scroll with keyboard;
- details panel readable at high zoom;
- delete queue controls target-safe;
- progress footer not covering focused content.

Rule:

- disk cleanup safety beats density.

If a destructive confirmation cannot fit safely, switch to a full-screen or
step-based flow.

## API Shape Sketch

```text
DensityPolicy
  level
  inputModality
  minSemanticTarget
  minVisualTarget
  textScaleBucket
  focusRingBudget
  allowTargetException

LayoutPressureReport
  clippedText
  targetExceptions
  focusObscured
  overflowAxes
  recommendedAdaptation
```

## Conformance Scenarios

- icon button remains reachable at compact density;
- high text scale wraps or collapses without overlap;
- focus ring is not clipped in dense table rows;
- touch mode increases target policy;
- data grid horizontal scroll remains keyboard accessible;
- destructive dialog reflows instead of clipping confirmation text;
- target-size exceptions have alternate command path;
- layout pressure report triggers compact-to-stacked transition.

## Failure Catalog

- fixed row height clipping text at high scale;
- tiny icon button with no semantic hit area;
- focus ring hidden by overflow clipping;
- compact density used on touch without adaptation;
- destructive confirmation button off-screen;
- visible icon with no accessible label;
- target exception without alternative command;
- horizontal scroll trapping keyboard focus;
- using viewport-scaled font sizes;
- layout pressure ignored by app shell.

