# Frontend Boundaries Decision

Last updated: 2026-05-16.

This document records the accepted frontend boundary rules for Clean Disk.

It complements:

- [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md)
- [Architecture decisions](architecture-decisions.md)
- [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md)
- [Implementation edge cases protocol data contracts](implementation-edge-cases-protocol-data-contracts.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Implementation edge cases UI accessibility and i18n](implementation-edge-cases-ui-accessibility-i18n.md)
- [Disk usage map view adapter decision](disk-usage-map-view-adapter.md)

## Accepted Decision

Clean Disk frontend boundaries are explicit. Widgets, MobX stores, application
use cases, repositories, protocol DTOs, design-system primitives, and platform
adapters each own a different reason to change.

Accepted direction:

```text
Widget
  -> Presentation ViewModel / MobX Store
  -> Application UseCase
  -> Application Port
  -> Data Repository / Adapter
  -> Protocol Source
  -> Rust daemon / Platform API
```

The frontend is allowed to be rich and reactive, but it is not allowed to become
the source of truth for scan data, cleanup authority, operation results,
platform capability, or protocol semantics.

## Layer Boundary Map

```text
Design system
  owns reusable visual primitives and accessibility behavior
  does not own product state or protocol parsing

Feature widgets
  own layout and event forwarding
  do not own durable UI workflow state

MobX stores
  own presentation state, screen orchestration, and reactive projections
  do not own application state machines or backend truth

Application
  owns use cases, ports, pure Dart workflow state, command availability
  does not know MobX, Flutter widgets, Dio, Drift, Headless, or protocol DTOs

Data
  owns DTO mapping, repositories, HTTP/WebSocket sources, cache adapters
  does not expose transport types to stores/widgets

Daemon/Rust/platform
  owns scan truth, operation truth, delete authority, filesystem and platform facts
```

## Top Frontend Boundaries

1. DTO to application model to view model boundary - 🎯 10  🛡️ 10  🧠 5,
   roughly 400-900 LOC/tests.
2. Authoritative state boundary - 🎯 10  🛡️ 10  🧠 6, roughly 500-1200
   LOC/tests.
3. Command boundary - 🎯 10  🛡️ 10  🧠 5, roughly 400-1000 LOC/tests.
4. Design system versus feature UI boundary - 🎯 10  🛡️ 9  🧠 7, roughly
   800-2500 LOC/tests as primitives mature.
5. Event stream boundary - 🎯 9  🛡️ 9  🧠 6, roughly 500-1100 LOC/tests.
6. Persistence boundary - 🎯 9  🛡️ 10  🧠 6, roughly 500-1400 LOC/tests.
7. Platform action boundary - 🎯 9  🛡️ 9  🧠 6, roughly 500-1300 LOC/tests.
8. Accessibility and keyboard boundary - 🎯 9  🛡️ 10  🧠 8, roughly
   900-2400 LOC/tests.
9. Responsive layout boundary - 🎯 8  🛡️ 8  🧠 5, roughly 400-1000 LOC/tests.
10. Error and capability boundary - 🎯 9  🛡️ 9  🧠 5, roughly 400-900
    LOC/tests.
11. Formatting and localization boundary - 🎯 10  🛡️ 9  🧠 5, roughly
    300-800 LOC/tests.
12. Design tokens and theme boundary - 🎯 10  🛡️ 9  🧠 6, roughly
    500-1400 LOC/tests.
13. Async lifecycle boundary - 🎯 10  🛡️ 10  🧠 7, roughly 600-1600 LOC/tests.
14. Input intent boundary - 🎯 9  🛡️ 9  🧠 5, roughly 300-900 LOC/tests.
15. Feature module boundary - 🎯 9  🛡️ 9  🧠 6, roughly 400-1100 LOC/tests.
16. DI and composition boundary - 🎯 9  🛡️ 9  🧠 5, roughly 300-800
    LOC/tests.
17. Error taxonomy boundary - 🎯 10  🛡️ 9  🧠 6, roughly 500-1200 LOC/tests.
18. Observability and telemetry boundary - 🎯 9  🛡️ 10  🧠 7, roughly
    600-1600 LOC/tests.
19. Performance budget boundary - 🎯 9  🛡️ 9  🧠 7, roughly 700-1800 LOC/tests.
20. Generated code boundary - 🎯 8  🛡️ 8  🧠 4, roughly 200-600 LOC/tests.
21. Asset and icon boundary - 🎯 8  🛡️ 8  🧠 4, roughly 200-700 LOC/tests.
22. Testing boundary - 🎯 10  🛡️ 10  🧠 7, roughly 700-2000 LOC.
23. Feature flag and capability flag boundary - 🎯 9  🛡️ 9  🧠 5, roughly
    300-900 LOC/tests.
24. Path display boundary - 🎯 9  🛡️ 10  🧠 6, roughly 400-1000 LOC/tests.
25. View model granularity boundary - 🎯 9  🛡️ 8  🧠 5, roughly
    400-1000 LOC/tests.
26. Target runtime boundary - 🎯 10  🛡️ 10  🧠 5, roughly
    250-700 LOC/tests.
27. Daemon session and auth boundary - 🎯 10  🛡️ 10  🧠 7, roughly
    500-1400 LOC/tests.
28. Query cache and invalidation boundary - 🎯 10  🛡️ 9  🧠 7, roughly
    700-1800 LOC/tests.
29. Virtualized row identity boundary - 🎯 10  🛡️ 10  🧠 8, roughly
    800-2200 LOC/tests.
30. Confirmation surface boundary - 🎯 10  🛡️ 10  🧠 6, roughly
    500-1300 LOC/tests.
31. Frontend scheduler boundary - 🎯 9  🛡️ 9  🧠 7, roughly
    500-1500 LOC/tests.
32. Undo and receipt view boundary - 🎯 9  🛡️ 10  🧠 6, roughly
    400-1200 LOC/tests.
33. Window and shell boundary - 🎯 8  🛡️ 8  🧠 5, roughly
    300-900 LOC/tests.
34. Export and clipboard boundary - 🎯 9  🛡️ 9  🧠 5, roughly
    300-900 LOC/tests.
35. Preview and design fixture boundary - 🎯 8  🛡️ 8  🧠 4, roughly
    250-700 LOC/tests.
36. Selection, queue, and DeletePlan boundary - 🎯 10  🛡️ 10  🧠 7,
    roughly 600-1600 LOC/tests.
37. Details and metadata enrichment boundary - 🎯 9  🛡️ 9  🧠 6, roughly
    500-1400 LOC/tests.
38. Multi-window and multi-tab boundary - 🎯 9  🛡️ 9  🧠 7, roughly
    700-1800 LOC/tests.
39. Overlay, modal, menu, and focus boundary - 🎯 9  🛡️ 9  🧠 6,
    roughly 400-1200 LOC/tests.
40. Settings, preferences, and policy boundary - 🎯 9  🛡️ 10  🧠 6,
    roughly 500-1300 LOC/tests.
41. Drag and drop boundary - 🎯 8  🛡️ 8  🧠 5, roughly
    300-900 LOC/tests.
42. Notification and toast boundary - 🎯 8  🛡️ 8  🧠 4, roughly
    250-700 LOC/tests.
43. Protocol compatibility UX boundary - 🎯 9  🛡️ 9  🧠 6, roughly
    400-1000 LOC/tests.
44. Bulk action boundary - 🎯 9  🛡️ 10  🧠 7, roughly
    600-1600 LOC/tests.
45. Scroll and viewport restoration boundary - 🎯 8  🛡️ 8  🧠 5,
    roughly 300-900 LOC/tests.
46. Snapshot history and compare boundary - 🎯 10  🛡️ 9  🧠 7,
    roughly 700-1800 LOC/tests.
47. Table column, sort, and filter boundary - 🎯 9  🛡️ 9  🧠 6,
    roughly 500-1400 LOC/tests.
48. Degraded, offline, and daemon unavailable boundary - 🎯 10  🛡️ 10
    🧠 6, roughly 500-1300 LOC/tests.
49. Permission repair flow boundary - 🎯 10  🛡️ 10  🧠 7, roughly
    600-1600 LOC/tests.
50. Startup and hydration boundary - 🎯 9  🛡️ 9  🧠 6, roughly
    400-1100 LOC/tests.
51. Command registry and shortcut boundary - 🎯 9  🛡️ 9  🧠 5,
    roughly 400-1000 LOC/tests.
52. Semantic classification boundary - 🎯 9  🛡️ 9  🧠 7, roughly
    600-1500 LOC/tests.
53. Empty, loading, and partial state boundary - 🎯 8  🛡️ 8  🧠 4,
    roughly 250-700 LOC/tests.
54. Animation and motion boundary - 🎯 7  🛡️ 8  🧠 4, roughly
    200-600 LOC/tests.
55. Time and clock boundary - 🎯 8  🛡️ 8  🧠 4, roughly
    250-700 LOC/tests.

## DTO Boundary

Protocol DTOs are transport contracts, not UI models.

Required flow:

```text
HTTP/WebSocket DTO
  -> data mapper
  -> application model/result
  -> presentation view model
  -> widget props
```

Rules:

- generated or hand-written DTOs stay in `data/dto` or protocol packages;
- widgets and MobX stores do not depend on raw protocol DTOs;
- protocol enums map into application enums with unknown/future-safe handling;
- large counters, ids, cursors, byte sizes, event sequences, and timestamps are
  converted into exact-safe value objects before they reach presentation;
- DTO errors map into typed failures and disabled reasons;
- mappers are tested with old, current, and future-looking fixtures.

Stop if:

- a widget imports `data/dto`;
- a MobX store branches on raw protocol enum strings;
- a raw JSON map reaches presentation;
- web UI relies on JavaScript-safe numeric precision for ids or byte counters.

## Authoritative State Boundary

The frontend renders and orchestrates. It does not own product truth.

Truth ownership:

```text
Rust daemon
  scan tree, indexes, operations, cleanup authority, receipts, capability facts

Application
  workflow state, state machines, command availability, stale/conflict policy

Presentation
  viewport, focus, selection, expansion, input text, hover, layout, visible pages
```

Rules:

- scan tree and indexes stay in Rust;
- operation terminal state is confirmed through query, not only events;
- cleanup authority is `DeletePlan` plus snapshot/identity evidence, not UI
  selection;
- presentation state can be optimistic only when it has pending/synced/conflict
  state;
- stale snapshot and stale plan version are first-class UI states.

Stop if:

- Flutter stores the full tree;
- visible rows become cleanup truth;
- selected path text becomes command authority;
- UI treats optimistic state as final without server reconciliation.

## Command Boundary

Every side effect goes through an application command/use case.

Required flow:

```text
Widget event
  -> MobX store action
  -> Application use case
  -> Application port
  -> Data/platform adapter
```

Rules:

- widgets call callbacks, not services;
- stores call use cases or repositories through application-facing interfaces;
- destructive commands require `ActionAvailability`, `DisabledReason`, and
  current plan/snapshot version;
- `Reveal`, folder picker, permission repair, scan start/cancel, queue add, and
  cleanup execute are all commands;
- command results return typed `CommandState`, not booleans.

Stop if:

- widget imports Dio, WebSocket client, platform plugin, or daemon route path;
- a command is built from `displayPath`;
- a reaction can execute delete/trash/cleanup;
- command retry lacks idempotency key or current version check.

## Design System Boundary

The design system owns reusable interaction primitives. Feature UI owns product
composition.

Design-system primitives:

- `TreeTable`;
- `DiskUsageMapView`;
- status badge;
- issue surface;
- action menu;
- operation footer;
- confirmation dialog;
- receipt/operation timeline;
- responsive split layout;
- shortcut/command surface.

Rules:

- design-system primitives accept view models and callbacks, not repositories or
  stores;
- design-system code does not import feature packages;
- feature code does not fork local versions of missing shared primitives;
- Headless gaps are reported before awkward workarounds;
- visual primitives expose keyboard and semantics contracts, not just paint.

Stop if:

- `packages/design_system` knows about `ScanSessionStore` or protocol DTOs;
- feature widgets duplicate core tree/table/focus/menu behavior locally;
- renderer adapters such as Syncfusion leak into application contracts.

## Event Stream Boundary

WebSocket events are notifications and invalidations. They are not complete
state.

Rules:

- event stream updates stores or invalidates queries;
- terminal operation state is reconciled through HTTP query;
- missed/replayed/out-of-order events are handled by sequence and snapshot
  version;
- progress events are throttled before UI rendering;
- reconnect triggers resync, not blind continuation;
- event handlers are independent from widget lifecycle.

Stop if:

- `StreamBuilder` around the whole app shell drives product state;
- progress events rebuild the full tree/table;
- WebSocket event order is the only proof of operation completion;
- event history grows unbounded in Flutter.

## Persistence Boundary

Flutter persistence is for UI preferences and recoverable convenience state.
Safety-critical operation truth belongs to daemon-owned persistence.

Flutter may persist:

- theme;
- density;
- visible columns;
- last non-sensitive layout;
- non-sensitive recent target display aliases when policy allows;
- UI-only feature flags and onboarding completion.

Flutter must not persist:

- daemon auth token in ordinary preferences;
- cleanup confirmation tokens;
- operation journal truth;
- receipt truth;
- full scan tree;
- raw support bundle payloads;
- broad raw path history by default.

Rules:

- Rust/daemon owns operation journal and destructive receipts;
- Flutter can cache pages only as disposable cache with snapshot version;
- persisted values have schema/version and migration policy;
- support export uses redaction rules before leaving local machine.

Stop if:

- cleanup can run when daemon journal cannot be written;
- Flutter local storage is the only copy of operation state;
- UI preferences contain tokens or sensitive raw path sets.

## Platform Action Boundary

Native/platform actions are ports and adapters, not widget imports.

Platform actions include:

- folder picker;
- reveal in Finder/Explorer/file manager;
- open permissions pane;
- request/repair permission flow;
- open URL/file;
- system notifications;
- native menus and shortcuts;
- app update prompt.

Rules:

- widgets call feature/application commands;
- platform implementations live behind ports/adapters;
- platform action result is typed, cancelable, and recoverable;
- native dialog focus recovery is explicit;
- web, desktop, and future remote modes can expose different capability results.

Stop if:

- feature widgets import platform plugin packages directly;
- platform action availability is guessed from OS name only;
- native dialog cancel leaves focus or command state inconsistent.

## Accessibility And Keyboard Boundary

Accessibility is a product contract, not a decoration pass.

Rules:

- focus, selection, expansion, queued, checked, hover, and details selection are
  distinct states;
- tree/table supports keyboard navigation and roving focus;
- actions are reachable without hover;
- icon-only controls have labels and tooltips;
- screen-reader semantics expose row level, expansion, size, percent, warning,
  queued state, and available actions where practical;
- visual map views have table/list equivalents;
- shortcuts are platform-aware and do not override text-field/system behavior.

Stop if:

- mouse-only workflow can queue or confirm cleanup;
- selected row and queued-for-delete state look identical;
- visual map is the only way to access a cleanup candidate;
- focus can remain on an unmounted virtual row.

## Responsive Layout Boundary

Wide and compact layouts are two shells over one state model, not two products.

Rules:

- state stores are shared between wide and compact layouts;
- layout chooses panel placement, not data ownership;
- compact layout can collapse details/queue, but not hide safety states;
- bottom progress/status remains visible enough during active scan;
- long paths/names use ellipsis and details, not variable-height main rows;
- breakpoints are design-system constants, not scattered magic numbers.

Stop if:

- desktop and compact layouts have separate selection or queue stores;
- compact layout skips confirmation/details required for safety;
- layout switch resets scan session or cleanup queue.

## Error And Capability Boundary

The UI does not guess what is possible. It renders capability and command
availability.

Rules:

- UI uses `CapabilitySnapshot`, `ActionAvailability`, `DisabledReason`, and
  `ScanQuality` from application/daemon contracts;
- disabled controls expose specific reason and recovery path;
- permission quality is probed by the scanner process identity;
- skipped/protected/partial results are first-class states;
- unknown capability disables risky actions by default.

Stop if:

- UI enables cleanup because a button is visible;
- UI guesses permission from OS or path string;
- partial scan looks identical to complete scan;
- unknown protocol/capability value is treated as fully supported.

## Route And Navigation Boundary

Routes identify views and selected resources. They do not carry authority.

Rules:

- route parameters can contain scan/session/view ids, not raw delete authority;
- opening a deep link triggers capability/session validation;
- route restore after restart marks stale or unavailable objects honestly;
- route changes call store/use case methods, not raw repositories;
- browser history on web does not replay destructive commands.

Stop if:

- URL contains daemon token, cleanup confirmation token, or raw sensitive paths;
- back/forward can re-execute a command;
- stale route silently selects a different filesystem object.

## Formatting And Localization Boundary

Formatting is presentation work. Domain and application expose facts, not final
display copy.

Required flow:

```text
Application value object
  -> presentation formatter
  -> localized display string
  -> widget
```

Rules:

- user-facing strings come from the shared localization package;
- bytes, percentages, dates, durations, counts, and plural messages use shared
  formatters;
- domain/application code stores stable facts, enums, and value objects;
- widgets do not hand-roll byte formatting or plural text;
- locale-specific sorting is query/display policy, not filesystem identity.

Stop if:

- domain/application imports localization package;
- widgets concatenate plural/user-facing messages manually;
- display strings are used as command identifiers;
- localized labels are used for sorting authoritative data.

## Design Tokens And Theme Boundary

Feature UI must not invent visual constants.

Rules:

- colors, spacing, typography, radius, row height, focus rings, breakpoints, and
  density values come from `packages/design_system`;
- feature widgets can choose product layout, not raw palette values;
- design tokens support dark and light themes;
- platform-specific visual differences are exposed as tokens or primitives;
- table rows, icon buttons, status badges, and progress elements use stable
  dimensions.

Stop if:

- feature widgets introduce raw colors, random radius values, or layout magic
  numbers;
- compact/wide breakpoints are scattered outside design-system constants;
- row height changes because of ad hoc styling.

## Async Lifecycle Boundary

Widget lifecycle, store lifecycle, scan session lifecycle, and daemon operation
lifecycle are separate.

Rules:

- route close does not cancel scan unless user intent says so;
- screen dispose cleans subscriptions/reactions, not daemon operation truth;
- stores expose explicit `dispose`;
- scan session dispose is an application command;
- cleanup operation lifecycle is daemon-owned and reconciled after reconnect;
- native dialog lifecycle restores focus without mutating command truth.

Stop if:

- closing a screen silently cancels a scan;
- a widget `dispose` sends destructive or cleanup commands;
- a lost WebSocket subscription loses operation truth;
- route rebuild restarts HTTP queries or daemon operations.

## Input Intent Boundary

Raw input becomes typed user intent before it becomes a command.

Required flow:

```text
Raw pointer / keyboard / text input
  -> UserIntent
  -> store action
  -> use case command
```

Rules:

- keyboard shortcuts map to typed command intents;
- text input changes are separate from committed search query;
- `Delete`, `Enter`, `Space`, and context menu actions are scoped by focus
  region;
- multi-select range/checkbox state is represented explicitly;
- raw events never call repositories or platform plugins.

Stop if:

- key handlers execute cleanup directly;
- search query starts network work on every build;
- text field state becomes command state without validation.

## Feature Module Boundary

Feature packages do not import each other directly.

Rules:

- cross-feature communication goes through shared contracts, application ports,
  or app composition;
- `features/scan` does not import future cleanup/recommendation/settings
  feature implementations;
- common models move to shared packages only when they are truly cross-feature;
- route composition belongs to `apps/clean_disk`.

Stop if:

- `features/scan` imports another feature package for convenience;
- feature modules share stores directly;
- app routing decisions move into feature packages.

## DI And Composition Boundary

Dependency injection is composition, not business logic.

Rules:

- `GetIt` and Modularity wiring live in `di` or app bootstrap;
- stores, use cases, repositories, and adapters receive dependencies through
  constructors;
- factories are registered at module boundaries;
- test code can replace ports/adapters without global mutation.

Stop if:

- production code calls `GetIt.I.get()` inside use cases, repositories, stores,
  or widgets;
- feature code reaches into app composition for dependencies;
- hidden service locators make boundary tests impossible.

## Error Taxonomy Boundary

Technical failures must become typed application failures and user-facing
states.

Required flow:

```text
Exception / transport error
  -> AppFailure / typed issue
  -> application state
  -> user-facing view state
```

Rules:

- UI does not render raw exceptions;
- daemon disconnected, permission denied, stale snapshot, partial scan,
  unsupported action, timeout, and conflict are distinct states;
- disabled actions expose typed reasons and recovery hints;
- logs may include diagnostic codes but not sensitive raw paths by default.

Stop if:

- widgets branch on exception classes;
- all failures become generic error text;
- permission and stale-snapshot failures are visually indistinguishable.

## Observability And Telemetry Boundary

Observability data is classified before it leaves a component.

Rules:

- frontend logs use event ids, state names, counters, and redacted references;
- raw paths, search text, node names, tokens, and delete targets are not logged
  by default;
- telemetry is off or minimal by default until explicit policy is accepted;
- support bundles use redaction profiles and preview before export;
- metrics avoid high-cardinality path/user/query labels.

Stop if:

- UI analytics include raw paths or search strings;
- logs become the only evidence for a destructive operation;
- support export includes unredacted state by default.

## Performance Budget Boundary

Frontend performance budgets are product contracts.

Initial budgets:

- progress UI updates are throttled;
- visible row window is bounded;
- page size is capped by measured web/desktop parse and render cost;
- map tile projection is capped;
- tree/table does not rebuild on every progress event;
- search/filter/sort results are paginated from Rust;
- JSON payloads stay small enough for Flutter web main-thread parsing.

Stop if:

- a progress event rebuilds the page shell or tree;
- full scan data is parsed in Flutter web;
- tile or row count is unbounded;
- performance depends on debug-mode behavior.

## Generated Code Boundary

Generated code is an artifact, not a design surface.

Rules:

- generated localization, MobX, JSON, OpenAPI, or bridge files are not edited by
  hand;
- generated DTO/client code does not become application model;
- generated code is wrapped by adapters where needed;
- generator version and output are reviewed when dependencies change.

Stop if:

- application imports generated transport models directly;
- a manual patch is applied to generated code;
- generator output changes API boundaries without review.

## Asset And Icon Boundary

Assets and icons are part of the design system contract.

Rules:

- feature UI uses design-system icons/assets facade where available;
- platform/file/warning/status icons are centralized;
- raw asset paths are not scattered through features;
- decorative assets do not carry product meaning alone;
- missing asset fallback is explicit.

Stop if:

- feature widgets reference random SVG/PNG paths;
- status meaning depends only on color or an unlabeled icon;
- platform icons are duplicated across features.

## Testing Boundary

Tests follow architecture layers.

Required test groups:

- application state-machine tests;
- DTO mapper tests;
- MobX store tests with fake use cases;
- widget tests for feature screens;
- design-system primitive tests;
- golden tests for wide/compact layouts;
- accessibility and keyboard tests;
- performance smoke tests;
- boundary import tests.

Stop if:

- all behavior is tested only through golden/widget tests;
- use cases require Flutter test harness;
- boundary regressions are detectable only by manual review.

## Feature Flag And Capability Flag Boundary

Feature flags can reveal UI, but capabilities still decide safety.

Rules:

- flags do not bypass `ActionAvailability`;
- risky actions require daemon capability and current policy;
- unknown flag/capability values fail closed;
- remote/headless flags cannot enable destructive cleanup without authority
  gates.

Stop if:

- feature flag alone enables cleanup;
- hidden UI route can execute unsupported command;
- flag state is treated as platform capability.

## Path Display Boundary

Path text is display only, never authority.

Rules:

- display paths use bidi-safe and control-character-aware rendering;
- home shortening is a display transform only;
- copy path actions follow privacy/redaction policy;
- path text in confirmations is paired with stable node/snapshot identity;
- suspicious characters can be surfaced in details/confirmation.

Stop if:

- display path is used as delete target authority;
- bidi/control characters can spoof confirmation text;
- copied paths leak into logs/telemetry.

## View Model Granularity Boundary

Widgets receive compact view models, not raw application or protocol models.

Required examples:

```text
TreeRowViewModel
NodeDetailsViewModel
CleanupQueueItemViewModel
StatusBadgeViewModel
OperationFooterViewModel
DiskUsageMapTileViewModel
```

Rules:

- view models contain display-ready fields and stable ids;
- view models do not expose repositories, DTOs, or domain invariants;
- row/tile view models are cheap to compare and rebuild;
- view model creation is tested separately from widgets where logic exists.

Stop if:

- widgets branch on domain internals or protocol enum strings;
- one giant page view model drives every reactive subtree;
- view model includes full child trees or unbounded lists.

## Target Runtime Boundary

Desktop and web share product UI, but they do not share platform authority.

Runtime modes:

```text
Desktop app
  -> app shell
  -> local daemon / bundled helper / native platform adapters

Web UI
  -> daemon transport adapter
  -> no browser-side full disk scan
```

Rules:

- feature packages do not import `dart:io`, desktop window APIs, native process
  APIs, or platform plugins directly;
- desktop-only capabilities are exposed through application ports and
  capability snapshots;
- web UI talks to disk scanner functionality through daemon transport;
- app shell chooses runtime adapters based on target and capability, not
  feature widgets;
- runtime-specific code is isolated in app composition or data/platform
  adapters.

Stop if:

- a feature widget imports a desktop-only package;
- web build depends on `dart:io` or platform plugin APIs;
- product behavior is branched by raw platform checks inside widgets;
- browser filesystem APIs are treated as a replacement for daemon scanning.

## Daemon Session And Auth Boundary

The frontend does not own daemon authority. It holds a bounded session to a
specific daemon capability surface.

Rules:

- daemon base URL, local port, pairing state, and session token are adapter
  concerns;
- session token is never stored as ordinary UI preference, route parameter,
  log field, telemetry field, or support bundle default;
- reconnect validates daemon identity and session freshness before resuming
  commands;
- query reconnect can recover read state, but destructive authority must still
  pass current capability, policy, and plan validation;
- multi-tab or multi-window clients have explicit session ownership and
  conflict behavior.

Stop if:

- widgets or stores concatenate daemon URLs;
- session token appears in route, logs, copied text, or crash reports;
- reconnect silently restores destructive authority;
- a stale daemon session can execute cleanup after daemon restart or update.

## Query Cache And Invalidation Boundary

Flutter may cache query pages for responsiveness. It must not turn cached pages
into product truth.

Cache keys include:

```text
SessionId
SnapshotId
ProjectionId
QueryKey
PageCursor
SortKey
FilterKey
LocaleKey when display formatting affects ordering
```

Rules:

- tree pages, search results, top lists, map projections, and details queries
  have separate cache keys;
- cached pages carry snapshot/version and freshness state;
- WebSocket events invalidate or mark stale, then stores reconcile through
  queries;
- cache entries are bounded by count, bytes, and lifecycle;
- cached page data cannot be used as cleanup authority.

Stop if:

- stale cached rows can be added to a cleanup plan without revalidation;
- search cache, tree cache, and selected details share one mutable object;
- event handler mutates cached truth without version checks;
- cache grows with every scanned node or every search string forever.

## Virtualized Row Identity Boundary

Large tree UI must assume rows are recycled and visible indexes are unstable.

Rules:

- selection, expansion, focus, details selection, queued state, hover, and
  context menu target use `NodeRef` plus `SnapshotId`, not row index;
- visible row index is a rendering coordinate only;
- recycled row widgets receive complete view models and retain no durable row
  state;
- focus restoration handles missing, stale, collapsed, and filtered-out nodes;
- row actions always carry stable identity and current version evidence.

Stop if:

- row index is used for cleanup, details, expansion, or selection authority;
- recycled widgets keep old node state after virtualization reuse;
- focus remains on an unmounted row without a fallback target;
- sorting/filtering can cause action menus to act on the wrong node.

## Confirmation Surface Boundary

Confirmation UI is a safety surface over a validated plan, not a generic modal.

Rules:

- cleanup confirmation renders a current `DeletePlan` or equivalent
  application model;
- confirmation shows selected identity evidence, display path, size/reclaim
  confidence, warnings, and irreversible limitations where applicable;
- compact layout cannot hide safety warnings, stale state, or required
  acknowledgement;
- confirm button is disabled when plan version, snapshot, capability, or
  policy is stale;
- confirmation copy comes from localization and never uses display labels as
  command identity.

Stop if:

- modal confirms a list of display paths instead of a validated plan;
- stale plan can still enable `Move to Trash`;
- compact layout drops warnings to save space;
- visible selected rows are treated as equivalent to confirmed delete intent.

## Selection, Queue, And DeletePlan Boundary

Selection, cleanup queue, and delete authority are three different states.

State ownership:

```text
Selection
  transient presentation intent

CleanupQueue
  user-curated review set scoped to snapshot/version

DeletePlan
  validated application/daemon authority for destructive execution
```

Rules:

- selecting a row never creates delete authority;
- adding to cleanup queue stores `NodeRef`, `SnapshotId`, risk state, and
  review intent, not only display path;
- cleanup queue can become stale and must expose stale/conflict status;
- `DeletePlan` is created through application use case and daemon validation;
- removing an item from queue invalidates any plan that included it;
- queue totals are estimates until plan/preflight returns current evidence.

Stop if:

- selected rows can be deleted directly;
- cleanup queue item is identified only by display path or visible row index;
- stale queue item can remain silently actionable;
- `DeletePlan` is built in a widget or from local UI cache only.

## Bulk Action Boundary

Bulk actions are explicit user intents with scope, not shortcuts over visible
rows.

Bulk scopes:

```text
VisibleRows
ExpandedSubtree
CurrentFolderChildren
FilteredResultsPage
AllMatchingQuery
ExplicitQueue
```

Rules:

- `Select visible`, `select subtree`, and `select all matching query` are
  separate intents with different confirmation copy;
- bulk operations carry query/filter/sort/snapshot evidence;
- bulk add-to-queue returns count, skipped, conflict, and too-broad warnings;
- destructive bulk execution still requires validated `DeletePlan`;
- broad bulk actions require review surface before confirmation.

Stop if:

- `select all` is ambiguous;
- filter changes silently change the meaning of selected bulk intent;
- selecting all visible rows is treated as selecting all matching results;
- bulk cleanup runs without explicit scope and current snapshot evidence.

## Details And Metadata Enrichment Boundary

Details pane enriches the selected node lazily. It is not the scanner or the
delete authority.

Rules:

- hover does not trigger expensive metadata enrichment;
- selection can request bounded details with cancel/replace behavior;
- details state supports loading, partial, stale, unavailable, and permission
  denied;
- details requests are keyed by `NodeRef`, `SnapshotId`, and metadata profile;
- details pane can display warnings but cannot upgrade cleanup authority;
- expensive metadata is cached with TTL/version and invalidated by snapshot or
  filesystem identity changes.

Stop if:

- every row render or hover starts a metadata request;
- details panel becomes the only source of permission/delete truth;
- stale details are shown as current without badge/state;
- details cache grows with every selected node forever.

## Scroll And Viewport Restoration Boundary

Scroll position is presentation state. It must not become row identity or
action authority.

Rules:

- restore scroll by stable anchor such as `NodeRef` plus relative offset where
  possible, not only pixel offset;
- if anchor is missing, stale, filtered out, or collapsed, restore to nearest
  safe parent or top visible result;
- viewport restoration never triggers destructive commands;
- layout density/theme changes can invalidate pixel restoration;
- wide and compact layouts restore equivalent intent, not identical pixels.

Stop if:

- pixel offset or row index is used as selected node identity;
- sorting/filtering causes restored viewport actions to hit a different node;
- route restore silently selects a stale node as actionable;
- compact/wide switch loses safety-critical selection/queue state.

## Overlay, Modal, Menu, And Focus Boundary

Overlays are temporary surfaces over a stable command target. They do not own
the target identity.

Rules:

- context menus, popovers, command palette, tooltips, and modals receive an
  explicit target identity or command scope;
- overlay close restores focus to a valid fallback when the original row is
  unmounted or stale;
- confirmation modals trap focus but do not mutate product truth on dispose;
- keyboard shortcuts respect active text field, modal, menu, and table focus
  scopes;
- overlays use the same command availability model as visible buttons.

Stop if:

- context menu acts on whatever row is currently under the recycled widget;
- closing modal changes cleanup authority;
- keyboard shortcut bypasses disabled reason or confirmation;
- focus is lost after native/dialog/overlay lifecycle.

## Multi-Window And Multi-Tab Boundary

Multiple clients may observe the same daemon, but product truth still belongs
to daemon/application contracts.

Rules:

- each window/tab has a client id and explicit session attachment state;
- active scan ownership, shared observation, and cancel authority are modeled
  separately;
- cleanup queue and confirmation state are scoped to client/session unless an
  explicit shared workflow is designed;
- one client cannot execute a stale plan created by another client without
  revalidation;
- reconnect and visibility changes reconcile current daemon state before
  enabling risky commands.

Stop if:

- two tabs can both execute conflicting cleanup from stale local queues;
- closing one window cancels a scan owned by another client without policy;
- shared daemon state is inferred from local store memory;
- multi-window behavior depends on whichever event arrived last.

## Settings, Preferences, And Policy Boundary

Preferences may change appearance and convenience. They must not silently
weaken safety policy.

Rules:

- theme, density, visible columns, default sort, and layout preferences are UI
  preferences;
- cleanup safety, confirmation requirements, remote destructive authority,
  redaction profile, and telemetry policy are explicit policy objects;
- policy changes require current capability and, where risky, explicit
  acknowledgement;
- preferences are versioned and migrated independently from safety policy;
- unsupported or unknown policy values fail closed.

Stop if:

- a normal setting disables cleanup confirmation globally;
- feature flag or preference bypasses `ActionAvailability`;
- policy is stored only in Flutter UI preferences;
- remote/headless destructive behavior is enabled by local UI setting alone.

## Drag And Drop Boundary

Drag and drop creates typed user intent. It does not create trusted filesystem
authority by itself.

Rules:

- dropped files/folders become `ScanTargetIntent` or import intent through an
  application use case;
- dropped paths are normalized and capability-checked by platform/daemon
  adapters before scan;
- web, desktop, and remote modes expose different drag/drop capabilities;
- dropping into cleanup queue is disabled until delete-plan semantics are
  explicitly designed;
- drag feedback is visual only and not command truth.

Stop if:

- raw dropped path starts scan or cleanup directly from widget code;
- web drag/drop is treated as full disk permission;
- dropped item bypasses target validation or mount/policy checks;
- drag hover mutates durable queue state.

## Notification And Toast Boundary

Notifications and toasts are user feedback. They are not operation truth.

Rules:

- operation completion toast appears only after reconciled operation state or
  receipt confirmation;
- notifications include action intents that route through normal command
  boundary;
- transient feedback cannot replace details, receipt, or error surfaces;
- notification permission is a platform capability;
- toasts avoid raw paths and sensitive names unless policy allows display.

Stop if:

- toast says cleanup succeeded before daemon receipt/query confirms it;
- notification action executes a different command path than the UI;
- error toast is the only durable evidence for a failed cleanup;
- sensitive paths leak into system notifications by default.

## Protocol Compatibility UX Boundary

Version mismatch is a product state, not a generic error.

Rules:

- UI checks daemon protocol version, schema compatibility, and capability
  snapshot before enabling product workflows;
- unknown enum/capability values fail closed for risky actions and display
  recoverable unsupported state;
- incompatible daemon/UI versions show update, restart, or reconnect paths;
- partial compatibility can allow read-only views while blocking cleanup;
- generated clients and DTO mappers keep unknown/future fields from crashing
  presentation.

Stop if:

- UI guesses behavior from unknown protocol values;
- incompatible daemon still allows cleanup;
- version mismatch is shown as generic network failure;
- frontend ignores daemon compatibility manifest.

## Degraded, Offline, And Daemon Unavailable Boundary

Daemon availability is a product state. A disconnected UI can remain useful,
but it cannot pretend to have live authority.

States:

```text
Connecting
Connected
Reconnecting
DaemonUnavailable
DaemonRestarting
DaemonUpdated
ProtocolIncompatible
SessionExpired
ReadOnlyStale
```

Rules:

- risky actions are disabled when daemon/session/capability state is unknown or
  unavailable;
- read-only cached views are visibly stale and scoped to snapshot/version;
- reconnect flows through session and compatibility validation before commands
  resume;
- daemon restart/update invalidates operation assumptions and capability
  snapshots;
- degraded UI exposes recovery actions without losing local presentation state.

Stop if:

- disconnected UI shows cleanup as available;
- stale cached data looks live;
- reconnect resumes destructive commands without session/capability validation;
- daemon unavailable is rendered as generic empty state.

## Startup And Hydration Boundary

App startup hydrates UI state in stages. It must not revive old authority before
validation.

Hydration order:

```text
App config
  -> local UI preferences
  -> route state
  -> daemon discovery
  -> session validation
  -> protocol compatibility
  -> capability snapshot
  -> optional cached read-only views
```

Rules:

- route restore can select a view, but cannot restore destructive authority;
- stale scan/session/query cache starts read-only until daemon validates it;
- hydration failures are typed states, not startup crashes;
- startup does not block basic shell rendering on slow daemon discovery;
- persisted UI preferences are migrated before use.

Stop if:

- restored route enables cleanup before daemon validation;
- old query cache is displayed as current without stale marker;
- startup assumes daemon port/token from a previous run is still valid;
- failed preference migration crashes the product shell.

## Permission Repair Flow Boundary

Permission repair is a loop with evidence. It is not a button that says
"fixed".

Required flow:

```text
Capability probe
  -> user-facing repair action
  -> platform/native guidance
  -> re-probe from scanner process identity
  -> updated ScanQuality / CapabilitySnapshot
```

Rules:

- repair UI renders scanner-process capability evidence, not OS guesses;
- after opening platform settings or help, scanner identity must re-probe;
- partial access, skipped paths, denied paths, and protected roots stay visible;
- repair actions are platform adapters behind application ports;
- permission state is scoped to target, process identity, and runtime mode.

Stop if:

- UI marks permission repaired before re-probe;
- repair logic branches only on OS name or path prefix;
- permission denied and partial scan are collapsed into generic error;
- platform settings button mutates capability state directly.

## Snapshot History And Compare Boundary

History and compare are projections over explicit snapshots. They are not the
live scan tree.

Snapshot types:

```text
CurrentSnapshot
HistoricalSnapshot
DiffSnapshot
CompareProjection
```

Rules:

- every historical row carries source snapshot identity;
- compare rows distinguish added, removed, changed, unchanged, stale, and
  unavailable nodes;
- current live selection cannot silently operate on historical nodes;
- history storage and retention follow privacy and size policy;
- compare projections are bounded and paginated like live tree queries.

Stop if:

- compare UI mixes nodes from different snapshots without explicit ids;
- historical row can be queued for cleanup as if it were current;
- diff result is generated from display path text alone;
- old snapshots bypass current capability and identity validation.

## Table Column, Sort, And Filter Boundary

Table configuration is UI preference. Query semantics are application/Rust
contracts.

Rules:

- column visibility, order, width, and density are UI preferences;
- sort/filter/query models are typed application objects;
- Rust/server side owns sorting/filtering for large result sets;
- client-side sort is allowed only for bounded visible pages and must be marked
  as local presentation ordering;
- changing filters invalidates bulk scope, cached pages, and selected details
  where relevant.

Stop if:

- Flutter sorts or filters the full scan tree;
- column label text becomes sort key or protocol field name;
- filter change silently changes bulk action scope;
- table column preference mutates query authority.

## Command Registry And Shortcut Boundary

All commands should have one registry surface for UI buttons, menus, shortcuts,
and command palette entries.

Rules:

- command definitions include id, label key, shortcut, scope, availability,
  disabled reason, and execution handler reference;
- visible buttons, native menu items, command palette entries, and shortcuts use
  the same command availability model;
- shortcuts are scoped by focus region and never bypass modal/confirmation
  state;
- destructive commands require current plan/version evidence even when invoked
  by shortcut;
- command ids are stable product identifiers, not localized labels.

Stop if:

- shortcut executes a different path than button/menu;
- command palette invokes disabled or hidden destructive command;
- localized label is used as command id;
- keyboard shortcut bypasses current focus or confirmation scope.

## Semantic Classification Boundary

UI displays classifications. It does not decide that a folder is safe cache by
name.

Rules:

- cache, build artifact, developer tool storage, app data, cloud placeholder,
  system protected, and unknown classifications come from rule engine,
  daemon evidence, or application model;
- classification includes confidence, source, version, and explanation;
- unknown classification is conservative and does not imply cleanup safety;
- UI can filter by classification but cannot create product classification
  facts;
- classification labels are localized display strings over stable codes.

Stop if:

- widget decides cleanup category from folder name;
- unknown category is treated as safe cache;
- classification rule version is missing from recommendation/queue evidence;
- localized category label becomes policy or command identity.

## Empty, Loading, And Partial State Boundary

Absence of rows can mean many different things. The UI must say which one.

States:

```text
NotStarted
Loading
EmptyTarget
NoResultsForFilter
PartialScan
PermissionLimited
Cancelled
Failed
Stale
ReadOnlyUnavailable
```

Rules:

- empty, filtered-empty, loading, partial, failed, cancelled, and stale states
  use distinct view models;
- partial scan state preserves skipped/error counts and recovery actions;
- skeleton/loading UI cannot hide permission or compatibility warnings;
- empty states do not offer cleanup commands unless capability says they are
  meaningful;
- states are test fixtures, not ad hoc widget branches.

Stop if:

- daemon unavailable, no results, and permission denied share one empty screen;
- partial scan looks complete;
- loading skeleton covers critical warnings;
- cancelled scan appears as successful empty result.

## Animation And Motion Boundary

Motion supports comprehension. It must not affect safety, layout truth, or
accessibility.

Rules:

- reduced motion disables nonessential animation;
- row height, hit target, and warning visibility do not depend on animation
  frame;
- animated transitions cannot hide stale, destructive, or permission states;
- progress animation is visual only and does not represent exact scan truth;
- motion tokens live in design system.

Stop if:

- animation changes action target geometry during click/keyboard activation;
- warning or confirmation appears only after animation completes;
- reduced motion user still gets distracting nonessential animation;
- progress animation is treated as operation completion evidence.

## Time And Clock Boundary

Different time facts have different clocks.

Time facts:

```text
Elapsed scan time
  monotonic timer

Filesystem modified time
  filesystem timestamp

Event ordering
  daemon sequence

Receipt time
  daemon operation journal timestamp
```

Rules:

- elapsed duration uses monotonic clock semantics;
- event order uses sequence/version, not wall-clock time;
- modified/created/accessed timestamps are displayed with locale/timezone
  formatting and uncertainty when unavailable;
- receipt time comes from daemon operation journal;
- tests can inject clocks for application state machines and presentation
  formatters.

Stop if:

- wall-clock time is used to order daemon events;
- modified time is used as identity or freshness proof;
- scan elapsed time jumps because system clock changes;
- receipt/order display depends only on Flutter local clock.

## Frontend Scheduler Boundary

The frontend schedules rendering and queries deliberately. Incoming events do
not decide rebuild cost.

Work lanes:

```text
User input lane
Progress render lane
Visible page query lane
Background refresh lane
Expensive projection lane
```

Rules:

- user input stays responsive during scan, reconnect, and large query parsing;
- progress updates are throttled and coalesced before presentation;
- expensive projections such as treemap tiles run behind explicit request and
  page/size limits;
- search typing, committed search, and server query are separate states;
- scheduler policy is testable without relying on debug-mode timing.

Stop if:

- progress or event stream can starve input handling;
- typing search triggers unbounded daemon queries;
- one store reaction rebuilds unrelated panes for every event;
- UI smoothness depends on machine speed rather than budgets.

## Undo And Receipt View Boundary

The UI may present undo or restore only when daemon receipts prove the operation
supports it.

Rules:

- receipt truth belongs to daemon-owned operation journal;
- UI receipt views render receipt DTO/application models, not local optimistic
  assumptions;
- restore/undo button availability comes from receipt capability and platform
  policy;
- partial cleanup results show per-item outcome and recovery state;
- history views tolerate missing, expired, redacted, or incompatible receipts.

Stop if:

- UI says undo is available without receipt-backed capability;
- optimistic cleanup success creates a receipt in Flutter only;
- partial failure is collapsed into a single success/failure toast;
- restore action uses old display path as authority.

## Window And Shell Boundary

Native shell behavior belongs to `apps/clean_disk`, not feature packages.

Shell-owned concerns:

- window size and placement;
- title and native menu;
- tray/dock/taskbar integration;
- app quit behavior;
- update prompt;
- lifecycle events;
- top-level shortcuts.

Rules:

- feature packages expose product intents and pages;
- app shell maps native lifecycle to application/session commands;
- quit/close behavior respects active scan and cleanup operation state;
- native menus call the same command/use-case path as visible buttons.

Stop if:

- feature package owns window APIs;
- closing the window bypasses active operation checks;
- native menu executes a different command path than UI controls;
- app shell state leaks into feature stores.

## Export And Clipboard Boundary

Exporting and copying are data exfiltration surfaces, not harmless UI actions.

Rules:

- copy path, copy report, export CSV/JSON, screenshot, and support bundle use
  explicit export profiles;
- raw paths, search text, node names, token-like values, and delete targets are
  redacted unless the selected export profile allows them;
- clipboard actions show or log only redacted evidence by default;
- export payloads include schema/version and source snapshot id;
- user-facing export preview is required before broad sensitive exports.

Stop if:

- clipboard/export uses raw app state without redaction policy;
- support bundle includes full scan tree by default;
- export lacks schema/version and snapshot provenance;
- copied text can include daemon token or confirmation token.

## Preview And Design Fixture Boundary

Previews, goldens, and design fixtures must be deterministic and privacy-safe.

Rules:

- widget previews use synthetic fixtures, not local user paths or real scan
  results;
- fixtures cover wide, compact, loading, stale, partial, error, empty, long
  path, bidi/control-character, and large-count states;
- generated reference fixtures are versioned separately from live daemon data;
- preview-only adapters cannot enter production composition.

Stop if:

- a preview reads the local filesystem;
- golden fixtures contain real user paths;
- design fixture models become product protocol models;
- preview code imports production daemon adapters.

## Testing Gates

Frontend boundary compliance requires:

- mapper tests from DTO fixtures to application models;
- store tests with fake use cases and no widgets;
- widget tests proving widgets do not own durable state;
- fake event stream tests for missed, duplicate, out-of-order, and terminal
  events;
- command tests for stale snapshot, disabled reason, idempotency, and conflict;
- design-system tests for tree/table focus, semantics, action menu, and compact
  layout;
- persistence tests proving sensitive states are not stored by Flutter;
- web-specific tests for large numeric DTOs and route/history behavior;
- runtime boundary tests proving web-safe packages do not import desktop-only
  APIs;
- cache invalidation tests for stale snapshot, stale page, search cache, and
  reconnect;
- virtualization tests proving row index is never action authority;
- confirmation tests proving stale plans disable destructive actions;
- selection/queue/DeletePlan tests proving selection and queue are not delete
  authority;
- bulk action tests for visible, subtree, filtered page, and all matching
  scopes;
- metadata details tests for lazy loading, cancellation, stale, partial, and
  permission states;
- multi-window tests for stale plan, shared scan observation, reconnect, and
  cancel authority;
- focus/overlay tests for context menu target identity and modal lifecycle;
- settings/policy tests proving preferences cannot weaken safety policy;
- drag/drop tests proving dropped paths are normalized and validated before
  scan;
- notification/toast tests proving feedback is reconciled with operation truth;
- protocol compatibility UX tests for older, current, newer, and incompatible
  daemon manifests;
- scroll restoration tests proving anchors are stable and row index is not
  authority;
- degraded/offline tests proving risky actions fail closed while read-only
  stale views remain honest;
- startup hydration tests proving routes/cache/preferences do not restore
  destructive authority before validation;
- permission repair tests proving repair requires scanner identity re-probe;
- snapshot history and compare tests proving snapshot ids do not mix;
- table sort/filter tests proving large queries stay server-side and bulk scope
  invalidates correctly;
- command registry tests proving buttons, menus, shortcuts, and command palette
  share availability;
- semantic classification tests proving UI never classifies cleanup safety by
  display name;
- empty/loading/partial state tests proving states are distinct;
- motion tests proving reduced motion and safety visibility;
- time/clock tests proving event order and elapsed time do not rely on wall
  clock;
- export and clipboard tests proving redaction policies are applied.

## Stop Rules

Stop implementation and revisit the boundary if:

- a lower-level layer imports a higher-level layer for convenience;
- DTOs, repositories, or platform plugins appear in widgets;
- MobX annotations appear outside presentation stores;
- design-system primitives know product workflows;
- UI becomes source of truth for scan/delete/operation;
- a command can execute from visible rows, path text, or route params alone;
- Flutter cache is required for safety-critical recovery;
- a renderer adapter changes application contracts;
- web UI imports desktop/runtime-only APIs;
- daemon token or destructive authority leaks into route, log, clipboard, or
  support bundle;
- stale cached page, virtualized row index, or preview fixture can become
  cleanup authority;
- confirmation UI can execute cleanup without current plan validation.
- selection, queue, details, bulk action, drag/drop, notification, or restored
  viewport state can become destructive authority;
- settings or feature flags can weaken cleanup safety policy;
- incompatible daemon/frontend protocol still enables risky commands;
- multi-window behavior allows stale plan execution or hidden scan
  cancellation.
- disconnected/degraded UI enables risky actions or shows stale data as live;
- startup hydration restores route/cache/session as authority before daemon
  validation;
- permission repair is marked fixed without scanner identity re-probe;
- history/compare mixes snapshots or treats historical nodes as current cleanup
  targets;
- Flutter sorts/filters unbounded scan results or table labels become protocol
  keys;
- UI classifies cleanup safety from folder names instead of evidence;
- wall-clock time is used for event ordering or receipt truth.

## Final Decision

Use strict frontend boundaries:

```text
DTOs map inward.
Commands flow through use cases.
Events invalidate and reconcile.
Design system renders primitives.
Stores orchestrate presentation.
Daemon owns truth.
Runtime adapters own platform authority.
Confirmation surfaces render validated plans.
Selection is not queue.
Queue is not DeletePlan.
Feedback is not receipt.
Disconnected is not authorized.
History is not current state.
Labels are not protocol keys.
```

These boundaries keep the Flutter app replaceable, testable, responsive, and
safe enough for a disk utility that can later perform destructive cleanup.
