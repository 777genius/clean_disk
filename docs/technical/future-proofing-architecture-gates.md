# Future-Proofing Architecture Gates

Last updated: 2026-05-16.

This document records future-facing architecture rules that must shape the MVP contracts now, without pulling future features into MVP.

## Core Decision

Build the MVP quickly, but make the public contracts future-shaped.

Accepted best approach:

1. Stable contracts plus simple implementation - 🎯 10 🛡️ 9 🧠 7, roughly 4000-8000 LOC.
   This is the selected path. The contracts are designed for segmented snapshots, multiple backends, helper/service execution, remote/headless, scan history, and safe cleanup. The MVP implementation stays simple: one pdu scan, one segment, lazy metadata, paginated queries.
2. Build the full future now - 🎯 5 🛡️ 7 🧠 10, roughly 20000-40000 LOC.
   Rejected for MVP. It would delay product validation and force too many unproven abstractions.
3. Hack MVP now and rewrite later - 🎯 4 🛡️ 4 🧠 5, roughly 3000-6000 LOC now plus a major rewrite.
   Rejected. It would likely break cleanup safety, remote/headless, scan history, Windows fast path, and reusable library boundaries.

Accepted strategy:

1. Single pdu scan MVP with future-shaped snapshot contracts - 🎯 9 🛡️ 9 🧠 6, roughly 4000-7500 LOC.
2. Adaptive segmented snapshot engine later - 🎯 9 🛡️ 9 🧠 8, roughly 9000-18000 LOC.
3. Signed helper or service execution adapter later - 🎯 8 🛡️ 10 🧠 9, roughly 14000-28000 LOC.

Meaning:

- MVP can use one pdu scan and one segment.
- `NodeRef`, `Snapshot`, protocol DTOs, capabilities, and execution boundary must already support multiple segments/backends.
- Flutter and Clean Disk protocol must not know whether a snapshot came from one pdu scan, many shards, Windows MFT, APFS-specific backend, or remote agent.

## Irreversible Vs Reversible Decisions

Treat these as hard-to-change foundation decisions:

- node identity;
- size and reclaim semantics;
- protocol versioning;
- snapshot format;
- cleanup authority boundary;
- operation journal;
- public reusable library boundary;
- path encoding and exact-number transport;
- capability model;
- remote/headless authority model.

Treat these as replaceable implementation choices:

- pdu as the first scanner backend;
- single segment versus many segments;
- in-process scanner versus helper process;
- concrete search index;
- concrete metadata cache;
- concrete map renderer;
- concrete Trash adapter implementation;
- Windows MFT and APFS-specific backends;
- recommendation rule engine internals.

Rule:

```text
Make irreversible decisions conservative now.
Keep reversible choices behind ports/adapters.
```

## MVP Contract Checklist

The first implementation must include these contract shapes even if some fields are empty or degraded:

- `NodeRef` is opaque and snapshot-scoped.
- `Snapshot` supports multiple segments, while MVP may create one segment.
- `SizeFacts` separates logical, allocated, measured policy, reclaim estimate, confidence, and evidence.
- `Capabilities` drive UI behavior instead of OS/backend branching.
- `ScannerExecutionAdapter` hides in-process pdu so helper/service execution can replace it later.
- `SelectionSet` exists as the only bridge from scan UI selection to future cleanup planning.
- `DeletePlan`, `Preflight`, `Receipt`, and `ObservedEffect` are reserved model concepts even if cleanup is not MVP.
- Protocol DTOs are versioned and use exact-safe encodings for ids, cursors, sequences, and large counters.
- Snapshot lifecycle includes stale/invalidated/disposed states.
- Remote/headless contracts start read-only.
- Support/diagnostic data has privacy classes from the start.

MVP may defer:

- segmented shard scheduler;
- signed helper process;
- Windows MFT backend;
- APFS clone/snapshot accounting;
- remote destructive cleanup;
- public stable library semver;
- plugin API;
- full watcher/incremental scan engine;
- content hash duplicate detection;
- recommendation rule packs.

## Future Blockers To Avoid

### 1. Path-Shaped Identity

Risk: if node identity is a path, future rename, non-UTF8 names, hardlinks, symlinks, reparse points, cloud placeholders, case conflicts, and remote agents all become fragile.

Required now:

```text
NodeRef
  snapshot_id
  segment_id
  local_id
  generation
```

Protocol representation should be opaque string:

```text
sn_42.sg_7.n_39144.g_1
```

Path is display and revalidation input, not identity.

### 2. One-Number Size Model

Risk: if the product has only `size: u64`, it cannot honestly explain allocated size, logical size, shared extents, snapshots, hardlinks, cloud placeholders, quota effects, or actual reclaimed space.

Required now:

```text
SizeFacts
  logical_size
  allocated_size
  measured_size_policy
  hardlink_policy
  exclusive_reclaim_estimate
  quota_effect_estimate
  confidence
  evidence_refs
```

MVP can populate only the facts pdu supports, but the model must not collapse the future accounting problem into one byte value.

### 3. Unjournaled Cleanup

Risk: cleanup later becomes unsafe if the UI can move from selected row to delete operation without persisted intent, revalidation, and receipt.

Required now:

```text
scan_snapshot
  -> selection_set
  -> delete_plan
  -> preflight
  -> execution
  -> receipt
  -> observed_free_space_delta
```

Even if MVP is scan-only, API and UI state must not normalize "delete by path".

### 4. Version Drift

Risk: desktop app, daemon, helper, cached snapshots, web UI, rule packs, and scanner backend will eventually have different versions after update or rollback.

Required now:

```text
protocol_version
daemon_version
client_version
scanner_backend_id
scanner_backend_version
snapshot_format_version
capability_schema_version
receipt_schema_version
rule_pack_version
min_supported_client_version
min_supported_daemon_version
```

The UI must be able to degrade, ask for rescan, or report incompatible daemon instead of crashing.

### 5. Capability-Blind UI

Risk: UI becomes OS/backend-specific and later breaks when Windows MFT, APFS, Linux headless, remote agent, or helper process has different abilities.

Required now:

```text
Capabilities
  can_scan
  can_scan_allocated_size
  can_read_metadata
  can_estimate_exclusive_reclaim
  can_trash
  can_fast_cancel
  supports_hardlink_evidence
  supports_cloud_state
  supports_remote_readonly
  supports_remote_cleanup
```

UI asks capabilities, not "is macOS" or "is pdu".

## Contracts To Shape Now

### Snapshot

```text
Snapshot
  snapshot_id
  snapshot_format_version
  scanner_backend_id
  scanner_backend_version
  created_at
  traversal_policy
  size_policy
  hardlink_policy
  segments
  indexes
  issue_store
  metadata_store
  lifecycle_state
```

MVP can have one segment. Future segmented scans can add more segments without changing Flutter.

### Snapshot Lifecycle

```text
creating
preflighting
scanning
converting
indexing
ready_partial
ready
likely_stale
stale
invalidated
disposed
```

Snapshots must be explicitly disposed. Daemon must not hold old scan graphs forever.

### Segment

```text
SegmentArena
  parent
  first_child
  child_count
  name_ref
  size_facts_ref
  flags
  issue_count
  metadata_state
```

No full `PathBuf` per node. Full path is reconstructed on demand by `PathResolver`.

### SelectionSet

```text
SelectionSet
  snapshot_id
  selected_node_refs
  selection_policy
  captured_identity_evidence
  captured_size_facts
  created_at
```

Selection is not a list of paths. DeletePlan must revalidate before execution.

### Operation Journal

```text
OperationJournal
  operation_id
  operation_type
  intent
  preflight_result
  per_item_outcomes
  receipt
  observed_effect
  recovery_state
```

If cleanup truth cannot be persisted, cleanup must not run.

### Policy Objects

Policy should be explicit objects, not scattered booleans:

```text
TraversalPolicy
ResourcePolicy
MetadataPolicy
CleanupPolicy
PrivacyPolicy
RemoteAuthorityPolicy
RecommendationPolicy
```

This keeps future enterprise/server modes from leaking into random conditionals.

## Future Features That Must Not Be Blocked

### Scan History And Compare

Users will expect:

```text
what changed since last scan
which folders grew
export report
scheduled scan comparison
```

Need now:

- snapshot ids and generations;
- backend/version/size policy stored with snapshot;
- compare-ready path fingerprint;
- optional platform file identity where available;
- stale/invalidated snapshot states.

### Incremental Scans And Watchers

Do not implement watchers in MVP, but keep room for:

- watcher invalidation events;
- `must_rescan_subtree` states;
- dropped event recovery;
- subtree refresh;
- stale query result markers.

### Remote/Headless

Remote starts read-only:

```text
scan
query
export
diagnostics
```

Remote destructive cleanup stays future-only until target scopes, authZ, audit, quotas, receipts, and policy gates are proven.

### Windows MFT And APFS Accounting

Future backends must fit the same contracts:

```text
pdu_backend
windows_mft_backend
apfs_accounting_backend
remote_agent_backend
fixture_backend
```

Backend-specific facts go into capabilities and evidence, not into UI branches.

### Recommendations And Rule Packs

Recommendations must be evidence-backed:

```text
rule_id
rule_version
evidence_required
risk_tier
official_cleanup_adapter
explanation
stale_invalidation_policy
```

Plugins or rule packs can propose candidates. They cannot execute cleanup or bypass DeletePlan.

### Low-Disk Mode

When the system is already low on space:

- no huge cache writes;
- no full debug export by default;
- smaller event buffers;
- no idle metadata prefetch;
- emergency cleanup suggestions are conservative;
- journal/receipt durability still wins over convenience.

### Update And Rollback

After update or rollback, re-probe:

- daemon protocol compatibility;
- scanner backend version;
- helper identity;
- macOS Full Disk Access/TCC status;
- snapshot format compatibility;
- rule pack compatibility;
- receipt schema compatibility.

### Diagnostics And Privacy

Every data field needs a privacy class:

```text
safe_metric
native_path
search_text
delete_target
token
receipt_evidence
raw_tree
support_bundle_export
```

Default logs and support bundles must not include raw paths, tokens, full scan trees, or delete targets.

### Benchmark Fixture Lab

Before release, keep fixtures for:

- 100k nodes;
- 1M nodes;
- synthetic 5M nodes;
- deep tree;
- wide tree;
- permission denied;
- hardlinks;
- symlinks;
- sparse files;
- non-UTF8 names;
- cloud placeholders;
- network mounts;
- files changing during scan;
- low disk;
- daemon crash during cleanup.

Gates should include:

- peak memory;
- control-lane latency;
- query p95;
- cancellation latency;
- scan-quality classification;
- support bundle redaction;
- cleanup receipt durability.

## Operational Future Gates

These gates are not extra MVP features. They are future constraints that must be visible in contracts now so the product can grow without rewriting scanner, protocol, UI state, or cleanup safety.

### UI And Daemon Version Compatibility

Even if the MVP ships UI and daemon together, the product must assume mixed versions will happen later:

- desktop UI updated while daemon is still old;
- daemon restarted during a scan;
- web UI loaded from stale assets;
- desktop app attached to an already running daemon;
- remote/headless client uses a different protocol version;
- rollback leaves a newer database, journal, or cached snapshot behind.

Required contract shape:

```text
GET /health
GET /capabilities
GET /compatibility
```

Compatibility state must be a product state, not a crash or generic network error. UI can degrade, request daemon restart, disable cleanup, or ask for rescan.

Top option:

1. Versioned health, capabilities, and compatibility handshake - 🎯 10 🛡️ 10 🧠 6, roughly 400-900 LOC.
   This should be part of the first daemon protocol slice.

### Snapshot Lifecycle As Product State

A scan result is not just a tree. It is a versioned snapshot with lifecycle and invalidation behavior:

```text
creating
preflighting
scanning
indexing
ready
ready_partial
likely_stale
stale
invalidated
disposed
```

Required behavior:

- every query references a snapshot id;
- delete planning references a snapshot id and revalidates identity;
- search, top files, details, and export declare whether data is fresh or stale;
- history/compare can reuse the same snapshot contract later;
- partial refresh or segmented scans can add segments without changing Flutter.

Top option:

1. Snapshot lifecycle and opaque node references from day one - 🎯 10 🛡️ 9 🧠 7, roughly 800-1800 LOC.

### Multi-Client Daemon Model

Future clients can include desktop UI, daemon-served web UI, CLI, remote dashboard, and support tooling. The daemon must not assume one UI owns the world.

Required concepts:

```text
client_id
session_owner
session_observer
event_cursor
operation_id
permission_scope
```

Rules:

- scan owner can cancel its scan;
- observers can query and subscribe where policy allows;
- reconnect resumes events by cursor where possible;
- stale clients cannot execute destructive commands after compatibility changes;
- closing one UI must not leak scan sessions forever.

Top option:

1. Session owner plus observers plus resumable event cursor - 🎯 9 🛡️ 9 🧠 8, roughly 1000-2500 LOC.

### Local State, Cache, And Migrations

Drift/SQLite will eventually store more than UI cache:

- recent scans;
- operation journal;
- cleanup receipts;
- user settings;
- ignored paths;
- recommendation dismissals;
- benchmark profiles;
- daemon pairing/session state;
- support export metadata.

Required gates:

- schema version and compatibility policy;
- forward-only migrations;
- corruption recovery path;
- retention policy;
- privacy-safe support export;
- low-disk behavior that preserves journal/receipt durability first.

Top option:

1. Durable state classes with migration and retention policy - 🎯 9 🛡️ 9 🧠 7, roughly 1000-2200 LOC.

### Installer, Updates, And Permission Identity

Desktop product risk is often installer and identity, not app code.

Future release gates:

- macOS signed app/helper identity is stable across updates;
- Full Disk Access onboarding and re-probe are explicit;
- Windows installer chooses per-user or machine mode deliberately;
- Windows Defender false-positive handling is part of release readiness;
- Linux package mode is explicit: AppImage, deb/rpm, Flatpak, or Snap;
- daemon restarts after update without orphaning operations;
- rollback checks protocol, DB, journal, receipt, and helper compatibility;
- uninstall does not destroy receipts or user audit history without explicit choice.

Top option:

1. Release compatibility manifest and helper identity re-probe - 🎯 8 🛡️ 10 🧠 8, roughly 1500-4000 LOC across release milestones.

### Recommendation And Rule Pack Safety

Recommendations must be explainers, not hidden delete scripts.

Required model:

```text
rule_id
rule_version
rule_pack_version
risk_tier
evidence
official_cleanup_adapter
stale_invalidation_policy
```

Rules:

- recommendation does not execute cleanup;
- rule pack cannot bypass DeletePlan;
- every candidate has evidence and risk tier;
- tool-managed storage prefers official cleanup adapters;
- unknown folders are not called cache;
- rule pack updates invalidate stale recommendations where semantics changed.

Top option:

1. Evidence-backed recommendation model before rule packs execute anything - 🎯 9 🛡️ 10 🧠 8, roughly 2000-5000 LOC.

### Hard Data And Resource Budgets

Budgets are architecture, not tuning.

Required budget classes:

- max nodes retained per snapshot tier;
- max event rate;
- max WebSocket queue;
- max page size;
- max search result page;
- max path/display string size in DTOs;
- max log line size;
- max support bundle size;
- max operation journal growth;
- control-lane latency budget;
- cancellation latency budget;
- memory budget per scan profile.

Top option:

1. Budget policy objects with enforceable defaults - 🎯 10 🛡️ 10 🧠 5, roughly 300-900 LOC for initial policy and guards.

### Public API Discipline

Treat local protocol as public from the start because desktop UI, web UI, CLI, tests, and remote/headless clients will all depend on it.

Rules:

- domain models are not wire DTOs;
- pdu types never cross protocol;
- large counters and ids use exact-safe encoding for Flutter web;
- enum evolution has unknown handling;
- timestamps have one explicit encoding policy;
- path data separates display text from raw encoded representation;
- destructive command payloads reject unknown unsafe fields unless compatibility policy says otherwise.

Top option:

1. Versioned DTOs plus schema and compatibility fixtures - 🎯 9 🛡️ 9 🧠 6, roughly 700-1500 LOC.

### Degraded Mode And Repair Actions

The app must remain understandable when capabilities are missing.

States to model:

- Full Disk Access missing;
- daemon unavailable;
- WebSocket disconnected;
- pdu backend unavailable;
- scan partial;
- low disk;
- external volume disconnected;
- cloud provider offline;
- network mount slow;
- cleanup unsupported;
- reclaim estimate low confidence.

Every degraded state should map to:

```text
capability_state
user_message_key
repair_action
safety_impact
feature_disabled_reason
```

Top option:

1. Capability-first degraded mode with repair actions - 🎯 9 🛡️ 9 🧠 7, roughly 1200-2600 LOC.

### Design System Future

Clean Disk is a dense productivity UI, not a landing page. The design system must carry the complexity instead of feature widgets reinventing primitives.

Critical future primitives:

- virtualized tree table;
- accessible disclosure rows;
- sortable and resizable columns;
- split panes;
- command palette;
- operation status and toasts;
- confirmation dialogs;
- cleanup queue controls;
- keyboard navigation;
- compact layout primitives.

Rule:

```text
If Headless or design_system lacks a critical primitive, improve the shared primitive first or record the gap before creating a feature-local workaround.
```

Top option:

1. Shared dense-productivity primitives in design_system over Headless - 🎯 8 🛡️ 8 🧠 8, roughly 2000-6000 LOC over time.

## Strategic Flexibility Future Gates

These gates protect long-term product optionality. The product should be able to grow from a fast local disk scanner into a storage intelligence runtime without rewriting core contracts.

### Bounded Contexts

Do not let one `scan` module absorb every future concept.

Future bounded contexts:

```text
Scanning
Accounting
Indexing
Recommendations
Cleanup
Operations
Permissions
Diagnostics
Settings
Reports
RemoteAccess
```

MVP can have fewer crates/packages, but the language and model boundaries must stay clean:

- `SizeFacts` belongs to accounting, not cleanup;
- `DeletePlan` belongs to cleanup, not scanner;
- `CapabilityReport` belongs to runtime/application boundary, not UI widgets;
- `OperationJournal` belongs to operations, not scanner internals;
- recommendation evidence is layered over filesystem facts, not mixed into raw traversal.

Top option:

1. Keep bounded contexts as explicit modules and names before splitting crates - 🎯 9 🛡️ 9 🧠 7, roughly 800-2000 LOC.

### Target Model

The product must not treat every scan target as only a filesystem path.

Future targets include:

- volume;
- home directory;
- app sandbox;
- network share;
- cloud sync root;
- Docker storage;
- Xcode DerivedData;
- remote server path;
- selected subtree from an old snapshot;
- fixture/test tree.

Required contract shape:

```text
ScanTarget
  target_id
  target_kind
  display_name
  root_authority
  platform_identity
  access_scope
  traversal_policy
```

Path is one input to target resolution. It is not the full target identity or authority.

Top option:

1. Typed ScanTarget contract from the first scan API - 🎯 10 🛡️ 9 🧠 6, roughly 400-1000 LOC.

### Semantic Layers Over Filesystem Facts

Raw filesystem traversal should stay separate from user-facing meaning.

Pipeline:

```text
raw filesystem tree
  -> metadata enrichment
  -> semantic classification
  -> recommendations
  -> cleanup planning
```

Semantic classes can include:

- cache;
- logs;
- build artifacts;
- downloads;
- app data;
- user-created documents;
- cloud placeholders;
- tool-managed storage;
- unknown.

Rules:

- raw scanner does not decide what is safe to delete;
- semantic classification records evidence and confidence;
- recommendation rules consume semantic facts, not raw folder names only;
- cleanup planning revalidates identity and policy regardless of semantic label.

Top option:

1. Classification as an adapter/use-case layer above scan facts - 🎯 9 🛡️ 10 🧠 7, roughly 1200-3000 LOC when introduced.

### Shared Confidence And Evidence Model

Confidence should not be a one-off field for reclaim estimates. It is a reusable pattern for every uncertain claim.

Use the same shape for scan quality, accounting, cloud state, recommendations, duplicates, cleanup risk, and stale snapshots:

```text
confidence
evidence
limitations
risk_reasons
```

Rules:

- no recommendation without evidence;
- no exact reclaim claim without observed or proven basis;
- partial scan states include confidence and limitations;
- stale snapshots degrade confidence instead of pretending to be fresh.

Top option:

1. Shared evidence/confidence value objects - 🎯 10 🛡️ 10 🧠 6, roughly 500-1200 LOC.

### Scheduler Lanes Beyond Worker Pools

A worker pool controls parallelism. A scheduler controls priorities and fairness.

Future work types will compete:

- scan traversal;
- metadata enrichment;
- indexing;
- search;
- export;
- cleanup preflight;
- cleanup execution;
- support bundle generation;
- background refresh.

Required lane model:

```text
control_lane
foreground_scan_lane
background_enrichment_lane
cleanup_lane
diagnostics_lane
```

Rules:

- control lane keeps cancel, pause, health, and compatibility responsive;
- cleanup lane has stricter durability and cancellation semantics;
- background enrichment yields to foreground UI queries;
- resource budgets apply per lane and process-wide.

Top option:

1. Scheduler lanes as policy contracts, simple executor in MVP - 🎯 9 🛡️ 10 🧠 8, roughly 1000-2500 LOC.

### Product Trust Ledger

Users and support need an understandable history of important actions, not only debug logs.

Future ledger events:

- scan started;
- scan completed partially;
- permission coverage changed;
- candidate added to cleanup queue;
- preflight failed;
- item moved to Trash;
- official cleanup command executed;
- observed free-space delta recorded;
- restore info unavailable;
- daemon restarted during operation.

The ledger is not verbose telemetry. It is user-visible or support-visible operational truth with privacy classes.

Top option:

1. OperationLedger over the same durable journal foundation - 🎯 9 🛡️ 10 🧠 7, roughly 1200-3000 LOC.

### Headless API With Explicit Authority Scopes

Read/query/export can be universal. Destructive authority cannot be implied by transport.

Required contract shape:

```text
authority_scope
target_scope
command_scope
client_identity
policy_decision
audit_ref
```

Rules:

- local desktop cleanup is not the same authority as remote cleanup;
- remote/headless starts read-only;
- destructive commands require policy and audit;
- stale clients cannot execute commands after compatibility or policy changes.

Top option:

1. Authority scopes in command metadata before remote cleanup exists - 🎯 9 🛡️ 10 🧠 7, roughly 800-1800 LOC.

### Dependency And Supply-Chain Governance

If `fs_usage_*` becomes reusable, dependency choices become product and ecosystem constraints.

Every Rust/Dart dependency needs:

```text
license
maintenance_status
release_cadence
security_history
native_build_impact
transitive_risk
replacement_path
```

Special scrutiny:

- scanner crates;
- platform permission helpers;
- updater/installer libraries;
- archive/export libraries;
- chart/visualization libraries;
- telemetry/crash reporting libraries;
- procedural macros and build scripts.

Top option:

1. Lightweight dependency intake checklist before adding libraries - 🎯 9 🛡️ 9 🧠 5, roughly 200-700 LOC plus docs/checks.

### Internationalized And Safe Path Display

Paths are not ordinary strings.

Future path edge cases:

- non-UTF8 names;
- Unicode normalization;
- bidi and RTL text;
- emoji filenames;
- very long paths;
- case-insensitive conflicts;
- Windows reserved names;
- invalid display/control characters;
- cloud-provider virtual paths.

Required split:

```text
PathIdentity
PathDisplay
PathRawEncoded
PathSearchKey
```

Rules:

- display path is never destructive authority;
- raw encoded path is not blindly rendered;
- search normalization is separate from identity;
- support bundles redact path display by privacy profile.

Top option:

1. Path display and identity split in DTOs and domain value objects - 🎯 10 🛡️ 10 🧠 7, roughly 700-1800 LOC.

### Business And Distribution Optionality

Do not build billing now. Do avoid contracts that make future product modes impossible.

Possible future modes:

- local desktop free;
- pro developer cleanup;
- team/headless reports;
- enterprise policy/audit;
- support diagnostics;
- internal or public rule marketplace.

Rules:

- core scan/accounting contracts stay product-mode neutral;
- capabilities and policies drive availability;
- diagnostics and audit have privacy classes from the start;
- reusable library contracts must not depend on Clean Disk branding or UI concepts.

Top option:

1. Product-mode neutral core with capability/policy gates - 🎯 8 🛡️ 9 🧠 6, roughly 500-1500 LOC.

## Long-Term Product And Safety Gates

These gates protect the product after it has real users, old data, updates, support cases, and smarter recommendations. They must not force MVP scope, but the contracts should not make them impossible.

### Data Lifecycle Classes

Not all local data has the same durability, privacy, or migration requirements.

Required lifecycle classes:

```text
session_data
snapshot_cache
rebuildable_index
operation_journal
cleanup_receipt
user_setting
policy_state
support_bundle
compatibility_fixture
```

Rules:

- session data can be discarded after scan/session end;
- snapshot cache can be invalidated and rebuilt;
- indexes are rebuildable projections, not product truth;
- operation journal and cleanup receipts are durable;
- settings and policies are migrated deliberately;
- support bundles are explicit exports with privacy profiles;
- compatibility fixtures are release assets, not temporary tests.

Top option:

1. Data lifecycle classes in persistence and protocol docs - 🎯 10 🛡️ 10 🧠 6, roughly 500-1500 LOC.

### Adversarial Filesystem Assumption

The filesystem can change under us and can contain hostile or confusing names.

Cases to assume:

- file replaced between scan and cleanup;
- symlink race;
- mount disconnected;
- permissions changed;
- growing file during scan;
- non-UTF8 or control characters in names;
- Unicode normalization makes two paths look similar;
- very long path;
- cloud provider virtual path;
- archive or external volume with unusual metadata.

Rule:

```text
scan data is evidence, not authority
```

Every destructive or user-visible trust claim needs revalidation, confidence, and limitations.

Top option:

1. Revalidation-first action model - 🎯 10 🛡️ 10 🧠 7, roughly 1000-2500 LOC across cleanup and metadata gates.

### Kill Switches And Safety Gates

Real products need emergency switches when a rule, adapter, update, or backend behaves badly.

Required switches:

- disable cleanup globally;
- disable specific cleanup adapter;
- disable specific rule pack;
- force read-only mode;
- disable remote destructive commands;
- disable Fast scan profile;
- require rescan after update;
- disable a scanner backend by capability state.

Rules:

- kill switches can reduce capability;
- kill switches cannot grant authority;
- cleanup disabled means DeletePlan execution is unavailable, not hidden;
- support bundle should include redacted kill-switch state.

Top option:

1. Safety kill switches as policy inputs - 🎯 9 🛡️ 10 🧠 6, roughly 600-1600 LOC.

### Feature Flags Without Safety Bypass

Feature flags are useful for staged rollout, but dangerous if they bypass architecture gates.

Rules:

```text
feature flag can disable risk
feature flag cannot bypass policy
feature flag cannot enable cleanup if compatibility failed
feature flag cannot override authority scope
feature flag cannot skip receipt durability
```

Top option:

1. Feature flags as capability modifiers only - 🎯 9 🛡️ 9 🧠 5, roughly 300-900 LOC.

### Projection Model

Every UI view should be a projection over snapshot facts, not a separate source of truth.

Projection pipeline:

```text
Snapshot
  -> indexes
  -> projection query
  -> page/cursor
  -> UI view model
```

Future projections:

- tree table;
- top folders;
- top files;
- search results;
- treemap/sunburst data;
- details panel;
- cleanup queue;
- history compare;
- recommendations;
- reports/export.

Rules:

- projections are rebuildable;
- projections include snapshot id and version;
- UI never merges projection results into product truth;
- Rust owns sorting/filtering/search for large datasets.

Top option:

1. Typed projection/query model over snapshots - 🎯 9 🛡️ 9 🧠 7, roughly 1000-2500 LOC.

### Typed Query Future

Search can start simple, but the protocol should not trap us in one free-text string.

Future query examples:

```text
size > 1GB
kind == cache
modified_before 30d
path_contains Library
confidence == low
reclaimable == true
```

Required contract direction:

```text
QueryDto
  text
  filters
  sort
  page
  projection
```

Rules:

- free text is one field, not the entire search contract;
- filters are typed and versioned;
- expensive filters report unsupported or degraded capability;
- query limits are enforced by resource policy.

Top option:

1. Typed query DTO with simple MVP implementation - 🎯 9 🛡️ 9 🧠 6, roughly 500-1200 LOC.

### Export Profiles

Export is a product feature, not a raw dump.

Future export types:

- biggest folders report;
- scan comparison report;
- cleanup receipt;
- before/after cleanup report;
- support bundle;
- audit report;
- machine-readable headless output.

Required profiles:

```text
redacted
support_safe
local_full_paths
audit_grade
machine_readable
```

Rules:

- every export declares privacy profile;
- raw paths require explicit local profile;
- support exports redact by default;
- machine-readable output still follows protocol compatibility and exact-number rules.

Top option:

1. Export profiles plus privacy classes - 🎯 9 🛡️ 9 🧠 6, roughly 800-2000 LOC.

### Compatibility Corpus

Compatibility must become a release asset, not only test code.

Corpus should include:

- old protocol DTOs;
- old event streams;
- old snapshots;
- old receipts;
- old rule packs;
- old support bundles;
- old DB migration inputs;
- weird path cases;
- permission and partial-scan cases.

Rules:

- never delete old fixtures only because tests got updated;
- every breaking change has explicit compatibility decision;
- old clients decode unknown safe fields;
- destructive semantics require stricter compatibility than read-only queries.

Top option:

1. Compatibility corpus as release asset - 🎯 10 🛡️ 10 🧠 7, roughly 1000-3000 LOC over time.

### AI And Smart Recommendation Boundary

Future AI or smart recommendations can help classification and explanation, but must not own authority.

Rule:

```text
AI/recommendation can suggest.
DeletePlan decides.
User confirms.
Policy authorizes.
Journal records.
```

Required constraints:

- no direct delete authority;
- no hidden command execution;
- evidence and risk tier required;
- recommendation output is stale after relevant snapshot/rule changes;
- explanations must be reproducible enough for support and review.

Top option:

1. AI/recommendation without authority - 🎯 9 🛡️ 10 🧠 8, roughly 2000-6000 LOC later.

### Tenant, Machine, User, And Client Boundary

Remote/headless, web UI, helpers, and support tools need distinct identities.

Required concepts:

```text
machine_id
user_id
client_id
session_id
target_scope
authority_scope
audit_scope
```

Rules:

- local machine identity is not user identity;
- desktop UI, web UI, CLI, daemon, and helper are separate clients;
- audit scope is separate from telemetry;
- remote/headless starts with read-only scope.

Top option:

1. Identity scopes in protocol metadata before remote mode expands - 🎯 8 🛡️ 9 🧠 7, roughly 800-1800 LOC.

### Storage Semantics Versioning

Product words such as cache, duplicate, reclaimable, tool-managed, and safe candidate are semantic claims. They need versioning.

Required versions:

```text
semantic_model_version
classification_rule_version
recommendation_policy_version
cleanup_policy_version
```

Rules:

- old recommendations are invalidated when semantics change;
- reports include semantic version;
- receipts keep the semantic versions used at decision time;
- rule packs declare compatibility with semantic model version.

Top option:

1. Version semantic claims before recommendations become user-facing - 🎯 9 🛡️ 10 🧠 7, roughly 700-1800 LOC.

### Enterprise And Admin Future

Do not build enterprise now, but avoid blocking it.

Future admin policies:

- read-only scan mode;
- protected paths;
- allowed cleanup adapters;
- disabled remote cleanup;
- audit export;
- no raw paths in support bundles;
- signed rule packs only;
- maximum scan resource profile.

Rules:

- admin policy is another policy source, not UI conditionals;
- local personal mode remains simple;
- policy denial has user-visible reason and repair path.

Top option:

1. Policy-source abstraction without enterprise UI - 🎯 8 🛡️ 9 🧠 7, roughly 700-1600 LOC.

### Shell And Platform Actions

Platform actions should go through adapters, not direct UI calls.

Future actions:

- reveal in Finder/Explorer;
- open terminal here;
- copy path;
- drag and drop target;
- right-click "Scan with Clean Disk";
- show native properties;
- open official cleanup tool.

Rules:

- UI requests an action through an application port;
- platform adapter validates target identity and availability;
- action results are typed;
- destructive platform actions still go through cleanup policy.

Top option:

1. PlatformAction port with per-OS adapters - 🎯 8 🛡️ 8 🧠 6, roughly 600-1500 LOC.

### Accessibility As Safety

Accessibility is a product safety issue for cleanup and large tree navigation.

Required design constraints:

- keyboard navigation;
- screen-reader labels;
- row expansion semantics;
- focus order;
- high contrast;
- reduced motion;
- text scaling;
- no color-only meaning;
- accessible confirmation flow.

Rules:

- delete confirmation cannot rely on color or tiny text;
- tree rows must expose hierarchy and selected state;
- compact layout must preserve focus and semantics.

Top option:

1. Accessibility gates for tree, queue, and confirmation primitives - 🎯 8 🛡️ 9 🧠 7, roughly 1200-3000 LOC.

### Runtime Modes

Do not collapse all execution environments into one `baseUrl`.

Future runtime modes:

```text
local_desktop_daemon
daemon_served_web
hosted_web_with_pairing
remote_headless_server
read_only_report_viewer
test_fixture_runtime
```

Rules:

- each mode declares authority and capabilities;
- hosted web with localhost pairing is future-only until browser policy and pairing are proven;
- report viewer cannot mutate live state;
- test fixture runtime is explicit and cannot leak into production.

Top option:

1. RuntimeMode contract with capability mapping - 🎯 9 🛡️ 9 🧠 6, roughly 500-1200 LOC.

### Long-Term Library And SDK Shape

The reusable Rust library must stay clean if it may become useful outside Clean Disk.

Shape:

```text
fs_usage_core
fs_usage_engine
fs_usage_pdu
fs_usage_platform
clean_disk_server
```

Rules:

- `fs_usage_core` has no Clean Disk branding, Flutter DTOs, HTTP, pdu types, or UI concepts;
- public-stable semver waits until real product flows validate the API;
- stable error codes are introduced before external SDK users;
- MSRV and feature flags are explicit compatibility promises when public.

Top option:

1. Internal reusable library first, public SDK later - 🎯 9 🛡️ 9 🧠 7, roughly 1000-2500 LOC before public release.

### Architecture Entropy Budget

The long-term enemy is not one missing feature. It is uncontrolled exceptions.

Review rules:

- no platform branching in UI;
- no raw HTTP or WebSocket parsing in features;
- no pdu types outside pdu adapter;
- no delete by path;
- no full tree in Flutter;
- no feature-local copy of core primitives;
- no undocumented dependency;
- no capability bypass for convenience;
- no safety downgrade without a recorded decision.

Top option:

1. Architecture review checklist plus boundary tests - 🎯 10 🛡️ 9 🧠 5, roughly 300-1000 LOC plus review discipline.

## Organizational And Ecosystem Future Gates

These gates protect Clean Disk when the product has real incidents, platform changes, public releases, support tickets, old user data, and possibly an external library ecosystem. They are not MVP features, but the contracts should leave room for them.

### Incident Response And Recovery

If a rule pack, cleanup adapter, scanner backend, update, or release behaves badly, the product needs more than a kill switch.

Required response loop:

```text
detect incident
disable risky capability
notify UI
preserve receipts
offer recovery guidance
collect redacted diagnostics
ship fixed rule/app
```

Rules:

- incident response can reduce capability immediately;
- receipts and OperationLedger must preserve enough evidence to explain what happened;
- redacted diagnostics must not require raw path logging;
- UI must distinguish "feature disabled for safety" from ordinary failure;
- recovery guidance must be tied to receipts, not generic advice.

Top option:

1. Incident response flow over kill switches, receipts, and redacted diagnostics - 🎯 9 🛡️ 10 🧠 7, roughly 800-2000 LOC plus release process.

### Trust Channel And Revocation

Future updates, rule packs, and adapter policies need a trust channel.

Trust artifacts:

- signed app updates;
- signed rule packs;
- compatibility manifest;
- revocation list;
- known-bad adapter ids;
- known-bad rule ids;
- safety-impacting release notes;
- security advisory references.

Rules:

- trust channel can revoke or disable behavior;
- trust channel cannot grant destructive authority by itself;
- rule packs and adapters declare ids and versions;
- compatibility manifest is checked before enabling risky features;
- support bundles include redacted trust state.

Top option:

1. Signed trust channel with revocation and compatibility manifest - 🎯 9 🛡️ 10 🧠 8, roughly 1500-4000 LOC later.

### OS Evolution And Platform Drift

Operating systems, browsers, packaging systems, and cloud providers will change.

Future drift examples:

- macOS TCC or Full Disk Access behavior changes;
- Windows Defender, SmartScreen, UAC, or Recycle Bin behavior changes;
- browsers restrict localhost/private network access further;
- Linux sandbox packaging changes filesystem access;
- cloud providers change placeholder metadata or sync behavior;
- filesystems add new clone, compression, dedupe, or quota semantics.

Rules:

- platform behavior is discovered through capability probes;
- UI consumes degraded states, not hard-coded platform guesses;
- scanner, metadata, and cleanup preflight run under the same authority identity;
- platform drift can require rescan or feature disable.

Top option:

1. PlatformCapabilityProbe plus degraded capability states - 🎯 9 🛡️ 9 🧠 7, roughly 1000-2500 LOC.

### Data Quality Tiers

The product must distinguish what it observed from what it inferred.

Required data quality tiers:

```text
observed
measured
estimated
inferred
unknown
stale
```

Applies to:

- size facts;
- reclaim estimates;
- cloud state;
- scan completeness;
- recommendation safety;
- duplicate detection;
- history compare;
- cleanup risk.

Rules:

- UI must not present estimated or stale data as exact;
- reports include data quality tier;
- DeletePlan and Preflight can downgrade or reject low-quality evidence;
- recommendations must expose quality and limitations.

Top option:

1. Data quality tiers everywhere uncertain facts cross boundaries - 🎯 10 🛡️ 10 🧠 6, roughly 500-1200 LOC.

### User Intent Preservation

The most dangerous cleanup bug is losing what the user actually meant to select.

Selection records should preserve:

```text
selected_node_ref
display_path_at_selection
identity_evidence
size_facts_at_selection
selection_reason
preflight_diff
confirmation_text_version
```

Rules:

- stale scan selection must not silently execute;
- if target identity, type, size, or path changed materially, user confirms again;
- cleanup receipt stores both original intent and actual outcome;
- UI can explain why a selected item now needs revalidation.

Top option:

1. Intent-preserving SelectionSet and Preflight diff - 🎯 10 🛡️ 10 🧠 7, roughly 1000-2500 LOC.

### Public Library Governance

If `fs_usage_*` becomes public, it needs product-like governance, not only clean code.

Future public library requirements:

- roadmap;
- semver policy;
- deprecation policy;
- MSRV policy;
- feature flag policy;
- security policy;
- benchmark claims policy;
- examples and fixtures;
- stable error codes;
- compatibility fixtures.

Rules:

- no public-stable promise before Clean Disk validates real scan/query/cleanup flows;
- public API does not expose Clean Disk branding or UI concepts;
- benchmark claims state environment and data shape;
- deprecations preserve a migration path.

Top option:

1. Internal reusable library first, public governance before external stability - 🎯 9 🛡️ 9 🧠 7, roughly 1000-2500 LOC.

### Benchmark Honesty

Fast claims must be reproducible and not hide UI or system impact.

Benchmark tiers:

```text
cold_cache
warm_cache
ssd
external_hdd
network_mount
permission_heavy_tree
one_million_nodes
low_battery
background_mode
fast_mode
balanced_mode
```

Required metrics:

- scan elapsed time;
- peak memory;
- control-lane latency;
- cancellation latency;
- query p95;
- event pressure;
- UI responsiveness;
- skipped/error counts;
- scan quality tier.

Top option:

1. Benchmark matrix that measures speed and responsiveness - 🎯 10 🛡️ 9 🧠 7, roughly 1000-3000 LOC over time.

### Legal And Privacy Posture

Local-first does not eliminate privacy risk once exports, support bundles, diagnostics, crash reports, or telemetry exist.

Rules:

- no raw paths by default;
- explicit export consent;
- privacy profiles for every export;
- local-only full-path reports;
- retention policy for diagnostics;
- documented data collection boundaries;
- delete targets and search text are sensitive by default;
- support bundles are reviewable before sharing.

Top option:

1. Privacy posture as export/support/telemetry contract - 🎯 9 🛡️ 10 🧠 6, roughly 800-2000 LOC.

## Automation And Multi-Environment Future Gates

These gates protect future automation, multi-user machines, sync/account features, developer storage targets, diagnostics, and trust UX. They are especially important because each area can look harmless while silently expanding authority or data exposure.

### Automation Without Surprise

Future automation can be useful:

- scheduled scan;
- background scan;
- low-disk trigger;
- notify when a folder grows;
- weekly report;
- cleanup reminder.

Rule:

```text
automation can scan/report/suggest
automation cannot clean without explicit policy + user intent + receipt
```

Required model:

```text
AutomationPolicy
  trigger
  allowed_actions
  target_scope
  notification_policy
  authority_scope
  last_run_receipt
```

Rules:

- automation defaults to read-only;
- cleanup reminders are not cleanup execution;
- automated scans expose skipped/partial states;
- automated work uses background resource profile unless user elevates it;
- every automated action has an operation id and visible history.

Top option:

1. Automation can scan and report, not cleanup - 🎯 9 🛡️ 10 🧠 7, roughly 1000-2500 LOC.

### Multi-User Machine Boundaries

A single machine can have multiple OS users, admins, shared folders, mounted volumes, and helper processes with different rights.

Required identities:

```text
os_user
app_user
daemon_identity
helper_identity
target_owner
permission_scope
```

Rules:

- one user must not see another user's private paths just because a daemon can;
- scan targets declare owner and authority;
- shared folders are modeled as shared targets, not private home paths;
- admin/root elevation is a different authority state;
- support exports preserve user boundary redaction.

Top option:

1. Multi-user authority and visibility boundary - 🎯 9 🛡️ 10 🧠 8, roughly 1500-3500 LOC.

### Syncable Versus Local-Only State

If account, sync, team, or cloud features appear later, raw filesystem truth must not accidentally sync.

Syncable examples:

```text
theme
UI preferences
ignored rule ids
report templates
non-sensitive feature flags
```

Local-only examples:

```text
raw paths
snapshots
receipts with paths
daemon tokens
cleanup history
support bundles
machine identity
```

Rules:

- raw filesystem facts are local-only by default;
- sync requires explicit data classification;
- support bundles are never synced silently;
- daemon tokens and local pairing secrets never sync;
- report templates can sync, report contents do not unless exported intentionally.

Top option:

1. Local-only filesystem truth with explicit sync allowlist - 🎯 10 🛡️ 10 🧠 6, roughly 700-1800 LOC.

### Virtualized And Developer Storage Providers

Developer and virtualized storage should not be treated as ordinary folders.

Future provider targets:

- Docker volumes and images;
- WSL distributions;
- VM disks;
- Android emulators;
- iOS simulators;
- dev containers;
- Kubernetes local volumes;
- package manager stores;
- build cache roots.

Required boundary:

```text
StorageProviderAdapter
  provider_id
  target_discovery
  size_projection
  official_cleanup_actions
  risk_policy
  receipt_mapping
```

Rules:

- provider storage can be scanned like files, but cleanup must prefer provider adapters;
- Docker volumes, VM disks, SDK packages, and shared package stores are never ordinary cache by default;
- official cleanup commands need dry-run/preflight parity where possible;
- provider adapters declare risk tiers and undo limitations.

Top option:

1. StorageProviderAdapter for developer and virtualized targets - 🎯 9 🛡️ 9 🧠 8, roughly 2500-8000 LOC over time.

### Reason And Evidence Taxonomy

UI, support, reports, degraded mode, and recommendations need one language for explanations.

Required shape:

```text
reason_code
severity
evidence_refs
user_message_key
repair_action
data_quality
limitations
```

Use for:

- why something is large;
- why it is a cleanup candidate;
- why confidence is low;
- why cleanup is disabled;
- why permission is needed;
- why target changed;
- why scan is partial.

Rules:

- reason codes are stable product codes, not raw exception strings;
- localization uses message keys, not backend English text;
- support bundles can include reason codes without raw paths;
- UI explanations are compact evidence views, not hidden debug dumps.

Top option:

1. Typed reason/evidence taxonomy - 🎯 10 🛡️ 9 🧠 6, roughly 800-1800 LOC.

### Self-Test And Diagnostic Mode

Support needs a safe health check that does not require scanning user data.

Self-test checks:

- daemon starts;
- protocol compatibility passes;
- permissions are readable or clearly missing;
- pdu backend is available;
- database opens and migrations are healthy;
- WebSocket event loop works;
- small fixture scan passes;
- cleanup enabled/disabled state is explicit;
- support export redaction works.

Rules:

- self-test uses fixture data where possible;
- diagnostics do not require raw path collection;
- results are capability states with reason codes;
- destructive capability checks are dry-run or disabled unless explicitly authorized.

Top option:

1. Self-test mode with fixture scan and capability report - 🎯 9 🛡️ 9 🧠 5, roughly 500-1200 LOC.

### Trust UX

Safety mechanisms must be understandable in the UI.

Trust UX should answer:

- why this is considered safe;
- what changed since scan;
- what will happen;
- what cannot be undone;
- what was skipped;
- what is unknown;
- why confirmation is required again.

Rules:

- trust UI is evidence-driven, not marketing copy;
- destructive flows show limitations and data quality;
- low-confidence estimates are visually and textually distinct;
- compact details reveal evidence without overwhelming normal workflows.

Top option:

1. Compact trust/evidence UI for scan and cleanup flows - 🎯 9 🛡️ 10 🧠 7, roughly 1500-3500 LOC.

## Assurance And Fault-Model Future Gates

These gates protect the product when workflows become long-running, recoverable, destructive, or support-critical. The goal is to make behavior explicit enough that crash recovery, support, QA, and cleanup safety are testable rather than implied.

### Formal Operation State Machines

Lifecycle must not live only in prose or UI flags.

State machines needed over time:

```text
ScanSession
Snapshot
MetadataEnrichment
DeletePlan
CleanupExecution
ExportJob
AutomationJob
DaemonConnection
```

Rules:

- every long-running operation has a typed state;
- allowed transitions are explicit;
- terminal states are distinguishable: completed, cancelled, failed, expired, disposed;
- recovery after crash maps persisted state to the next safe action;
- UI renders state from operation status, not inferred widget flags.

Top option:

1. Explicit operation state machines - 🎯 10 🛡️ 10 🧠 7, roughly 1000-2500 LOC.

### Safety Case For Destructive Flows

Cleanup needs an explicit safety argument, not only implementation confidence.

Safety case shape:

```text
claim
evidence
risk
mitigation
test
release_gate
```

Example:

```text
claim: app will not delete the wrong target
evidence: NodeRef, identity revalidation, preflight diff, receipt
risk: path changed after scan
mitigation: revalidate identity before execution
test: stale target fixture
```

Rules:

- every destructive workflow has a safety case before release;
- safety claims connect to tests and fixtures;
- rule packs and cleanup adapters cannot skip safety case gates;
- support and incident response can refer to safety claims without raw path logs.

Top option:

1. Safety case model for destructive flows - 🎯 9 🛡️ 10 🧠 7, roughly 600-1800 LOC plus docs/tests.

### Storage Topology Model

Storage is not just paths and folder trees.

Future topology concepts:

```text
physical_disk
volume
mount_point
filesystem
quota_domain
cloud_sync_root
network_share
container_volume
snapshot_domain
```

Why it matters:

- reclaimed bytes may affect a quota, not global free space;
- cloud local size can differ from cloud logical size;
- network shares and external drives have different cost/risk;
- snapshots and clones can make delete results non-obvious;
- container/VM storage can hide reclaim behind provider tools.

Rules:

- ScanTarget should eventually attach to topology facts;
- reclaim estimate declares affected domain;
- UI does not promise OS free-space delta when only quota or provider storage changes;
- topology facts can be unknown or low-confidence.

Top option:

1. Storage topology model behind ScanTarget and SizeFacts - 🎯 9 🛡️ 9 🧠 8, roughly 1500-4000 LOC later.

### Deterministic Evidence Capture

When a user or support asks "why did the app show this?", the product needs decision context, not a raw disk replay.

Evidence capture should include:

```text
scanner_version
policy_version
target
snapshot_id
size_policy
capabilities
rule_versions
data_quality
reason_codes
operation_state
```

Rules:

- receipts store decision context at the time of action;
- reports store semantic and policy versions;
- support bundles can include redacted evidence references;
- deterministic evidence is compact and privacy-classified;
- evidence capture must not require full raw tree export.

Top option:

1. Deterministic evidence snapshot for decisions - 🎯 9 🛡️ 10 🧠 6, roughly 700-1600 LOC.

### Cost-Aware Runtime

Not every scan or query costs the same.

Cost factors:

- external HDD;
- network share;
- laptop on battery;
- thermal pressure;
- low disk;
- corporate VPN/NAS;
- cloud placeholder hydration risk;
- permission-heavy tree;
- very large node count.

Required contract direction:

```text
RuntimeCostProfile
  io_cost
  cpu_cost
  battery_cost
  hydration_risk
  network_cost
  user_visible_warning
  recommended_resource_policy
```

Rules:

- expensive targets can lower default scan aggressiveness;
- Fast mode remains opt-in;
- cloud placeholder hydration risk is surfaced before aggressive metadata work;
- UI can explain why a scan is slower or backgrounded.

Top option:

1. Cost-aware runtime profile feeding resource policy - 🎯 8 🛡️ 9 🧠 7, roughly 1000-2500 LOC.

### Data Retention And Forgetting

Privacy posture needs deletion semantics for Clean Disk's own data.

Future user actions:

```text
forget_snapshot
delete_report
delete_receipt
clear_support_bundle
clear_search_history
reset_daemon_pairing
wipe_local_diagnostics
```

Rules:

- retention policy is explicit per data lifecycle class;
- deleting a snapshot does not silently delete required operation receipts;
- receipts can be redacted or retained according to policy;
- daemon tokens and pairing secrets have a clear reset path;
- support bundles are user-visible files, not hidden retained exports.

Top option:

1. Retention and forgetting policy per data class - 🎯 9 🛡️ 9 🧠 6, roughly 700-1800 LOC.

### Simulation And Fault Injection Lab

Fixtures prove normal cases. Fault injection proves recovery behavior.

Fault cases:

- file deleted during scan;
- file replaced between scan and cleanup;
- mount disappears;
- permissions change;
- daemon dies;
- WebSocket reconnects;
- database is locked;
- low disk during receipt write;
- cleanup partially succeeds;
- update occurs while operation is active.

Rules:

- cleanup beta requires fault injection coverage for wrong-target and partial-success cases;
- operation journals are tested under crash and restart;
- protocol reconnect and event replay have fixtures;
- low-disk receipt durability has a release gate;
- fault tests use synthetic fixtures, not real user data.

Top option:

1. Fault injection lab for scan, protocol, journal, and cleanup - 🎯 10 🛡️ 10 🧠 8, roughly 2000-6000 LOC over time.

## External Boundary And Abuse-Resistance Future Gates

These gates protect Clean Disk once local daemon APIs, browser/web UI, helpers, remote/headless, rule packs, exports, integrations, and public libraries create boundaries that other code can call. The product is local-first, but local APIs are still APIs.

### Local Daemon Threat Model

HTTP and WebSocket daemon APIs must assume that not every local caller is trusted UI.

Required controls:

```text
origin_policy
local_token
client_identity
command_scope
rate_limit
csrf_localhost_protection
destructive_command_guard
```

Rules:

- daemon binds only to intended local interfaces by default;
- browser-origin checks are explicit;
- local token or pairing is required for non-trivial commands;
- destructive commands require stronger guards than read-only queries;
- rate limits protect control plane and expensive query surfaces;
- hosted web to localhost remains future-only until pairing and browser policy are proven.

Top option:

1. Local daemon threat model plus browser-origin and token gates - 🎯 10 🛡️ 10 🧠 7, roughly 1000-2500 LOC.

### Confused Deputy Protection

The daemon or helper can have more filesystem authority than a client. That authority must not leak.

Rule:

```text
daemon authority != client authority
```

Every command should validate:

```text
client_scope
target_scope
operation_scope
policy_decision
```

Examples:

- daemon has Full Disk Access, but web UI cannot query every private path by default;
- elevated helper cannot be used as a generic privileged file tool;
- remote client cannot request cleanup outside target scope;
- read-only report viewer cannot mutate live daemon state.

Top option:

1. Confused deputy protection through scoped commands - 🎯 10 🛡️ 10 🧠 7, roughly 1000-2500 LOC.

### Schema Governance

Versioned DTOs need an evolution process, not only fields.

Schema change process:

```text
schema_proposal
compatibility_impact
old_fixture_update
client_fallback
migration_note
release_gate
```

Rules:

- every protocol/schema change updates compatibility fixtures or records why not;
- destructive DTOs have stricter compatibility review than read-only DTOs;
- old clients have unknown-field and unknown-enum behavior tested;
- schema changes that affect semantics link to semantic model versions.

Top option:

1. Schema governance as small decision records plus compatibility fixtures - 🎯 9 🛡️ 9 🧠 6, roughly 400-1000 LOC plus discipline.

### Extension Sandbox Boundary

If plugins, rule packs, or third-party adapters appear later, they cannot be trusted as core.

Future extension options:

- signed static rule packs;
- WASM sandbox for classification;
- external tool adapter through command sandbox;
- no direct filesystem mutation;
- no network by default;
- explicit resource limits;
- explicit capability manifest.

Rule:

```text
extension can classify
extension cannot mutate
```

Cleanup remains owned by core `DeletePlan`, policy, preflight, confirmation, execution adapter, and receipt.

Top option:

1. Extension sandbox before public plugins or third-party rule packs - 🎯 8 🛡️ 10 🧠 9, roughly 3000-10000 LOC later.

### Content Boundary

Disk usage analysis should be metadata-first. Reading file contents changes privacy, performance, and legal posture.

Rule:

```text
metadata scan is default
content read is explicit capability
```

Content-read use cases:

- content hash duplicate detection;
- preview generation;
- archive inspection;
- AI content classification;
- file-type sniffing beyond metadata.

Required safeguards:

- opt-in policy;
- target scope;
- file size limits;
- cloud hydration warning;
- privacy profile;
- cancellation and resource budget;
- no content in logs/support bundles by default.

Top option:

1. Metadata-first scanner with content-read opt-in capability - 🎯 10 🛡️ 10 🧠 6, roughly 600-1500 LOC for contracts and guards.

### Release Rings

Risky recommendations, rule packs, adapters, and scanner backends should not jump straight to stable.

Future release rings:

```text
internal
canary
beta
stable
disabled_by_revocation
```

Rules:

- release ring is part of capability decision;
- cleanup adapters require stronger evidence before stable;
- trust channel can revoke a ring or specific artifact;
- UI can show a feature as experimental or disabled for safety;
- release ring cannot bypass policy or compatibility.

Top option:

1. Release rings for risky rules/adapters/backends - 🎯 8 🛡️ 9 🧠 7, roughly 800-2000 LOC later.

### Human-Readable Audit Trail

Receipts are necessary, but users and support need an understandable audit trail.

Audit should explain:

- what the user selected;
- what changed since scan;
- what was revalidated;
- what actually happened;
- what failed;
- what could not be known;
- which confidence limits applied.

Rules:

- audit trail is human-readable and machine-readable;
- audit references reason codes and evidence refs;
- audit does not expose raw paths unless privacy profile allows it;
- audit is generated from operation journal and receipts, not separate truth.

Top option:

1. Human-readable audit trail over receipts and operation ledger - 🎯 9 🛡️ 10 🧠 7, roughly 1000-2500 LOC.

### Storage Provider Honesty Contracts

Provider storage needs honest contracts because filesystem size and actual reclaim can diverge.

Required provider facts:

```text
provider_size
filesystem_size
exclusive_reclaim_estimate
official_cleanup_command
undo_capability
risk_tier
quota_or_free_space_domain
```

Rules:

- provider adapter declares what size means;
- UI distinguishes provider reclaim from OS free-space delta;
- official cleanup command results are receipts, not guessed delete counts;
- unknown provider semantics downgrade confidence.

Top option:

1. Provider honesty contract for Docker, WSL, VM, cloud, and package stores - 🎯 9 🛡️ 9 🧠 8, roughly 1500-4000 LOC per mature provider family.

## Complexity And Evolution Future Gates

These gates protect the project from the opposite failure mode: not under-design, but over-design. Future readiness is useful only if each abstraction protects a real safety boundary, removes a future blocker, or simplifies current work.

### Complexity Budget

Every new abstraction must pass a small budget check.

Rule:

```text
new abstraction must:
  remove a real future blocker
  or protect a safety/security boundary
  or simplify current implementation
```

Budget questions:

- what concrete decision becomes easier?
- what future rewrite does this prevent?
- what safety boundary does this protect?
- what code becomes smaller or clearer now?
- what test proves this abstraction earns its place?
- what is the removal path if it proves unnecessary?

Top option:

1. Complexity budget before each new abstraction - 🎯 10 🛡️ 9 🧠 5, roughly 200-600 LOC across checklists and gates.

### Progressive Disclosure UX

The product must tell the truth without overwhelming users.

Disclosure layers:

```text
simple_summary
visible_warning
expandable_evidence
advanced_details
support_or_audit_export
```

Rules:

- uncertainty is visible, but not dumped as raw diagnostics;
- common users see clear summary and next action;
- advanced users can inspect evidence and limitations;
- support/audit export can carry deeper machine-readable context;
- warnings do not become alarmist pressure to delete.

Top option:

1. Progressive disclosure for trust UX - 🎯 9 🛡️ 9 🧠 7, roughly 1200-3000 LOC when cleanup/recommendations mature.

### Deprecation And Sunset Policy

Compatibility cannot grow forever without boundaries.

Required policy fields:

```text
contract_id
support_status
first_supported_version
last_supported_version
migration_path
user_notice
drop_gate
```

Rules:

- persisted user data needs stronger support than ephemeral session DTOs;
- snapshots may be dropped or rescanned where safe;
- receipts and operation journals need longer retention and migration rules;
- old rule packs and adapters can be revoked or sunset;
- every sunset decision records user impact and recovery path.

Top option:

1. Deprecation and sunset policy for protocol, snapshots, receipts, and rule packs - 🎯 9 🛡️ 9 🧠 6, roughly 500-1500 LOC plus release discipline.

### Reproducible Release Trust

A trusted open-source product needs trust in binaries, not only source code.

Release trust artifacts:

- signed artifacts;
- SBOM;
- provenance;
- dependency review;
- notarization/package verification;
- reproducible or reproducibility-oriented build notes;
- rollback proof;
- compatibility manifest.

Rules:

- release trust is a release gate, not MVP scan logic;
- dependency and build-script changes are reviewed as supply-chain changes;
- update artifacts connect to compatibility and rollback checks;
- public binaries should be traceable to source, dependency set, and build process.

Top option:

1. Reproducible release trust pipeline before broad distribution - 🎯 8 🛡️ 10 🧠 8, roughly 1500-5000 LOC plus release infrastructure.

### Product Ethics For Cleanup

Cleanup tools can create pressure and unsafe behavior if the UX optimizes only for reclaimed gigabytes.

Rules:

```text
do not create pressure to delete
show risk before reclaim
never hide uncertainty
prefer official cleanup
make cancel and review easy
```

Required behavior:

- cleanup candidates show risk tier and confidence before primary action;
- reclaim numbers do not dominate when confidence is low;
- scary language is avoided;
- review and cancel stay easy;
- official cleanup paths are preferred over raw deletion when available.

Top option:

1. Ethical cleanup UX rules before cleanup/recommendations become prominent - 🎯 9 🛡️ 10 🧠 5, roughly 300-900 LOC in UX rules and review gates.

### Documentation Decay Control

The documentation set is now large enough to need lifecycle rules.

Required metadata for important docs:

```text
source_of_truth
status
last_validated
superseded_by
implementation_evidence
owner_area
```

Rules:

- accepted decisions live in one source-of-truth document;
- superseded documents link forward;
- docs that gate implementation include validation or evidence links;
- old research cannot silently override accepted decisions;
- short recovery summaries stay updated when gates change.

Top option:

1. Documentation decay control for architectural memory - 🎯 10 🛡️ 9 🧠 5, roughly 300-800 LOC across docs metadata and maintenance rules.

### Cross-Product Reuse Boundary

Some patterns are reusable across other projects, but Clean Disk-specific models must not leak into generic infrastructure.

Reusable patterns:

- versioned protocol envelopes;
- event stream cursor;
- operation journal;
- capability report;
- reason codes;
- policy gates;
- bounded worker lanes;
- compatibility corpus.

Clean Disk-specific concepts:

- filesystem identity;
- reclaim model;
- Trash adapters;
- storage topology;
- pdu adapter;
- provider cleanup semantics;
- scan target authority.

Rules:

- reusable extraction waits for at least two real product contexts;
- generic packages must not depend on Clean Disk domain language;
- Clean Disk-specific safety rules stay in Clean Disk or `fs_usage_*`;
- orchestrator/agent projects may reuse patterns, not filesystem assumptions.

Top option:

1. Reuse patterns, not Clean Disk-specific domain models - 🎯 9 🛡️ 9 🧠 6, roughly 500-1500 LOC when extracting shared packages.

## Highest Future Gates

If only a few future gates are remembered, use these:

1. Snapshot, NodeRef, and SizeFacts from day one - 🎯 10 🛡️ 10 🧠 7.
   Required for history, delete safety, remote mode, accurate accounting, and future scanner backends.
2. Daemon compatibility and capability handshake from day one - 🎯 10 🛡️ 9 🧠 6.
   Required for desktop, web, update, rollback, and degraded mode.
3. Resource budgets as architecture from day one - 🎯 10 🛡️ 10 🧠 6.
   Required to avoid UI/system freezes and keep the control plane responsive.
4. ScanTarget, confidence/evidence, and authority scopes from day one - 🎯 10 🛡️ 10 🧠 7.
   Required for permissions, semantic classification, remote/headless, support, and safe future cleanup.
5. Data lifecycle, compatibility corpus, and export profiles before persisted data expands - 🎯 10 🛡️ 10 🧠 7.
   Required for updates, rollback, support, privacy, reports, and old user data.
6. Kill switches, feature-flag safety, and architecture entropy checks before smart cleanup - 🎯 9 🛡️ 10 🧠 6.
   Required before recommendations, rule packs, AI-assisted classification, or adapter-driven cleanup can be trusted.
7. Data quality tiers and user intent preservation before cleanup expands - 🎯 10 🛡️ 10 🧠 7.
   Required to prevent stale or inferred scan data from becoming wrong-target cleanup.
8. Incident response, trust channel, and benchmark honesty before public rule/update ecosystem - 🎯 9 🛡️ 10 🧠 8.
   Required for revocation, safety advisories, responsible benchmark claims, and recovery guidance.
9. Automation, multi-user boundaries, and local-only filesystem truth before account/sync features - 🎯 10 🛡️ 10 🧠 7.
   Required to prevent background work, shared machines, or sync from leaking authority or private paths.
10. Reason taxonomy, self-test, and trust UX before smart cleanup becomes prominent - 🎯 9 🛡️ 10 🧠 7.
   Required so recommendations, degraded states, and cleanup confirmations are explainable and supportable.
11. Explicit state machines, safety case, and fault injection before cleanup beta - 🎯 10 🛡️ 10 🧠 8.
    Required so destructive flows are recoverable, testable, and backed by evidence.
12. Storage topology, deterministic evidence, and retention policy before advanced accounting/reports - 🎯 9 🛡️ 10 🧠 7.
    Required for honest reclaim claims, support, privacy, and long-term data governance.
13. Local daemon threat model and confused deputy protection before web/remote expansion - 🎯 10 🛡️ 10 🧠 7.
    Required so HTTP/WebSocket, browser UI, helpers, and remote clients cannot borrow more authority than they own.
14. Content boundary, extension sandbox, and provider honesty before plugins/AI/developer cleanup - 🎯 9 🛡️ 10 🧠 8.
    Required so smart features can classify and explain without silently gaining mutation authority or making false reclaim claims.
15. Complexity budget and documentation decay control before adding more layers - 🎯 10 🛡️ 9 🧠 5.
    Required so future-proofing does not become architecture drag or stale documentation.
16. Progressive disclosure and ethical cleanup UX before recommendations dominate - 🎯 9 🛡️ 10 🧠 7.
    Required so honest evidence improves trust without overwhelming users or pressuring unsafe deletion.
17. Deprecation, release trust, and reuse boundaries before public stability promises - 🎯 9 🛡️ 10 🧠 8.
    Required before public SDKs, broad binary distribution, or cross-project extraction.

## What Not To Implement In MVP

Do not pull these forward unless a gate requires it:

- public plugin API;
- public-stable reusable library semver;
- hosted web connecting to localhost without pairing/security model;
- remote destructive cleanup;
- Windows MFT backend;
- APFS clone/snapshot accounting;
- content-hash duplicate detection;
- full path fuzzy search;
- global metadata sort;
- always-on watchers;
- signed helper process;
- aggressive Fast mode default;
- AI-assisted auto cleanup;
- public SDK compatibility promise;
- enterprise/admin UI;
- advanced query language;
- shell extension integration;
- public rule marketplace;
- automatic trust-channel rule updates;
- public performance claims without benchmark matrix;
- telemetry collection beyond local diagnostics;
- scheduled cleanup automation;
- account sync for filesystem facts;
- developer storage provider cleanup adapters;
- trust UX overhaul as a blocker for scan-only MVP;
- full storage topology engine;
- formal safety-case tooling;
- full fault injection lab;
- retention management UI;
- cost-aware scheduler UX;
- hosted web localhost pairing;
- extension sandbox runtime;
- public third-party plugin system;
- content hashing or content inspection;
- release-ring infrastructure;
- human-readable audit UI as a blocker for scan-only MVP;
- mature provider cleanup families.
- full reproducible release pipeline as a blocker for scan-only MVP;
- public generic platform extraction;
- full documentation governance tooling;
- cleanup growth-pressure UX;
- deprecation automation framework.

## Future-Proof Invariants

```text
Facts are immutable.
Metadata is refreshable.
Paths are display, not identity.
Targets are authority-scoped, not path-shaped.
Selection is snapshot-scoped.
Cleanup is journaled.
Reclaim is estimated with confidence.
Execution is replaceable.
Protocol is versioned.
Capabilities drive UI behavior.
Policies own authority.
Semantic meaning is layered over raw filesystem facts.
Evidence accompanies uncertain claims.
Scheduler lanes protect the control plane.
Data lifecycle decides durability.
Indexes and views are projections, not truth.
Feature flags can disable risk, not bypass policy.
AI and recommendations can suggest, not authorize.
Exports declare privacy profiles.
Compatibility corpus is a release asset.
Accessibility is safety for destructive flows.
Data quality tiers travel with uncertain facts.
User intent is preserved through preflight and receipt.
Trust channel can revoke behavior, not grant authority.
Incident response preserves receipts and redacted evidence.
Benchmark claims include environment, data shape, and responsiveness.
Automation cannot clean without explicit policy, user intent, and receipt.
Raw filesystem truth is local-only unless intentionally exported.
Multi-user boundaries protect private paths.
Developer storage uses provider adapters for cleanup.
Reason codes explain product decisions.
Self-tests avoid real user data by default.
Trust UX exposes evidence, limits, and unknowns.
Operations have explicit state machines.
Safety claims connect to evidence, mitigations, tests, and gates.
Storage topology defines where reclaim applies.
Decision evidence is deterministic and privacy-classified.
Runtime cost can reduce aggressiveness.
Retention and forgetting are explicit.
Fault injection proves recovery paths.
Local daemon APIs treat callers as scoped clients.
Daemon authority is not client authority.
Schema changes carry compatibility evidence.
Extensions can classify, not mutate.
Metadata scan is default, content read is opt-in.
Release rings reduce risky rollout blast radius.
Audit trails are human-readable and machine-readable.
Provider adapters state what reclaim means.
Complexity must earn its place.
Truth is progressively disclosed.
Deprecation and sunset are explicit.
Release artifacts carry trust evidence.
Cleanup UX does not pressure deletion.
Docs declare source-of-truth and validity.
Reusable patterns stay separate from Clean Disk domain assumptions.
Support export is redacted by default.
```

## Stop Rules

Stop and redesign if:

- a public contract exposes pdu types;
- a command accepts display path as destructive authority;
- exact byte values cross Flutter web as unsafe JSON numbers;
- UI stores the full tree;
- snapshot cache has no format version;
- cleanup can run without receipt durability;
- remote mode can run destructive operations by default;
- helper/process identity is changed without capability re-probe;
- recommendation rules can directly delete files;
- benchmarks do not cover memory and control-lane latency;
- raw scanner starts classifying delete safety directly;
- scan API accepts a plain path where a typed `ScanTarget` is required;
- remote/headless command has no explicit authority scope;
- feature flag can enable cleanup after compatibility or policy failed;
- AI, recommendation, or rule pack can execute cleanup directly;
- export can include raw paths without explicit privacy profile;
- persisted receipt, journal, or snapshot changes without compatibility fixture;
- operation journal is treated as rebuildable cache;
- projection result becomes a second source of truth;
- accessibility is skipped for cleanup confirmation or tree selection;
- stale or inferred data is presented as measured truth;
- selected user intent is not stored before cleanup preflight;
- incident response requires raw path logs to explain what happened;
- trust channel can enable destructive behavior without policy approval;
- benchmark claim omits control-lane latency or scan quality tier;
- automation can execute cleanup without explicit policy, user intent, and receipt;
- sync includes raw paths, snapshots, receipts, daemon tokens, or support bundles by default;
- one OS user can view another user's private paths through daemon state;
- developer or virtualized storage is cleaned as an ordinary folder by default;
- backend sends raw exception strings as user-facing explanation contract;
- self-test requires scanning real user data;
- trust UI hides skipped states, unknowns, or undo limitations;
- long-running operation uses ad hoc booleans instead of a typed state machine;
- destructive workflow has no safety case tied to tests;
- reclaim claim does not state affected volume, quota, provider, or unknown topology;
- receipt lacks decision context needed to explain the action later;
- runtime ignores high-cost target signals and saturates the system;
- user cannot clear local diagnostics, search history, support bundles, or pairing secrets;
- cleanup beta lacks fault tests for stale target, partial success, crash recovery, and low disk;
- daemon accepts browser or localhost commands without origin/token/client-scope gates;
- daemon or helper executes a command using broader authority than the client scope allows;
- schema changes ship without compatibility fixtures or fallback behavior;
- extension, rule pack, or plugin can mutate filesystem state directly;
- content-read capability is enabled implicitly by a scan, export, recommendation, or support action;
- risky rule, adapter, or backend can reach stable without release-ring evidence;
- audit trail is a separate story from operation journal and receipts;
- provider cleanup claims exact OS free-space gain without provider evidence.
- new abstraction has no safety, current-simplicity, or future-blocker rationale;
- UI either hides uncertainty or dumps raw diagnostics without progressive disclosure;
- old protocol, snapshot, receipt, or rule contract is removed without deprecation/sunset decision;
- public release artifact has no signing/provenance/SBOM or equivalent trust evidence;
- cleanup UX pressures deletion before showing risk and uncertainty;
- changed architecture doc does not declare source-of-truth or superseded status;
- Clean Disk filesystem assumptions leak into generic shared packages.
