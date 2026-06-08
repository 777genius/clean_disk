# Clean Disk Project Instructions

This repository is a Flutter workspace for a universal disk usage analyzer and cleanup tool. It keeps the original workspace architecture: feature micro-packages, Clean Architecture, Hexagonal Ports & Adapters, simple DDD, Modularity, GetIt, Drift cache, and an abstract HTTP client backed by Dio when network adapters are needed.

## Core Project Rule

Контракты проектируем как Pro, реализацию делаем как MVP.

Design irreversible boundaries as future-shaped contracts: opaque node references, snapshots, size facts, capability DTOs, scanner execution ports, selection sets, operation journals, versioned protocol DTOs, and privacy classes. Keep the first implementation intentionally simple: single pdu-backed scan, one segment, lazy metadata, paginated queries, and no future feature pulled forward without an explicit gate.

## No Delete Rule

- Do not delete files, folders, caches, generated artifacts, screenshots, build outputs, or temporary files unless the user explicitly asks to delete that exact target in the current context.
- Do not run destructive cleanup commands such as `rm`, `rmdir`, `find -delete`, `git clean`, `flutter clean`, `cargo clean`, `melos clean`, or broad cache cleanup commands without direct confirmation.
- If cleanup seems useful for verification or disk space, ask first and explain what exact paths would be removed.

## Runtime

- Use FVM and Flutter `3.41.9`.
- Run Flutter and Dart commands through `fvm`, for example `fvm flutter analyze`.
- Run workspace commands from the repository root.
- Use Dart workspaces and Melos.
- For frontend visual verification, run the app in debug mode with Marionette enabled and use the Marionette MCP server first. The app already initializes `MarionetteBinding` in debug builds, and the project MCP config starts the server from `apps/clean_disk` with `fvm dart run marionette_mcp`. Use Marionette for screenshots, widget discovery, taps, scrolling, hot reload, and size/layout checks before falling back to Playwright/browser tools.

## Repository Map

- `START_HERE.md` - short recovery file for project context without chat history.
- `FRONTEND_LAYOUT_GUIDE.md` - practical Headless/design-system layout rules, frontend architecture boundaries, wide/compact workflow, tree/map contracts, AI assistant placement, and verification checklist.
- `docs/technical/README.md` - canonical technical documentation map, dependency flow, end-to-end build roadmap, work lanes, mandatory reading bundles, stop rules, implementation phases, phase gates, full document inventory, and task-specific index.
- `docs/technical/documentation-map.md` - documentation structure, source-of-truth routing, lifecycle, maintenance rules, and anti-patterns.
- `docs/technical/documentation-sitemap.md` - grouped visual structure of all technical documentation by area.
- `docs/technical/phase-reading-guide.md` - phase-by-phase minimum reading, risk add-ons, expected output, and boundaries.
- `docs/technical/task-router.md` - day-to-day task routing by task type, required docs, gate, and expected output.
- `docs/technical/reading-order-checklist.md` - scenario checklists for reading order, expected output, gates, and stop conditions.
- `docs/technical/execution-board.md` - row-by-row implementation board with deliverables, docs, gates, workstreams, and excluded scope from zero to release.
- `docs/technical/start-to-finish-guide.md` - one linear route from context recovery to scan-only MVP, cleanup beta, desktop release, remote/headless, and release gates.
- `docs/technical/clean-architecture-implementation-phases.md` - strict phase-by-phase implementation steps, gates, stop rules, and first slice that protects Clean Architecture, SOLID, simple DDD, and ports/adapters.
- `docs/technical/capability-implementation-matrix.md` - capability-to-train, milestone, phase, owner lane, gate, and excluded-scope routing.
- `docs/technical/implementation-runbook.md` - operational execution plan with milestones, exit gates, minimum scan-only slice, first cleanup slice, and PR review checklist.
- `docs/technical/release-train-map.md` - product slice boundaries for scan-only MVP, local cleanup beta, recommendations/tool adapters, signed desktop release, remote/headless read-only, future remote cleanup, and support operations.
- `docs/technical/architecture-decisions.md` - accepted architecture decisions and open questions.
- `docs/technical/architecture-fit-validation.md` - validation of the accepted daemon, worker pool, HTTP/WebSocket, and protocol architecture from multiple angles.
- `docs/technical/future-proofing-architecture-gates.md` - future-shaped contracts, operational, strategic, product, safety, organizational, ecosystem, automation, multi-environment, assurance, fault-model, external-boundary, abuse-resistance, complexity, and evolution future gates, invariants, stop rules, and extension points that MVP must preserve for segmented snapshots, helper processes, typed scan targets, semantic classification, authority scopes, data lifecycle, compatibility corpus, export profiles, kill switches, incident response, trust channel, data quality tiers, user intent preservation, benchmark honesty, automation boundaries, multi-user machines, local-only filesystem truth, storage provider adapters, reason taxonomy, self-test diagnostics, trust UX, state machines, safety case, storage topology, deterministic evidence, cost-aware runtime, retention/forgetting, fault injection, local daemon threat model, confused deputy protection, schema governance, extension sandbox, content boundary, release rings, audit trail, provider honesty, complexity budget, progressive disclosure, deprecation/sunset policy, release trust, ethical cleanup UX, documentation decay control, cross-product reuse boundary, remote/headless, scan history, compatibility, resource budgets, rule packs, and safe cleanup.
- `docs/technical/disk-usage-map-view-adapter.md` - `DiskUsageMapView` abstraction, renderer adapter boundary, optional Syncfusion policy, and treemap/sunburst projection rules.
- `docs/technical/flutter-frontend-architecture-decision.md` - Flutter responsibility zones, feature-scoped MobX store architecture, store lifecycle, identity, Observer, reaction, and testing rules.
- `docs/technical/frontend-boundaries-decision.md` - frontend DTO, command, authoritative state, design-system, event stream, persistence, platform action, accessibility, responsive layout, and route boundary rules.
- `docs/technical/frontend-i18n-localization-decision.md` - official Flutter `gen-l10n`, shared localization package, formatting boundary, supported locales, and stop rules.
- `docs/technical/implementation-edge-cases.md` - implementation edge cases, risks, and required mitigations.
- `docs/technical/implementation-edge-cases-advanced-scenarios.md` - advanced storage, recommendation, installer, update, and enterprise edge cases.
- `docs/technical/implementation-edge-cases-deep-dive.md` - deeper platform, cloud, daemon security, watcher, and UI edge cases.
- `docs/technical/implementation-edge-cases-cloud-network-virtual-filesystems.md` - cloud placeholders, sync roots, network shares, NAS, FUSE/rclone mounts, removable volumes, local-vs-remote size, and delete propagation edge cases.
- `docs/technical/implementation-edge-cases-cleanup-delete-safety.md` - DeletePlan, Trash adapters, stale identity revalidation, partial cleanup outcomes, receipts, restore expectations, reclaim estimates, and delete safety edge cases.
- `docs/technical/implementation-edge-cases-dependency-supply-chain-governance.md` - dependency selection, license policy, vulnerability gates, supply-chain trust, build scripts, procedural macros, SBOM, provenance, vendoring, and release artifact governance edge cases.
- `docs/technical/implementation-edge-cases-diagnostics-observability-support.md` - diagnostics, observability, logs, metrics, crash reports, support bundles, telemetry, redaction, and support workflow edge cases.
- `docs/technical/implementation-edge-cases-filesystem-model.md` - low-level filesystem size, identity, quota, delete, and DTO modeling edge cases.
- `docs/technical/implementation-edge-cases-flutter-large-tree-ui.md` - Flutter large-tree UI, virtualization, frontend state ownership, design-system primitives, rendering performance, and web/desktop layout edge cases.
- `docs/technical/implementation-edge-cases-incremental-scan-watchers.md` - incremental scan, filesystem watcher, stale snapshot, subtree refresh, cache invalidation, watcher health, and auto-refresh edge cases.
- `docs/technical/implementation-edge-cases-local-state-persistence.md` - local state, Drift/SQLite, cache durability classes, receipts, operation journals, migrations, retention, support bundles, corruption recovery, and local secrets edge cases.
- `docs/technical/implementation-edge-cases-performance-scale.md` - performance, scale, benchmarking, Rust scanner, protocol, and Flutter UI throughput edge cases.
- `docs/technical/implementation-edge-cases-pdu-adapter-integration.md` - pdu scanner adapter integration, option mapping, hardlink policy, progress, cancellation, tree mapping, and fork/upstream strategy edge cases.
- `docs/technical/pdu-adapter-capability-spike.md` - pre-implementation pdu capability findings for final tree, progress, cancellation, hardlinks, boundaries, benchmark split, and read-model memory.
- `docs/technical/pdu-library-deep-validation.md` - local CLI and library validation of `parallel-disk-usage` 0.23.0 on synthetic fixtures, Downloads, Library, hardlinks, sparse files, progress, memory, and adapter implications.
- `docs/technical/pdu-implementation-start-gate.md` - compact must-read gate before the first Rust scanner PR, covering pdu source facts, Clean Architecture layer contracts, DDD/SOLID mapping, stop gates, first PR shape, and critical contract tests.
- `docs/technical/pdu-cross-layer-contract-matrix.md` - review matrix mapping pdu internals to domain, application, infrastructure, protocol, Flutter, size/path/issue/event/reclaim/runtime/read-model contracts, and PR gates.
- `docs/technical/pdu-domain-infrastructure-contract-blueprint.md` - practical Rust module blueprint for `fs_usage_core`, `fs_usage_engine`, `fs_usage_pdu`, `fs_usage_platform`, product data flow, and contract tests.
- `docs/technical/pdu-data-model-and-adapter-guide.md` - what pdu returns through `DataTree`, reporter events, and diagnostic JSON, and how the pdu adapter converts that into Clean Disk arena/read-model, metadata enrichment, issues, indexes, and paginated queries.
- `docs/technical/pdu-clean-architecture-contract.md` - Clean Architecture/SOLID/ports-and-adapters contract that keeps pdu private to `fs_usage_pdu` and defines domain, application, data/infrastructure, platform, accounting, and test boundaries.
- `docs/technical/pdu-data-flow-architecture-contract.md` - accepted end-to-end data flow for the pdu-backed scanner: Flutter command/query flow, daemon protocol, engine session/read-model ownership, pdu adapter internals, snapshot publication, events, cleanup authority, and first implementation contract tests.
- `docs/technical/pdu-raw-api-contract-map.md` - raw pdu API, JSON shape, reporter events, fixture observations, and required mapping before product data contracts.
- `docs/technical/pdu-critical-risk-verification.md` - local spike results for pdu latest version, read-model memory, compact arena shape, metadata restat cost, cancellation latency, hardlink mode cost, resource pressure, and macOS permission identity.
- `docs/technical/pdu-required-capabilities-audit.md` - strict pdu 0.23.0 feature audit against Clean Disk needs, including target handling, max depth, metadata gaps, progress, cancellation, hardlinks, filters, JSON, and required contract tests.
- `docs/technical/windows-ntfs-mft-fast-path.md` - future Windows-only fast scanner adapter idea using NTFS MFT/USN-style enumeration with pdu fallback for non-NTFS and unsupported targets.
- `docs/technical/pre-implementation-critical-spikes.md` - ordered research plan for read-model memory, protocol streaming, Trash, packaging permissions, and resource profiles.
- `docs/technical/preimplementation-critical-research-sequence.md` - broader ordered decisions before scanner, read-model, daemon, cleanup, and large-tree UI implementation.
- `docs/technical/preimplementation-critical-zones-deep-dive.md` - hidden failure modes, spike protocols, invariants, evidence models, blast-radius budgets, fault injection, kill switches, release blockers, systemic risk boundaries, bounded memory, quantity/rounding truth, selection/visible intent safety, cancellation/abortability, power/thermal QoS budgets, observability privacy budgets, SQLite/Drift persistence integrity, content-read boundaries, hostile display/export safety, clock/causality semantics, low-disk mode, lifecycle ownership, async/blocking runtime isolation, remote/headless authority scopes, path authority, privilege boundaries, assurance traceability, policy-as-code gates, long-term compatibility, migration gates, extension safety, and fallbacks for the highest-risk implementation zones.
- `docs/technical/critical-zones/README.md` - focused global critical-zone files created after the broad deep dive.
- `docs/technical/critical-zones/update-release-rollback-safety.md` - update artifact trust, quiesce gates, compatibility manifests, app identity continuity, rollback safety, and release gates.
- `docs/technical/critical-zones/rust-runtime-execution.md` - Tokio versus blocking scanner work, worker lanes, pdu execution boundary, bounded channels, cancellation, panic containment, shutdown, recovery, and runtime observability.
- `docs/technical/critical-zones/recommendation-policy-rule-pack-safety.md` - evidence-backed recommendations, false-positive control, risk tiers, official tool adapters, stale recommendation invalidation, and rule-pack safety.
- `docs/technical/critical-zones/restore-quarantine-undo-safety.md` - restore capability levels, cleanup receipts, platform Trash/Recycling Bin semantics, cloud provider recovery, app quarantine policy, and no-undo tool cleanup.
- `docs/technical/critical-zones/tool-command-execution-sandbox.md` - safe official command execution, executable identity, argv/env/cwd policy, output limits, timeout/cancellation, dry-run parity, command receipts, and injection defenses.
- `docs/technical/critical-zones/remote-headless-destructive-cleanup-authorization.md` - remote/headless destructive authority, object-level auth, target scopes, WebSocket message auth, audit, quotas, and policy gates.
- `docs/technical/critical-zones/persistent-operation-journal-receipt-durability-low-disk.md` - durable cleanup intent, item outcomes, receipts, SQLite/WAL policy, low-disk emergency reserve, crash recovery, and support export safety.
- `docs/technical/critical-zones/support-bundle-diagnostics-export-privacy-evidence.md` - diagnostic data classes, redaction profiles, support bundle manifest, privacy-preserving evidence refs, crash metadata, and export authorization.
- `docs/technical/implementation-edge-cases-platform-identity-delete-revalidation.md` - platform file identity, delete preflight, stale candidate validation, Trash adapter reliability, and cleanup receipt edge cases.
- `docs/technical/implementation-edge-cases-protocol-data-contracts.md` - Rust/Flutter protocol DTOs, JSON precision, path encoding, timestamps, enum evolution, schema/codegen, and compatibility edge cases.
- `docs/technical/implementation-edge-cases-product-workflows.md` - product workflow, protocol correctness, delete plan, export, and multi-client edge cases.
- `docs/technical/implementation-edge-cases-concurrency-state-machines.md` - operation state machines, command idempotency, cancellation, event ordering, Rust async ownership, and multi-client concurrency edge cases.
- `docs/technical/implementation-edge-cases-transport-protocol-streaming.md` - HTTP/WebSocket transport, protocol envelopes, event classes, backpressure, reconnect, schema, and Flutter streaming edge cases.
- `docs/technical/implementation-edge-cases-web-ui-daemon-runtime.md` - web UI delivery, local daemon runtime, CORS/PNA, browser lifecycle, service worker cache, pairing, and Flutter web runtime edge cases.
- `docs/technical/implementation-edge-cases-platform-permissions-packaging.md` - macOS/Windows/Linux permissions, signing, installers, package modes, app identity, daemon helper packaging, and update/uninstall edge cases.
- `docs/technical/permission-ux-playbook.md` - user-facing permission ladder, scan-quality states, preflight flow, capability DTO contract, platform defaults, recovery cases, and testing checklist.
- `docs/technical/cross-platform-user-experience-playbook.md` - install trust, first-run flow, scan lifecycle, cleanup review, cloud/provider behavior, repair cards, updates, diagnostics, package modes, and remote/headless UX.
- `docs/technical/feature-ux-benchmark.md` - feature-by-feature benchmark and accepted contracts for home, target picker, scan progress, tree/table, search/filter/sort, bulk actions, history/compare, export, keyboard commands, notifications, automation, receipts/restore, details, recommendation cards, cleanup queue, cloud providers, duplicate search, repair, settings, updates, diagnostics, accessibility, and web/remote UX.
- `docs/technical/real-product-ux-lessons.md` - product lessons copied from launched storage, cleanup, sync, backup, security, and disk analyzer tools, including what to adopt and what not to copy blindly.
- `docs/technical/launched-product-ux-playbook.md` - second-pass launched-product benchmark for product journeys, feature-by-feature borrowing rules, architecture implications, and next UX/DTO spikes.
- `docs/technical/top-company-product-ux-patterns.md` - top-company UX benchmark for state-led product architecture, daemon/agent health, low-space/resource behavior, diagnostics, settings, accessibility, and enterprise/headless separation.
- `docs/technical/real-product-feature-adoption-playbook.md` - feature-by-feature product patterns to copy from launched disk analyzers, cleanup tools, OS storage managers, sync clients, backup tools, developer utilities, and platform guidelines.
- `docs/technical/launched-product-cross-platform-workflows.md` - practical workflow patterns for consistent cross-platform UX with native platform actions, official tool cleanup, cloud/provider states, diagnostics, repair, and web/headless constraints.
- `docs/technical/launched-product-operational-ux-deep-dive.md` - operational UX patterns from mature desktop/web products for command registry, trust modes, operation ledger, repair recipes, shell integration, keyboard UX, web capability boundaries, updates, and support bundles.
- `docs/technical/implementation-edge-cases-operational-reliability.md` - daemon lifecycle, crash recovery, update/version compatibility, persistence, observability, overload, and release operations edge cases.
- `docs/technical/implementation-edge-cases-ui-accessibility-i18n.md` - tree/table accessibility, keyboard UX, screen-reader semantics, localization, bidi-safe paths, text scaling, and design-system primitive edge cases.
- `docs/technical/implementation-edge-cases-remote-headless-mode.md` - remote/headless/server mode, auth/authZ, target scopes, containers, Kubernetes/systemd, audit, quotas, and read-only remote defaults.
- `docs/technical/implementation-edge-cases-recommendation-rule-engine.md` - recommendation/rule engine, cleanup candidate classification, evidence, risk tiers, app/tool-specific cleanup, rule versioning, and explainability edge cases.
- `docs/technical/implementation-edge-cases-resource-governance.md` - scan resource profiles, CPU/IO budgets, OS priority/QoS, battery/thermal behavior, UI responsiveness, and benchmark edge cases.
- `docs/technical/implementation-edge-cases-search-query-indexing.md` - search, sort, filter, top lists, query pagination, indexing, stale search results, result privacy, and query performance edge cases.
- `docs/technical/implementation-edge-cases-security-privacy.md` - security, privacy, threat model, daemon hardening, tokens, remote mode, and supply-chain edge cases.
- `docs/technical/implementation-edge-cases-storage-accounting-snapshots-shared-extents.md` - logical vs allocated vs exclusive reclaim accounting, APFS snapshots/clones, VSS, ReFS/Btrfs/ZFS shared extents, dedupe, sparse/compressed files, quotas, and honest reclaim estimates.
- `docs/technical/reclaim-accounting-deep-research.md` - deep reclaim-accounting research, confidence/evidence model, platform API feasibility, pdu limits, and delete-plan accounting algorithm.
- `docs/technical/implementation-edge-cases-testing-quality-gates.md` - testing strategy, fixture lab, CI quality gates, benchmarks, destructive-test safety, dependency gates, and release readiness edge cases.
- `docs/technical/implementation-edge-cases-tool-managed-storage.md` - Docker, Xcode, npm, pnpm, Yarn, Pub, CocoaPods, Cargo, Gradle, Android, pip, Homebrew, developer cache classification, official cleanup adapters, and persistent tool-data edge cases.
- `docs/technical/rust-architecture.md` - Rust daemon/server architecture, crate layout, and transport rules.
- `docs/design/references/clean-disk-wide-reference.png` - primary wide UI reference.
- `docs/design/references/clean-disk-compact-reference.png` - compact/narrow UI reference.
- `apps/clean_disk` - the universal Flutter app shell and composition root for desktop and web.
- `features/scan` - isolated scan feature package.
- `packages/core` - shared kernel: `Result`, `AppFailure`, `Unit`, `UseCase`, `AppEnvironment`.
- `packages/cache` - Drift infrastructure and shared cache database.
- `packages/design_system` - app UI facade over Headless and Material primitives.
- `packages/localization` - shared Flutter `gen-l10n` package, ARB files, generated localizations, and BuildContext convenience extension.
- `packages/network` - app-level HTTP client factory and Dio-backed infrastructure wiring.
- `packages/abstract_http_client` - vendored abstract HTTP contracts.
- `packages/dio_http_client` - vendored Dio implementation of the abstract HTTP client.

## Dependency Direction

Dependencies must point inward and toward stable shared packages:

```text
apps/clean_disk
  -> features/*
  -> packages/design_system
  -> packages/localization
  -> packages/core
  -> packages/cache/network only when concrete adapters are needed

features/*
  -> packages/core
  -> packages/design_system only from presentation
  -> packages/localization only from presentation
  -> infrastructure packages only from data/di when needed

packages/network
  -> packages/abstract_http_client
  -> packages/dio_http_client
  -> packages/core

packages/cache
  -> Drift only

packages/design_system
  -> Headless and Flutter UI primitives

packages/localization
  -> flutter_localizations
  -> intl
```

Feature packages must not import another feature directly. Share cross-feature contracts through `packages/core` or a dedicated shared package.

## App Composition

`apps/clean_disk` owns app-level composition:

- Reads runtime config from Dart defines.
- Registers app-level services in GetIt.
- Creates the app router.
- Keeps app route paths and route builders in `AppRoutes`.
- Mounts feature modules through Modularity scopes.
- Chooses concrete adapters for native scan, cache, network, or platform capabilities.

Do not move app-wide bootstrap decisions into feature packages. Feature packages expose modules, pages, ports, and adapters; `apps/clean_disk` decides which concrete implementation is used in the running app.

## Design Reference

Before changing frontend layout or shared UI primitives, read
`FRONTEND_LAYOUT_GUIDE.md`.

Before changing user-facing UI, inspect these reference screenshots:

- [Wide desktop reference](docs/design/references/clean-disk-wide-reference.png)
- [Compact narrow reference](docs/design/references/clean-disk-compact-reference.png)

Design direction:

- Use the Cyber Blue/Violet dark theme direction from the references as the primary visual target.
- The app is a dense productivity tool, not a landing page: folder tree, details, scan status, and cleanup queue are the product surface.
- The folder tree/table is the central workflow. Keep hierarchy, indentation, disclosure controls, selected row, size, percent bars, item counts, and modified metadata easy to scan.
- Disk usage maps must use the `DiskUsageMapView` abstraction. Treemap, sunburst, icicle, bar, and donut charts are replaceable renderer adapters over bounded Rust projections, not sources of truth. Syncfusion may be used only as an optional adapter, never as a core feature/domain/protocol dependency.
- Wide layout: left scan-target sidebar, central tree table, right details/delete queue, bottom scan progress/status.
- Compact layout: no permanent sidebar; use target chips/top controls, central tree table, below-tree details, collapsible delete queue, sticky bottom progress.
- Keep cards/panels at 8px radius or less. Do not nest cards inside cards.
- Use icon buttons for common actions such as scan, pause, cancel, refresh, search, sort/filter, settings, reveal, queue, remove.
- Use restrained neon accents for selected state, progress, key metrics, and primary actions. Do not let gradients or glow dominate table readability.
- Text must fit within controls at desktop and compact widths. Use ellipsis for long paths and names.
- Build shared UI through `packages/design_system` over Headless/Material primitives. If Headless is missing a critical primitive or has an API limitation that would force an awkward workaround, report it clearly before working around it so the Headless library can be improved.
- Tree/table UI uses a design-system `TreeTable` facade. MVP implementation is `ListView.builder` with fixed-height visible rows and controlled columns. Keep `two_dimensional_scrollables` `TableView`/`TreeView` and custom slivers as future adapters behind the facade. Do not keep polishing the scan UI once the saved wide/compact reference structure, no-overflow checks, synthetic 50k-row profile smoothness, distinct row states, and non-rebuilding progress footer pass.

## Feature Package Shape

Every feature package should follow this shape:

```text
lib/
  feature_name.dart
  src/
    domain/
    application/
      ports/
      use_cases/
      state/
    data/
      dto/
      sources/
      repositories/
      cache/
    presentation/
      pages/
      stores/
    di/
```

Layer rules:

- `domain` contains entities, value objects, and domain rules only.
- `application` contains use cases, app-specific state, and ports.
- `data` contains DTOs, sources, repositories, cache adapters, and infrastructure adapters.
- `presentation` contains Flutter UI and feature-specific view state.
- MobX stores belong only in `presentation/stores` or presentation-facing state.
  Domain, application, data, protocol DTOs, and design-system primitives must
  not depend on MobX.
- Localization belongs only to app shell and presentation. Domain,
  application, data, repositories, protocol DTOs, and generated clients must not
  import `clean_disk_localization` or generated localization classes.
- `di` contains feature module wiring.

Ports belong to `application`, not `domain`. Domain must not know repositories, HTTP, cache, Flutter, MobX, Modularity, GetIt, Drift, Dio, pdu, Rust, `flutter_rust_bridge`, or design system UI.

Frontend boundary rules:

- Protocol DTOs must map into application models before reaching stores/widgets.
- Widgets must not import protocol DTOs, repositories, HTTP/WebSocket clients,
  platform plugins, daemon route strings, or renderer adapter types directly.
- Commands flow through store action, application use case, port, and adapter.
- WebSocket events invalidate/reconcile state; they are not complete truth.
- Design-system primitives accept view models and callbacks, not feature stores
  or product workflows.
- User-facing strings come from `packages/localization`; widgets do not
  hand-roll plural messages or use localized display text as command/domain
  identity.
- Runtime-specific authority stays behind adapters. Feature code must not
  import desktop-only APIs, `dart:io`, daemon route strings, WebSocket clients,
  platform plugins, or native process/window APIs directly.
- Flutter query caches are disposable and versioned by session/snapshot/query.
  Cached rows, visible indexes, virtualized row widgets, display paths, preview
  fixtures, and stale pages must never become cleanup authority.
- Confirmation UI must render a current validated plan. Stale plan, stale
  snapshot, missing capability, or policy conflict disables destructive actions.
- Daemon session/auth data must not appear in routes, logs, telemetry,
  clipboard, support bundles, or ordinary UI preferences.
- Selection, cleanup queue, and `DeletePlan` are separate concepts. Selection
  is not queue; queue is not delete authority; `DeletePlan` must be validated
  through application/daemon contracts.
- Bulk actions, details panes, drag/drop, notifications, toasts, restored
  viewport state, context menus, and multi-window state must never bypass the
  normal command, capability, policy, and confirmation flow.
- Settings/preferences may change UI convenience, but cleanup safety,
  redaction, telemetry, remote destructive authority, and confirmation policy
  are explicit policy objects and must fail closed on unknown values.
- Protocol compatibility is a first-class UX state. Unknown daemon capability
  or incompatible protocol blocks risky actions by default.
- Disconnected, degraded, offline, restarting, updated, or incompatible daemon
  state disables risky actions. Cached read-only views must be clearly stale.
- Startup hydration restores config, preferences, route, daemon session,
  compatibility, capabilities, and optional caches in stages. Route/cache
  restore must not restore destructive authority before validation.
- Permission repair is complete only after the scanner process identity
  re-probes access and publishes updated capability/scan-quality evidence.
- History and compare views operate on explicit snapshot ids. Historical nodes
  are not current cleanup targets without current validation.
- Table columns are UI preference, while sort/filter/query semantics are typed
  application/Rust contracts. Flutter must not sort/filter the full scan tree.
- Command ids, semantic classification codes, protocol keys, and policy codes
  are stable identifiers, not localized labels or display names.

## Native Scanner Guardrails

- Rust native logic is split into three layers: reusable `fs_usage_*` library crates, the Clean Disk Rust host (`clean-disk-server`), and Flutter client code.
- `fs_usage_*` owns reusable scan sessions, read models, ports, indexes, metadata enrichment, capability reporting, and optional cleanup primitives. It must not depend on Clean Disk protocol, Flutter, HTTP/WebSocket, or app-specific UI.
- `clean-disk-server` is the host/composition root. It owns process lifecycle, local token/origin policy, config, protocol mapping, transport, observability, and concrete adapter wiring.
- Local runtime uses one `clean-disk-server` daemon process with internal bounded worker pools and resource budgets. Do not introduce local microservices or distributed workers unless the architecture is explicitly revisited.
- The accepted initial transport is HTTP commands/queries plus plain WebSocket events. JSON-RPC, Socket.IO, gRPC, gRPC-Web, and FRB are future adapter candidates only, not MVP transport choices.
- Flutter uses small product protocol adapters: `CleanDiskApiClient` over the existing `abstract_http_client` and `ScanEventClient` for WebSocket events. Do not scatter raw routes or socket parsing through repositories.
- The selected scanner plan is `parallel-disk-usage` as a Rust library adapter: final tree plus progress stream.
- Do not wrap the `pdu` CLI as the production integration unless explicitly revisited. CLI wrapping is acceptable only for throwaway prototypes.
- On macOS, the production scanner must be a signed Clean Disk app component or bundled helper. Do not launch an external/random `pdu` binary for production scans because Full Disk Access/TCC authority depends on the process identity, code requirement, and responsible bundle.
- Capability probing, real scanning, metadata enrichment, and delete preflight must run under the same scanner process identity.
- Treat `pdu` or any other scanner crate/process as an adapter.
- Only the dedicated pdu adapter crate should import `parallel_disk_usage`.
- Keep reusable Rust scanner contracts in `fs_usage_engine` ports. Keep Flutter-side scan client contracts in feature application ports.
- Keep Rust core independent from Flutter DTOs where practical.
- Use an opaque scan session handle plus event stream and paginated node queries when the bridge is added.
- Rust owns the full scan tree and indexes. Flutter must not receive or keep the entire tree.
- Stream progress/errors/skipped/hardlink information at a throttled rate. Do not emit one UI event per filesystem entry.
- Query tree data by pages: children, top folders, top files, search results, selected node details.
- Sort and filter large scan results in Rust, then return pages to Flutter.
- Scanner, indexing, cleanup, and event delivery must run under explicit resource budgets. Balanced mode preserves UI/system responsiveness by default; Fast mode is opt-in; Background mode reduces CPU/IO pressure where the OS allows it.
- Logs, metrics, traces, crash summaries, support bundles, and telemetry must classify data before export. Never log daemon tokens, auth headers, raw paths, raw search text, full scan trees, or delete target paths in production; avoid high-cardinality path/user/query labels in metrics.
- Keep `flutter_rust_bridge` DTOs separate from domain models. Domain must not depend on generated bridge code.
- Keep protocol DTOs separate from domain, persistence, generated clients, and Flutter view state. Exact byte sizes, large counters, IDs, cursors, and event sequences must not rely on JSON numeric precision in Flutter web.
- Session lifecycle must be explicit: create, start, cancel, query, dispose.
- Web is a UI surface. Full disk scanning must run through a local Rust process/bridge, not browser filesystem APIs. If using a localhost daemon for web UI, require a local session token, origin allowlist, and randomized/local-only port.
- The default local web path should be daemon-served loopback UI, not a hosted website connecting to localhost, until hosted pairing/CORS/PNA policy is explicitly implemented.
- Do not enable offline-first service worker behavior for daemon-served UI until update/version compatibility semantics are designed.
- Deletion must go through an explicit confirmation workflow and a trash/quarantine adapter where the platform supports it.
- Before delete/move-to-trash, revalidate current path, metadata, and selected node identity to avoid stale scan data deleting the wrong target.
- Reclaim estimates must distinguish logical/app-visible size, allocated local size, exclusive reclaim estimate, confidence, quota effect, and observed free-space delta. Snapshots, clones/reflinks, dedupe, sparse/compressed files, cloud placeholders, open files, and shared extents lower confidence; never claim exact freed bytes unless observed or proven.
- Permission errors, skipped paths, locked files, symlinks/reparse points, hardlinks, mount boundaries, and files changing during scan are first-class states, not generic failures.
- Developer tool storage must be classified conservatively. Prefer official cleanup adapters over raw folder deletion, and never treat Docker volumes, Xcode Archives, Android AVDs, SDK packages, Homebrew Cellar, shared package stores, or unknown tool folders as ordinary cache.

## Runtime Configuration

App runtime config is read from Dart defines:

- `CLEAN_DISK_FLAVOR` - `development`, `staging`, or `production`.
- `CLEAN_DISK_API_BASE_URL` - optional HTTP API base URL for future backend adapters.
- `CLEAN_DISK_STORAGE_BASE_URL` - optional storage/media base URL for future backend adapters.

Do not concatenate URLs as strings. Use typed config and adapter objects.

## Architecture Guardrails

Each feature package follows:

```text
domain -> application -> data/presentation -> di
```

Domain and application layers must not import Flutter, Dio, Drift, MobX, GetIt, Modularity, Headless, design system UI, pdu, Rust bridge bindings, or platform process APIs.

Boundary tests should protect core, network, scanner contracts, and feature domain/application layers from accidental framework or infrastructure imports.
