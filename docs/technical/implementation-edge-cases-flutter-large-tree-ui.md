# Implementation Edge Cases - Flutter Large Tree UI

Last updated: 2026-05-13.

This file records edge cases for the Flutter frontend that renders Clean Disk's huge folder/file tree, details panel, delete queue, scan status, charts, and desktop/web layouts.

Related documents:

- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Implementation edge cases search query indexing](implementation-edge-cases-search-query-indexing.md)
- [Implementation edge cases UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md)
- [Implementation edge cases concurrency state machines](implementation-edge-cases-concurrency-state-machines.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md)

This document focuses on frontend architecture. Rust still owns the full scan tree, indexes, sorting, filtering, and node details. Flutter owns visible UI state, user intent, routing, layout, and rendering.

## Sources Reviewed

- Flutter Documentation, [Performance best practices](https://docs.flutter.dev/perf/best-practices). Relevant points: avoid expensive builds, avoid unnecessary intrinsic layout, use lists/grids thoughtfully, and aim to build/display frames within the frame budget.
- Flutter DevTools, [Performance view](https://docs.flutter.dev/tools/devtools/performance). Relevant points: profile builds are needed for meaningful performance diagnosis; a frame taking more than about 16 ms causes visible jank on 60 Hz displays.
- Flutter API docs, [DataTable](https://api.flutter.dev/flutter/material/DataTable-class.html). Relevant points: `DataTable` measures columns twice and `SingleChildScrollView` mounts/paints the entire child; `TableView`, `PaginatedDataTable`, or `CustomScrollView` are better choices for large data.
- Flutter API docs, [ListView.builder](https://api.flutter.dev/flutter/widgets/ListView/ListView.builder.html). Relevant points: builder creates children on demand and is appropriate for large/infinite lists; `itemCount` helps estimate scroll extent; child identity needs care when order changes.
- Flutter API docs, [ListView](https://api.flutter.dev/flutter/widgets/ListView-class.html). Relevant points: lazily built children are destroyed when scrolled out of view; non-trivial state should live outside row subtrees.
- Flutter package, [two_dimensional_scrollables](https://pub.dev/packages/two_dimensional_scrollables). Relevant point: `TableView` builds children lazily inside a two-dimensional viewport.
- Flutter Documentation, [Concurrency and isolates](https://docs.flutter.dev/perf/isolates). Relevant points: use isolates when large computations cause UI jank; Flutter web does not support isolates and `compute()` runs on the main thread on web.
- Flutter Cookbook, [Parse JSON in the background](https://docs.flutter.dev/cookbook/networking/background-parsing). Relevant point: large JSON parsing can block the UI and should be moved off the main isolate where supported.
- Flutter API docs, [FutureBuilder](https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html). Relevant points: futures must be obtained before build; creating a future in build restarts async work on parent rebuild.
- W3C WAI-ARIA APG, [Treegrid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/). Relevant points: treegrid focus, selection, expansion, sorting, and keyboard behavior need explicit semantics.

## Severity Scale

- `P0` - can make the app unusable on large scans, show stale/wrong cleanup state, queue wrong nodes, hide warnings, or make destructive workflows inaccessible.
- `P1` - can cause jank, memory growth, lost scroll/selection state, inconsistent desktop/web behavior, or hard-to-debug frontend state bugs.
- `P2` - important polish, maintainability, design-system quality, or future extensibility risk.

## Accepted Tree Table Implementation Decision

Accepted path:

1. `TreeTable` facade plus `ListView.builder` fixed-row implementation for MVP
   - 🎯 9 🛡️ 9 🧠 6, roughly 1800-3500 LOC across design-system primitive,
   viewport store, row models, keyboard/focus hooks, tests, and reference
   layout validation.
   Accepted. This is the fastest reliable path to the saved wide/compact
   references without committing the product to one table engine.
2. `TreeTable` facade backed by `two_dimensional_scrollables` `TableView` or
   `TreeView` - 🎯 7 🛡️ 8 🧠 7, roughly 2200-4500 LOC.
   Future adapter. `two_dimensional_scrollables` is published by `flutter.dev`,
   supports lazy two-dimensional viewports, pinned rows/columns, `TableView`,
   and `TreeView`, but must be spiked against our server-owned paginated
   read model and accessibility expectations before adoption.
3. Fully custom sliver/render-object tree table - 🎯 5 🛡️ 9 🧠 10, roughly
   6000-12000 LOC.
   Future escape hatch only. It is too expensive before the product validates
   the scan UI behavior.

The facade is the real contract. The initial implementation is intentionally a
fixed-height virtualized row list with controlled columns. If horizontal
virtualization, pinned columns, or treegrid semantics become impossible to keep
clean under the list implementation, switch the implementation behind the facade
instead of rewriting feature stores or protocol adapters.

Do not use `DataTable`, `SingleChildScrollView` over all rows, or a full local
tree model for the central folder/file tree.

## Anti-UI-Bog Guardrails

The first UI implementation must avoid endless visual tweaking before the data
contract exists.

First-pass scope:

- match the wide and compact reference layout structure;
- implement stable theme tokens for dark mode and leave light mode token-ready;
- implement fixed row heights, fixed column contracts, selected row, progress
  bars, disclosure controls, and ellipsis;
- use mock/projection row models shaped like future daemon DTOs;
- implement details and delete queue as contract-shaped panels, not final
  cleanup logic;
- make `Move to Trash` disabled until real DeletePlan/preflight exists.

Do not polish these before real projection DTOs exist:

- exact chart category taxonomy;
- final cleanup candidate wording;
- final reclaim confidence copy;
- tiny glow/shadow differences;
- advanced column resizing;
- drag-and-drop row actions;
- full keyboard grid model;
- animated tree expansion.

Definition of "good enough" for the first UI pass:

- no text overflow at wide and compact widths;
- main tree scrolls smoothly with synthetic 50k visible rows in profile mode;
- selected/expanded/focused/queued states are visually distinct;
- details panel and queue do not change tree row height;
- progress footer does not rebuild the tree;
- UI uses stable `NodeRef`-like ids, not paths or row indexes;
- all critical visual states exist: loading, empty, scanning, partial, skipped,
  selected, queued, disabled destructive action.

Stop polishing and move to data integration when those checks pass. Any
remaining visual tweaks become design-system follow-up tickets unless they block
readability, accessibility, or the saved reference structure.

Switch from the `ListView.builder` implementation to a `TableView`/custom
implementation only if one of these measured blockers appears:

- horizontal scrolling or pinned columns cannot be implemented without nested
  scroll fragility;
- row virtualization janks in profile mode with the accepted synthetic fixture;
- keyboard/focus semantics require unsafe row-local state;
- column layout needs intrinsic measurement across many rows;
- compact/wide layout forces duplicate table implementations;
- accessibility tests cannot represent treegrid semantics through the list
  facade.

## Core Principle

Flutter renders the viewport. Rust owns the tree.

Required shape:

```text
Rust scan/query service
  -> paginated query DTOs
  -> Flutter protocol adapter
  -> feature store/view model
  -> design-system tree table row models
  -> visible widgets only
```

The Flutter UI must not:

- hold the full scan tree;
- sort/filter/search the full scan tree client-side;
- rebuild the full table on scan progress events;
- use row index as identity;
- use transport DTOs directly as widget state;
- let a row widget own business state needed after it scrolls out of view.

## Viewport And Virtualization Edge Cases

### Main Tree Cannot Use `DataTable` - `P0`

Flutter's `DataTable` is convenient but expensive for large data because it measures columns twice, and wrapping it in `SingleChildScrollView` mounts and paints the whole child.

Required:

- main folder/file tree uses virtualized rows;
- row height is fixed or bounded by density setting;
- column widths are explicit, cached, or based on controlled layout rules;
- horizontal and vertical scrolling are coordinated;
- pinned header and optionally pinned name column are owned by the tree-table primitive;
- large table rendering is profiled in profile/release-like builds.

Avoid:

- `DataTable` as the central tree;
- `SingleChildScrollView` around all rows;
- nested scroll views for table body unless the design-system primitive owns them carefully;
- intrinsic width/height measurement across thousands of cells.

### One-Dimensional List Is Not Enough Forever - `P1`

`ListView.builder` is good for visible-row virtualization. Clean Disk also needs columns, pinned header, indentation, disclosure controls, percent bars, keyboard grid navigation, and horizontal scroll.

Options:

1. `ListView.builder` rows with custom row layout in MVP - 🎯 8 🛡️ 8 🧠 5, roughly 500-1400 LOC. Good first implementation if columns are fixed and horizontal behavior is simple.
2. `TableView` from `two_dimensional_scrollables` - 🎯 7 🛡️ 8 🧠 7, roughly 900-2400 LOC. Better for two-dimensional virtualization, but must validate package maturity and semantics needs before adopting.
3. Fully custom sliver/render object table - 🎯 6 🛡️ 8 🧠 10, roughly 3000-9000 LOC. Powerful later, too expensive before UI behavior is proven.

Recommendation: MVP can use a virtualized row list with fixed table columns if we keep it behind a `TreeTable` facade. If horizontal virtualization becomes necessary, switch the implementation under the facade.

### Row Height Must Be Stable - `P0`

Variable row height makes scrolling, keyboard movement, lazy paging, and tree indentation harder. Long names and paths are common.

Required:

- row height is stable per density mode;
- text uses ellipsis and tooltips/details for overflow;
- icons/disclosure controls have fixed hit boxes;
- percent bars and size cells do not change row height;
- selected/hover/focus/queued badges do not resize rows.

Avoid:

- wrapping long paths into multi-line cells in the main tree;
- dynamic row height based on warning text;
- animated expansion that changes many row heights during scroll.

### Visible Row Window Is A Derived Projection - `P1`

Expanded tree state, server pages, filters, and visible viewport together define visible rows. That projection must be explicit.

Required:

- store visible row keys separately from raw page data;
- row key includes scan session/snapshot, node ID, and projection version;
- expanded state is by node ID, not row index;
- collapsed rows unload descendant view rows but not server truth;
- visible-row cache has a bounded size.

Avoid:

- storing one giant `List<TreeNodeDto>` in Flutter;
- calculating visible rows recursively in every `build`;
- losing expansion state when rows are repaged;
- expanding a row by path text.

## State Ownership Edge Cases

### Row Widgets Are Disposable - `P0`

Flutter lazily destroys list children when they scroll out of view. Row-local state is not reliable for product state.

Required:

- focus, selection, expansion, hover, context menu, details selection, and queued state live in feature stores;
- row widgets are pure renderers of row model plus callbacks;
- row keys are stable by node identity;
- if order can change, provide child identity mapping where the chosen widget requires it;
- row subtrees can be destroyed and recreated without losing business state.

Avoid:

- storing selected/expanded/queued state inside row `StatefulWidget`;
- using row index as key;
- building a list of preconstructed row widgets;
- relying on widget lifecycle to keep delete queue state.

### Focus, Selection, Details, Queue, And Checkbox Are Different States - `P0`

The main tree has multiple concepts that look similar visually but mean different things.

Required:

- focused row: keyboard navigation target;
- selected row: details panel object;
- expanded row: tree visibility state;
- queued item: server-side or draft DeletePlan item;
- checked item in delete queue: item included for execution;
- hovered row: pointer-only affordance.

Avoid:

- focusing a row queues it;
- selecting a row confirms cleanup;
- expansion state changes selected node implicitly;
- queued state appears identical to selection state.

### Optimistic UI Must Reconcile With Server Version - `P0`

The UI can feel responsive, but Rust is authoritative for scan snapshot, delete plan, and cleanup state.

Required:

- local draft changes have pending/synced/conflict states;
- Add to Queue command returns authoritative plan version;
- details panel shows stale/conflict when server rejects a draft action;
- delete queue totals come from server plan or explicitly marked local estimate;
- stale plan version disables destructive button until revalidated.

Avoid:

- updating queue as final before server accepts it;
- hiding plan conflicts by silently overwriting;
- enabling Move to Trash from local-only state.

## Data Flow And Protocol Edge Cases

### Transport Stream Is Not UI State - `P0`

WebSocket event streams can reconnect, coalesce, miss replay, or arrive while a screen is not mounted.

Required:

- stream events update application stores or invalidate queries;
- widgets subscribe to store slices, not raw sockets;
- terminal events trigger status query reconciliation;
- progress events are throttled to frame budget;
- event handlers are independent from widget lifecycle.

Avoid:

- `StreamBuilder` around the whole app shell;
- rebuilding the tree on every progress tick;
- assuming event order can update visible rows without query confirmation;
- tying scan lifetime to widget lifetime.

### FutureBuilder Must Not Start Queries In Build - `P1`

Flutter's `FutureBuilder` docs warn that futures created in build restart async work when parents rebuild.

Required:

- route/store owns query lifecycle;
- page requests are triggered by user intent, scroll threshold, expansion, filter, or explicit refresh;
- `FutureBuilder` can render a known future if already owned by state/store;
- repeated builds do not restart network queries;
- scroll and hover changes do not trigger unrelated data fetches.

Avoid:

- creating HTTP future in `build`;
- creating search future on every text field rebuild;
- letting row build trigger node details request.

### JSON Parsing Can Jank Differently On Desktop And Web - `P0`

Flutter docs recommend isolates for expensive parsing, but Flutter web does not support isolates and `compute()` runs on the main thread on web.

Required:

- server keeps payloads small enough for web main-thread parsing;
- page size is tuned by measured Flutter desktop and web performance;
- large result exports/downloads are not parsed into widget state;
- desktop can use isolates for heavy parsing if measured needed;
- web relies more heavily on Rust-side filtering/paging and smaller DTOs.

Avoid:

- sending megabyte tree pages to Flutter;
- parsing full scan JSON in Flutter web;
- assuming desktop isolate strategy works on web;
- using one payload size for all platforms without profiling.

### Page Cache Must Be Bounded And Versioned - `P1`

The UI needs local page cache for smooth scrolling, but old pages can become stale after rescan, sort/filter changes, or snapshot invalidation.

Required:

- cache key includes scan session, snapshot, parent, sort, filter, page cursor, and density-relevant projection if needed;
- cache has size limits and eviction;
- stale cursor clears affected pages;
- scroll position recovery can request anchor node/page;
- cache never authorizes cleanup.

Avoid:

- one global map keyed only by parent node;
- keeping pages across snapshot change;
- caching sensitive paths longer than app retention policy;
- memory leak from every search result page.

## Layout Edge Cases

### Wide And Compact Layouts Need Different Composition - `P1`

The design references define a wide three-pane layout and a compact stacked layout. The same state must survive layout changes.

Required:

- layout breakpoint switches presentation, not data ownership;
- selected node and delete queue persist across wide/compact changes;
- compact mode keeps warnings and delete confirmation visible;
- bottom scan progress stays reachable;
- details panel can collapse without losing selected state.

Avoid:

- separate stores for desktop and compact layout;
- hiding cleanup warnings only because width is narrow;
- rebuilding scan session UI state on window resize.

### Split Panes Need Constraints - `P2`

Desktop users will resize windows and panels.

Required:

- min/max widths for sidebar, tree, details, and queue;
- tree remains usable at compact width;
- long path/details fields ellipsize;
- empty/error/loading states fit in constrained panes;
- no nested cards inside cards.

Avoid:

- details pane shrinking table to unusable width;
- queue controls clipping text;
- chart taking space from critical warnings.

### Theme And Density Must Be Tokens - `P1`

The references use a dense cyber blue/violet dark theme, but the app also needs light theme and density options.

Required:

- row height, icon size, focus ring, selected color, warning color, chart palette, and table grid lines come from design-system tokens;
- dark/light themes share semantic tokens;
- density changes keep hit targets accessible;
- neon accents are restrained and never reduce table readability.

Avoid:

- hardcoded colors in feature widgets;
- one-off row padding per page;
- gradients/glow behind dense table text.

## Design System And Headless Edge Cases

### `TreeTable` Should Be A Product Primitive - `P0`

Clean Disk's central component is not a generic list. It is a tree table with safety semantics.

Required primitive capabilities:

- virtualized rows;
- disclosure/indentation;
- selected/focused/hover/queued/stale/warning states;
- sortable headers;
- fixed row height;
- keyboard navigation hooks;
- accessible labels/semantics;
- row action slots;
- pinned header;
- loading/error/empty row overlays;
- stable test handles.

Avoid:

- duplicating tree row behavior per feature page;
- putting protocol DTOs directly into design-system components;
- making design system depend on scan feature package.

### Headless Improvement Triggers - `P1`

If our Headless library lacks primitives that make Clean Disk clean, we should improve the library rather than workaround badly in app code.

Report a Headless gap when we need:

- roving focus for virtualized tree/grid;
- keyboard selection model;
- sortable column state primitive;
- virtualized collection state hooks;
- disclosure tree state;
- typeahead within tree;
- tooltip/focus-visible behavior;
- cross-platform shortcut abstraction;
- accessible menu/context menu primitives;
- split pane/resizable panel behavior.

Avoid:

- embedding fragile focus logic in one screen;
- using invisible buttons for semantics hacks;
- duplicating roving focus per table.

### Design System Must Not Own Product Data - `P1`

The design-system package should render component state, not own scan/delete business logic.

Required:

- design-system receives row models and callbacks;
- feature presentation store owns scan/delete UI state;
- application/domain own safety decisions;
- design-system emits intent events such as row selected, row expanded, action invoked;
- design-system does not know pdu, Rust protocol DTOs, DeletePlan internals, or app routes.

Avoid:

- `CleanDiskTreeTable` inside generic design-system if it imports scan package;
- design-system storing server cursors;
- design-system deciding whether Move to Trash is allowed.

## Rendering Performance Edge Cases

### Rebuild Scope Must Be Small - `P0`

Scan progress can update many times per second. Tree rows should not rebuild unless visible row data or row state changes.

Required:

- store selectors or equivalent fine-grained subscriptions;
- separate progress/status store from tree row store;
- row widgets receive immutable row view models;
- visible-row diffing updates only changed rows;
- expensive charts update at lower cadence than table selection.

Avoid:

- one huge observable state object for entire screen;
- `setState` at page root for progress ticks;
- recomputing all percent bars on every event;
- rebuilding details panel on unrelated hover.

### Text Layout And Icons Can Become Hot Paths - `P2`

Large tables render many names, paths, sizes, counts, and dates.

Required:

- format bytes/dates in store or memoized row model where appropriate;
- avoid repeated path splitting in row build;
- use fixed icon dimensions;
- cache expensive display strings by node/version;
- keep text styles stable from tokens.

Avoid:

- formatting large numbers in every `build` for every visible cell without need;
- recalculating path breadcrumbs per frame;
- using rich text spans for every plain cell unless measured.

### Charts Are Secondary To Tree Responsiveness - `P2`

Donuts, bars, and details charts are useful, but the table is the main workflow.

Required:

- charts update from summary/detail queries, not raw full tree;
- chart animations respect reduced motion;
- chart updates are throttled during scanning;
- selected details chart never blocks row scroll.

Avoid:

- recomputing chart segments from all visible rows;
- animating charts on every progress tick;
- making chart color the only category label.

## Web-Specific Edge Cases

### Browser UI Cannot Depend On Native Desktop Assumptions - `P1`

Web UI may connect to a local daemon or remote daemon. It cannot reveal in Finder, use desktop file pickers the same way, or rely on isolates.

Required:

- platform capability endpoint drives available actions;
- local-only actions are hidden or disabled with reason;
- web shows host/context clearly;
- payload sizes are stricter for web;
- keyboard shortcuts avoid browser-reserved conflicts where possible.

Avoid:

- showing Reveal in Finder in remote web mode;
- assuming Cmd/Ctrl shortcuts always reach Flutter web;
- using web UI as proof desktop packaged UX works.

### Browser Back/Refresh Must Not Lose Dangerous Context Silently - `P0`

The web user can refresh during scan or cleanup.

Required:

- route state can recover selected scan/session from operation status;
- refresh during active cleanup shows authoritative operation status;
- stale confirmation tokens cannot execute after reload;
- delete queue draft either persists intentionally or is discarded visibly;
- browser navigation does not create duplicate scan commands.

Avoid:

- restarting scan on page load without idempotency;
- losing cleanup receipt after refresh;
- using in-memory widget state as only confirmation state.

## Testing Edge Cases

### Fake Rust Query Source Is Required - `P1`

Frontend tests need huge trees without real disk scans.

Required:

- fake query client returns deterministic pages;
- fake supports latency, errors, stale cursor, resync required, permission warnings, and changing progress;
- fake can generate million-node logical trees without allocating huge widget lists;
- widget tests use fake store/protocol, not real daemon.

Avoid:

- tests that scan local filesystem;
- golden tests with machine-specific paths;
- only testing small 20-row trees.

### Golden And Screenshot Tests Need Density Cases - `P1`

The UI can look good at one size and fail at compact width or high text scale.

Required:

- wide reference-like layout;
- compact reference-like layout;
- light and dark themes;
- long file names;
- long paths;
- warning/stale/queued states;
- empty/error/loading states;
- text scale and density variants.

Avoid:

- only golden-testing happy-path dark theme;
- ignoring delete queue overflow;
- hiding scrollbars/focus state in tests.

### Performance Tests Need Product Scenarios - `P0`

Performance should be tested around actual workflows.

Required scenarios:

- initial scan progress screen;
- completed scan with large root expanded;
- expand/collapse large folder;
- fast scroll through 100k visible logical rows;
- selection changes details panel;
- search/filter result page;
- add/remove queue item;
- compact layout with delete queue open;
- web payload parsing and rendering.

Measured targets:

- frame time in profile/release-like mode;
- row build count per action;
- memory after scroll;
- query count per interaction;
- time from event to visible update;
- scroll position stability after data refresh.

Avoid:

- debug-mode-only performance conclusions;
- performance tests that include real network/disk unless explicitly end-to-end;
- microbenchmarks without UI frame metrics.

## MVP Cut Line

Before first large-tree UI:

- main tree is virtualized;
- Flutter does not hold full scan tree;
- row identity is node ID, not index/path;
- focus, selection, expansion, details, and queue states are separate;
- query pages are cached with snapshot/version keys and bounded;
- progress events do not rebuild the tree;
- DataTable/SingleChildScrollView full-tree approach is banned for central table;
- wide and compact layouts use same store;
- basic keyboard navigation works.

Before cleanup-capable beta:

- Add to Queue reconciles with server DeletePlan version;
- stale row/details/queue states are visible;
- Move to Trash cannot be enabled from local-only draft state;
- delete queue survives layout changes and reload policy is explicit;
- long names/paths and warnings fit compact layout;
- accessibility tests cover focus, selection, queue, and confirmation;
- frontend performance tests cover scan/progress, expand/collapse, scroll, search, and queue workflows.

Deferred:

- fully custom render object table;
- full two-dimensional virtualization if fixed-column row list is enough for MVP;
- collaborative multi-user delete plan editing UI;
- user-customizable columns;
- advanced typeahead/tree search interaction beyond MVP search field;
- persisted UI workspaces/layout presets.

## Summary

Clean Disk's Flutter invariant:

```text
The frontend renders only the current product surface, never the whole disk model.
```

📌 The app can feel native only if Rust does the heavy tree/query work and Flutter keeps state small, explicit, virtualized, and version-aware. The design-system tree table is not polish. It is the central safety and performance primitive.
