# Architecture Decisions

Last updated: 2026-05-16.

This document records decisions already accepted for Clean Disk. Open questions are tracked separately and are not implementation instructions.

## Accepted Decisions

### Workspace Shape

- The workspace is Flutter/Dart with `apps`, `features`, and `packages`.
- The only runnable Flutter app is `apps/clean_disk`.
- `apps/clean_disk` is the app shell and composition root.
- Feature code lives under `features/*`.
- Shared reusable code lives under `packages/*`.

### Application Architecture

- The architecture is Clean Architecture + Hexagonal Ports and Adapters + simple DDD.
- Feature packages follow `domain`, `application`, `data`, `presentation`, and `di` layers.
- `domain` is framework-free and must not know Flutter, Rust bridge code, pdu, Dio, Drift, MobX, GetIt, Modularity, or design-system UI.
- Application ports belong to `application`, not `domain`.
- Concrete adapters are chosen by `apps/clean_disk`, not by domain or application layers.

### UI Direction

- The accepted visual direction is the Cyber Blue/Violet dark productivity UI.
- The folder tree/table is the central workflow.
- The wide layout uses left scan targets, central tree table, right details/delete queue, and bottom scan progress.
- The compact layout removes the permanent sidebar and keeps the tree central, with details and delete queue below.
- UI implementation must use `packages/design_system` over Headless/Material primitives.
- If Headless is missing a critical primitive or API, report it before adding awkward UI workarounds.
- Disk usage maps use a `DiskUsageMapView` abstraction with renderer adapters.
  Treemap, sunburst, icicle, bar, and donut views are projections over the Rust
  read model, not separate sources of truth.
- Syncfusion treemap may be tested only as an optional adapter. Syncfusion
  types must not enter feature domain, application ports, Rust protocol DTOs,
  or core design-system contracts.

Reference screenshots:

- [Wide desktop reference](../design/references/clean-disk-wide-reference.png)
- [Compact narrow reference](../design/references/clean-disk-compact-reference.png)

Details: [Disk usage map view adapter decision](disk-usage-map-view-adapter.md).

### Flutter Frontend Architecture

- Flutter stores are feature-scoped MobX stores used as presentation-layer
  controllers that orchestrate application use cases.
- Application layer may own workflow state and state machines as framework-free
  pure Dart, for example `ScanLifecycle`, `CommandState`,
  `ActionAvailability`, `QueryFreshness`, and `OperationStatus`.
- MobX belongs to presentation stores and presentation-facing state only.
  Domain, application ports, use cases, data repositories, protocol DTOs, and
  design-system primitives must not depend on MobX.
- Stores own visible UI state, user intent, bounded query caches, lifecycle
  subscriptions, and compact view models.
- Widgets are lean renderers. They forward events to stores and use granular
  `Observer` boundaries.
- Row widgets must not own selection, focus, expansion, cleanup queue, scan
  session, or delete authority.
- Store identity uses `ScanSessionId`, `ScanSnapshotId`, `NodeRef`,
  `ProjectionId`, `QueryKey`, `DeletePlanId`, and `OperationId`, not row index
  or display path text.
- Reactions are lifecycle-managed side effects only. Every reaction must have a
  disposer, and reactions must not execute destructive commands.

Details: [Flutter frontend architecture decision](flutter-frontend-architecture-decision.md).

### Flutter Localization

- Flutter localization uses official `gen-l10n` plus `flutter_localizations`
  and `intl`.
- Localizations live in `packages/localization`, not inside `apps/clean_disk`,
  so feature presentation code can import localized strings without depending
  on the app shell.
- `apps/clean_disk` wires localization delegates and supported locales.
- Feature presentation code may import `clean_disk_localization`; domain,
  application, data, repositories, protocol DTOs, generated clients, and
  design-system primitives must not.
- MVP supported locales are `en` and `ru`.
- Generated localization files are artifacts. They must not be edited by hand.
- `synthetic-package` is not used. Flutter 3.41.9 marks it deprecated and it
  cannot be enabled, so generated files live in a real package output
  directory.

Details: [Frontend i18n localization decision](frontend-i18n-localization-decision.md).

### Frontend Boundaries

- Protocol DTOs must map through data mappers into application models before
  they reach presentation stores or widgets.
- Frontend commands flow from widget event to MobX store action to application
  use case to port/adapter. Widgets must not call HTTP, WebSocket, platform
  plugins, or daemon routes directly.
- WebSocket events are notifications and invalidations, not complete product
  truth. Terminal operation state is reconciled through queries.
- Design-system primitives accept view models and callbacks. They must not
  import feature stores, repositories, protocol DTOs, or product workflows.
- Flutter persistence is for UI preferences and disposable cache only. Daemon
  tokens, cleanup confirmations, operation journal truth, receipt truth, and
  full scan trees must not be stored as ordinary Flutter preferences/cache.
- Platform actions such as reveal, folder picker, permissions, notifications,
  and native dialogs go through ports/adapters.
- Wide and compact layouts share the same state model. Layout shells move
  panels; they do not fork stores or product workflows.
- Routes can identify views/resources, but cannot carry cleanup authority,
  tokens, broad raw paths, or replayable destructive commands.
- Runtime-specific authority stays behind adapters. Web UI must not import
  desktop-only APIs or `dart:io`; desktop/native authority is exposed through
  capability-driven ports.
- Query caches are disposable, bounded, and versioned by session/snapshot/query.
  Cached rows, virtualized row indexes, stale pages, display paths, and preview
  fixtures cannot become cleanup authority.
- Confirmation UI renders current validated plans only. Stale plan, stale
  snapshot, missing capability, or policy conflict disables destructive actions.
- Clipboard, export, support bundle, telemetry, and logs apply explicit
  redaction policies before exposing paths, search text, tokens, or delete
  targets.
- Selection, cleanup queue, and `DeletePlan` are separate states. Selection is
  transient UI intent, queue is user review intent, and `DeletePlan` is the
  validated authority for destructive execution.
- Bulk actions must carry explicit scope: visible rows, subtree, current folder,
  filtered page, all matching query, or explicit queue.
- Details panes enrich metadata lazily and cannot become delete authority.
- Multi-window/tab, overlay/menu focus, scroll restoration, drag/drop,
  notifications/toasts, and protocol compatibility are explicit frontend
  boundary concerns.
- Settings/preferences cannot weaken cleanup safety policy, redaction policy,
  telemetry policy, or remote destructive authority by ordinary UI preference.
- Degraded, offline, restarting, updated, session-expired, or incompatible
  daemon states disable risky actions. Read-only cached views must be marked
  stale.
- Startup hydration restores preferences, route, daemon discovery, session,
  protocol compatibility, capabilities, and caches in stages. Restored route or
  cache cannot restore destructive authority.
- Permission repair requires scanner-process re-probe before UI treats access
  as repaired.
- Snapshot history and compare views are snapshot-scoped projections.
  Historical nodes are not current cleanup targets without current validation.
- Table column configuration is UI preference. Sort/filter/query semantics are
  typed application/Rust contracts and must not require Flutter to process the
  full scan tree.
- Command ids, semantic classification codes, protocol keys, policy codes, and
  time/order semantics use stable identifiers and daemon/application evidence,
  not localized labels, display names, or wall-clock guesses.

Details: [Frontend boundaries decision](frontend-boundaries-decision.md).

### Scanner Integration

- The accepted long-term build strategy is stable future-shaped contracts with simple MVP internals. MVP can use single pdu scan, one segment, lazy metadata, and paginated queries, while contracts already preserve segmented snapshots, multiple backends, replaceable scanner execution, remote/headless read-only, scan history, and safe cleanup.
- Irreversible decisions are made conservatively now: identity, size/reclaim semantics, protocol versioning, snapshot format, cleanup authority, operation journal, public reusable library boundary, exact transport, capabilities, and remote authority. Reversible choices stay behind ports/adapters.
- MVP may start with one pdu scan and one snapshot segment, but public contracts must be future-shaped for segmented snapshots, multiple scanner backends, and replaceable execution adapters.
- `NodeRef` is opaque identity, not a path. Protocol DTOs should expose node references as opaque strings so Flutter web and future remote/headless clients do not depend on numeric precision or path identity.
- Size modeling uses `SizeFacts`, not one generic `size` field. Logical size, allocated size, measured policy, reclaim estimate, confidence, and evidence must stay distinct even when MVP can populate only part of the model.
- Snapshot, protocol, capability, scanner backend, rule pack, and receipt schemas are versioned. Update and rollback must re-probe compatibility instead of assuming cached state is valid.
- UI behavior is capability-first. It asks what the current scanner/host can do, not which OS or backend is active.
- Cleanup selection is snapshot-scoped and journaled. Future cleanup flows must pass through SelectionSet, DeletePlan, preflight, execution, receipt, and observed free-space delta, not path lists from UI.
- Remote/headless starts read-only by architecture. Remote destructive cleanup remains future-only until target scopes, authZ, audit, quotas, receipts, and policy gates are proven.
- The selected first scanner backend is `parallel-disk-usage` as a Rust library adapter.
- Local deep validation of `parallel-disk-usage` 0.23.0 confirmed it is viable as the first scanner adapter on macOS synthetic fixtures, `~/Downloads`, and `~/Library`, but not as product truth.
- The pdu required capabilities audit confirmed that pdu covers fast traversal and aggregate trees, but not product identity, metadata, queryability, cancellation, cloud state, reclaim truth, or delete safety.
- A future Windows NTFS MFT fast path is accepted as a later adapter idea, not MVP scope. It must use the same scanner/read-model/protocol contracts and fall back to pdu/general traversal when unavailable.
- Scanner, indexing, metadata, accounting, and optional cleanup logic live in reusable `fs_usage_*` Rust crates.
- Clean Disk is the first production consumer of the reusable `fs_usage_*` library, not the owner of the reusable scanner domain.
- `pdu` must stay an adapter. It is not part of domain vocabulary.
- The only crate allowed to import `parallel_disk_usage` is the dedicated pdu adapter crate, provisionally `fs_usage_pdu`.
- The accepted pdu dependency policy is latest verified stable, exact pinned version. Latest checked crates.io version on 2026-05-16 is `0.23.0`; future upgrades require adapter source audit, fixture rerun, real-directory smoke scan, benchmark comparison, and semantic review.
- The production plan is not to wrap the `pdu` CLI.
- On macOS, production scanning must run inside a signed Clean Disk app component or bundled helper. External `pdu` binaries are prototype-only because Full Disk Access/TCC authority depends on process identity, code requirement, and responsible bundle attribution.
- Capability probing, scan traversal, metadata enrichment, and delete preflight must run under the same scanner process identity.
- The scanner model is final tree plus progress stream.
- pdu's data return model is `DataTree<OsStringDisplay, Size>` plus reporter events and optional diagnostic JSON. This is not the Clean Disk product protocol.
- pdu JSON is prototype/diagnostic/golden-fixture material only. It must not be the production Flutter or daemon tree protocol.
- The pdu adapter must convert `DataTree` into our own arena/read-model, build indexes and item counts, attach issue/hardlink evidence, then drop the pdu tree as early as practical.
- The read model must store parent id plus local name segment, not full `PathBuf` per node. A local spike on `~/Library` showed about 694 MB peak for a naive full-path arena versus about 265 MB for a compact parent+basename arena.
- Metadata enrichment is not provided by pdu `DataTree`. Clean Disk should enrich visible/query/detail nodes lazily first, and only fork/patch pdu for metadata streaming if duplicate stat cost is measured as a blocker.
- pdu provides final aggregate `DataTree` and reporter events, but Clean Disk must add stable node ids, full paths, metadata enrichment, scan issues, read-model indexes, pagination, search/sort/top queries, reclaim estimates, operation state, and cleanup revalidation.
- pdu has no confirmed cooperative cancellation hook in 0.23.0. Clean Disk cancellation must be session-supervised with `cancel_requested`, late-result discard by epoch, and a future upstream/fork option if measured latency is unacceptable.
- Real pdu scans can create visible system pressure. The default scan mode must be `Balanced` with explicit CPU/IO/event budgets; `Fast` mode is opt-in; heavy full-depth test scans must have a stop switch.
- pdu `max_depth` is not a lazy expansion solution. Lower depths preserve aggregate size but discard child nodes, so expandable UI needs full-depth scans or our own subtree rescan strategy.
- User-selected symlink targets need explicit target policy. pdu uses `symlink_metadata`, does not follow symlinks, and treats a symlink-to-directory root as a leaf.
- pdu missing targets can produce a zero-size tree and error event with successful process exit. Clean Disk must preflight targets and classify scan quality itself.
- pdu multi-root and overlapping target behavior is CLI/product-specific and not our contract. Clean Disk owns target normalization and synthetic root semantics.
- Rust owns the full scan tree and indexes.
- Flutter must not receive or keep the entire scan tree.
- Tree data is queried by pages: children, top folders, top files, search results, and selected node details.
- Sorting and filtering over large scan results are done in Rust, then returned to Flutter as pages.
- Progress, skipped paths, permission errors, and other scan events are streamed at a throttled rate.
- Do not emit one UI event per filesystem entry.

### Client API Shape

- The accepted client API shape is an opaque scan session handle plus event stream plus paginated node queries.
- Session lifecycle is explicit: create, start, cancel, query, dispose.
- Wire/protocol DTOs are separate from domain models.
- Domain must not depend on generated transport or bridge code.
- Flutter feature repositories should not scatter raw HTTP paths or WebSocket event parsing.
- Use a small product-specific `CleanDiskApiClient` over the existing `abstract_http_client` for HTTP commands and queries.
- Use a small `ScanEventClient` for WebSocket session events.
- These clients are protocol adapters, not new generic network layers and not wrappers over Dio.

### Rust Daemon/Server API

- The primary native architecture is a Rust daemon/server API.
- Rust architecture has three layers: reusable `fs_usage_*` library, Clean Disk Rust host, and Flutter client.
- The reusable `fs_usage_*` library owns scan sessions, read models, ports, indexes, metadata enrichment, capability reporting, and optional cleanup primitives.
- `clean-disk-server` is a host/composition root. It owns process lifecycle, config, auth, local token, transport, protocol mapping, and concrete adapter wiring.
- Flutter is a client of the Clean Disk API and must not contain disk traversal logic.
- The reusable Rust library should be reusable before it is public-stable. External semver stability is deferred until Clean Disk validates the API through real scan/details/search/cleanup flows.
- Clean Disk uses one Rust daemon process for the local runtime, not a microservice architecture.
- Parallel scanning happens inside that daemon through an explicit bounded worker pool, scan scheduler, resource budgets, and backend capabilities.
- Multiple worker processes or distributed workers are future extension points only, not MVP architecture.
- Transport is abstract and must not leak into domain or application layers.
- Data transfer is socket-based.
- The first accepted socket transport is HTTP commands/queries plus WebSocket events.
- The same application-level command/query/event contract is used by desktop, web, CLI, and remote server modes.

### Permission Architecture

- Permission handling is a capability workflow, not a startup prompt.
- The app should launch without asking for broad filesystem authority.
- Broad access is requested progressively from scan intent: Home, Library, full disk, protected folders, external volumes, or cleanup from protected targets.
- Clean Disk follows disk-analyzer UX by default: scan what is available, expose hidden/skipped/protected areas, and offer access improvement/rescan. Backup-style setup gates are reserved for features that cannot honestly work without broad access.
- The accepted product UX is analyzer-first with a progressive capability ladder, conservative cleanup recommendations, explicit delete plans, optional advanced authority, and Permission Doctor for repair/support.
- Permission UX follows a proof loop: show useful result, expose limits, offer repair, re-probe from scanner process, then show what changed. Opening settings or clicking an instruction is never treated as proof.
- Built-in OS cleanup patterns influence recommendations: users review categories before cleanup, Downloads/cloud/user documents are conservative by default, and enterprise cleanup policy is a later admin surface.
- Distribution/package mode is part of capability state. Direct signed/notarized macOS apps, Windows signed installers, Linux AppImage/deb/rpm, Flatpak/Snap, MSIX, portable builds, and remote mode may expose different scan authority and repair actions.
- Scan profiles are explicit product concepts: `Quick`, `Targeted`, `Full`, `External`, `Advanced`, and `Background`. Advanced profiles are read-only first and may require extra authority.
- Cleanup candidates are risk-tiered as `Safe`, `Review`, `Risky`, or `Unsupported`. Only high-confidence generated cache/log/temp data can be auto-selected by default.
- Cleanup flow is explicitly staged: analyzer selection, cleanup queue, DeletePlan, final execution, receipt. Selecting a row in the scan tree never implies deletion.
- Cloud/File Provider data must expose local-vs-cloud semantics. The app must not hydrate online-only files during scan, treat placeholders as local reclaim, or hide cloud delete propagation.
- Cloud/provider actions are distinct from local deletion. `Remove local download`, `Move to Trash`, `Delete from sync root`, and `Use provider cleanup action` must be separate product actions when supported.
- Recommendation cards are category-backed views over the same scan/read model, not a separate cleanup engine. Each card must expose reason, risk, evidence, action, and reclaim confidence.
- Low-space mode is a first-class runtime state. The app must avoid large caches, cloud hydration, oversized logs, and background update downloads while helping a user recover storage.
- Updates must preserve or revalidate scanner/helper identity, daemon protocol compatibility, and capability status before claiming full functionality after upgrade.
- Feature-level UX follows explicit product contracts. Home, target picker, scan progress, tree/table, search/filter/sort, bulk actions, saved scans/history, compare, export, keyboard commands, notifications, automation, receipts/restore, details, recommendation cards, cleanup queue, cloud providers, duplicate search, repair, settings, updates, diagnostics, accessibility, and web/remote UX each own user promise, states, actions, and evidence rules.
- The tree/table remains the primary power surface. Recommendation cards and charts are projections over the same Rust read model, not separate sources of truth.
- Product UX follows the launched-product hybrid: DaisyDisk/TreeSize/WizTree-style discovery plus CleanMyMac/BleachBit/Storage Sense-style safety. Clean Disk must not become an opaque one-click cleaner.
- Search, filter, sort, top lists, and comparison are Rust read-model queries, not Flutter-side traversal over a transferred tree.
- Bulk selection is a server-side selection-set workflow. The UI must show whether a selection applies to visible rows, one page, an expanded subtree, or all query results.
- Saved scans are immutable snapshots for review, comparison, and reporting. They are not delete authority until revalidated against live filesystem identity.
- Export/reporting is an explicit operation with redaction levels, progress, cancellation, and receipt.
- Keyboard shortcuts, context menus, toolbars, and details actions must share command availability data so disabled actions are explained consistently.
- Automation starts with reminders, scheduled scans, scheduled reports, and dry-run previews. Destructive scheduled cleanup is advanced and disabled by default.
- After cleanup, the product shows restore capability and receipt facts. It must not promise generic undo unless the action is still cancelable or platform/provider restore has been verified.
- Real-product lessons are accepted as UX guardrails: copy tree/table discovery, preview-first cleanup, safety rules, cloud-state vocabulary, repair checklists, redacted diagnostics, and conservative automation; avoid startup permission walls, silent broad cleanup, unsafe user-defined cleanup commands, and permanent delete as primary UX.
- Launched-product UX playbook is accepted as a product-journey guardrail. Clean Disk UX is built around discover space, explain completeness, review candidates, choose exact action, execute with platform semantics, and show receipt/repair/support path.
- Top-company product UX research is accepted as a state-led product architecture guardrail. Clean Disk should model product state first, then render screens from that state.
- Real-product feature adoption research is accepted as a feature guardrail. Clean Disk should copy launched-product behavior where it improves inspection, safety, restore semantics, diagnostics, resource behavior, accessibility, or cross-platform honesty.
- Launched-product cross-platform workflow research is accepted as a product guardrail. Clean Disk shares workflows and product vocabulary across platforms, but uses native platform adapters where OS semantics affect trust or safety.
- Launched-product operational UX research is accepted as an application architecture guardrail. Actions should be first-class product concepts with shared availability, risk, shortcut, platform adapter, progress, receipt, and repair semantics.
- Target picker, scan profile, scan quality, issue groups, recommendation cards, selection sets, cleanup queue, DeletePlan, operation receipt, Permission Doctor, low-space rescue, and report/export are product concepts, not incidental widgets.
- CapabilityProbe, CapabilityState, OperationStateMachine, ActionAvailability, DisabledReason, SupportBundlePlan, SupportBundleReceipt, RestoreCapability, ResourceProfile, LowSpaceMode, DaemonHealth, and UpdateCompatibilityState are application-level concepts, not incidental UI fields.
- ActionAvailability, DisabledReason, ScanQuality, RestoreCapability, ReclaimConfidence, and OperationReceipt should be defined before feature screens depend on ad hoc booleans.
- CloudFileState, PackageMode, ToolCleanupPlan, IssueGroup, NodeDetails, ReclaimEstimate, and OperationState are required product/protocol contracts before cross-platform UI depends on them.
- ActionDescriptor, ActionRole, ActionScope, ActionRisk, CommandRegistry, KeyboardShortcut, TrustMode, OperationLedger, RepairRecipe, ShellAction, ExternalToolAction, ProtocolCompatibility, MachineLocalState, and SupportEvidence are application-level concepts for operational UX.
- Native platform action adapters are required for Trash/Recycling Bin, file reveal, capability probing, permission repair, package mode, cloud state, diagnostics, support bundle, and official tool cleanup.
- Screens should render registered actions and their availability. They should not invent one-off scan, reveal, delete, export, repair, or support operations inside widgets.
- Trust modes are explicit product state. Read-only, normal, advanced cleanup, admin scan, remote read-only, and remote managed capabilities must gate actions by intent, authority, and policy.
- Every major product surface should define empty, loading, partial, error, disabled-action reason, recovery action, keyboard path, and analytics-safe event name before implementation.
- Daemon/scanner health is quiet by default but inspectable and repairable. Support bundle preview, redaction, receipt, and verified repair status are first-class product flows.
- Resource Saver, Low-space mode, and scan resource profiles are user-facing behavior, not just internal scheduler options.
- Cleanup queue and DeletePlan should be prototyped before recommendation cards drive deletion. Recommendations must remain evidence-backed views over scan indexes.
- Size accounting UI must expose logical size, allocated size, exclusive reclaim estimate, quota effect estimate, observed free-space delta, confidence, and explanation codes where available.
- Cloud/sync state is part of node metadata and action availability. Removing local downloads, moving to Trash, deleting from sync roots, and provider cleanup actions are distinct product actions.
- Every destructive workflow should follow preview, preflight, execute, reconcile, and receipt. Raw file deletion without platform semantics is a fallback, not the default.
- Cross-platform consistency means shared workflow contracts, not pretending macOS, Windows, Linux, web, and headless have identical filesystem authority or deletion semantics.
- If access is missing, the app should continue with a partial scan where safe and expose skipped/protected counts.
- MVP includes Downloads/custom folder scan without broad permission, Home/full disk preflight, partial result banner, skipped reasons drawer, Permission Doctor, scanner-process re-check, and separate delete preflight.
- MVP does not default to macOS admin scan, Windows MFT/admin scan, Linux root scan, or Flatpak/Snap full-host promises.
- Permission UI should speak in product states: `Complete`, `May be partial`, `Needs access`, `Advanced`, and `Unavailable`.
- The recommended first scan should be low-friction, usually Downloads or a user-selected folder.
- Permission Doctor is available from warnings/settings, but is not a first-launch wall.
- The scan result must always expose a completeness state and grouped skipped/protected reasons.
- Read authority and delete authority are separate. Cleanup permission prompts happen only after the user selects cleanup targets and before final confirmation.
- Product copy should explain scan quality and metadata access, not raw OS internals.
- Non-blocking permission issues should use badges, status strips, banners, and drawers before modal dialogs. Modals are reserved for target preflight choices that require a decision and destructive cleanup confirmation.
- Opening system settings never means permission is granted. The app must re-probe from the scanner process after the user returns.
- Platform-specific permission concepts stay in infrastructure adapters. Domain/application use normalized capability, grant, and issue types.
- Capability probing must run in the process that will actually scan or delete, not in Flutter UI.
- Windows elevation is not a default app mode. System/admin areas are advanced/read-only until explicitly designed.
- Linux package mode is part of capability state because Flatpak/Snap/AppImage/distro packages have different filesystem visibility.

### Transport Architecture

- Browser web UI uses browser-supported socket transports, such as WebSocket over TCP, to talk to a local or remote Rust daemon.
- Desktop can later use loopback TCP, Unix domain sockets, named pipes, or another socket adapter without changing application contracts.
- FRB is not the primary architecture. It may be revisited later as an optional desktop optimization.
- JSON-RPC, Socket.IO, gRPC, and gRPC-Web are not accepted as the initial Clean Disk protocol.
- JSON-RPC remains the strongest future candidate if we later build a daemon/orchestrator-style RPC protocol.
- Socket.IO remains a future adapter candidate only if rooms, namespaces, fallback polling, or public Socket.IO clients become product requirements.
- gRPC/gRPC-Web remains a future candidate for internal service-to-service APIs, not for the initial browser/local daemon protocol.

### Web Surface

- Flutter web is a UI surface.
- Full disk scanning does not happen through browser filesystem APIs.
- Web UI must talk to a local or remote Rust daemon/server to display real scan data.
- Any localhost daemon/server must use local-only binding, a session token, and an origin allowlist.

### Delete Safety

- Delete is never a direct one-click permanent delete.
- Cleanup goes through an explicit delete queue and confirmation workflow.
- Prefer platform Trash/quarantine behavior where supported.
- Before moving/deleting, revalidate path, metadata, and selected node identity to avoid acting on stale scan data.
- Permission errors, locked files, symlinks/reparse points, hardlinks, mount boundaries, and files changing during scan are first-class states.

## Open Questions

These are not accepted decisions yet.

- Persistent scan history format and retention policy.
- Exact delete confirmation UX and platform-specific Trash behavior.
