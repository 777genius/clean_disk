# Flutter Frontend Architecture Decision

Last updated: 2026-05-16.

This document records the accepted Flutter-side responsibility zones and MobX
store architecture for Clean Disk.

It complements:

- [Architecture decisions](architecture-decisions.md)
- [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md)
- [Implementation edge cases UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Disk usage map view adapter decision](disk-usage-map-view-adapter.md)
- [Frontend boundaries decision](frontend-boundaries-decision.md)

## Sources Reviewed

- MobX.dart documentation, concepts and API docs. Relevant points: observable
  state is mutated through actions, computed values derive state, reactions
  return disposers, and `Observer` rebuilds from observables read inside its
  builder.
- MobX.dart code generation docs. Relevant points: annotated stores use
  `mobx_codegen` and generated files are build artifacts.
- Existing Clean Disk frontend docs. Relevant points: Rust owns the full scan
  tree and indexes, Flutter owns viewport state and user intent, and large UI
  results must be paginated.

## Accepted Decision

Clean Disk uses feature-scoped MobX stores as presentation-layer controllers
that orchestrate application use cases and expose application state to the UI.

Accepted shape:

```text
apps/clean_disk
  -> app composition, routing, config, DI, concrete adapters

features/scan/application
  -> ports, use cases, framework-free application state, state machines

features/scan/data
  -> CleanDiskApiClient adapter, ScanEventClient adapter, DTO mapping,
     repositories, cache adapters when needed

features/scan/presentation/stores
  -> MobX stores, visible UI state, user intent,
     command orchestration over use cases

features/scan/presentation/pages/widgets
  -> lean widgets, Observer boundaries, callbacks, layout

packages/design_system
  -> shared UI primitives, Headless/Material facade, themes, accessibility
```

MobX annotations, observables, actions, computed values, reactions, and
`ObservableFuture` are allowed only in presentation stores and
presentation-facing state objects.

Application layer may own state, but only as framework-free pure Dart models,
state machines, and result types. Domain and application contracts stay free of
Flutter, MobX, generated store code, and widget lifecycle concerns.

## Top 3 Options

1. Feature-scoped MobX presentation stores plus pure application state/use cases
   - 🎯 10  🛡️ 10  🧠 6, roughly 1200-2800 LOC for scan UI stores, tests, and
   adapters.
   Accepted. It matches the current workspace, keeps UI reactive, and still
   preserves Clean Architecture boundaries.
2. One global MobX mega-store - 🎯 4  🛡️ 4  🧠 4, roughly 700-1800 LOC first.
   Rejected. It becomes a hidden app kernel, mixes daemon state, selection,
   settings, queue, layout, and cleanup authority, and makes safety reviews
   harder.
3. No MobX, only widgets plus FutureBuilder/StreamBuilder - 🎯 2  🛡️ 2  🧠 3,
   roughly 400-1200 LOC first.
   Rejected. It is too easy to restart queries in build, tie scan lifetime to
   widget lifetime, and lose state when virtualized rows unmount.

## Responsibility Zones

### App Shell

`apps/clean_disk` owns:

- app bootstrap;
- GetIt registration and Modularity module mounting;
- route definitions and route-level guards;
- runtime config from Dart defines;
- concrete adapter choice for daemon API, event stream, local cache, platform
  actions, and optional visual renderers;
- app-level theme and localization setup.

It must not own scan business rules, delete safety, row virtualization internals,
or Rust protocol parsing beyond adapter wiring.

### Feature Application

Feature application owns:

- ports for scan queries, events, cleanup plan commands, settings, and platform
  actions;
- use cases that coordinate one user intent across repositories;
- framework-free application state and state machines, such as scan status,
  query freshness, command availability, disabled reasons, stale snapshot
  states, operation status, and cleanup plan status;
- command result types and failure mapping.

It must not import Flutter widgets, MobX, Dio, Drift, GetIt, Modularity,
Headless, pdu, Rust bridge bindings, or generated protocol code.

### Feature Data

Feature data owns:

- HTTP and WebSocket adapter implementation;
- DTO decoding and mapping to application/domain-safe models;
- repository implementations;
- local cache adapters when needed;
- retry/reconnect glue that is transport-specific.

It must not expose raw HTTP routes, WebSocket payloads, generated DTOs, or Dio
types to presentation stores.

### Presentation Stores

MobX stores own:

- visible UI state;
- user intent;
- screen-level orchestration;
- reactive projections of application state for a screen;
- bounded view/query caches;
- active subscriptions and reaction disposers;
- route/screen lifecycle state;
- conversion from application models to compact view models.

Stores must not:

- define application state machines with MobX annotations;
- hold the full scan tree;
- own filesystem truth;
- own delete authority;
- keep raw path strings as cleanup authority;
- parse raw protocol messages directly;
- contain widget layout code beyond presentation state;
- perform expensive full-tree sorting/filtering/searching.

### Widgets

Widgets own:

- layout;
- pointer, focus, and keyboard event forwarding;
- animation and visual affordances;
- local ephemeral widget state only, such as open menu anchor or text field
  controller lifecycle;
- `Observer` boundaries around the smallest practical reactive subtree.

Widgets must not:

- start HTTP queries in `build`;
- create long-lived WebSocket subscriptions;
- store selection, expansion, delete queue, or scan session truth;
- use row index as identity;
- derive cleanup candidates from visible rows.

### Design System

`packages/design_system` owns reusable UI primitives:

- `TreeTable`;
- `DiskUsageMapView`;
- status badge;
- issue/warning surface;
- action menu;
- operation footer;
- confirmation dialog;
- receipt/operation timeline;
- responsive split layout primitives.

Feature code can compose these primitives but should not fork local one-off
versions when a missing primitive should exist in the shared layer.

### TreeTable Implementation Strategy

Accepted implementation strategy:

1. `TreeTable` facade with `ListView.builder` fixed-row adapter for MVP
   - 🎯 9 🛡️ 9 🧠 6, roughly 1800-3500 LOC.
   Accepted. It gives a fast path to the saved design references while keeping
   the table engine replaceable.
2. `TreeTable` facade backed by `two_dimensional_scrollables` `TableView` or
   `TreeView` - 🎯 7 🛡️ 8 🧠 7, roughly 2200-4500 LOC.
   Future adapter after a spike validates pinned columns, treegrid semantics,
   and server-owned paginated rows.
3. Fully custom sliver/render-object tree table - 🎯 5 🛡️ 9 🧠 10, roughly
   6000-12000 LOC.
   Escape hatch only.

The facade is the contract. `ListView.builder` is only the first internal
adapter. Feature stores, query use cases, selection, expansion, and cleanup
queue must not depend on the concrete table engine.

First UI pass is considered good enough when the wide/compact reference
structure is matched, text does not overflow, synthetic 50k visible rows scroll
smoothly in profile mode, progress updates do not rebuild the tree, and all
critical visual states exist. Do not spend long cycles on glow/shadow minutiae,
advanced resizing, final chart taxonomy, or final cleanup copy before real
projection DTOs and DeletePlan contracts exist.

## Store Taxonomy

Stores are small and actor-oriented. Each store has one reason to change.

Accepted store set for scan MVP and cleanup beta:

```text
DaemonConnectionStore
CapabilityStore
ScanSessionStore
ScanProgressStore
ScanViewportStore
TreeExpansionStore
SelectionStore
NodeDetailsStore
SearchFilterSortStore
DiskUsageMapStore
CleanupQueueStore
OperationStore
IssueStore
SettingsStore
ShortcutCommandStore
```

Future stores:

```text
ReceiptStore
RecommendationStore
SupportBundleStore
UpdateCompatibilityStore
RemoteSessionStore
```

### Store Responsibilities

`DaemonConnectionStore` owns connection state, daemon version, protocol version,
reconnect status, pairing/token health, and compatibility status. It does not
own active scan data.

`CapabilityStore` owns current product capabilities, disabled reasons,
permission quality, feature flags, and platform capability profile. It does not
infer capabilities from OS names in widgets.

`ScanSessionStore` owns selected target, active scan session id, scan snapshot
id, scan lifecycle state, and start/pause/cancel/dispose command orchestration.
It does not keep visible rows or full nodes.

`ScanProgressStore` owns the latest throttled progress snapshot, throughput,
elapsed time, scanned count, skipped count, progress freshness, and terminal
state reconciliation. It does not rebuild tree rows on every event.

`ScanViewportStore` owns current root node, visible row window, page cursors,
bounded page cache, row view models for the current viewport, and page
loading/error state. It does not own expansion policy, cleanup queue, or full
tree.

`TreeExpansionStore` owns expanded node ids by scan snapshot, pending expansion
state, and collapse behavior when focused child disappears. It stores node ids
only, not child DTO trees.

`SelectionStore` owns focused node ref, selected node ref, future multi-selection
state, and active panel focus region. It keeps focus, selection, queued, and
checked states separate.

`NodeDetailsStore` owns selected node details query, details freshness, lazy
metadata enrichment result, and action availability for details actions. It does
not turn selected node into delete authority.

`SearchFilterSortStore` owns search input state, committed query, sort
column/direction, filter chips, query mode, debounce, and query version. It
requests Rust-side query pages and does not filter a full local tree.

`DiskUsageMapStore` owns current map kind, root node for projection, projection
id, bounded tile projection, and selection sync with tree/details. It uses
`DiskUsageMapView` and does not depend on Syncfusion types.

`CleanupQueueStore` owns draft queue view, server DeletePlan id/version, item
inclusion state, total reclaim estimate display state, and stale/conflict state.
It does not execute cleanup. Execution goes through DeletePlan commands,
preflight, confirmation, operation journal, and receipt.

`OperationStore` owns active operation summaries, cancel command state, terminal
reconciliation, and recovery-required state after crash/restart. It does not
replace daemon-owned operation journal.

`IssueStore` owns skipped paths summary, permission issues, scan quality
warnings, and visible issue filters. It does not log raw sensitive paths by
default.

`SettingsStore` owns UI preferences, density, theme, visible columns, keyboard
preferences, and non-destructive local settings. It does not store daemon
tokens, cleanup confirmations, or operation authority.

## MobX Rules

These rules follow MobX Dart concepts: observables hold reactive state, actions
mutate state, computed values derive from state, reactions perform effects, and
`Observer` rebuilds only when observables read inside its builder change.

### Observables

Use observables for mutable presentation state only.

Allowed:

- current scan session id;
- selected node ref;
- focused node ref;
- expanded node ids;
- current query;
- bounded page cache;
- visible row models;
- loading/error state;
- current capability snapshot.

Forbidden:

- full scan tree;
- raw protocol envelopes;
- daemon auth token;
- delete confirmation token;
- filesystem path as action authority;
- unbounded event history;
- large exports or support bundles.

### Actions

Every mutation happens inside a named action.

Rules:

- user intent methods are actions, for example `startScan`, `selectNode`,
  `expandNode`, `commitSearch`, and `addSelectedToQueue`;
- async actions update explicit pending/success/failure state;
- actions call use cases or repositories, not Dio/WebSocket directly;
- destructive actions return command state and disabled reasons, never silently
  proceed from local UI state.

### Computed Values

Computed values derive cheap view state.

Allowed:

- `canStartScan`;
- `canAddSelectedToQueue`;
- `visibleSummary`;
- `selectedRowViewModel`;
- `isStale`;
- `primaryDisabledReason`.

Forbidden:

- async work;
- HTTP queries;
- expensive full-tree transforms;
- mutation of other observables;
- logging or analytics side effects.

### Reactions

Reactions are for lifecycle-managed side effects.

Allowed:

- debounce committed search after input changes;
- invalidate visible page cache after query key changes;
- reconcile route parameter changes with selected session;
- persist non-sensitive UI preferences;
- throttle progress view updates.

Rules:

- every `autorun`, `reaction`, or `when` must store its `ReactionDisposer`;
- stores expose `dispose()` and call every disposer;
- reactions have debug names where practical;
- reactions do not execute destructive commands;
- reactions do not open native dialogs;
- reactions do not write secrets, tokens, or cleanup confirmations to local
  storage.

### ObservableFuture

`ObservableFuture` can be used for one bounded request status, but not as the
main architecture.

Allowed:

- selected node details request;
- one page request;
- capability refresh;
- support bundle preview request.

Forbidden:

- active scan lifecycle;
- WebSocket stream lifecycle;
- cleanup operation lifecycle;
- unbounded search stream;
- entire scan result loading.

Long-lived flows use explicit state machines, not one future.

### Observer Boundaries

`Observer` widgets must be granular.

Rules:

- wrap the smallest practical UI subtree;
- do not wrap the whole app shell around high-frequency scan progress;
- use built child patterns for expensive static subtrees when needed;
- read observables directly inside the builder so MobX tracks them correctly;
- keep row widgets pure: row model in, callbacks out.

## State Identity Rules

All important UI state is keyed by stable identity.

Required keys:

```text
ScanSessionId
ScanSnapshotId
NodeRef
ProjectionId
QueryKey
PageCursor
DeletePlanId
DeletePlanVersion
OperationId
CapabilitySnapshotId
```

Forbidden keys:

- row index;
- display path text;
- localized label;
- tile index;
- visible table position;
- object identity of DTO instances.

## Store Composition

Stores can depend inward or sideways only through stable interfaces.

Allowed:

```text
ScanViewportStore
  -> ScanQueryRepository
  -> SearchFilterSortStore
  -> TreeExpansionStore

CleanupQueueStore
  -> CleanupPlanUseCases
  -> SelectionStore
  -> CapabilityStore

NodeDetailsStore
  -> NodeDetailsRepository
  -> SelectionStore
```

Avoid:

- circular store dependencies;
- store constructors that need more than roughly 5 direct collaborators;
- repositories depending on stores;
- design-system widgets depending on feature stores;
- stores reaching into GetIt directly after construction.

When two stores need to coordinate, prefer a small application use case or a
facade store over hidden cross-calls.

## Package Shape

Target shape for a feature package:

```text
features/scan/lib/src/
  application/
    models/
      node_ref.dart
      scan_snapshot_ref.dart
      command_state.dart
      action_availability.dart
    ports/
      scan_query_port.dart
      scan_command_port.dart
      scan_event_port.dart
      cleanup_plan_port.dart
    use_cases/
      start_scan_use_case.dart
      query_children_page_use_case.dart
      add_to_cleanup_queue_use_case.dart
      reconcile_scan_event_use_case.dart
    state/
      scan_lifecycle.dart
      query_freshness.dart
      disabled_reason.dart

  data/
    dto/
      scan_session_dto.dart
      node_page_dto.dart
      scan_event_dto.dart
    sources/
      clean_disk_api_client.dart
      scan_event_client.dart
    repositories/
      scan_query_repository.dart
      scan_command_repository.dart
      cleanup_plan_repository.dart

  presentation/
    stores/
      scan_session_store.dart
      scan_progress_store.dart
      scan_viewport_store.dart
      selection_store.dart
      cleanup_queue_store.dart
      disk_usage_map_store.dart
    view_models/
      tree_row_view_model.dart
      node_details_view_model.dart
      cleanup_queue_item_view_model.dart
    pages/
      scan_page.dart
    widgets/
      scan_tree_panel.dart
      scan_details_panel.dart
      cleanup_queue_panel.dart

  di/
    scan_module.dart
```

Generated MobX files stay beside stores as normal Dart generated artifacts, but
generated code must not be hand-edited.

## Lifecycle

Stores have explicit lifecycle.

Rules:

- app-scoped stores live for the app process;
- route-scoped stores live for a route or feature module scope;
- scan-session stores are disposed when the session is closed or route scope is
  torn down;
- every WebSocket subscription, stream subscription, timer, and reaction is
  disposed;
- screen close does not cancel daemon operation unless user intent says so;
- daemon terminal state is reconciled by query after reconnect or route resume.

## Testing Gates

Before scan UI is considered architecture-compliant:

- store unit tests cover state transitions without widgets;
- widget tests verify observer granularity and no state loss after row unmount;
- fake repositories simulate slow pages, rejected commands, stale snapshots,
  reconnect, duplicate events, and out-of-order events;
- golden tests cover wide and compact references;
- accessibility tests cover focus, selection, expansion, and queued state;
- perf smoke tests prove progress updates do not rebuild the whole tree.

## Stop Rules

Stop implementation and revisit architecture if:

- a store needs the full scan tree to render the UI;
- a widget owns selection, expansion, queue, or scan session truth;
- a repository imports a presentation store;
- `Observer` wraps the whole app shell for high-frequency state;
- a reaction can trigger delete, trash, or command execution;
- raw protocol DTOs become widget state;
- cleanup action uses path text instead of `NodeRef` plus snapshot/plan version;
- Syncfusion or any renderer type leaks into feature application contracts;
- WebSocket events become the only source of truth for terminal operation state.

## Final Decision

Use feature-scoped MobX stores as presentation-layer controllers, with
application ports/use cases below them and design-system primitives above them.

Flutter owns viewport, intent, and rendering. Rust and the daemon own scan truth,
operation truth, cleanup authority, and large indexes.

Application owns workflow state and state machines as pure Dart. Presentation
owns MobX reactivity.
