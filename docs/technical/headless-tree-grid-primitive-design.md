# Headless TreeGrid Primitive Design

This document records the accepted direction for a future Headless TreeGrid
primitive that Clean Disk can use for the central folder/file table.

The decision is intentionally written as a reusable Headless community primitive
plan, not as a Clean Disk-only widget plan.

## Status

Accepted as deeper design direction, not implemented yet.

Detailed primitive RFCs live in
[Headless primitive RFC index](headless-primitives/README.md). That folder
breaks this direction into separate community-grade designs for collection,
grid, tree, viewport, TreeGrid, SplitPane, ContextMenu, Dialog, Tooltip,
StatusRegion, reducer/effect internals, semantics adapters, conformance,
names/descriptions, pointer and drag alternatives, async loading, compliance
playbooks, IME/editing, focus algorithms, selection semantics, clipboard
privacy, combobox/search, state semantics, validation, timing/data loss, command
bars, tabs/disclosure, progress/log/status, app shell landmarks, visualization
accessibility, label-in-name, button/menu/split button, form fields,
checkbox/radio/switch, slider/spinbutton, select/listbox, breadcrumb
navigation, links/navigation, alerts/toasts, icons/images, badges/chips,
pagination/load-more, empty/skeleton states, skip/bypass navigation, side
navigation/drawer/rail, popover/floating panels, drawer/sheet/side panels,
wizard/stepper workflows, file picker/dropzone/path targets, query/filter/sort
surfaces, data summary metrics, property/details inspectors, command
discovery/shortcut help, destructive action safety affordances, native
menubar/app commands, motion/reduced animation, contrast/color-scheme/theme
adaptation, route/focus/history restoration, undo/redo operation history,
export/print/report snapshots, multi-window/session scopes, live announcement
broker, capability/permission progressive enhancement, locale/unit/quantity
formatting, zoom/density/target size, degraded/offline/partial availability,
instrumentation/telemetry privacy budget, user intent/command provenance,
untrusted content sanitization, recoverable error assistance, versioned state
migration, safe-area/orientation/viewport, automation/test driver boundaries,
semantic identity/reference stability, command routing/scope arbitration,
nested interactive composition, sticky/scroll anchoring geometry, screen-reader
browse/focus mode, third-party renderer trust, semantic diff/change
announcements, operation lifecycle/cancellation/retry, cognitive
load/progressive disclosure, evidence/confidence/uncertainty, cross-adapter
semantic parity, extension lifecycle/deprecation compatibility,
accessibility-tree snapshot regression, ARIA role/attribute linting,
personalization preference profiles, localization/bidi stress corpus, semantic
API review/release gates, support feedback/defect triage, public extension
rules, data-transfer payload governance, keyboard layout/dead-key shortcuts,
virtualized collection metadata, policy/feature flag evaluation, cross-window
transfer trust, visual/semantic diff alignment, accessibility exception
waivers, executable documentation examples, deterministic time/scheduler tests,
render failure containment, property-based fuzz conformance, privacy-safe
evidence capture, WCAG2ICT native app profiles, accessibility-supported
technology policy, ACT rule integration, ACR/VPAT evidence reporting, platform
role/action mapping, assistive technology transcript correlation, native
semantic preference/ARIA minimization, host boundary iframe/shadow/portal
rules, accessibility event ordering/cache invalidation, assistive technology
workaround governance, misuse diagnostics/dev warnings, public fixture pack
interoperability, platform accessibility settings adapters, switch access/linear
scanning, voice control/speech commands, magnifier visual viewport reflow,
closed functionality/kiosk runtime, assistive API permission/privacy
boundaries, braille display output, screen-reader rotor/quick navigation,
touch screen-reader exploration, dictation text input/correction,
captions/transcripts/status media, adaptive symbols/plain language, regulatory procurement standards profiles,
native accessibility API family contracts, AOM experimental boundaries,
accessibility inspector debug evidence, localized accessible name catalogs,
assistive technology compatibility lifecycle, accessible authentication/pairing,
credential autofill/passkey forms, browser permission prompt orchestration,
web filesystem picker/origin storage, local daemon network access,
PWA service worker install/offline boundaries, web notification permission/attention, spatial navigation/D-pad,
gamepad/remote input, fullscreen lock/immersive modes,
text selection/find-in-page, accessible export artifacts,
native shell integration/status, haptic vibration feedback,
speech synthesis audio output, dwell/eye-tracking activation,
virtual keyboard input viewport, writing assistance/spellcheck/translation,
sensor motion/orientation permissions, path/filename semantic display,
technical identifiers/error codes, code/preformatted/log output,
abbreviation/definition terms, quantity/byte/unit semantics,
time/date/duration recency, data table caption/header association,
meter/comparison value indicators, description/details/help associations,
inline annotation/highlight/revision semantics, figure/media caption/fallback
semantics, mathematical expression/formula semantics, list/feed/result-set
semantics, document outline/section/heading semantics, receipt/report document
semantics, machine-readable metadata/provenance, audit timeline/event feed
semantics, search result count/navigation semantics, structured
evidence/chain-of-custody semantics, faceted filter taxonomy semantics,
grouping/aggregation summary semantics, comparison baseline/delta semantics,
bulk selection scope/preview semantics, column view preset/layout
personalization, responsive card-grid alternate view semantics,
severity/risk/threshold/trend semantics, row action menu/action cell semantics,
master-detail preview panel semantics, command palette execution safety,
reorderable drag-drop keyboard semantics, status footer activity region
semantics, resizable pane layout persistence, async collection cursor window
contracts, operation center task queues, notification inbox attention
management, guided repair onboarding coachmarks, scope context authority
banners, overlay layer stack z-order contracts, design token semantic theme
bridges, dense target focus visibility, segmented control toggle groups, date time range picker filters, overflow truncation tooltip disclosure, scroll container keyboard affordances, modal focus return stacks, selection activation intent separation, inline edit commit cancel flows, column operations, and optional
web ARIA bridge.

Updated after checking:

- WAI-ARIA APG `treegrid` pattern:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN `treegrid` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/treegrid_role
- Flutter `TwoDimensionalScrollView`:
  https://api.flutter.dev/flutter/widgets/TwoDimensionalScrollView-class.html
- Flutter `two_dimensional_scrollables` package:
  https://pub.dev/packages/two_dimensional_scrollables
- `TableView` API:
  https://pub.dev/documentation/two_dimensional_scrollables/latest/two_dimensional_scrollables/TableView-class.html
- `TreeView` API:
  https://pub.dev/documentation/two_dimensional_scrollables/latest/two_dimensional_scrollables/TreeView-class.html
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Flutter focus system:
  https://docs.flutter.dev/ui/interactivity/focus
- Flutter web accessibility and Semantics:
  https://docs.flutter.dev/ui/accessibility/web-accessibility
- TanStack Table architecture:
  https://tanstack.com/table/v8/docs/overview
- React Aria collections and table:
  https://react-aria.adobe.com/Table
- MUI X Data Grid accessibility and virtualization:
  https://mui.com/x/react-data-grid/accessibility/
  https://v6.mui.com/x/react-data-grid/virtualization/
- AG Grid accessibility:
  https://www.ag-grid.com/react-data-grid/accessibility/

## Why This Is Critical

Clean Disk's main workflow is a large hierarchical table with folders, files,
sizes, percent bars, selection, details, cleanup queue actions, sorting,
filtering, keyboard navigation, and potentially hundreds of thousands or
millions of logical rows.

For Headless as a public UI kit, this is also the exact category where people
usually regret weak primitives: grids, trees, tables, virtualized rows, keyboard
focus, accessibility, row selection, and pinned columns all interact.

Building this as an app-only `Column`, `ListView`, or ad hoc table would mix
behavior, rendering, accessibility, and data access. It would also teach the
Headless ecosystem the wrong extension model.

The Headless primitive should own interaction behavior, state machines,
keyboard model, semantic intent, and renderer contracts. Applications should own
product data, visual slots, async loading, protocol queries, and business
commands.

## Main Decision

Do not build a monolithic `RTreeGrid` first.

Build a small layered collection/grid/tree foundation, then compose `RTreeGrid`
from those layers.

Accepted direction:

```text
headless_foundation
  collection/
    identity
    selection
    typeahead
    range math
    disabled policy
    focus target math
  grid/
    row and cell focus model
    header focus model
    2D keyboard navigation
    sort descriptor contracts
    column sizing descriptors
  tree/
    expansion state
    visible row projection
    depth/level facts
    parent/child navigation

headless_contracts
  tree_grid/
    renderer capability interfaces
    render requests
    typed slot contexts

components/headless_tree_grid
  RTreeGrid
  RTreeGridController
  RTreeGridState
  event reducer/effects executor
  Flutter widget shell

headless_material
  Material RTreeGrid renderer
  Material token resolver
  optional TableView viewport adapter
```

Why: this matches the existing Headless rules: component packages own behavior
and accessibility, renderers are capability contracts, public APIs are minimal,
component packages do not depend on other component packages, and reusable
mechanics live in foundation.

## Top Options

1. Layered collection/grid/tree foundation plus `RTreeGrid` composition -
   🎯 9   🛡️ 9   🧠 9, roughly 2600-5200 LOC.

   Best community-grade design. The work is heavier, but it keeps SOLID
   boundaries clean: collection identity and selection can be reused by list,
   menu, tree, table, data grid, and future command palette components. It also
   keeps `RTreeGrid` from becoming a component that changes for too many
   reasons.

2. Single `components/headless_tree_grid` package with all behavior inside -
   🎯 6   🛡️ 6   🧠 7, roughly 1800-3500 LOC.

   Faster for Clean Disk, but weaker for the public Headless ecosystem. It will
   likely duplicate selection, focus, typeahead, expansion, row identity, and
   virtual range logic later when `RDataGrid`, `RTreeView`, or `RListView` are
   needed.

3. Thin wrapper around `two_dimensional_scrollables.TableView` or `TreeView` -
   🎯 7   🛡️ 6   🧠 5, roughly 900-1800 LOC.

   Good viewport technology, but not enough as a Headless standard. `TableView`
   and `TreeView` help with lazy layout, pinned rows/columns, merged cells,
   tree rows, and cache extent. They do not define Headless public contracts for
   selection, keyboard policy, ARIA-like semantic intent, controlled state,
   renderer capabilities, or app-owned async data.

Accepted: option 1, with `two_dimensional_scrollables` as a viewport adapter
candidate, not the component architecture itself.

## What Flutter Gives Us

Flutter gives useful low-level building blocks:

- `TwoDimensionalScrollView` coordinates two scroll axes, two scroll
  controllers, a two-dimensional viewport, and a child delegate.
- `two_dimensional_scrollables` is an official Flutter package. Current pub.dev
  latest observed version: `0.5.2`, published by `flutter.dev`, supporting
  Android, iOS, Linux, macOS, web, and Windows.
- `TableView` builds visible cells lazily, supports row/column span
  configuration, pinned rows/columns, row/column decorations, infinite rows or
  columns, and cache extent.
- `TreeView` lazily lays out active tree nodes, exposes row depth through
  `TreeVicinity`, and has a controller for expand/collapse.
- `Actions`, `Shortcuts`, `Focus`, `FocusScope`, and `FocusableActionDetector`
  are the right Flutter primitives for keyboard commands and focus ownership.
- `Semantics` is the Flutter-level accessibility surface. On web, Flutter
  translates its Semantics tree into an accessible HTML DOM structure.

Interpretation:

- Use Flutter's viewport primitives for layout and scrolling.
- Do not outsource Headless behavior contracts to Flutter viewport widgets.
- Keep viewport choice replaceable behind `TreeGridViewportAdapter`.

## What Accessibility Standards Require

WAI-ARIA and mature data grids converge on these rules:

- `treegrid` is for hierarchical grid/table data where rows can expand or
  collapse.
- Both rows and cells may need focus. Header cells may skip focus only when
  they do not expose actions such as sort or filter.
- Focus and selection are separate concepts, especially in multi-select grids.
- Parent rows expose expanded/collapsed state. Non-parent rows must not pretend
  to be expandable.
- Virtualized grids need total row/column counts and row/column indexes where
  available.
- Sort state belongs on relevant column headers, not on the grid globally.
- A composite widget should not dump every inner control into the global tab
  order. One active tab stop, roving focus, or active-descendant semantics are
  required.

Flutter caveat:

Flutter Semantics is not a 1:1 ARIA DOM API. Therefore Headless should expose
semantic intents that renderers/platform adapters map into Flutter Semantics
and, if needed later, web-specific ARIA shims.

## Community-Grade Component Shape

The public API should be generic:

```dart
RTreeGrid<TNode, TColumn>(
  controller: controller,
  columns: columns,
  dataSource: dataSource,
  selectionMode: TreeGridSelectionMode.multiple,
  focusMode: TreeGridFocusMode.rowsFirst,
  viewportAdapter: const TableViewTreeGridViewportAdapter(),
  slots: RTreeGridSlots(...),
)
```

Do not expose Clean Disk paths, file sizes, cleanup state, daemon DTOs, or
MobX/store concepts in Headless.

`TNode` and `TColumn` are app values. Headless identity must use stable keys:

```text
TreeGridNodeKey
TreeGridColumnKey
TreeGridCellKey = node key + column key
TreeGridRowIndex = visible row position, not identity
```

Indexes are viewport coordinates. Keys are logical identity.

## Public Contracts

Core value objects:

- `TreeGridNodeKey` - stable row/node identity inside one collection.
- `TreeGridColumnKey` - stable column identity.
- `TreeGridCellKey` - pair of node key and column key.
- `TreeGridVisibleRow` - node key, depth, row index, expandable, expanded,
  selected, focused, disabled, loading, error, and row metadata.
- `TreeGridColumnSpec` - key, label, width policy, min/max width, sortable,
  resizable, alignment, is row header.
- `TreeGridSortDescriptor` - column key and direction.
- `TreeGridSelection` - none, single key, multiple keys, range anchor, all
  visible token where supported.
- `TreeGridViewportRange` - visible row/column window plus overscan.
- `TreeGridSemanticSnapshot` - row count, column count, indexes, expanded,
  selected, disabled, sorted, readonly, loading, and action labels.

Command surface:

- expand/collapse/toggle row;
- expand/collapse recursively if enabled;
- focus row;
- focus cell;
- move focus by row/cell/page/home/end;
- select/toggle/select range;
- sort column;
- start/commit/cancel column resize;
- activate row or cell;
- open context menu through an app callback;
- announce row state change through semantic effect.

No delete, cleanup, scan, file, or product command belongs in Headless.

## Data Source Boundary

Headless must support three data modes:

1. Eager rows - 🎯 9   🛡️ 8   🧠 4, roughly 300-600 LOC.

   The caller provides a finite in-memory collection. This is required for
   demos, tests, menus, small tables, and conformance fixtures.

2. App-owned paged visible rows - 🎯 9   🛡️ 9   🧠 7, roughly 700-1400 LOC.

   The caller provides currently loaded visible pages and receives viewport,
   expansion, sorting, filtering, and selection intents. The app or backend owns
   loading. This is the best Clean Disk MVP mode because Rust owns the scan tree
   and Flutter must not keep the full tree.

3. Headless async data source interface - 🎯 7   🛡️ 7   🧠 8,
   roughly 900-1800 LOC.

   Headless calls `loadChildren`, `loadRows`, or `loadRange` through an abstract
   source. Useful for community components, but risky as an MVP default because
   it can blur app/application boundaries.

Accepted for Clean Disk: mode 2.

Accepted for Headless public roadmap: support mode 1 first, design mode 2
before release, add mode 3 only after the contracts are stable.

## State Ownership

Use controlled/uncontrolled rules consistent with current Headless spec:

- external controller/value means controlled mode;
- internal controller is disposed by the component;
- external controller is not disposed;
- `onChanged` callbacks dedupe equal state;
- component never silently overwrites controlled state;
- public state is immutable snapshots or `ValueListenable` views;
- reducer state is the single source for interaction, not renderer-local state.

Split state by reasons to change:

```text
TreeGridExpansionController
  expanded node keys, loading expansion keys

TreeGridSelectionController
  selected keys, anchor key, range policy

TreeGridFocusController
  focused row/cell key, focus mode, last navigation source

TreeGridSortController
  sort descriptors, header focus

TreeGridColumnController
  widths, order, visibility, pinned columns

TreeGridViewportController
  visible range, scroll offsets, overscan
```

`RTreeGridController` can be a facade over these controllers, but internally the
responsibilities should stay split. That keeps SRP and allows smaller public
APIs later.

## Keyboard Model

Support two modes from day one:

1. Rows-first mode - 🎯 9   🛡️ 8   🧠 6, roughly 500-900 LOC.

   Best Clean Disk default. Arrow Up/Down moves rows. Left collapses or moves
   to parent. Right expands or moves to first child. Space toggles selection.
   Enter activates. Home/End/Page Up/Page Down work by visible range.

2. Cells-first mode - 🎯 7   🛡️ 8   🧠 8, roughly 800-1400 LOC.

   Required for full data-grid parity. Arrow keys move between cells. Row tree
   expansion is usually on the tree column cell. Header cells can be focused for
   sort/resize/menu.

Avoid hardcoding one model into the primitive. The focus model is a policy:

```text
TreeGridFocusMode.rowsFirst
TreeGridFocusMode.cellsFirst
TreeGridFocusMode.cellsOnly
```

Clean Disk starts with rows-first. Public Headless must not make cells-first
impossible.

## Tab Order Policy

Headless needs a first-class tab policy:

```text
TreeGridTabPolicy.composite
  one tab stop enters the grid; arrows navigate inside

TreeGridTabPolicy.content
  Tab can move through cells or active in-cell controls

TreeGridTabPolicy.header
  Tab can move through headers only

TreeGridTabPolicy.all
  advanced mode for spreadsheet-like tools
```

MUI X exposes a similar distinction because large grids become unusable when
every cell control is in the global tab sequence.

Clean Disk default: `composite`.

## Selection Model

Selection must be independent from focus:

- focus key can exist without selection;
- selected keys can exist without focus;
- multi-select uses selected state on all selectable rows/cells;
- disabled rows cannot be selected;
- range selection is anchored by stable key, not index;
- when a page unloads, selected keys remain logical intent but not delete
  authority;
- selection all must be explicit about scope: visible rows, filtered result,
  loaded rows, or backend query.

For Clean Disk:

- selection is not cleanup queue;
- cleanup queue is not delete authority;
- DeletePlan validation happens outside Headless.

## Virtualization Strategy

Viewport is an adapter, not the primitive:

```text
TreeGridViewportAdapter
  buildViewport(request)
  expose visible range
  expose scroll controllers
  scroll row/cell into view
  pin headers/columns if supported
```

Initial adapters:

1. `ListViewTreeGridViewportAdapter` - 🎯 8   🛡️ 8   🧠 5,
   roughly 400-900 LOC.

   One-dimensional rows, fixed row height, inline columns. Fastest to stabilize
   behavior, tests, and Clean Disk MVP.

2. `TableViewTreeGridViewportAdapter` - 🎯 9   🛡️ 8   🧠 8,
   roughly 900-1800 LOC.

   Uses `two_dimensional_scrollables.TableView` for lazy cells, pinned header,
   optional pinned columns, row/column decorations, and bidirectional scroll.

3. Custom sliver/render adapter - 🎯 5   🛡️ 6   🧠 10,
   roughly 2500-6000 LOC.

   Only if official Flutter primitives block required features or performance.

Accepted: design the public adapter boundary now, implement fixed-row
`ListView` adapter first if needed for MVP, then move to `TableView` adapter
for real TreeGrid behavior.

Important performance constraints:

- fixed row height first;
- bounded overscan;
- stable keys for row/cell widgets;
- no full tree flattening in Flutter for Clean Disk;
- no rebuild of all visible rows on hover;
- no unbounded `AutomaticKeepAlive`;
- no expensive layout per cell;
- column virtualization should overscan at least one column so keyboard focus
  can move into the next offscreen cell smoothly.

## Renderer and Slots

Follow existing Headless renderer contracts:

- component owns interaction and root accessibility;
- renderer owns visuals only;
- renderer receives commands, not app callbacks;
- absence of renderer capability is a clear diagnostic;
- slots are typed, not stringly;
- Prefer `Replace`, `Decorate`, `Enhance` slot overrides.

Minimum renderer contracts:

```text
RTreeGridRenderer
RTreeGridHeaderRenderer
RTreeGridRowRenderer
RTreeGridCellRenderer
RTreeGridDisclosureRenderer
RTreeGridSelectionRenderer
RTreeGridColumnResizeRenderer
RTreeGridEmptyStateRenderer
RTreeGridLoadingRowRenderer
RTreeGridErrorRowRenderer
RTreeGridTokenResolver
```

Minimum slots:

- root;
- header row;
- header cell;
- row;
- row background;
- tree cell;
- data cell;
- disclosure control;
- selection checkbox;
- row actions;
- context menu anchor;
- loading row;
- empty state;
- error row.

Clean Disk wraps this in `packages/design_system` as `AppTreeGrid`. Feature UI
must not consume raw Headless internals directly.

## Semantic Intent API

Because Flutter Semantics is not ARIA, do not expose ARIA attributes directly
as the core API.

Expose platform-neutral facts:

```text
TreeGridSemanticRole.treeGrid
TreeGridSemanticRole.row
TreeGridSemanticRole.columnHeader
TreeGridSemanticRole.rowHeader
TreeGridSemanticRole.cell

TreeGridSemanticState
  level
  rowIndex
  rowCount
  columnIndex
  columnCount
  expanded
  selected
  selectable
  disabled
  readonly
  sorted
  loading
  hasPopup
  actionLabel
  textValue
```

Adapters map these facts to Flutter Semantics, and later to browser-specific
ARIA where Flutter web semantics are insufficient.

## Feature Scope For V1

V1 Headless TreeGrid should include:

- row identity;
- column identity;
- fixed row heights;
- eager rows and app-owned visible rows;
- rows-first keyboard mode;
- focus/selection split;
- single and multi-select;
- expansion state;
- sort intent on headers;
- disabled rows;
- typed slots;
- Material renderer;
- conformance tests;
- fixed-width and flexible columns;
- pinned header if using `TableView` adapter.

V1 should not include:

- editable spreadsheet cells;
- drag/drop reorder;
- row grouping unrelated to tree hierarchy;
- full column pinning if it delays stable V1;
- variable row height;
- server-side async source owned directly by Headless;
- disk/file-specific logic;
- delete/cleanup actions;
- Excel export;
- custom render object.

## Clean Disk Integration

Clean Disk should expose:

```text
features/scan/presentation
  ScanTreeTable
    -> packages/design_system AppTreeGrid
      -> Headless RTreeGrid
```

Scan feature owns:

- scan session id;
- query cursors;
- visible pages;
- selected node details;
- cleanup queue state;
- sort/filter/search commands;
- mapping from daemon DTOs to app row view models.

Design system owns:

- Clean Disk row visuals;
- size bar visuals;
- folder/file icons;
- warning badges;
- compact/wide density;
- dark/light theme tokens;
- Headless renderer wiring.

Headless owns:

- focus;
- expansion interaction;
- selection interaction;
- keyboard behavior;
- semantic shape;
- render request contracts;
- viewport adapter protocol.

Rust/daemon owns:

- full scan tree;
- indexes;
- search;
- sort/filter semantics;
- pagination;
- authoritative node metadata;
- cleanup validation.

## Headless Gaps To Fix For Clean Disk And Community

Priority 1:

1. `headless_collection` foundation - 🎯 9   🛡️ 9   🧠 8,
   roughly 900-1800 LOC.

   Generic keyed collection identity, selection, typeahead, range anchor,
   disabled policy, item text values, and state snapshots. Current listbox has
   valuable pieces, but it is listbox-shaped and single-highlight/single-select
   oriented. TreeGrid needs reusable collection mechanics.

2. `headless_grid` foundation - 🎯 9   🛡️ 8   🧠 8,
   roughly 800-1600 LOC.

   Row/cell focus math, header focus, column descriptors, sort descriptors,
   2D movement, page movement, and tab policy. This should not live only inside
   `RTreeGrid`.

3. `headless_tree` foundation - 🎯 9   🛡️ 8   🧠 7,
   roughly 600-1200 LOC.

   Expansion state, depth facts, parent/child navigation, visible row
   projection contract, async child loading state. This can later power
   `RTreeView` too.

4. `components/headless_tree_grid` - 🎯 9   🛡️ 8   🧠 9,
   roughly 1200-2500 LOC after foundation.

   Public component, controller facade, reducer/effects, keyboard, semantics,
   render requests, and conformance suite.

5. `headless_material` TreeGrid renderer - 🎯 8   🛡️ 8   🧠 8,
   roughly 900-1800 LOC.

   Visual preset, tokens, focus rings, headers, rows, cells, disclosure,
   selection controls, row actions, resize handles, empty/loading/error states.

Priority 2:

1. `RSplitPane` / resizable panes - 🎯 8   🛡️ 8   🧠 7,
   roughly 600-1200 LOC.

   Clean Disk wide layout needs left tree targets, center table, right details.
   This is also broadly useful for IDE-like apps.

2. `RContextMenu` / command menu foundation - 🎯 9   🛡️ 8   🧠 8,
   roughly 900-1700 LOC.

   TreeGrid rows need contextual commands. Should reuse overlay/menu/listbox
   foundation but needs right-click, keyboard invocation, focus restore, and
   disabled/danger command states.

3. `RDialog` / confirmation primitive - 🎯 9   🛡️ 9   🧠 7,
   roughly 700-1400 LOC.

   Clean Disk destructive confirmation must be accessible and consistent.
   Headless needs focus trap, escape policy, initial focus, restore focus,
   action roles, and danger action semantics.

4. `RTooltip` and `RStatusRegion` - 🎯 8   🛡️ 8   🧠 6,
   roughly 500-1000 LOC.

   Dense tools need icon tooltips and non-invasive status announcements.

5. Public conformance harness for complex widgets - 🎯 9   🛡️ 9   🧠 7,
   roughly 700-1500 LOC.

   TreeGrid needs reusable tests for keyboard, focus, semantics, controlled
   state, renderer capability lookup, disabled rows, and virtualization-safe
   identity.

Priority 3:

1. Column resize/pin/reorder contracts - 🎯 7   🛡️ 7   🧠 8,
   roughly 900-1800 LOC.

   Useful, but can wait until rows-first TreeGrid is stable.

2. Variable row height support - 🎯 5   🛡️ 6   🧠 9,
   roughly 1200-2600 LOC.

   Attractive but high-risk. Fixed row height is the right first contract.

3. Drag/drop row operations - 🎯 5   🛡️ 6   🧠 9,
   roughly 1500-3000 LOC.

   Out of Clean Disk MVP. Later useful for community tree/data tools.

4. Web ARIA bridge/shim if Flutter Semantics is insufficient - 🎯 6   🛡️ 7
   🧠 9, roughly 1200-3000 LOC.

   Only after measuring actual Flutter web accessibility output.

## Staged Implementation

Stage 0 - RFC and fixtures - 🎯 10   🛡️ 9   🧠 4, roughly 250-500 LOC.

- Write package RFC in Headless repo.
- Add 5 synthetic fixtures: flat table, nested tree, disabled rows,
  multi-select, virtualized 100k rows.
- Define conformance checklist before implementation.

Stage 1 - Collection/grid/tree pure foundation - 🎯 9   🛡️ 9   🧠 8,
roughly 1600-3200 LOC.

- Pure state/value objects and reducers.
- Selection, range, expansion, focus movement, typeahead, sort descriptors.
- No renderer and minimal Flutter dependency beyond foundation package policy.

Stage 2 - `RTreeGrid` shell and renderer contracts - 🎯 8   🛡️ 8   🧠 8,
roughly 900-1800 LOC.

- Controller facade.
- Commands.
- render request composer.
- missing renderer diagnostics.
- semantics intent requests.
- Material placeholder renderer.

Stage 3 - Virtualized viewport adapters - 🎯 8   🛡️ 8   🧠 9,
roughly 900-2200 LOC.

- Fixed-height `ListView` adapter for conformance and simple use.
- `TableView` adapter for 2D virtualization, pinned header, horizontal scroll.
- Scroll-to-focused-row/cell.
- Overscan policy.

Stage 4 - Material renderer and design-system wrapper - 🎯 8   🛡️ 8   🧠 8,
roughly 1000-2200 LOC.

- Headless Material renderer.
- Clean Disk `AppTreeGrid` wrapper.
- dark/light tokens.
- compact/wide density.

Stage 5 - Clean Disk scan table integration - 🎯 8   🛡️ 8   🧠 7,
roughly 900-1800 LOC.

- row DTO mapping;
- paged query integration;
- sort/filter commands;
- selected row details;
- cleanup queue commands through app slots;
- no full scan tree in Flutter.

## Critical Risks

- Accessibility and virtualization can conflict: virtual rows are not all
  present. Semantic row count and row indexes must be explicit.
- Flutter web semantics may not expose everything that ARIA treegrid expects.
  Measure before promising full web screen-reader parity.
- `TreeView` is useful but not a table. `TableView` is useful but not a tree.
  `RTreeGrid` may need a custom adapter that projects tree rows into a table.
- Variable row heights can break scroll-to-index and stable virtualization.
  Fixed row height is a V1 invariant.
- Pinned columns and row tree indentation interact with horizontal scrolling.
  V1 should pin header first, not promise frozen tree column unless proven.
- Cell focus plus row actions can create many focusable children. Use one
  composite tab stop by default.
- Async loading inside Headless can blur architecture. Prefer app-owned pages
  for Clean Disk.
- Large selected sets cannot always be represented as a huge Set in Flutter.
  Need selection scopes and query tokens for future backend-owned selection.
- Renderer slots can accidentally reintroduce behavior. Slot docs must say
  app callbacks go through commands and adapters, not renderer root gestures.
- Tests in headless browsers often need virtualization disabled or controlled.
  Provide a test viewport adapter instead of disabling production behavior.

## Stop Rules

- Do not implement Clean Disk's production table as a custom app-only `ListView`
  unless it is explicitly marked disposable.
- Do not pass the full Rust scan tree into Flutter just to feed the grid.
- Do not couple Headless contracts to disk/file concepts.
- Do not implement delete/cleanup actions inside Headless. They are app
  commands exposed through slots.
- Do not freeze the public `RTreeGrid` API before the foundation contracts,
  conformance tests, and at least one Material renderer are proven.
- Do not make `two_dimensional_scrollables` a hard conceptual dependency of the
  behavior package. It is a viewport implementation candidate.
- Do not let renderer implementations own root activation, root focus, or root
  semantics.

## Summary

📌 The right architecture is not "TreeGrid widget over TableView". The right
architecture is reusable Headless collection/grid/tree behavior, with `RTreeGrid`
as a composed component and `TableView` as a replaceable virtualization adapter.

For Clean Disk this keeps the central folder table fast and safe. For Headless
as a community UI kit, it creates reusable standards for future `RTreeView`,
`RDataGrid`, command menus, split panes, and other dense productivity widgets.
