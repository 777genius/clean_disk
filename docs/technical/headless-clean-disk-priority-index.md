# Headless Clean Disk Priority Index

## Status

Accepted implementation priority guide. This is the Clean Disk-specific routing
document for Headless/UI work.

Use this file when deciding:

- what UI/design-system component to build next;
- what must be strong in MVP;
- what should exist only as an adapter boundary;
- what is a future public Headless concern;
- when to stop because a task is becoming too broad.

This document is intentionally stricter than the full
[Headless primitive RFC index](headless-primitives/README.md). The RFC index is
the broad public UI-kit catalog. This file is the product implementation filter
for Clean Disk.

## Related Documents

- [Headless primitive RFC index](headless-primitives/README.md)
- [Headless TreeGrid primitive design](headless-tree-grid-primitive-design.md)
- [Frontend boundaries decision](frontend-boundaries-decision.md)
- [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md)
- [Disk usage map view adapter decision](disk-usage-map-view-adapter.md)
- [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md)
- [Implementation edge cases UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md)

## One Sentence Decision

Build Clean Disk through small product-specific design-system facades now, while
keeping public Headless contracts behind those facades so the UI can scale
without forcing us to build the whole public UI kit first.

Accepted strategy:

1. Product-specific design-system facades over Headless/Material now -
   🎯 10   🛡️ 10   🧠 7, roughly 3000-7000 LOC for the first real scan UI.
   This is the chosen route.
2. Full public Headless primitives first -
   🎯 5   🛡️ 8   🧠 10, roughly 9000-20000 LOC before the product is useful.
   Too slow for Clean Disk.
3. Ad hoc Flutter widgets with no Headless contracts -
   🎯 6   🛡️ 4   🧠 4, roughly 1800-4500 LOC first, but high rewrite and safety
   cost later.
   Too risky for cleanup authority and large-tree behavior.

## Non-Negotiable Rules

These rules override visual convenience:

- Flutter never owns the full scan tree.
- Row index is never identity.
- Selection is not cleanup queue.
- Cleanup queue is not delete authority.
- DeletePlan comes only from current daemon validation.
- Widgets do not parse protocol DTOs.
- `packages/design_system` does not import feature stores.
- Renderer visual state is not domain truth.
- Menus, shortcuts, command palette, and row actions all route through the same
  command/use-case path.
- `DiskUsageMapView` is a projection adapter, not source of truth.
- Public Headless primitives are future-shaped, but MVP implements only what
  the product workflow needs.

## Priority Legend

| Priority | Meaning | Build stance |
| --- | --- | --- |
| P0A | Foundational contract needed before meaningful UI | Build first |
| P0B | Main scan-only MVP surface | Build in MVP |
| P0C | Cleanup safety surface | Build before destructive cleanup |
| P1 | Important soon after scan MVP | Build after TreeTable and status work |
| P2 | Architecture-only for now | Keep extension point, do not implement UI |
| P3 | Public Headless/community depth | Document and test hooks only |

## Critical Product Path

```text
P0A contracts and tokens
  -> P0B layout shell
  -> P0B TreeTable
  -> P0B scan progress footer
  -> P0B details inspector
  -> P0C cleanup queue
  -> P0C validated confirmation
  -> P1 query controls
  -> P1 disk usage map projection
```

The first usable product is not a complete UI kit. It is a scan workbench that
can show a large paginated tree, explain what is selected, and safely prepare a
cleanup plan.

## Dependency Order

Build in this order unless there is a clear reason to split a spike.

| Order | Work item | Why it comes here | Blocks |
| --- | --- | --- | --- |
| 0 | View model and command contracts | Prevents widgets from becoming app logic | all product widgets |
| 1 | Theme/token bridge | Prevents Material and Headless visual drift | layout and controls |
| 2 | App shell layout | Provides wide/compact product frame | TreeTable integration |
| 3 | TreeTable facade | Core workflow and biggest risk | details, queue, query |
| 4 | Progress footer | Scan lifecycle visibility | real scan UX |
| 5 | Details inspector | Safe inspection and full path visibility | cleanup review |
| 6 | Queue and confirmation | Destructive safety boundary | cleanup beta |
| 7 | Query controls | Scales navigation after tree works | search/filter/sort UX |
| 8 | Map projection | Adds visual exploration without becoming truth | advanced scan UX |

## Clean Disk Design-System Surface

The first real `packages/design_system` surface should be this small set:

```text
AppButton
AppIconButton
AppTextField
AppSelectField
AppBadge
AppMetricTile
AppStatusBanner
AppPanel
AppToolbar
AppTreeTable
AppDetailsInspector
AppCleanupQueue
AppConfirmDialog
AppProgressFooter
AppDiskUsageMapView
```

Rules:

- app components are facades over Headless or Material primitives;
- facades accept view models and command callbacks;
- facades do not import feature stores;
- facades do not parse protocol DTOs;
- facades do not own cleanup authority;
- facades expose semantic parts and states, not product workflow internals.

## Public Headless Versus Clean Disk Facade

| Clean Disk facade | Public Headless direction | MVP implementation |
| --- | --- | --- |
| `AppTreeTable` | future `RTreeGrid` over collection/grid/tree/viewport contracts | fixed-height virtual list with stable row ids |
| `AppConfirmDialog` | future dialog/alertdialog/overlay stack primitives | focused confirmation dialog with safe defaults |
| `AppCleanupQueue` | future list/collection/bulk action primitives | explicit queued items and remove action |
| `AppProgressFooter` | future progress/status/live region primitives | throttled scan status footer |
| `AppDetailsInspector` | future property/details inspector primitive | selected node facts and safe path display |
| `AppDiskUsageMapView` | future visualization adapter contract | bounded projection adapter |
| `AppToolbar` | future command bar/toolbar/menu button primitives | command buttons with disabled reasons |

This keeps Open/Closed Principle in practice: Clean Disk can swap renderer or
public Headless implementation later without changing feature workflows.

## P0A Foundation Components

### View Model And Command Contracts

Why this is first:

- every component depends on stable identity and command routing;
- it prevents Flutter widgets from inventing product authority;
- it keeps Clean Architecture boundaries visible.

Critical now:

- `NodeRef`, `SnapshotRef`, `ScanSessionRef`, and `CommandId` shapes;
- presentation view models separate from protocol DTOs;
- command intent shape with source, scope, target, and disabled reason;
- semantic row states: focused, selected, current, queued, stale, disabled,
  busy, warning;
- typed size and percent display values.

Architect for later:

- command registry;
- shortcut mapping;
- command palette;
- operation provenance;
- multi-window command scope.

Avoid now:

- global command bus;
- reflection/string command dispatch;
- localized labels as command ids;
- feature store references inside design-system props.

Risk rating: 🎯 10   🛡️ 10   🧠 7, roughly 500-1200 LOC/tests.

### Theme And Token Bridge

Why:

- Clean Disk design depends on dense tables, dark/light themes, neon accents,
  readable state differences, and strong focus;
- Headless and Material must not diverge.

Critical now:

- one source for color, typography, spacing, radius, focus, density, and status
  tokens;
- dark and light themes;
- Headless scope receives the same tokens as Material;
- selected/focused/current/queued row tokens are visually distinct;
- stale/disabled/warning/destructive tokens are distinct;
- no hardcoded per-widget color systems.

Architect for later:

- forced-colors/high contrast;
- user density profiles;
- custom themes;
- public renderer token contract.

Avoid now:

- polishing glow/gradient effects before table readability;
- separate Headless and Material theme systems;
- visual state names that do not map to semantic state.

Risk rating: 🎯 10   🛡️ 9   🧠 6, roughly 500-1400 LOC/tests.

## P0B Scan MVP Components

### App Shell Layout

Why:

- it creates the product frame shown in the saved wide/compact references;
- it lets scan state, details, queue, and progress have stable places;
- it avoids rewriting layout once real data arrives.

Critical now:

- wide layout with target sidebar, central workbench, details/queue side pane,
  and bottom progress footer;
- compact layout with top target controls, central TreeTable, below-tree
  details, collapsible queue, and sticky progress footer;
- no nested cards;
- no text overflow in known target sizes;
- stable slots for toolbar, target picker, tree, details, queue, and footer.

Architect for later:

- split-pane persistence;
- multi-window;
- route/focus restoration;
- saved layout presets.

Avoid now:

- every possible breakpoint;
- draggable split panes before MVP;
- route-level layout customization;
- decorative layout work that delays data rendering.

Risk rating: 🎯 9   🛡️ 8   🧠 5, roughly 700-1600 LOC/tests.

### TreeTable Facade

This is the most important UI component in the project.

Why:

- it is the main product surface;
- it connects Rust paginated node queries to Flutter UI;
- it carries hierarchy, size comparison, selection, current details, focus,
  expansion, row actions, and queue entry points;
- it is the biggest rewrite risk if built as an ad hoc `Column`.

Critical now:

- stable row id from `NodeRef`, never visible row index;
- fixed row height for MVP virtualization;
- controlled expansion set;
- separate channels for focused row, selected row, current details row, queued
  row, stale row, disabled row, and warning row;
- columns for name, size, percent bar, item count, modified date, warnings, and
  action trigger;
- row action part emits command intent only;
- paginated/window loading state;
- skeleton/empty/error states;
- no full scan tree in Flutter.

Architect for later:

- renderer adapter behind `AppTreeTable`;
- future public `RTreeGrid`;
- `two_dimensional_scrollables` or custom sliver adapter;
- pinned columns;
- column resize and presets;
- accessibility snapshot tests;
- advanced keyboard model.

Avoid now:

- full AG Grid clone;
- editable cells;
- drag/drop rows;
- Excel-like keyboard model;
- arbitrary cell render plugin system;
- client-side recursive search/sort/filter;
- exposing protocol DTOs to row widgets.

Exit gate:

- 50k synthetic visible-row dataset remains smooth enough;
- progress footer updates do not rebuild all rows;
- expansion, selection, current row, focus, and queue states are visually
  distinct;
- long names and paths do not overflow controls;
- screen-reader semantics at least expose row name, level, expanded state, size,
  and selected/current facts.

Risk rating: 🎯 10   🛡️ 10   🧠 9, roughly 1800-4000 LOC/tests.

### Progress Footer

Why:

- disk scans can take time;
- users need proof the scanner is alive;
- pause/cancel must stay visible and safe;
- progress events must not rebuild the whole app.

Critical now:

- scan status;
- current path with truncation disclosure;
- percent or indeterminate mode;
- scanned item count;
- elapsed time;
- throughput;
- skipped and error counters;
- pause/cancel command intents;
- disconnected/degraded scanner state.

Architect for later:

- operation center;
- operation journal;
- notification inbox;
- multi-scan sessions;
- support bundle operation timeline.

Avoid now:

- full log viewer;
- per-file UI events;
- charts for throughput;
- footer owning scan lifecycle;
- notification system before footer is stable.

Exit gate:

- progress updates are throttled;
- current path is readable and accessible;
- cancel/pause commands go through application use cases;
- footer can update without invalidating TreeTable row widgets.

Risk rating: 🎯 9   🛡️ 9   🧠 5, roughly 500-1200 LOC/tests.

### Details Inspector

Why:

- it is where users verify what the selected node actually is;
- it provides full path visibility without bloating table rows;
- it is the safe place for warnings, permissions, and metadata.

Critical now:

- selected node name and icon;
- full path with bidi-safe and truncation-safe display;
- size facts with clear labels;
- item count;
- modified date;
- permissions/capability warnings;
- reveal action;
- add-to-queue command intent;
- loading/degraded state for lazy metadata.

Architect for later:

- richer metadata enrichment;
- evidence/confidence sections;
- compare view;
- recommendation cards;
- support export redaction.

Avoid now:

- plugin inspector architecture;
- deep forensic metadata;
- filesystem metadata editing;
- details view becoming delete authority.

Exit gate:

- full operational path is visible before any cleanup review;
- warnings are not hidden in tooltips only;
- missing metadata is shown as unavailable/degraded, not blank truth;
- reveal/add-to-queue go through command boundary.

Risk rating: 🎯 9   🛡️ 9   🧠 6, roughly 700-1600 LOC/tests.

## P0C Cleanup Safety Components

### Cleanup Queue

Why:

- it is the explicit user-intent boundary;
- it prevents table selection from becoming deletion;
- it prepares users for a validated confirmation plan.

Critical now:

- explicit queued item list;
- stable queued ids;
- item path/name/size summary;
- remove item;
- total estimated reclaim;
- stale/degraded item state;
- disabled reason when validation is required;
- no destructive execution from queue alone.

Architect for later:

- grouped queue;
- partial cleanup results;
- receipts;
- restore/undo capability levels;
- operation journal.

Avoid now:

- one-click delete;
- queue from hidden filtered selection without preview;
- optimistic deletion;
- queue items keyed by path string alone.

Risk rating: 🎯 10   🛡️ 10   🧠 7, roughly 700-1600 LOC/tests.

### Confirmation Dialog

Why:

- it is the final safety gate before destructive cleanup;
- it must render the current daemon-validated plan, not stale UI state.

Critical now:

- current validated DeletePlan summary;
- stale plan disabled state;
- missing capability disabled state;
- item count and reclaim estimate with confidence;
- safe initial focus;
- cancel path;
- explicit destructive command;
- visible disabled reasons.

Architect for later:

- receipt preview;
- policy conflict details;
- remote authority scopes;
- multi-step review.

Avoid now:

- modal framework beyond needed confirmation behavior;
- destructive button focused by default;
- confirmation based on table selection;
- confirmation from stale snapshot.

Exit gate:

- destructive button is disabled unless a current validated plan exists;
- focus return is safe after cancel/complete;
- plan changes while dialog is open invalidate action;
- confirmation content is readable with keyboard and screen reader.

Risk rating: 🎯 10   🛡️ 10   🧠 8, roughly 700-1800 LOC/tests.

## P1 Components After Scan MVP

P1 is important soon. It should not block the first useful scan workbench.

### Search Filter Sort Surface

Build after TreeTable can show paged rows.

Critical:

- typed query state;
- debounced search;
- sort by protocol fields;
- filter chips for major classes;
- query id and stale result handling;
- Rust-side sorting/filtering.

Architect for later:

- faceted filters;
- query presets;
- date/range filters;
- history/compare integration.

Avoid:

- Flutter-side full tree search;
- complex query language before simple query works;
- custom date picker before scan history exists.

Risk rating: 🎯 9   🛡️ 9   🧠 6, roughly 600-1500 LOC/tests.

### Capability And Permission Banner

Build once daemon capability DTOs exist.

Critical:

- scan quality state;
- permission issue summary;
- repair entry point;
- degraded/offline/stale daemon states;
- risky actions disabled when capability is unknown.

Architect for later:

- guided repair wizard;
- notification inbox;
- support diagnostics;
- platform-specific repair recipes.

Avoid:

- hiding permission issues in logs;
- modal-only permission UX;
- pretending partial scan is complete;
- enabling cleanup when capability is unknown.

Risk rating: 🎯 9   🛡️ 10   🧠 6, roughly 500-1300 LOC/tests.

### Disk Usage Map View

Build as an optional visual projection after TreeTable works.

Critical:

- `AppDiskUsageMapView` facade;
- bounded Rust projection;
- selected node sync;
- adapter interface for treemap/donut/sunburst;
- clear "visual estimate" semantics.

Architect for later:

- Syncfusion adapter;
- custom treemap adapter;
- sunburst/icicle adapter;
- map accessibility fallback.

Avoid:

- chart as source of truth;
- blocking MVP on custom treemap;
- rendering millions of nodes;
- cleanup execution from chart alone.

Risk rating: 🎯 8   🛡️ 8   🧠 7, roughly 700-1800 LOC/tests.

### Context Menu And Menu Button

Build when row actions outgrow visible icon buttons.

Critical:

- keyboard open;
- disabled reasons;
- command id routing;
- focus return;
- no destructive bypass;
- same command path as toolbar and row buttons.

Architect for later:

- nested menus;
- native menubar;
- command palette integration.

Avoid:

- app-wide menubar before core commands stabilize;
- menu callbacks that skip store/use case;
- destructive commands without review path.

Risk rating: 🎯 8   🛡️ 8   🧠 6, roughly 500-1400 LOC/tests.

## P2 Architecture Only

These are important for future scale, but should not produce product code
until a workflow demands them.

| Area | Keep now | Do not build now |
| --- | --- | --- |
| Public `RTreeGrid` | adapter boundary and row model compatibility | full 2D grid engine |
| Command palette | command id and registry shape | destructive command execution |
| Operation center | operation id and event model | background task dashboard |
| Notification inbox | attention levels | persistent notification system |
| Date/range picker | typed temporal query values | custom calendar UI |
| Inline edit | edit state machine notes | editable grid cells |
| Drag/drop | command alternative and stable ids | row drag reorder |
| Multi-window | session and scope ids | live multi-window coordination |
| Accessibility lab | semantic snapshot hooks | full ARIA-AT style lab |
| Exotic inputs | adapter vocabulary | switch/braille/eye/gamepad implementation |

## What Can Take Too Much Time

Use this table before starting a large UI task.

| Time sink | Why risky | Safe MVP stance |
| --- | --- | --- |
| Full TreeGrid platform | huge API, keyboard, columns, virtualization, semantics | `AppTreeTable` facade with fixed-height virtual rows |
| Public conformance lab | valuable but very broad | semantic snapshot hooks and focused widget tests |
| Custom treemap/sunburst | algorithm/rendering/perf rabbit hole | bounded `DiskUsageMapView` projection |
| Command palette | can bypass command policy | architecture only until commands stabilize |
| Modal/overlay framework | easy to overbuild | confirmation dialog plus focus return rules |
| Date picker | locale/timezone/calendar complexity | typed query contract first |
| Inline editing | IME, dirty state, virtualization conflicts | not in scan MVP |
| Drag/drop | pointer, keyboard alternative, authority complexity | command alternatives first |
| Multi-window | session ownership and stale state | identifiers only |
| Advanced accessibility procurement docs | high value for public Headless | after core product flow works |

## Implementation Packets

### Packet 0 - Contracts Before Widgets

Build:

- view model types;
- command intent types;
- stable id wrappers;
- row state vocabulary;
- disabled reason vocabulary;
- size/percent display facts.

Exit gate:

- design-system props do not expose protocol DTOs;
- command ids are stable and not localized;
- row index is not used as identity.

### Packet 1 - Theme And Primitive Bridge

Build:

- shared design tokens;
- `AppHeadlessScope` token bridge;
- dark and light themes;
- button/select/text field migration where Headless supports the needed states;
- focus/disabled/stale/destructive tokens.

Exit gate:

- Headless and Material use the same token source;
- disabled states work;
- focus states are visible in dark and light themes;
- table readability beats decorative effects.

### Packet 2 - App Layout Shell

Build:

- wide layout matching reference;
- compact layout matching reference;
- toolbar;
- scan target navigation;
- placeholder panels;
- sticky progress footer slot.

Exit gate:

- no text overflow at target sizes;
- no nested cards;
- shell can host real scan state;
- compact layout has no permanent sidebar.

### Packet 3 - TreeTable MVP

Build:

- `AppTreeTable` facade;
- fixed row height;
- indentation and disclosure;
- stable row ids;
- selected/current/focused/queued/stale/disabled/warning states;
- size/percent/items/modified columns;
- paginated loading placeholders.

Exit gate:

- 50k synthetic rows are smooth enough;
- progress footer updates do not rebuild all rows;
- keyboard focus and selected row are visibly different;
- all row actions emit command intents.

### Packet 4 - Scan Status And Details

Build:

- progress footer;
- details inspector;
- path truncation disclosure;
- warnings and permissions;
- reveal and add-to-queue command intents.

Exit gate:

- selected row details are clear;
- long paths are accessible and copy-safe;
- progress updates are throttled;
- missing metadata is represented honestly.

### Packet 5 - Cleanup Queue And Confirmation

Build:

- explicit queue;
- remove from queue;
- total estimate;
- validated plan state;
- confirmation dialog;
- stale/disabled reasons.

Exit gate:

- destructive command cannot run from row selection alone;
- stale plan disables action;
- confirmation shows current validated plan;
- cancel/complete focus return is safe.

### Packet 6 - Query Controls And Map Adapter

Build:

- search/filter/sort controls over typed query port;
- bounded `DiskUsageMapView` adapter;
- selected node synchronization.

Exit gate:

- Rust-side query owns sort/filter;
- Flutter receives pages/projections only;
- chart cannot execute cleanup;
- stale query results are visible as stale.

## Stop Rules

Stop, split, or redesign if any of this appears:

- a design-system component imports a feature store;
- a widget parses protocol DTOs;
- selection, queue, and DeletePlan collapse into one state;
- row index becomes identity;
- Flutter sorts/filters the full scan tree;
- a menu, shortcut, or command palette can execute destructive action without
  the confirmation path;
- visual polish delays readable rows and progress;
- TreeTable begins growing into full public `RTreeGrid` before MVP passes;
- chart projection becomes cleanup authority;
- disabled reason is hidden in logs or toasts only;
- cleanup action is enabled when daemon capability is unknown;
- long paths are only visible on hover.

## Future Scaling Rules

Keep these extension points even in MVP:

- `AppTreeTable` renderer adapter boundary;
- `AppDiskUsageMapView` renderer adapter boundary;
- stable command ids and command scopes;
- stable node refs and snapshot ids;
- view models separate from protocol DTOs;
- typed query objects;
- operation ids;
- capability DTOs;
- modal focus return tokens;
- token bridge between app theme and Headless;
- semantic state names for selected, focused, current, queued, stale, disabled,
  busy, warning, destructive, and degraded;
- query id and snapshot id in every large data view;
- explicit stale state for cached UI.

These are cheap to preserve now and expensive to retrofit later.

## What Not To Optimize Yet

Do not spend MVP time on:

- full public Headless release packaging;
- exhaustive ARIA role matrix implementation;
- full keyboard shortcut customization;
- custom date/time picker;
- inline editing;
- drag/drop;
- multi-window;
- PWA offline mode;
- web notifications;
- haptics/gamepad/eye tracking;
- public extension marketplace;
- all accessibility procurement artifacts;
- complete visual chart suite;
- complex plugin architecture for inspector panels.

Architectural notes can exist. Runtime code waits until a product workflow
demands it.

## Definition Of Done For First Useful UI

The first useful UI is done when:

- user can choose a scan target;
- app can show scan progress;
- app can render a large paginated folder tree;
- user can inspect a selected node;
- user can add explicit items to cleanup queue;
- destructive action is disabled until current validation exists;
- wide and compact layouts match the saved direction;
- theme/focus/disabled states are consistent;
- no component violates frontend boundaries;
- synthetic large-row profile is smooth enough;
- long paths and warnings are visible without relying on hover only.

## Summary

📌 Critical path: `Contracts -> Theme Bridge -> Layout Shell -> TreeTable ->
Progress Footer -> Details -> Queue -> Confirmation -> Query/Map`.

The main risk is not that we under-design Headless. We already have deep RFCs.
The main risk is implementing the entire public UI kit before Clean Disk can
scan, inspect, and safely prepare cleanup. Keep the contracts strong, keep the
facades small, and only promote a primitive to public Headless implementation
after the product workflow proves it needs that depth.

