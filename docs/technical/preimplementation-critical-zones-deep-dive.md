# Preimplementation Critical Zones Deep Dive

Last updated: 2026-05-16.

This document goes one level deeper than `preimplementation-critical-research-sequence.md`. It focuses on what can still break even if the high-level architecture is correct.

The main rule: every critical zone needs a measurable spike, a pass/fail gate, and a fallback decision before product implementation depends on it.

## Sources Reviewed

- `parallel-disk-usage` docs.rs and GitHub docs for library integration, hardlinks, symlinks, progress, and output shape.
- `parallel-disk-usage` reporter trait and event docs for synchronous reporter callbacks, `ParallelReporter::destroy`, and non-exhaustive event variants.
- Rust std docs for `metadata`, `symlink_metadata`, `read_dir`, `canonicalize`, `Path`, `PathBuf`, `Vec::try_reserve`, `HashMap`, and `BTreeMap`.
- Rust std docs for `OsString`, `OsStr`, Unix `OsStrExt`, and path conversion APIs for lossless native path handling and non-UTF-8 path boundaries.
- Rust std docs for `panic::catch_unwind`, especially that it is not a general error mechanism and cannot catch aborting panics.
- Rust std allocation docs for `handle_alloc_error`, `Allocator`, `TryReserveError`, and the distinction between fallible reservation and process-aborting allocation failure.
- Rust primitive integer docs for checked arithmetic, saturating arithmetic, wrapping arithmetic, and exact integer boundaries.
- Linux man-pages for `statx`, `open`, `openat2`, `unlink`, `rename`, and `stat`.
- Linux man-pages for `unlink` and `openat2` path resolution flags, including open-file unlink semantics, `RESOLVE_IN_ROOT`, `RESOLVE_NO_SYMLINKS`, `RESOLVE_NO_MAGICLINKS`, and `RESOLVE_NO_XDEV`.
- Linux man-pages for `/proc/pid/mountinfo`, `statx`, and `statmount` for mount IDs, mount namespace topology, mount-root detection, and mount ID reuse constraints.
- Linux kernel FIEMAP documentation for extent mapping and shared extent flags.
- Tokio docs for bounded `mpsc`, bounded `broadcast`, lag handling, semaphores, and `spawn_blocking` limits.
- Tokio `spawn_blocking` and sync-bridging docs for blocking pool limits, CPU-bound throttling, non-abortable started blocking work, shutdown behavior, and dedicated-thread guidance for long-lived work.
- Tokio graceful shutdown docs for shutdown detection, cancellation tokens, notifying tasks, waiting for tasks, and flushing state before termination.
- Rust Async Book docs for blocking, cancellation, cooperative async scheduling, and the risk of blocking standard filesystem I/O inside async tasks.
- Rayon docs for explicit worker pool configuration, custom thread naming, non-global pool construction, global pool one-time initialization, and thread lifetime caveats.
- Rust Reference, Rust std `catch_unwind`, and Rustonomicon FFI guidance for panic strategy, unwind boundaries, `UnwindSafe`, aborting panics, and why panics must not cross non-unwinding FFI/runtime boundaries.
- Apple ProcessInfo, ThermalState, Low Power Mode, Dispatch QoS, and Energy Efficiency docs for thermal pressure, power-state notifications, CPU/IO throughput priority, and background/utility workload classification.
- Microsoft EcoQoS, Windows Quality of Service, SYSTEM_POWER_STATUS, and Power Setting GUID docs for process/thread power throttling, battery saver, power-source notifications, and visibility/focus-derived QoS.
- Linux `ionice`, `ioprio_set`, cgroup v2, and systemd resource-control docs for IO scheduling classes, per-thread IO context caveats, CPU/IO weights, IO bandwidth/IOPS caps, and controller support variability.
- MDN WebSocket API docs. Important current fact: stable browser `WebSocket` has broad support but no built-in backpressure; `WebSocketStream` has backpressure but is non-standard and not baseline.
- RFC 6455 for WebSocket transport semantics.
- RFC 9110 for HTTP semantics.
- RFC 9457 for HTTP problem details.
- RFC 9457 details for machine-readable problem types, stable `type` identifiers, advisory human-readable titles, extension members for validation errors, and localization boundaries.
- Rust `std::io::ErrorKind` docs for non-exhaustive I/O categories, future variants, expected wildcard matching, and the need to avoid exhaustive public matches over platform errors.
- Apple `NSError` and Cocoa Error Handling docs for layered error domains, domain-specific codes, localized descriptions, failure reasons, recovery suggestions, recovery options, and underlying errors.
- Microsoft Win32 system error and `FormatMessage` docs for `GetLastError` codes, developer-oriented system messages, inserts/format sequences, and the need to map native codes before showing user-facing diagnostics.
- OpenTelemetry Logs Data Model, semantic conventions, sensitive-data guidance, and attribute requirement levels for structured events, data minimization, opt-in sensitive/high-cardinality attributes, redaction processors, and explicit implementer responsibility.
- NIST SP 800-92 for log management process, retention, protection, and enterprise log-management practices.
- MITRE CWE-532 for sensitive information in log files and the risk of logs becoming an easier path to private data than the primary system.
- OWASP WebSocket Security, REST Security, CSRF Prevention, Logging, Input Validation, Transaction Authorization, Threat Modeling, and CSP cheat sheets.
- OWASP API Security Top 10, Broken Object Level Authorization, Broken Object Property Level Authorization, and Mass Assignment guidance for object ownership, field allowlisting, DTO separation, and avoiding unsafe generic binding.
- OWASP API Security Top 10 2023 for Broken Object Level Authorization, Broken Authentication, Broken Object Property Level Authorization, Unrestricted Resource Consumption, Broken Function Level Authorization, and API inventory risk.
- OWASP API Security, REST Security, and WebSocket Security guidance for remote/headless mode authentication, object-level authorization, function-level authorization, resource-consumption limits, HTTPS/WSS, origin validation, message-level authorization, and security logging.
- NIST SP 800-207 Zero Trust Architecture and NIST SP 800-204 microservices security guidance for no implicit trust by network location, per-session authentication/authorization, access management, secure communication protocols, throttling, monitoring, and resiliency controls.
- Chrome Private Network Access and Microsoft Edge Local Network Access docs for local daemon browser access risks.
- Chrome Local Network Access and WICG Local Network Access docs for hosted web UI to local daemon permission prompts.
- Flutter performance docs, DevTools performance docs, `ListView.builder`, `DataTable`, `FutureBuilder`, isolates, and long-list docs.
- WAI-ARIA Treegrid Authoring Practices for keyboard and accessibility behavior.
- WAI-ARIA Treegrid Authoring Practices for focus versus selection, multi-select state, sortable treegrid headers, and virtualized/hidden row count/index semantics.
- Microsoft Windows confirmation UX guidance for destructive actions, undo, safe defaults, bulk confirmations, and providing enough information for an intelligent confirmation.
- GNOME Human Interface Guidelines for confirmation dialogs, destructive actions, undo preference, and explicit user action before disruptive dialogs.
- Apple Human Interface Guidelines undo/redo guidance for predictable reversible actions and user control over action outcomes.
- Apple FileManager `trashItem`, App Sandbox, security-scoped bookmarks, notarization, hardened runtime, APFS, URLResourceValues, and Time Machine local snapshot docs.
- Apple APFS filename normalization/case behavior, `NSURL` file-system representation guidance, and security-scoped bookmark lifecycle docs.
- Apple Disk Arbitration docs for disk appear/disappear, mount/unmount notifications, approval callback limits, and unusual removable-media behavior.
- Apple Service Management `SMAppService`, launchd daemon/agent lifecycle, and code-signing guidance for helper identity, user-agent versus daemon boundaries, on-demand launch, and stable responsible-code attribution.
- Apple launchd daemon/agent creation and lifecycle docs for `SIGTERM` on shutdown/logout, on-demand launch, `KeepAlive`, socket/file-descriptor ownership, respawn behavior, and daemonization pitfalls.
- Microsoft IFileOperation, IFileOperationProgressSink, FILE_ID_INFO, FILE_STANDARD_INFO, CreateFileW, DeleteFile, file access rights, longPathAware, Controlled Folder Access, SmartScreen, MSIX, VSS, ReFS block cloning, Data Deduplication, and Cloud Files docs.
- Microsoft Windows path namespace, reserved names, long path, `\\?\` prefix, shell-vs-filesystem behavior, alternate data stream, and IFileOperation flag docs.
- Microsoft `CancelIoEx`, Canceling Pending I/O, and synchronous I/O cancellation docs for best-effort cancellation, cancel races, and normal completion after a cancel request.
- Microsoft Windows volume naming docs for drive-letter instability, volume GUID paths, mounted folders, and volume mount points.
- Microsoft COM apartments, `CoInitialize`, and cross-apartment interface rules for Windows Shell adapter execution context.
- Microsoft file attribute constants and Cloud Files placeholder state docs for offline, recall-on-open, recall-on-data-access, and placeholder states.
- Microsoft UAC, Mandatory Integrity Control, Windows service security, service access rights, and Session 0 isolation guidance for elevation, integrity level, service-account, and user-session boundaries.
- FreeDesktop Trash Specification.
- FreeDesktop polkit docs for privileged mechanism versus untrusted subject authorization, authentication agents per user session, temporary authorization, and headless/no-agent behavior.
- systemd user-service and `systemd.exec` docs for user service lifecycle, lingering, service capabilities, `NoNewPrivileges`, sandboxing, and system-service hardening limitations.
- systemd service docs for `TimeoutStopSec`, `KillSignal`, `FinalKillSignal`, `WatchdogSec`, `Restart`, stop failure modes, and `sd_notify` timeout extension behavior.
- Microsoft Windows service control handler docs for `SERVICE_CONTROL_STOP`, `SERVICE_CONTROL_PRESHUTDOWN`, `SERVICE_CONTROL_SHUTDOWN`, stop-pending status, handler return deadlines, and shutdown cleanup time limits.
- Apple Developer ID, Gatekeeper, notarization, provider translocation, quarantine properties, and code-signing docs for app trust state, app translocation, helper launch paths, certificate expiry, and revoked Developer ID behavior.
- Microsoft SmartScreen reputation, Smart App Control, Microsoft Defender Controlled Folder Access, Defender performance analyzer, and Windows Search indexing docs for runtime trust, protected-folder writes, reputation prompts, security-product interference, and background indexing load.
- Apple FSEvents security docs for file-event privacy, non-consecutive event IDs, deleted-name retention, and event log storage behavior.
- Apple FSEvents Programming Guide for coalesced events, `MustScanSubDirs`, dropped kernel/user events, root changes, persistent event IDs, volume UUID checks, and event-log invalidation after restore/purge.
- Microsoft `ReadDirectoryChangesExW` docs for per-handle buffers, overflow behavior, zero-byte results requiring enumeration, network buffer limits, `ERROR_NOTIFY_ENUM_DIR`, and NTFS-only extended notifications.
- Linux `inotify(7)` docs for queue overflow, coalesced events, non-recursive watching, watch limits, missed network/pseudo-filesystem changes, racy rename pairs, and filename staleness by processing time.
- Rust `notify` crate docs for cross-platform watcher abstraction, network filesystem gaps, PollWatcher fallback, FSEvents ownership limitations, editor behavior differences, watch limits, and large-directory unreliability.
- SQLite WAL, atomic commit, and online backup docs for operation journal design and support bundle export.
- SQLite corruption documentation for WAL/journal copy hazards, raw file access hazards, and filesystem locking pitfalls.
- SQLite WAL persistence, Backup API, `quick_check`, `integrity_check`, file-locking, and corruption docs for live backup, health checks, WAL/shm/journal handling, and avoiding raw file access while the database is open.
- Drift migration and schema verifier docs for generated schema snapshots, step-by-step migrations, and test-time validation that migrations transform old schemas into the current expected schema.
- SQLite result-code docs for `SQLITE_FULL`, `SQLITE_IOERR`, `SQLITE_READONLY`, and write-failure handling when disk, quota, or filesystem state prevents persistence.
- Apple volume capacity URL resource keys for available, important, and opportunistic capacity estimates, including required-reason privacy implications.
- Windows `GetDiskFreeSpaceEx` docs for caller-available free bytes versus total free bytes and quota-aware capacity reporting.
- Linux/POSIX `statvfs` docs for free blocks, caller-available blocks, quotas, and filesystem capacity reporting.
- Linux PSI docs and systemd memory-pressure guidance for detecting memory stalls and releasing memory before OOM where supported.
- Windows `CreateMemoryResourceNotification` docs for memory resource notifications.
- Apple `DISPATCH_SOURCE_TYPE_MEMORYPRESSURE` and low-memory-warning docs for memory-pressure callbacks.
- MDN Storage API quota and eviction docs for browser storage pressure, best-effort data, persistent storage requests, and `QuotaExceededError`.
- Unicode UTR #36, UTS #39, and UAX #9 docs for Unicode security, visual confusables, mixed scripts, bidi controls, and bidirectional text rendering.
- NIST SI prefix and binary prefix docs for decimal prefixes, binary prefixes, and explicit byte-unit naming such as MB versus MiB.
- Apple byte count formatting docs for storage/file byte-count display policy and localized formatting.
- Dart number representation and `int` docs for Dart VM versus JavaScript/web integer precision behavior.
- MDN `Number.MAX_SAFE_INTEGER` docs and RFC 8259 JSON docs for safe JSON integer interoperability limits around 2^53.
- OWASP CSV Injection docs and CWE-1236 for spreadsheet formula injection from untrusted export cells.
- OWASP Logging Cheat Sheet, OWASP Log Injection, and CWE-117 for CRLF/log forging risks when untrusted text reaches logs.
- Confluent schema evolution docs for backward, forward, full, and transitive compatibility concepts.
- IETF Idempotency-Key draft and MDN Idempotency-Key docs for mutating-command retry semantics.
- Stripe idempotency docs and RFC 9110 idempotent-method semantics for safe retry design.
- TLA+ invariant documentation for state-machine invariant thinking.
- NIST SSDF and SLSA references for secure development and supply-chain release gates.
- NASA Software Assurance and Software Safety guidance for systematic assurance, software safety, independent verification and validation, hazard analysis, requirements traceability, and objective evidence.
- NIST SP 800-160 Vol. 1 Rev. 1 for systems security engineering, trustworthy system requirements, verification, validation, risk treatment, and traceability of security-relevant system elements.
- MIT STPA handbook material for unsafe control actions, system-level hazards, safety constraints, and software/human-intensive control loops.
- FMEA and FMECA references for failure mode, effect, severity, occurrence, detection, and action tracking as a release risk discipline.
- OWASP ASVS and OWASP Secure Product Design guidance for verification requirements, secure defaults, fail-secure behavior, least privilege, defense in depth, and requirement identifiers that can be mapped to tests.
- NIST SP 800-88 for the distinction between delete, Trash, clear, purge, and destroy.
- Cargo SemVer compatibility guidance for Rust public API evolution, dependency exposure, pre-1.0 compatibility expectations, and MSRV signaling.
- Rust API Guidelines for public API documentation, public dependency stability, permissive licensing, examples, builder APIs, and type-safety expectations.
- SQLite PRAGMA and WAL docs for `user_version`, `application_id`, `data_version`, WAL compatibility, and multi-process database visibility.
- Protocol Buffers schema evolution guidance for field-number stability, reserved fields, unknown fields, and wire-unsafe changes as transferable lessons for DTO evolution.
- OpenAPI specification docs for machine-readable HTTP API contracts and versioned API descriptions.
- CloudEvents specification and primer for event envelopes, `type`, `dataschema`, extension attributes, and event data schema evolution.
- OpenTelemetry schema docs for immutable telemetry schema URLs, schema families, and explicit evolution of observability data.
- The Update Framework specification for rollback, freeze, mix-and-match, and arbitrary-install attack classes in software update systems.
- WebAssembly security docs and WASI capability docs for sandboxed execution, host-provided capabilities, fault isolation, and capability-based filesystem/network access.
- OPA/Rego docs for declarative policy over structured data, policy modules, and separating policy decisions from application code.
- Cedar policy language docs for authorization request shape, policy validation, level validation, and schema-based constraints before policy evaluation.
- Common Expression Language docs for non-Turing-complete expression evaluation, host-provided data access, and production safety controls such as cost limits.
- JSONLogic docs for side-effect-free, deterministic, serialized decision rules.
- Sigstore, in-toto, SLSA, and OWASP SCVS docs for signed artifacts, provenance, transparency, and software component verification.
- Apple SMAppService, deprecated SMJobBless, Authorization Services, and Secure Coding Guide docs for privileged helper registration, code-signing requirements, app sandbox limits, and least-privilege elevation patterns.
- Microsoft UAC, UAC architecture, LocalSystem account, and Windows service security docs for split tokens, elevation prompts, service access rights, and avoiding over-privileged service accounts.
- systemd.exec docs for Linux service hardening with `NoNewPrivileges`, `CapabilityBoundingSet`, `DynamicUser`, namespace restrictions, and filesystem protection options.
- NIST Privacy Framework guidance for privacy-risk management, selective collection, data processing minimization, and privacy outcomes in system design.
- NIST FIPS 180-4 Secure Hash Standard for content digest semantics and the distinction between integrity hashes and privacy-safe identifiers.
- Microsoft Azure File Sync cloud-tiering docs for recall-on-data-access behavior and the fact that opening a tiered file can recall its content to disk.
- Apple Quick Look and Microsoft Windows thumbnail provider docs for preview/thumbnail generation as content processing, not metadata scanning.
- FreeDesktop Thumbnail Managing Standard for thumbnail cache locations, source URI metadata, modification checks, and thumbnail artifacts.
- Rust `std::time::Instant` and `SystemTime` docs for monotonic versus wall-clock behavior, suspend ambiguity, and non-monotonic system time.
- RFC 3339 for internet timestamp representation with explicit UTC offset.
- Dart `DateTime.microsecondsSinceEpoch` docs for UTC epoch semantics and JavaScript/web precision caveats.
- SQLite date/time function docs for UTC `unixepoch`, lack of dedicated date/time storage type, and `now` behavior inside one statement.
- Microsoft Windows file time docs for NTFS/FAT timestamp semantics, UTC/local storage differences, and filesystem-specific timestamp behavior.
- Linux `statx`, `stat`, and inode timestamp docs for mtime, ctime, atime, birth time availability, and timestamp precision differences.
- Apple file attribute docs for modification date and required-reason privacy handling of file timestamp APIs.
- Microsoft Cloud Filter API and Apple File Provider docs for cloud placeholder and provider-managed filesystem behavior.
- OpenTelemetry security and semantic convention docs for telemetry data classification and low-cardinality attributes.
- CISA and OWASP secure-by-design guidance for secure defaults, fail-secure behavior, and ownership of security outcomes.
- NIST Privacy Framework docs for privacy risk over the data lifecycle from collection through disposal.
- OWASP Fail Securely and Secure Product Design docs for safe failure paths, least privilege, and defense in depth.
- Microsoft Azure Bulkhead and AWS fault-isolation/circuit-breaker guidance for blast-radius containment.
- Google SRE workbook canarying and error-budget guidance for release safety and rollback cost.
- OpenTelemetry sensitive-data handling docs for data minimization and telemetry review.
- Windows Shell `SHFileOperation` and Recycle Bin docs for undo/recycle behavior and permanent-delete differences.
- cargo-nextest, proptest, cargo-fuzz, Miri, loom, Criterion, RustSec, cargo-deny, Flutter testing, golden testing, Dart analyze, and Melos docs for quality gates.
- `assert_fs` and `tempfile` docs for disposable filesystem fixture roots, fixture assertions, temporary directory cleanup semantics, explicit close checks, early-drop pitfalls, and temp-cleaner security caveats.
- cargo-nextest repository configuration and retry docs for checked-in test profiles, per-test overrides, timeouts, retries, flaky-test classification, and CI-specific execution behavior.
- Proptest, cargo-fuzz, and loom docs for property testing with shrinking, targeted fuzzing constraints, and deterministic exploration of concurrent interleavings.
- Flutter `matchesGoldenFile` docs for golden UI snapshots, golden versioning, platform/font instability, and the need to separate visual snapshots from semantic product assertions.

## Criticality Matrix

| Zone | If wrong | Earliest gate |
| --- | --- | --- |
| pdu adapter | scanner fast in CLI but unusable in product | before Rust crate layout hardens |
| read model memory | daemon OOM, slow queries, full-tree leakage to Flutter | before UI tree/table work |
| memory pressure | OOM, allocator abort, buffer explosion, or Flutter heap growth during large scans | before large-tree scan and protocol work |
| metadata enrichment | scan becomes slow despite pdu speed | before details/delete plan UI |
| content boundary | app reads file contents, hydrates cloud files, or creates private previews | before duplicate finder or preview UI |
| display/export injection | hostile filenames spoof UI, logs, CSV, support bundles, or confirmations | before tree UI, export, and support bundle work |
| traversal policy | loops, wrong totals, unsafe cleanup targets | before scanner MVP |
| identity + Trash | wrong-file deletion or fake restore promise | before cleanup MVP |
| reclaim accounting | user sees false freed bytes | before cleanup totals UI |
| quantity/rounding truth | UI, export, or protocol misrepresents bytes, units, percentages, or exactness | before metrics, table, and cleanup totals UI |
| selection + confirmation authority | focus, selected rows, filtered result sets, and confirmed DeletePlan diverge | before tree UI bulk actions and cleanup queue |
| protocol/backpressure | stale UI, memory growth, missed terminal states | before web UI integration |
| async/blocking runtime boundary | Tokio reactor stalls, blocking pool explosion, uncancellable scans, shutdown hangs, or panics poison daemon state | before daemon MVP |
| cancellation/abortability | cancel/pause UI lies, workers keep running, or destructive operation enters unknown side-effect state | before scan controls and cleanup MVP |
| clock/causality | stale evidence, wrong expiry, or wrong ordering after clock changes | before leases, receipts, and recommendations |
| daemon security | browser/local process can control scan/delete | before localhost daemon exposure |
| remote/headless authority | remote client controls wrong host, target scope, tenant, or destructive capability | before remote API or hosted web UI |
| privilege/elevation | app gains too much authority or exposes root/admin RPC | before installer/helper work |
| resource governance | app makes machine unusable during scan | before performance claims |
| power + thermal budgets | fast scan drains battery, heats the device, triggers OS throttling, or starves foreground apps | before scan profiles and benchmark claims |
| packaging/permissions | app cannot scan what installer promises | before public desktop build |
| operation journal | crash leaves unknown delete state | before destructive workflow |
| low-disk/write-failure | app cannot write journals, receipts, cache, or support data while trying to free space | before cleanup MVP |
| Flutter tree UI | jank or wrong queued row at scale | after query contracts, before polished UI |
| fixture lab | architecture stays unproven | starts immediately |

## Zone 1 - pdu Adapter Contract

### Hidden Failure Modes

- pdu is fast as a CLI but the library shape forces holding a large `DataTree` while we build our own read model.
- progress exists but is too coarse, too noisy, or cannot be throttled cleanly.
- cancellation is cooperative but latency is unacceptable on deep folders.
- skipped paths/errors are not rich enough for the UI.
- symlink entries are counted but not typed enough for safe cleanup display.
- hardlink policy changes totals in a way we cannot explain to users.
- pdu internal parallelism conflicts with daemon worker pools.
- pdu upgrade changes traversal or size semantics without a compiler error.

### Spike Protocol

Inputs:

```text
small fixture
100k-node synthetic fixture
1M-node synthetic fixture
real Downloads scan
real Library scan
hardlink fixture
symlink fixture
permission denied fixture
deep tree fixture
huge direct-child directory fixture
```

Measurements:

```text
raw_pdu_scan_ms
pdu_peak_rss
mapping_to_read_model_ms
mapping_peak_overlap_rss
skipped_count_by_reason
progress_events_total
progress_event_max_gap_ms
cancel_requested_to_terminal_ms
hardlink_policy_total_delta
```

### Pass Gate

- pdu can be driven as a library without CLI wrapping.
- adapter can map output into our model without leaking pdu types.
- raw pdu scan and post-processing metrics are separated.
- cancellation terminal state is deterministic enough for product UX.
- skipped/error entries can become first-class UI rows or summary pages.
- pdu version and option mapping are captured in golden fixture tests.

### Fallback Decision

If pdu cannot satisfy progress/cancellation/skipped-path needs, do not replace the app architecture. Keep the port and either:

1. patch/fork pdu behind `fs_usage_pdu` - 🎯 7 🛡️ 7 🧠 8, roughly 1500-4500 LOC;
2. add a sidecar traversal/enrichment pass for missing metadata - 🎯 8 🛡️ 7 🧠 7, roughly 1000-3000 LOC;
3. write a scanner backend later - 🎯 4 🛡️ 6 🧠 10, roughly 5000-15000 LOC.

## Zone 2 - Read Model Memory, Pagination, And Indexes

### Hidden Failure Modes

- storing full path per node dominates memory more than node structs;
- keeping both pdu tree and our arena doubles peak memory;
- child sorting clones large vectors per query;
- one folder with hundreds of thousands of children breaks page latency;
- search scans all nodes on every keystroke;
- `HashMap` iteration accidentally becomes UI order;
- cursor uses offset only, then rows duplicate or disappear after index rebuild;
- tree snapshot cannot be disposed because clients keep references;
- index choices work for 100k nodes but fail at 5M.

### Memory Budget Targets

These are spike targets, not promises:

```text
100k nodes:
  should be comfortably below 150 MB additional RSS

1M nodes:
  target below 500-800 MB additional RSS depending on names/indexes

5M nodes:
  must either stay within an explicit memory profile or return resource_exhausted with partial stats
```

The spike must report:

```text
bytes_per_node_record
bytes_per_name
bytes_per_child_index
bytes_per_sort_cache
bytes_per_search_index
peak_overlap_rss
post_dispose_rss_delta
```

### Recommended Internal Shape

```text
NodeRecord
  node_id
  parent_id
  name_id or compact name
  kind
  flags
  logical_bytes
  allocated_bytes
  child_start
  child_len
  item_counts
  modified_time_compact
  enrichment_state

NodeArena
  nodes: Vec<NodeRecord>
  child_index: Vec<NodeId>
  names: compact storage
  indexes: optional projections
```

Do not add:

- full path string per node;
- UI labels per node;
- protocol DTO per node;
- separate sorted vectors for every parent and every sort mode upfront;
- object graphs with `Arc<Node>` children for the main tree.

### Pagination Rules

Cursor must bind to:

```text
session_id
snapshot_id
index_version
query_scope
parent_id or root scope
sort_key
filter_hash
last_sort_tuple
last_node_id
```

Fail cursor when:

- snapshot changed;
- sort/filter changed;
- parent/scope changed;
- index version incompatible;
- cursor references unknown node.

### Pass Gate

- 1M synthetic nodes can be indexed and queried within memory target.
- 5M synthetic nodes either passes a higher memory profile or fails gracefully.
- `children` query p95 is acceptable on huge direct-child folder.
- `top folders/files` does not require full scan per query.
- search can throttle/cancel old queries.
- disposal releases old snapshot memory after active clients detach.

## Zone 3 - Metadata Enrichment Cost

### Hidden Failure Modes

- "just one more stat call" becomes millions of syscalls.
- Windows handle opens trigger antivirus or Controlled Folder Access delays.
- cloud placeholders hydrate unexpectedly.
- File Provider/Cloud Files metadata calls block on network or provider process.
- permissions/ACL/owner lookups are much more expensive than size metadata.
- icon lookup or file type detection accidentally enters UI hot path.
- selected-node enrichment races with a rescan and writes stale details.
- enrichment errors are shown as scan failures.

### Decision

Metadata must be tiered:

```text
scan baseline:
  minimum facts needed to build tree and totals

cheap index enrichment:
  facts already available or cheap enough under bounded concurrency

selected details:
  richer metadata for visible user intent

delete plan:
  live revalidation and safety facts
```

### Spike Protocol

For macOS, Windows, Linux:

```text
measure per-entry cost:
  basic stat/lstat/statx
  allocated-size API
  permission/owner lookup
  cloud/reparse/provider detection
  path canonicalization
  selected-folder rich metadata
```

Target fixtures:

```text
10k tiny files
100k tiny files
large app bundle/package
cloud placeholder tree if available
network share if available
permission denied subtree
```

### Pass Gate

- baseline scan time stays close to raw pdu scan.
- expensive enrichment is not required to display the initial tree.
- details enrichment can be cancelled when selection changes.
- delete plan performs fresh revalidation and ignores stale details.
- no metadata call hydrates cloud files by default.

### Fallback

If selected metadata is expensive, details panel should show progressive loading:

```text
known from scan
enriching...
partially available
unavailable because permission/provider/network
```

## Zone 4 - Traversal Policy

### Hidden Failure Modes

- symlink loop or Windows junction loop creates infinite traversal.
- root path itself is a symlink and policy is ambiguous.
- mount boundary crossing makes a "Home" scan include external/network volumes.
- APFS/system firmlink behavior confuses system totals.
- app bundles, photo libraries, sparsebundles, VM packages are treated as plain folders with unsafe cleanup suggestions.
- cloud placeholder scan hydrates remote content.
- FUSE/rclone/SMB/NFS latency makes fast-mode unusable.
- pseudo filesystems return weird sizes or endless dynamic entries.
- skipped paths disappear from UI, making partial scan look complete.

### Accepted Defaults

```text
follow_symlinks = false
follow_windows_reparse_points = false
hydrate_cloud_files = false
respect_gitignore = false
include_hidden = true
scan_packages_as_dirs = true, with package classification
cross_mounts = explicit policy, not adapter default
network_targets = reduced resource profile
pseudo_filesystems = skip
```

### Required Skip Reasons

```text
permission_denied
tcc_or_privacy_denied
sandbox_denied
symlink_not_followed
reparse_not_followed
mount_boundary_skipped
cloud_placeholder_not_hydrated
network_target_throttled
pseudo_filesystem_skipped
system_managed_storage
path_too_long
invalid_name_encoding
metadata_unavailable
```

### Pass Gate

- traversal policy is serialized into scan metadata.
- skipped reasons are queryable and visible.
- root symlink behavior is tested and documented.
- Windows reparse/junction behavior is tested.
- mount boundary behavior is tested on each OS.
- cleanup sees symlink/reparse policy, not just displayed row type.

## Zone 5 - Identity, Trash, Reclaim, And Journal Coupling

Focused split-out file for restore, quarantine, undo, and cleanup receipt
safety: `critical-zones/restore-quarantine-undo-safety.md`.

### Hidden Failure Modes

- row selected at scan time points to different object by delete time.
- directory is replaced by symlink/junction between preflight and action.
- Trash move succeeds but no restore URL is available.
- cross-volume Trash means copy plus delete, with partial failure risk.
- file is moved to Trash but free space does not change.
- path is gone, but operation retry treats it as failure instead of already-gone.
- app crashes after some items moved, before receipt write.
- user repeats command and items are moved twice or second operation targets new path.
- hardlink, snapshot, clone, VSS, dedupe, open file make reclaim estimate wrong.

### Coupled Design

These are not separate features. They must compose:

```text
DeletePlan
  identity evidence
  selected node IDs
  scan snapshot
  accounting estimate
  confirmation token
  idempotency key
  operation journal record

TrashAdapter
  current identity revalidation
  native move-to-trash
  item result
  resulting trash reference if available

Receipt
  item outcomes
  observed free-space delta
  estimated reclaim
  uncertainty
```

### Pass Gate

- stale identity blocks action.
- unsupported Trash blocks action or requires explicit permanent delete mode.
- every item has an outcome.
- crash before native call recovers as not executed.
- crash after partial native results recovers with unknown/partial state, not fake success.
- observed free-space delta is never confused with selected size.

## Zone 6 - Protocol Backpressure And State Recovery

### Hidden Failure Modes

- progress events fill browser memory because stable WebSocket has no backpressure.
- one slow browser tab blocks daemon event fanout.
- dropped terminal event leaves UI stuck in scanning state.
- reconnect resumes from a sequence that the daemon no longer retains.
- Flutter rebuilds the entire tree on every progress event.
- command retry after network drop starts duplicate scan/delete job.
- old web UI version connects to newer daemon and misreads event payload.

### Event Policy

```text
lossless bounded replay:
  operation accepted
  scan terminal state
  delete item result
  delete receipt created
  plan invalidated
  server shutdown

coalescible:
  current path
  percentage
  throughput
  counters
  ETA

invalidation:
  index ready
  query stale
  details stale
```

### Backpressure Rules

- Server queues are bounded.
- Per-client outbound queue is bounded.
- Coalescible events drop first.
- Durable event replay window is finite and explicit.
- If durable event cannot be guaranteed, close client and require resync.
- HTTP status and query endpoints remain authoritative after socket loss.

### Pass Gate

- slow-client test cannot grow memory without bound.
- reconnect inside retention window resumes.
- reconnect outside retention window returns `resync_required`.
- terminal states are queryable by HTTP.
- old client with unsupported protocol version gets clear error.

## Zone 7 - Local Daemon Security

### Hidden Failure Modes

- malicious website connects to localhost daemon.
- DNS rebinding bypasses naive localhost checks.
- browser extension or local app steals token from URL/logs.
- wildcard CORS exposes token-bearing API.
- WebSocket accepts missing or hostile Origin.
- local daemon starts on `0.0.0.0`.
- delete-capable API is accidentally enabled in remote/headless mode.
- support bundle leaks raw private paths or daemon tokens.

### Required Local Mode

```text
bind:
  127.0.0.1 and ::1 only

port:
  random by default

auth:
  per-session token
  no cookies
  no token in URL
  custom HTTP auth header
  authenticated WS handshake

browser checks:
  Host allowlist
  Origin allowlist
  no wildcard CORS
  reject Origin null for sensitive endpoints

limits:
  body size
  message size
  connection count
  rate limits
  bounded queues

logs:
  no tokens
  no raw paths in telemetry
  no raw search text
  no raw delete target paths
```

### Pass Gate

- hostile Host rejected.
- hostile Origin rejected.
- missing token rejected on HTTP and WS.
- token in URL is unsupported.
- delete endpoint rejects browser ambient credentials.
- security tests run as part of protocol/daemon gate.

## Zone 8 - Resource Governance

### Hidden Failure Modes

- pdu/Rayon consumes all cores while HTTP/WS status stalls.
- metadata pool plus scanner pool creates too many open files.
- network scan becomes slower with high concurrency.
- external HDD thrashes under fast mode.
- laptop battery/thermal state makes user blame the app.
- pause only pauses UI, not actual scanner work.
- cancel returns fast but background threads keep scanning.
- multiple scan sessions fight each other.

### Required Runtime Budgets

```text
scan_worker_budget
metadata_worker_budget
index_worker_budget
open_file_permits
event_queue_limits
session_memory_budget
concurrent_session_limit
target_class_profile
```

### Pass Gate

- status endpoint responds during heavy scan.
- cancel reaches terminal state within measured bound.
- background/fast/balanced profiles are observable in metrics.
- network/removable target gets conservative profile.
- open-file limit failure maps to typed warning/failure.
- benchmark report separates raw scan, metadata, indexing, protocol, and UI.

## Zone 9 - Packaging, Permissions, And Process Identity

### Hidden Failure Modes

- user grants macOS Full Disk Access to app, but daemon is the process scanning.
- debug build works, signed/notarized build cannot access same paths.
- security-scoped bookmark works in UI process but not helper.
- update changes helper path/signature and permission state.
- Windows long paths fail in packaged app without manifest.
- Controlled Folder Access blocks writes/trash but appears as generic permission denied.
- SmartScreen/Gatekeeper creates install friction that looks like app crash.
- Linux Flatpak/Snap cannot see hidden/system/external paths but UI promises full scan.

### Required Capability Probe

```text
package_mode
signed_or_debug
sandboxed
scanner_process_identity
trash_process_identity
can_read_home
can_read_downloads
can_read_library_or_app_data
can_read_external_volume
can_trash_selected_target
long_path_support
known_limitations
```

### Pass Gate

- packaged build probes permissions from the same process that scans.
- permission doctor runs before full scan.
- partial scan is labeled as partial.
- update test preserves or clearly invalidates permissions.
- package mode limitations are visible in capability endpoint.

## Zone 10 - Operation Journal

### Hidden Failure Modes

- journal record is written after side effect, so crash loses intent.
- item outcome is recorded before native API actually completed.
- SQLite WAL files are not included in support/backup behavior.
- journal migration fails and cleanup still proceeds.
- idempotency key is reused with different payload.
- operation resumes after app update with incompatible protocol version.
- support bundle exposes full paths from receipt.

### Journal Ordering

```text
1. persist accepted operation intent
2. persist preflight started
3. persist per-item native action started where needed
4. persist per-item native result
5. persist observed free-space measurement
6. persist receipt finalized
```

### Pass Gate

- crash before native call recovers as pending/not executed.
- crash during native call recovers as partial/unknown and requires reconciliation.
- retry same idempotency key returns same operation/result.
- retry same idempotency key with different payload is rejected.
- migration failure disables cleanup.
- receipt redaction is tested.

## Zone 11 - Flutter Large Tree UI

### Hidden Failure Modes

- table uses `DataTable` and mounts too many widgets.
- row index is used as identity, then sort/filter queues wrong item.
- expansion state stored in row widget disappears when scrolled out.
- progress event rebuilds whole tree.
- details query starts inside `build` and restarts repeatedly.
- compact layout hides warning/delete state.
- accessibility tree cannot represent virtualized treegrid semantics.
- Headless/design_system lacks primitive, causing local hacks.

### Required UI State Split

```text
focused_node
selected_node
expanded_nodes
queued_nodes
checked_delete_items
hovered_row
visible_projection
query_cache
server_plan_version
```

### Pass Gate

- 50k-200k visible projection test stays smooth enough in profile build.
- full scan tree is never stored in Flutter.
- row key uses node/snapshot/projection identity.
- queue action uses server node ID and plan version, not row index/path text.
- compact reference keeps delete warnings visible.
- if Headless lacks treegrid/table virtualization primitives, report it before workaround.

## Zone 12 - Fixture Lab

### Hidden Failure Modes

- edge cases exist only in docs and never become tests.
- destructive tests accidentally touch real user files.
- CI passes because platform-specific tests silently skipped.
- golden/protocol snapshots are not reviewed.
- performance benchmarks compare different fixture shapes.
- property test failures are not persisted as regressions.

### Fixture Classes

```text
identity:
  hardlink
  symlink file
  symlink dir
  broken symlink
  path replaced after scan
  Windows reparse/junction when available

accounting:
  sparse file
  compressed file where supported
  APFS clone optional
  Btrfs reflink optional
  open deleted POSIX file

traversal:
  deep tree
  huge direct-child directory
  permission denied subtree
  mount boundary
  pseudo filesystem mock
  cloud placeholder mock

cleanup:
  Trash supported
  Trash unsupported
  locked file
  partial failure
  retry/idempotency

protocol:
  slow client
  reconnect inside replay window
  reconnect outside replay window
  unsupported event type
  stale cursor
```

### Pass Gate

- fixtures are created only under disposable temp roots.
- destructive tests require explicit fixture root marker.
- platform skip reason is explicit.
- benchmark fixtures define node count, depth, branching factor, file sizes, and target class.
- every P0 bug gets a named regression test.

## Most Dangerous Integration Points

These are the places where multiple zones meet and bugs become expensive:

1. **pdu -> read model conversion**
   🎯 7 🛡️ 9 🧠 8, roughly 1000-2500 LOC spike/tests.
   Risk: memory overlap and semantic loss.

2. **read model -> protocol cursor**
   🎯 8 🛡️ 9 🧠 7, roughly 700-1800 LOC.
   Risk: stale pages, duplicate rows, wrong selection after sort/filter.

3. **UI queue -> DeletePlan**
   🎯 8 🛡️ 10 🧠 8, roughly 900-2400 LOC.
   Risk: row index/path string becomes destructive authority.

4. **DeletePlan -> TrashAdapter -> journal**
   🎯 7 🛡️ 10 🧠 9, roughly 1500-4000 LOC.
   Risk: partial operation without recoverable receipt.

5. **daemon local API -> browser UI**
   🎯 8 🛡️ 10 🧠 7, roughly 800-2200 LOC.
   Risk: localhost API becomes a private-file disclosure or delete surface.

6. **packaging -> permission probe -> scanner process**
   🎯 7 🛡️ 9 🧠 8, roughly 1000-3000 LOC/config/tests.
   Risk: app asks permission for one binary and scans from another.

## Strongest Next Spike Recommendation

If we want maximum risk reduction before product UI work:

1. **pdu + read-model memory combined spike**
   🎯 8 🛡️ 9 🧠 8, roughly 1600-3500 LOC.
   Proves scanner contract, memory, indexes, query pagination, and disposal.

2. **identity + Trash + operation journal combined spike**
   🎯 7 🛡️ 10 🧠 9, roughly 1800-4500 LOC.
   Proves cleanup can be made safe enough to build UX around it.

3. **daemon security + protocol backpressure spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1300-3000 LOC.
   Proves web UI/local daemon model is safe and recoverable.

Do these before building the polished tree UI. Otherwise the UI will be designed against unproven contracts.

## Additional Source-Specific Findings

This section records deeper findings from a second pass over current docs and dependency surfaces.

### pdu 0.23.0 Integration Surface

`parallel-disk-usage` latest docs expose the library crate and point integration toward `FsTreeBuilder`, `TreeBuilder`, `DataTree`, and reporter modules.

Implications:

- production integration can stay in-process as a Rust library adapter;
- production must not shell out to a user-installed `pdu` binary;
- adapter tests must pin pdu option mapping and pdu version behavior;
- reporter integration must be measured separately from final tree conversion;
- if `DataTree` traversal forces memory duplication, the first fallback is a pdu adapter patch/fork, not replacing the app architecture.

New proof gate:

```text
pdu version: 0.23.0 or selected pinned version
raw pdu scan peak RSS
pdu reporter event count
pdu reporter max event gap
pdu DataTree to NodeStore conversion peak RSS
time until raw pdu tree is dropped
```

### Read-Model Storage Crates

Current candidates:

1. Plain `Vec<NodeRecord>` plus typed `NodeId` - 🎯 9 🛡️ 8 🧠 4, roughly 200-600 LOC.
   Best first spike. Immutable snapshots do not need deletion, so generational arena complexity is not justified yet.

2. `compact_str` for names - 🎯 7 🛡️ 8 🧠 4, roughly 100-400 LOC.
   Good if many node names are short and string memory is visible in profiling.

3. `lasso` interning after profiling - 🎯 6 🛡️ 8 🧠 6, roughly 300-900 LOC.
   Good if repeated path segments dominate. Its read-only resolver modes are interesting for immutable snapshots, but lifetime and concurrency rules need care.

4. `fst` for future name prefix/fuzzy index - 🎯 4 🛡️ 8 🧠 8, roughly 800-2200 LOC.
   Strong later because it is designed for very large key sets and can stream to file/mmap, but too heavy for MVP tree browsing.

5. `dhat` for repeatable heap profiling - 🎯 8 🛡️ 7 🧠 4, roughly 100-300 LOC in benchmark harness.
   Useful for spike builds, not production runtime.

Do not add `slotmap`/generational arena first unless snapshot mutation becomes real. The immutable scan snapshot is simpler and more cache-friendly as an append-only vector.

### WebSocket Security And Localhost Browser Policy

OWASP WebSocket guidance reinforces that WebSocket is a DoS and auth surface, not just a convenience transport.

New protocol defaults:

- max message size starts at 64 KB or lower;
- compression disabled by default until memory/CPU tested;
- token and Origin validation required during handshake;
- message schemas are validated;
- heartbeat and idle timeout required;
- rate limits per client;
- server logs connection lifecycle and violations, not payloads;
- slow client policy is tested with synthetic client that stops reading.

Chrome Local Network Access research changes the web deployment posture:

- daemon-served loopback UI remains MVP;
- hosted web UI connecting to `localhost` is future work;
- hosted web UI requires pairing, token, origin allowlist, secure context, and browser prompt testing;
- service worker cache must not make an old hosted UI talk to a newer daemon protocol silently.

Critical distinction:

```text
daemon-served local UI:
  lower browser policy risk
  simpler origin story
  good MVP

hosted UI to local daemon:
  higher browser policy risk
  requires pairing and LNA/PNA testing
  future adapter
```

### Trash Semantics

FreeDesktop Trash specification explicitly warns not to recover original filenames from Trash filenames. Original path comes from `.trashinfo`. It also requires atomic info-file creation before moving the item.

Implications:

- Linux receipt must store adapter-provided Trash evidence, not inferred path;
- Trash filename is not identity;
- missing `.trashinfo` is an emergency/unsupported state, not a normal receipt;
- per-volume Trash support must be detected per target.

macOS `FileManager.trashItem` returns a resulting URL because the actual name may change. Windows `IFileOperation` must report item-level results through progress sink behavior. Both reinforce the same rule:

```text
receipt evidence comes from the native Trash operation result,
not from our guessed target path.
```

### Packaged Identity

Apple PPPC identity docs say helper tools embedded within an app bundle can inherit enclosing app bundle permissions. This is useful, but it is not enough as proof for our exact product shape.

Required macOS packaged tests:

- app-child helper launched from bundle;
- helper that does not daemonize through shell;
- `SMAppService` helper later;
- app moved after permission grant;
- app updated with same bundle/team identity;
- helper renamed/resigned;
- Full Disk Access granted to app only;
- Full Disk Access denied;
- selected folder bookmark flow.

Windows MSIX docs add two non-obvious constraints:

- full-trust MSIX behaves much closer to normal desktop apps than AppContainer, but still has package identity and virtualization details;
- packaged app loopback IPC is explicitly constrained and requires manifest/capability choices or debug exemptions in some cases.

Therefore Windows MVP should prefer signed unpackaged installer unless MSIX loopback and daemon child process behavior are proven.

### Resource Governance

Tokio `spawn_blocking` docs are a clear architecture warning: started blocking tasks cannot be aborted and the default blocking-thread upper limit is large. Long scanner sessions need owned workers, cooperative cancellation, and explicit budgets.

Linux IO priority docs add another warning: realtime IO can starve the system, while idle IO only runs when no one else needs the disk. So platform resource adapters must report actual support and effective policy.

Apple QoS docs reinforce that QoS changes CPU, IO throughput, scheduling, and timer latency. That makes QoS a resource-profile adapter, not a domain concept.

Resource profile hard rules:

- Fast mode cannot bypass queue, memory, file-handle, or cancellation budgets.
- Background mode must reduce event rate and optional metadata work, not only thread count.
- Control plane must have independent budget from scanner/indexer.
- Delete preflight should have priority over optional enrichment.
- The daemon chooses effective budget. UI only requests a profile.

## Third-Pass Adversarial Findings

This section documents failure modes that only become visible when the system is stressed, upgraded, backgrounded, packaged, or interrupted.

### pdu Reporter And Tree API Risks

`DataTree` exposes `children()`, `name()`, `size()`, parallel sort/retain helpers, and conversion into a serializable reflection. Its fields are private and `DataTree` itself does not directly implement protocol serialization. Reporter integration is synchronous through `Reporter::report(&self, Event)`. `Event` is non-exhaustive and currently includes received data, encountered errors, and hardlink detection.

New risks:

- reporter callbacks must never do blocking IO, JSON serialization, UI transport, or heavy allocation;
- reporter must accept future unknown pdu event variants without panicking;
- hardlink events must not be treated as ordinary progress;
- progress data is not an authoritative scan snapshot;
- `ParallelReporter::destroy` can fail or panic through boxed thread join state, so adapter shutdown must map this into a typed degraded terminal state;
- `DataTree` parallel sort/retain APIs are useful for CLI output, but product paging should not depend on mutating pdu's tree;
- conversion through reflection/JSON is unacceptable for production because it adds serialization cost and loses adapter control;
- pdu dependency upgrades can alter semantics without our public API changing.

Stricter adapter contract:

```text
PduAdapter
  build_tree(options, reporter)
  reporter callback:
    nonblocking
    bounded
    panic-safe
    unknown-event-safe
  result:
    raw tree only inside adapter boundary
    mapped snapshot stats
    pdu version
    option fingerprint
    semantic flags
```

Kill criteria:

- reporter blocks scanner worker threads under slow transport;
- unknown pdu event crashes the scan;
- adapter must serialize `DataTree` to JSON to access data;
- pdu parallel sort/retain becomes required for UI pagination;
- pdu option fingerprint is missing from fixture snapshots.

### Read-Model Pathology Tests

The read model must pass adversarial shapes, not only normal home directories.

Add these fixtures:

```text
wide_500k:
  one directory with 500k direct children

deep_10k:
  path depth near OS and recursion limits

repeated_segments:
  millions of repeated short names

long_names:
  names near platform max component length

case_fold_collision:
  names that collide on case-insensitive platforms

unicode_normalization:
  visually same names with different byte sequences

permission_mixed:
  readable parent with unreadable descendants

mutation_during_conversion:
  file replaced while pdu result is being mapped
```

New rules:

- use iterative traversal during pdu tree conversion if recursion depth can exceed safe stack bounds;
- path equality and display equality are separate concepts;
- cursor tie-breaker must include stable node ID, not only size/name;
- names are byte/OS-string facts first and display strings second;
- search normalization cannot become cleanup authority;
- if a name cannot be represented as valid Unicode, display uses lossless escaped/encoded form and protocol carries raw path evidence separately where needed.

Kill criteria:

- conversion stack overflows on deep fixture;
- cursor duplicates/skips rows in wide fixture;
- case-folded search result can queue the wrong object;
- lossy path display is used in DeletePlan identity;
- search index must be rebuilt fully for every keystroke.

### Browser Transport Edge Cases

Stable browser `WebSocket` has no incoming backpressure. `bufferedAmount` only helps detect bytes queued by `send()` on that socket; it does not give us a reliable inbound pressure signal from the browser UI to the daemon. `WebSocket.close()` also begins a closing handshake after queued outgoing messages, so it must not be used as proof that a terminal event reached the UI.

New rules:

- terminal state must be queryable by HTTP before or at the same time as emitting terminal event;
- client marks local event stream state as `possibly_stale` after abnormal close, sleep/wake, background resume, tab freeze, service worker update, or protocol version mismatch;
- daemon treats WebSocket delivery as best-effort notification unless event is acknowledged and replayable;
- no event payload should depend on compression to fit size limits;
- browser `bufferedAmount` is a client diagnostic only, not server flow control;
- service worker must not cache protocol JS independently from daemon protocol version.

Reconnect states:

```text
connected_live
  events current

connected_replaying
  events replaying from last_seen_sequence

possibly_stale
  websocket dropped, HTTP resync required

resync_required
  replay window missing or snapshot changed

protocol_incompatible
  UI and daemon versions cannot safely talk
```

Kill criteria:

- close frame is treated as terminal event delivery;
- abnormal browser close leaves UI looking current;
- service worker serves old UI after daemon protocol upgrade;
- hosted UI to local daemon is enabled without Local Network Access test plan;
- slow client can force durable event replay window to grow without bound.

### Delete And Trash Adversarial Cases

Delete safety must survive path mutation and provider behavior.

Add adversarial cases:

```text
replace_file_with_symlink_after_scan
replace_dir_with_junction_after_scan
case_rename_before_confirm
parent_moved_before_execute
volume_unmounted_after_plan
cloud_placeholder_hydrates_on_metadata
readonly_file_in_selected_dir
locked_file_in_selected_dir
partial_trash_success
trash_receipt_missing_native_destination
```

Windows file attributes add product-relevant signals:

- `REPARSE_POINT` means symlink, junction, mount point, cloud file, or provider-managed behavior can be present;
- `OFFLINE` means data is not immediately available;
- `RECALL_ON_OPEN` and `RECALL_ON_DATA_ACCESS` indicate opening/enumerating/reading can fetch remote content or virtualized contents.

New rules:

- metadata enrichment must not hydrate cloud files accidentally;
- delete preflight should treat provider-managed placeholder state as high-risk;
- selected directory cleanup is item-level best-effort with receipt, not one atomic operation;
- if a child inside selected directory fails Trash, parent plan cannot be summarized as simple success;
- final receipt must distinguish "moved to Trash", "probably moved", "permanently removed", "not touched", and "unknown".

Kill criteria:

- any cleanup path follows a newly introduced symlink/junction without explicit policy;
- cloud placeholder hydration occurs during normal scan without user intent;
- partial delete loses per-item status;
- receipt cannot distinguish Trash from permanent delete;
- unsupported Trash target can still be confirmed through normal cleanup flow.

### Packaged Runtime And Local API Adversarial Cases

Packaging tests must prove negative cases too.

Add adversarial cases:

```text
macos_helper_launched_through_shell
macos_helper_daemonizes
macos_app_moved_after_permission
macos_helper_resigned_only
windows_msix_fulltrust_loopback
windows_msix_appcontainer_loopback
windows_unpacked_signed_installer
linux_appimage_full_access
linux_flatpak_limited_home
linux_snap_hidden_home_denied
```

Rules:

- if scanner process identity changes, capability cache is invalidated;
- local daemon token is bound to daemon instance and rotated on restart/update;
- loopback bind address defaults to loopback only, never `0.0.0.0`;
- daemon-served UI includes daemon protocol version in HTML/bootstrap response;
- hosted UI pairing stores only scoped token, not a reusable broad local token;
- packaged mode appears in capability endpoint.

Kill criteria:

- Full Disk Access is tested only in debug;
- packaged app can connect to a stale daemon from older install;
- local API listens on LAN by default;
- update can replace daemon while scan/delete operation is active;
- uninstall leaves active daemon with valid token.

### Operation Journal And SQLite/WAL Risks

The operation journal is part of delete safety. SQLite WAL is useful, but it introduces operational details:

- WAL mode appends changes to a separate WAL file before checkpoint;
- WAL can grow if checkpoints are blocked by readers;
- copying only the `.db` file is not a valid support/export backup while WAL is active;
- recovery may return `SQLITE_BUSY` or need exclusive recovery locks in edge cases.

Rules:

- support bundle export must use SQLite backup API or checkpoint-safe copy, not raw `.db` copy;
- operation journal write happens before destructive adapter call;
- receipt write happens immediately after adapter item result;
- long-running read queries must not block checkpoints forever;
- journal schema migrations must not run during active delete operation.

Kill criteria:

- crash after Trash action but before receipt loses item status;
- support bundle misses `.wal` state or copies DB unsafely;
- journal checkpoint competes with scanner under disk-full condition;
- delete operation can start while journal is unavailable.

### Resource Budget Failure Injection

Resource governance needs failure injection, not only benchmark comparison.

Inject:

```text
slow_disk_latency
network_share_timeout
permission_error_storm
metadata_hydration_delay
websocket_client_stop_reading
http_cancel_during_index_build
battery_saver_enabled_mid_scan
sleep_wake_mid_scan
disk_full_during_journal_write
```

Rules:

- `cancel` endpoint has its own budget and priority;
- `status` endpoint has its own budget and priority;
- disk-full during cache/write does not corrupt scan session state;
- background profile reduces optional work first, then scanner work;
- Fast profile never raises Linux IO to realtime class;
- Windows background/EcoQoS and macOS QoS are effective-policy hints, not correctness assumptions.

Kill criteria:

- cancel takes longer than accepted SLA under load;
- status endpoint stalls behind pdu/indexing;
- Fast mode can starve the machine;
- low disk space breaks operation journal;
- sleep/wake leaves scan permanently "running" without progress or terminal state.

## Fourth-Pass System Boundary Findings

This section records boundaries where the product must choose an explicit failure policy. These are not ordinary edge cases. They decide whether Clean Disk fails closed, leaks authority, or gives the user a false sense of safety.

### Local Daemon Attack Boundary

The local daemon is a private-data API. Binding to loopback does not make it trusted. Browser policies help, but the daemon still needs its own defenses.

Threats:

- DNS rebinding sends browser traffic to loopback/private addresses after a public page is loaded;
- hostile `Host` header reaches local daemon;
- hostile or missing `Origin` reaches WebSocket handshake;
- `Origin: null` appears from sandboxed documents or local files;
- public hosted UI triggers Private Network Access / Local Network Access policy;
- service worker serves an old UI bundle with new daemon connection info;
- browser extension or local process tries to call delete-capable endpoints;
- token leaks through URL, logs, crash reports, or support bundles.

Required local mode policy:

```text
bind:
  127.0.0.1
  ::1
  never 0.0.0.0 by default

auth:
  explicit header for HTTP
  explicit handshake field or subprotocol for WebSocket
  no cookie auth
  no token in URL

browser:
  Host allowlist
  Origin allowlist
  reject Origin null for sensitive endpoints
  no wildcard CORS
  PNA/LNA behavior tested before hosted UI
```

Top 3 local UI deployment choices:

1. Daemon-served loopback UI - 🎯 9 🛡️ 9 🧠 6, roughly 500-1400 LOC.
   Best MVP. The daemon serves the matching UI bundle and protocol version, which reduces hosted-origin and service-worker skew.

2. Desktop Flutter UI connecting to loopback daemon - 🎯 9 🛡️ 8 🧠 5, roughly 400-1000 LOC.
   Good desktop path. It avoids browser PNA prompts but still needs daemon token, Host, and local process hardening.

3. Public hosted web UI connecting to local daemon - 🎯 4 🛡️ 6 🧠 8, roughly 1200-3200 LOC.
   Future adapter only. It needs pairing, PNA/LNA tests, strict Origin policy, token scoping, and clear browser prompt UX.

Kill criteria:

- local API accepts arbitrary Host;
- WebSocket accepts missing or hostile Origin;
- delete-capable API accepts cookie-only auth;
- token appears in URL;
- hosted UI can talk to daemon without pairing;
- daemon returns private path data to an unpaired origin.

### Rust Panic, Abort, And OOM Boundary

Rust safety does not mean the daemon cannot crash. Panics, aborts, allocation failures, and poisoned state still matter because scans can run for minutes and cleanup is destructive.

Important facts:

- `catch_unwind` catches only unwinding panics, not aborting panics;
- it is not a replacement for `Result`;
- pdu `Event` is non-exhaustive and is not `UnwindSafe`;
- `Vec::push` and ordinary reserve growth can panic on capacity overflow;
- `try_reserve` can turn allocation failure or overflow into a typed error before complex work starts;
- if the process aborts, only crash recovery and durable journal can explain state.

Top 3 panic/OOM strategies:

1. Typed errors plus fallible allocation at large growth points - 🎯 9 🛡️ 9 🧠 6, roughly 500-1400 LOC.
   Use `try_reserve`, explicit node budgets, and `resource_exhausted` outcomes before large arena/index growth.

2. In-process worker supervisor with panic mapping for scan/index tasks - 🎯 7 🛡️ 7 🧠 6, roughly 600-1600 LOC.
   Useful for non-destructive scan workers. It can map unwinding panics to failed scan sessions, but cannot protect against aborts.

3. Separate scanner subprocess isolation - 🎯 5 🛡️ 9 🧠 8, roughly 1500-4000 LOC.
   Stronger crash isolation if pdu or native adapters prove unstable. More protocol/process complexity, so not MVP unless spikes expose crashes.

Required rules:

- adapter callbacks must never panic on unknown pdu event;
- scan/index worker panic becomes `ScanFailedPanic` when recoverable;
- delete adapter panic during destructive workflow becomes `DeleteStateRequiresReview`, never automatic retry;
- operation journal is the source of truth after daemon crash;
- OOM risk is managed by memory budgets and fallible reservation, not catch-unwind;
- debug panic details stay out of production user-facing errors and telemetry path fields.

Kill criteria:

- production relies on catch-unwind to make cleanup safe;
- pdu reporter panic can crash the daemon silently;
- arena/index growth uses only unchecked `push`/`reserve` after node count is known;
- panic during delete can auto-resume on restart;
- crash recovery cannot distinguish interrupted scan from interrupted delete.

### Non-Atomic Scan Snapshot Boundary

A filesystem scan is not a database transaction. The tree can mutate while pdu scans, while we convert the tree, and while the user is deciding what to delete.

Risks:

- total size combines files observed at different times;
- directory entry changes after parent was scanned;
- file grows or shrinks after pdu size calculation;
- path is deleted and recreated with same name;
- pdu result is internally consistent as a tree shape but not a point-in-time filesystem state;
- UI compares two snapshots as if they were exact deltas.

Required snapshot model:

```text
ScanSnapshot
  snapshot_id
  scan_started_at
  scan_finished_at
  observed_window
  consistency: best_effort_filesystem_walk
  mutation_warnings
  skipped_summary
  source_adapter_version
```

Rules:

- UI says scan data is a snapshot estimate, not live truth;
- selected-node details can refresh current metadata;
- DeletePlan always revalidates identity and metadata;
- diff/incremental scan must treat unchanged path as a hypothesis until identity evidence agrees;
- snapshot IDs are never reused;
- page cursors expire when snapshot is disposed.

Kill criteria:

- scan snapshot is described as exact filesystem state;
- delete plan trusts scan-time size/path without revalidation;
- rescan diff uses path-only matching for cleanup decisions;
- user can act on stale warning-free node after target mutation is detected.

### Protocol Version And Compatibility Boundary

Version skew is inevitable: desktop app, web bundle, daemon, generated DTOs, cached service worker, and support tools can all be out of sync.

Required handshake:

```text
client:
  client_kind
  client_version
  protocol_major
  protocol_minor
  supported_features

daemon:
  daemon_version
  protocol_major
  protocol_minor
  min_supported_client_protocol
  feature_flags
  package_mode
  cleanup_enabled
```

Rules:

- protocol major mismatch disables commands;
- incompatible cleanup protocol disables delete UI and server rejects delete commands;
- unknown event type is ignored only if marked non-critical;
- unknown required field fails fast;
- generated DTO snapshots are versioned;
- service worker cache is disabled or version-bound until update semantics are designed.

Kill criteria:

- old UI can send delete command to newer daemon without version gate;
- old service worker can serve UI bundle that misreads daemon payloads;
- protocol errors show as generic network failure;
- server accepts missing protocol version;
- generated DTOs are changed without snapshot compatibility tests.

### Path Representation And Privacy Boundary

Paths are both identity-sensitive and privacy-sensitive. Display strings are not enough for correctness, and raw paths are too sensitive for logs.

Rules:

- path bytes / OS string / display string are separate representations;
- path normalization is allowed for search, never for destructive identity;
- path redaction happens before telemetry/logging/support bundle export;
- support bundle can include stable opaque node IDs and path hashes by default;
- user explicitly opts in before raw paths are exported;
- bidi/control characters in names are escaped or safely rendered in UI;
- path length and invalid Unicode are tested in protocol DTOs.

Kill criteria:

- lossy display path is used as delete authority;
- raw search query or raw path appears in production logs;
- support bundle exports full tree by default;
- bidi/control character can visually disguise queued delete target;
- protocol assumes all paths are valid UTF-8.

### Final Fourth-Pass Gates

Before scanner implementation:

- pdu reporter callback is proven nonblocking and unknown-event-safe.
- pdu conversion uses iterative traversal or stack-depth limit.
- arena/index allocation uses budgets and fallible reservation at large growth points.

Before local daemon exposure:

- Host/Origin/token tests pass, including hostile Host, hostile Origin, `Origin: null`, no token, oversized body, oversized WS frame, and replayed command.
- daemon-served UI version matches daemon protocol.
- hosted UI path stays disabled until PNA/LNA pairing is designed.

Before cleanup implementation:

- operation journal can recover from crash at every state transition.
- delete preflight blocks path replacement, symlink/junction swap, cloud-placeholder high-risk state, and stale identity.
- receipt storage is durable before final success is shown.

Before beta:

- packaged macOS and Windows permission identity is tested with release-like signed artifacts.
- low-memory and disk-full injection produce typed outcomes.
- sleep/wake and update/restart do not leave active operations in misleading states.

## Fourth-Pass Hardening Layer

This layer turns the critical zones into invariants, negative tests, kill switches, and release blockers. It should be treated as architecture, not QA polish.

### Cross-Zone Invariants

Product safety:

- A path string is never destructive authority. Delete authority comes only from a `DeletePlan` built from scan snapshot, node identity evidence, live revalidation, confirmation token, and idempotency key.
- A selected row cannot be deleted if its current identity no longer matches the scan identity evidence.
- A symlink, junction, reparse point, mount boundary, package, cloud placeholder, or system-managed folder cannot silently change cleanup semantics.
- Every destructive operation produces one durable item outcome per requested item: `not_started`, `blocked`, `moved_to_trash`, `already_gone`, `partial_unknown`, `failed`, or `unsupported`.
- Reclaim totals never collapse logical bytes, allocated local bytes, exclusive reclaim estimate, quota effect, and observed free-space delta into one number.
- The app never claims exact freed bytes unless the daemon observed the free-space delta or proved exclusivity with platform evidence.
- Cleanup can be globally disabled by capability probe, package mode, policy, unsupported Trash, journal migration failure, or security mode.

Data and protocol:

- Rust owns the complete scan snapshot. Flutter owns only visible projections, selection state, expansion state, and queued command intent.
- A protocol DTO is not a domain entity, not a persistence row, and not a Flutter view model.
- Every event has `session_id`, `operation_id` where relevant, monotonic `sequence`, `schema_version`, and explicit event class: `durable`, `coalescible`, or `invalidation`.
- HTTP query state is authoritative after reconnect. WebSocket events are acceleration and notification, not the only source of truth.
- A cursor is valid only for the same `session_id`, `snapshot_id`, `index_version`, query scope, sort key, filter hash, last sort tuple, and last node id.
- When a client lags past replay retention, the only valid result is `resync_required`, not best-effort continuation.
- Terminal states are durable and queryable by HTTP even if the WebSocket terminal event is missed.

Runtime:

- Every queue that can be influenced by filesystem size, client count, or event rate is bounded.
- Slow clients cannot make daemon memory grow without bound.
- Scanner, metadata, indexer, protocol, and control plane have separate budgets.
- Cancel is cooperative but must reach a typed terminal state within a measured bound for each target class.
- Optional metadata cannot block scan completion, protocol commands, or delete safety revalidation.
- A session memory budget breach returns a typed `resource_exhausted` state with partial stats, not process OOM.

Security and packaging:

- The process that asks for or probes permissions must be the same effective identity that scans or deletes, or the capability endpoint must say otherwise.
- Local daemon binds only loopback by default.
- Local HTTP and WebSocket require a session token, explicit Host allowlist, and explicit Origin allowlist.
- Tokens, raw paths, raw search text, raw delete targets, and full scan trees are never written to production logs or telemetry.
- Remote/headless mode starts read-only unless explicit auth, scope, audit, and destructive capability policy are implemented.

### Fault Injection Matrix

| Area | Injected failure | Expected result |
| --- | --- | --- |
| pdu adapter | pdu returns tree after many skipped paths | skipped reasons are preserved and queryable |
| pdu adapter | cancel during deep traversal | terminal state is `cancelled`, not hanging worker |
| pdu adapter | pdu upgrade changes hardlink total | golden fixture fails with semantic diff |
| read model | 1M and 5M generated nodes | memory budget measured, graceful resource limit if exceeded |
| read model | one parent with 300k children | paginated query works without sorting every request from scratch |
| read model | dispose snapshot with active cursor | old snapshot held only while referenced, then released |
| cursor | sort/filter changes after cursor issued | cursor rejected as stale |
| search | user types rapidly over 1M nodes | old queries cancelled or superseded |
| metadata | selected node deleted during enrichment | details returns stale/unavailable, delete plan revalidates separately |
| traversal | symlink loop or junction loop | skipped with typed reason, no infinite traversal |
| traversal | root is symlink | root policy is explicit in scan metadata |
| traversal | network/FUSE target stalls | conservative profile, cancel works, UI remains responsive |
| accounting | sparse/compressed/reflinked file | lower confidence and separate logical/allocated/exclusive fields |
| accounting | free-space delta differs from estimate | receipt keeps both estimate and observed delta |
| delete | path replaced after scan | delete blocked by identity mismatch |
| delete | Trash unsupported for volume | operation blocked or requires explicit future permanent-delete mode |
| delete | crash after 1 of N items moved | journal recovers partial/unknown state with receipt evidence |
| delete | retry same idempotency key | same result returned, not a second destructive action |
| protocol | WebSocket client stops reading | bounded queue hits lag policy, daemon memory remains bounded |
| protocol | reconnect after replay retention expired | client receives `resync_required` |
| protocol | old UI version connects | protocol negotiation rejects unsupported version |
| daemon security | hostile Origin and valid-looking localhost Host | request rejected |
| daemon security | oversized WS frame | connection closed and violation logged without payload |
| daemon security | token appears in URL | request rejected and token not logged |
| packaging | macOS permission granted to app but daemon path changes | capability probe exposes mismatch before scan |
| packaging | Windows long path target | manifest/capability probe determines support before scan |
| journal | SQLite migration fails | destructive operations disabled |
| journal | disk full while writing receipt | cleanup stops in recoverable state |
| UI | progress event storm | table projection does not rebuild from scratch |
| UI | row sorted while queued | queue keeps node/plan identity, not row index |
| UI | compact layout with delete warning | warning remains visible before confirmation |

### Test Strategy By Risk Class

Property tests:

- generated trees where every child has one parent and totals roll up consistently;
- generated path names with Unicode, separators, reserved names, empty-ish edge cases, long names, and invalid byte cases on Unix adapters;
- cursor round trips for random sort/filter/page combinations;
- delete plan construction where stale identity evidence always blocks action;
- reclaim confidence propagation where any uncertain child lowers or caps parent confidence;
- event streams where terminal events are never reordered behind later non-terminal events;
- operation state machines where every accepted command reaches exactly one terminal state.

Property-test pass gate:

- failing cases are persisted as regression inputs;
- generators include huge direct-child directories, deep chains, and mixed file/folder/package nodes;
- shrinking does not destroy the invariant being tested.

Fuzz targets:

- protocol JSON envelope parser;
- cursor decoder;
- path DTO decoder;
- problem-details decoder;
- event stream frame decoder;
- import/export format if added later;
- redaction logic for logs/support bundles.

Fuzz pass gate:

- malformed input never panics the daemon;
- invalid input maps to typed protocol error;
- parser does not allocate unbounded memory from claimed lengths;
- fuzz targets run with bounded time in CI and longer in scheduled jobs.

Concurrency and model tests:

- event queue lag handling;
- scan session state machine;
- cancellation race against terminal completion;
- dispose race against active query;
- idempotency-key race on duplicate command;
- pause/resume state transitions if implemented;
- watcher refresh race against selected node details if incremental scan is added.

Concurrency pass gate:

- no state transition depends on wall-clock timing for correctness;
- no public operation can observe an impossible state;
- concurrency tests are separate from performance benchmarks.

Crash and kill tests:

- kill before journal intent write;
- kill after intent write and before native action;
- kill after per-item native action started;
- kill after native result before receipt finalized;
- kill during WAL checkpoint or database reopen;
- kill while scanner snapshot is being replaced;
- kill while UI is connected through WebSocket.

Crash pass gate:

- daemon restarts without corrupting local state;
- destructive operation either resumes to a safe recovery state or requires explicit user reconciliation;
- terminal state is not invented from missing evidence;
- support bundle can explain the recovery state without leaking raw paths by default.

Performance stress tests:

- 100k, 1M, and 5M synthetic node snapshots;
- huge direct-child directory;
- deep path chain near OS limits;
- multiple clients connected, one slow and one active;
- repeated search/sort/filter while scan progresses;
- selected-node details churn during progress event stream;
- low memory budget;
- low file descriptor limit;
- network/removable target profile;
- heavy antivirus/Spotlight/indexer activity where reproducible.

Stress pass gate:

- status endpoint remains responsive;
- daemon memory reaches a plateau or explicit resource limit;
- UI frame budget is measured in profile build;
- event rate is coalesced before it reaches Flutter rebuild hot paths;
- benchmark report separates raw scan, mapping, indexing, protocol, and UI rendering.

### Kill Switches And Feature Flags

These switches should exist before the corresponding risky capability ships.

```text
cleanup_enabled
trash_enabled
permanent_delete_enabled
remote_destructive_actions_enabled
metadata_enrichment_enabled
cloud_hydration_enabled
follow_symlinks_enabled
follow_reparse_points_enabled
cross_mount_scan_enabled
hosted_web_ui_pairing_enabled
incremental_watchers_enabled
recommendation_rules_enabled
```

Defaults:

- `cleanup_enabled = false` until identity, Trash, journal, and receipt gates pass.
- `permanent_delete_enabled = false` for MVP.
- `cloud_hydration_enabled = false` for MVP.
- `remote_destructive_actions_enabled = false` unless remote auth/audit/scope is designed.
- `hosted_web_ui_pairing_enabled = false` until browser local-network policy is tested.

Flutter should not infer dangerous capability from platform name.

Rules:

- UI reads daemon capability endpoint.
- UI hides or disables actions from capabilities, not compile-time assumptions.
- UI shows partial scan and unsupported cleanup states as first-class product states.
- UI never shows "safe to delete" without evidence and risk tier from daemon.

### Release Blockers

P0 blockers:

- delete can be initiated from raw path text;
- stale identity can still delete;
- Trash operation lacks per-item outcome;
- journal can lose accepted destructive intent;
- operation retry can perform a second destructive action;
- missing WebSocket terminal event can leave no HTTP terminal state;
- hostile Origin/Host can access local daemon;
- daemon binds non-loopback in local mode by default;
- production logs can include daemon token or raw delete target path;
- UI can queue wrong row after sort/filter;
- scan claims complete while skipped paths are hidden;
- reclaim UI presents estimate as exact freed space.

P1 blockers:

- 1M-node snapshot exceeds memory target without graceful resource state;
- slow WebSocket client causes unbounded memory growth;
- selected-node details can block scan/index/control plane;
- cancellation cannot reach terminal state in bounded time for local SSD target;
- packaged permission probe is from different effective process than scanner;
- old client version can misread new daemon events silently;
- support bundle can leak raw paths without explicit user-visible export mode.

P2 blockers:

- compact UI hides cleanup warnings;
- search cannot cancel/supersede stale queries;
- protocol schemas are not versioned;
- benchmark results mix raw scanner time with indexing/protocol/UI time;
- flaky tests are retried as pass without being reported as flaky.

### Recommended Next Hardening Spikes

1. **Invariant test harness for read model + protocol**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2200 LOC.
   Build generated tree snapshots, cursor property tests, stale cursor tests, and event sequence tests before table UI work.

2. **DeletePlan fault-injection harness**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3000 LOC.
   Simulate stale identity, partial Trash, crashes, idempotency retry, journal disk-full, and receipt redaction before cleanup UI.

3. **Daemon abuse and slow-client harness**
   🎯 8 🛡️ 10 🧠 7, roughly 900-2400 LOC.
   Test hostile Origin/Host/token cases, oversized frames, slow WS consumers, reconnect retention, and control-plane responsiveness.

Best order:

```text
pdu/read-model spike
  -> protocol invariant harness
  -> DeletePlan fault injection
  -> daemon abuse harness
  -> Flutter large-tree profile UI
```

## Fifth-Pass Systemic Risk Layer

This layer treats Clean Disk as a local privileged system, not only a scanner UI. The core question changes from "can it scan fast?" to "can it remain correct when contracts evolve, permissions change, the user upgrades the app, the browser reconnects, and the filesystem mutates under us?"

### Critical State Machines To Specify First

These state machines need explicit transition tables before implementation. The table can live as docs first, then as Rust enums and tests.

```text
ScanSession:
  created
  permission_checking
  queued
  scanning
  indexing
  ready_partial
  ready_complete
  cancelling
  cancelled
  failed
  disposed

ProtocolClient:
  unauthenticated
  authenticated
  live
  replaying
  possibly_stale
  resync_required
  incompatible
  closed

DeletePlan:
  draft
  validating
  blocked
  confirmation_required
  confirmed
  executing
  partially_completed
  completed
  failed
  reconciliation_required
  expired

JournaledOperation:
  intent_persisted
  preflight_started
  native_action_started
  item_result_persisted
  receipt_finalizing
  receipt_finalized
  recovery_required

CapabilityProbe:
  unknown
  probing
  supported
  partial
  unsupported
  stale_due_to_identity_change
```

Rules:

- invalid transitions are code errors, not runtime "best effort";
- terminal states are explicit and queryable;
- a state machine must define what happens after crash, reconnect, update, permission loss, and user cancellation;
- UI state can mirror daemon state, but cannot invent daemon state;
- state transition logs must use opaque IDs and redacted labels.

Deepest uncertainty:

1. **Rust enums + property tests first**
   🎯 9 🛡️ 8 🧠 5, roughly 600-1500 LOC.
   Best default. It keeps the state model close to implementation and catches most impossible transitions.

2. **Small TLA+ specs for DeletePlan and protocol replay**
   🎯 6 🛡️ 9 🧠 8, roughly 300-900 LOC/specs.
   Useful because the hardest bugs are ordering bugs. Keep scope small or it becomes ceremony.

3. **Full formal model for all operations**
   🎯 3 🛡️ 9 🧠 10, roughly 2500-8000 LOC/specs and maintenance.
   Too heavy for this product now. Consider only if remote destructive operations become enterprise-critical.

### Threat Model Boundaries

Threat modeling should be boundary-based, not a generic checklist.

Trust boundaries:

```text
Flutter UI process
  <-> local daemon HTTP/WS boundary

browser renderer
  <-> localhost daemon boundary

daemon control plane
  <-> scanner worker pool boundary

scanner adapter
  <-> filesystem/provider boundary

DeletePlan
  <-> native Trash adapter boundary

daemon
  <-> local SQLite/journal boundary

packaged app/updater
  <-> daemon binary/config/state boundary

support bundle exporter
  <-> private user data boundary

remote/headless client
  <-> remote daemon boundary, future only
```

STRIDE questions per boundary:

- Spoofing: can another process pretend to be the UI, daemon, scanner, or updater?
- Tampering: can request payload, cursor, DeletePlan, journal, cache, or updater metadata be modified?
- Repudiation: can we prove which operation was accepted without logging private paths?
- Information disclosure: can scan results, search text, full paths, tokens, or receipts leak?
- Denial of service: can a huge tree, slow socket client, malicious website, or network share exhaust resources?
- Elevation of privilege: can a browser page or lower-trust user cause scan/delete outside intended scope?

Hard rule:

```text
Every new transport, cleanup mode, updater path, support export, or remote/headless mode requires a threat-model delta before implementation.
```

### Protocol Evolution And Compatibility

HTTP + WebSocket is simple enough, but protocol evolution is a long-term risk. The app will have daemon, Flutter desktop, Flutter web, cached web assets, generated DTOs, old support bundles, and persisted journal rows.

Compatibility contracts:

```text
HTTP request/response DTOs:
  backward compatible within same major protocol version

WebSocket event DTOs:
  forward tolerant for unknown coalescible/invalidation events
  strict for unknown durable destructive events

Journal schema:
  migration-gated
  no destructive operation during incompatible migration

Support bundle schema:
  readable by newer tools
  private fields redacted by default

fs_usage_* Rust API:
  semver contract independent from Clean Disk product protocol
```

Safe changes:

- add optional response field;
- add optional request field with default;
- add new non-durable event type if old clients can ignore it;
- add new skip reason if old clients display `unknown_reason`;
- add new capability flag if default is conservative;
- add new error code if generic fallback remains clear.

Breaking changes:

- rename or remove field;
- change numeric unit or precision;
- change cursor meaning;
- change enum semantics without fallback;
- make optional field required;
- change DeletePlan confirmation hash inputs;
- change journal recovery interpretation;
- make old client treat unsafe action as safe.

Protocol gates:

- daemon-served UI boot response includes daemon protocol version, UI asset version, and compatibility range;
- WebSocket handshake includes protocol version and last seen sequence;
- HTTP clients send protocol version header;
- old client gets typed `protocol_incompatible`, not partial behavior;
- service worker cannot serve stale protocol code across daemon major upgrade;
- protocol golden fixtures include old and new versions.

### Transaction Authorization For Cleanup

Delete is the product equivalent of a sensitive transaction. The UX should follow a "what you see is what you delete" rule.

Significant confirmation data:

```text
plan_id
plan_hash
scan_snapshot_id
selected_item_count
top_selected_items
target_volume_or_root
estimated_logical_bytes
estimated_allocated_bytes
estimated_exclusive_reclaim
confidence
known_uncertainties
trash_mode
unsupported_or_high_risk_items
expiration_time
```

Rules:

- confirmation token is bound to `plan_hash`, not to raw path text;
- if the plan changes, confirmation is invalidated;
- if any selected item becomes stale, confirmation is invalidated;
- high-risk items require separate acknowledgement, not buried warning text;
- remote/headless destructive cleanup requires stronger auth and audit than local UI cleanup;
- future permanent delete requires a different confirmation path from move-to-trash.

Kill criteria:

- user confirms one plan and daemon executes a different plan;
- UI hides high-risk item count in compact mode;
- confirmation token can be replayed after plan expiration;
- confirmation token is valid across daemon restart without journal evidence;
- remote client can perform destructive action with the same token policy as local UI.

### TOCTOU And Path Resolution Hardening

Time-of-check/time-of-use is the central delete risk. The scan snapshot is historical evidence, not execution authority.

Platform principles:

- Linux should prefer descriptor-relative operations and `openat2` style constraints where available: no symlink traversal, no escaping root, no unexpected mount crossing.
- Windows must account for sharing, pending-delete state, file IDs, reparse points, long paths, and cloud placeholders.
- macOS must account for TCC, security-scoped access, APFS clones/snapshots, packages, and Trash result URLs.
- Network shares and provider filesystems need reduced assumptions because identity, locking, Trash, and reclaim semantics can differ from local disks.

Delete preflight must re-check:

```text
path still resolves under expected root
file identity evidence still matches
parent identity evidence still matches if available
type did not change across file/dir/symlink/reparse/package
mount or volume did not change
cloud/provider state did not become unsafe
permissions still allow intended native Trash operation
Trash support still exists for target volume
```

Execution rule:

```text
If platform cannot prove enough identity for a target, downgrade to blocked/high-risk.
Do not silently fall back to raw path delete.
```

### Upgrade, Downgrade, And Rollback Risks

Local daemon plus web UI creates upgrade states that normal apps can ignore less.

Adversarial update scenarios:

```text
new UI talks to old daemon
old UI talks to new daemon
daemon updates during active scan
daemon updates during active delete
database migrates then app is downgraded
pdu version changes size semantics
capability cache survives app move/resign
service worker serves stale web assets
updater leaves two daemon instances running
```

Rules:

- one active daemon instance per user profile and product channel;
- daemon refuses update/restart during native delete execution unless recovery path is persisted;
- DB migrations are transactional and block cleanup if incomplete;
- downgrade with newer DB schema starts read-only diagnostic mode or asks for explicit reset;
- pdu version and semantic fingerprint are stored with snapshot;
- update invalidates permission/capability cache if binary identity/path/signature changes;
- web asset cache is coupled to daemon protocol major version.

Kill criteria:

- two daemon versions can control the same journal;
- downgraded daemon interprets newer journal as safe;
- old UI can submit cleanup to newer daemon without protocol negotiation;
- pdu upgrade changes totals without golden fixture failure;
- update interrupts delete after native action and before receipt without recovery.

### Remote And Headless Mode Hard Stop Rules

Remote/headless support is attractive, but it changes the product from "local utility" to "remote file visibility and deletion surface".

Remote mode MVP rule:

```text
remote/headless starts scan-only and read-only
cleanup is disabled until auth, authz, audit, scope, rate limits, and restore semantics are designed
```

Extra requirements before remote cleanup:

- authenticated user identity;
- target scope policy, for example allowed roots and deny roots;
- audit trail with redacted but correlatable item evidence;
- per-operation authorization;
- server-side policy for Trash availability;
- tenant/user isolation if multi-user;
- rate limits and concurrent operation limits;
- explicit retention and redaction policy for scan snapshots;
- emergency disable switch.

Kill criteria:

- remote scan can expose arbitrary server paths by default;
- remote cleanup uses local UI confirmation model unchanged;
- audit trail needs raw paths to be useful;
- one user's scan snapshot can be queried by another client;
- daemon token doubles as long-lived remote API credential.

### Data Classification For Every Field

Every DTO, log field, metric label, support bundle field, and cache row needs classification.

Suggested classes:

```text
public:
  app version, protocol version, OS family

operational:
  opaque IDs, durations, counts, sizes, error codes

private_low:
  coarse root labels like Home, Downloads, external volume label if user permits

private_high:
  full paths, filenames, search text, selected cleanup targets, receipts

secret:
  daemon tokens, auth headers, signing keys, pairing codes

dangerous:
  full scan tree, raw DeletePlan targets, unredacted support bundles
```

Rules:

- metrics labels cannot contain high-cardinality private data;
- logs default to `public` and `operational`;
- support bundle export needs explicit user-visible mode for raw paths;
- crash reports never include full scan tree or DeletePlan targets by default;
- protocol debug logging is disabled in production builds;
- redaction is tested with fuzz and golden samples.

### Quality Gates As Architecture

The release process should fail closed.

Required gates before scanner MVP:

- pdu adapter semantic fixtures;
- read model memory benchmark for 100k and 1M nodes;
- cursor property tests;
- bounded queue slow-client test;
- daemon security Host/Origin/token tests;
- partial scan/skipped path UI state.

Required gates before cleanup MVP:

- DeletePlan identity revalidation tests;
- stale path/symlink/reparse replacement tests;
- Trash adapter per-item outcome tests;
- operation journal crash tests;
- confirmation token/plan hash tests;
- redacted receipt/support bundle tests.

Required gates before public desktop installer:

- signed packaged permission probe;
- update/rollback smoke test;
- single-instance daemon lock;
- no stale service worker protocol mismatch;
- supply-chain checks: lockfile, cargo-deny, RustSec, license policy, provenance plan.

Required gates before remote/headless:

- threat model delta;
- scan scope policy;
- auth/authz design;
- audit design;
- destructive actions disabled by default;
- rate-limit and abuse tests.

### New Highest-Risk Unknowns

1. **DeletePlan + journal + native Trash proof under real packaged apps**
   🎯 7 🛡️ 10 🧠 9, roughly 1800-5000 LOC/tests.
   This is still the hardest area because it crosses OS APIs, app identity, user confirmation, crash recovery, and receipt semantics.

2. **Protocol/version compatibility with daemon-served web UI**
   🎯 7 🛡️ 9 🧠 8, roughly 1000-2600 LOC/tests.
   The risk is not writing HTTP routes. The risk is old assets, old clients, reconnect, schema evolution, and cached UI talking to the wrong daemon contract.

3. **TOCTOU-safe path resolution across platforms**
   🎯 6 🛡️ 10 🧠 9, roughly 1500-4500 LOC/tests.
   We can design the interface now, but each OS needs real proof. This is where "looks safe in Rust" can still be wrong because the filesystem is mutable and provider-managed.

## Sixth-Pass Evidence And Containment Layer

This layer is about refusing misleading certainty. Every risky UI statement must be backed by evidence. Every subsystem that can fail under load or platform weirdness must fail into a contained state.

### Evidence Objects, Not Booleans

Avoid domain flags like `is_safe`, `can_delete`, `is_cloud`, `is_reclaimable`, or `is_complete` unless they are derived from explicit evidence.

Core evidence types:

```text
IdentityEvidence:
  path
  volume_id
  file_id_or_inode
  parent_identity
  file_type
  symlink_or_reparse_state
  observed_at
  confidence

AccountingEvidence:
  logical_bytes
  allocated_bytes
  exclusive_reclaim_estimate
  quota_effect
  observed_free_space_delta
  uncertainty_reasons
  confidence

CapabilityEvidence:
  package_mode
  process_identity
  target_root
  volume_type
  filesystem_type
  cloud_provider_state
  trash_supported
  long_path_supported
  permission_scope
  probed_at
  stale_when

TrashEvidence:
  native_api
  requested_target
  native_result
  resulting_trash_reference
  per_item_outcome
  restore_hint
  uncertainty_reasons

ProtocolEvidence:
  daemon_protocol_version
  ui_asset_version
  compatibility_range
  negotiated_features
  last_seen_sequence
  replay_status

JournalEvidence:
  operation_id
  idempotency_key
  persisted_stage
  db_schema_version
  migration_state
  recovery_state
```

Rules:

- evidence has a timestamp and a scope;
- evidence can expire;
- evidence can be partial;
- evidence can be contradictory;
- contradictory evidence blocks destructive actions;
- UI wording must reflect evidence confidence;
- tests must assert evidence propagation, not only final boolean result.

Kill criteria:

- UI shows `safe` from a boolean that is not traceable to evidence;
- delete proceeds when evidence is stale or contradictory;
- confidence is manually set by presentation code;
- support bundle cannot explain why an action was blocked;
- two adapters use different meanings for the same confidence value.

### Target Capability Matrix

Capabilities are per target, not per operating system. A single macOS machine can have APFS local disk, external exFAT, SMB share, iCloud File Provider, Docker volumes, and mounted disk images.

Capability key:

```text
process_identity
package_mode
target_root
volume_id
filesystem_type
mount_kind
provider_kind
permission_scope
resource_profile
```

Capabilities to probe:

```text
can_scan_baseline
can_read_metadata
can_read_allocated_size
can_detect_identity
can_detect_shared_extents
can_detect_cloud_placeholder
can_avoid_cloud_hydration
can_trash
can_restore_hint
can_measure_free_space_delta
can_watch_incrementally
can_delete_safely
```

Rules:

- capability cache is invalidated by process identity change, app update, target remount, permission change, or provider state change;
- a positive capability for one target never generalizes to another target;
- a failed capability probe is not a scan failure, but it changes UI claims;
- delete capability requires stronger evidence than scan capability;
- remote/headless capability is scoped by server policy, not only filesystem access.

### Semantic Drift Ledger

Semantic drift is when the code still compiles but the meaning changes.

Track semantic fingerprints for:

```text
pdu version
pdu option mapping
hardlink policy
symlink/reparse policy
mount boundary policy
size quantity policy
metadata enrichment policy
reclaim accounting policy
Trash adapter version
protocol schema version
journal schema version
recommendation rule version
design-system destructive-action UX version
```

Rules:

- every scan snapshot stores semantic fingerprint;
- every DeletePlan stores semantic fingerprint;
- golden tests compare semantic fingerprints and output;
- recommendation rules cannot change cleanup risk tier without version bump;
- stale snapshots become read-only when semantic policy changes incompatibly.

Kill criteria:

- pdu upgrade changes totals but old snapshots look comparable;
- recommendation rule update makes old candidate look safer;
- journal recovery depends on current code semantics only;
- support bundle lacks enough version info to reproduce a decision.

### Delete, Trash, And Sanitization Language

Move-to-trash is not secure deletion. Permanent delete is still not media sanitization. NIST SP 800-88 distinguishes sanitization levels such as clear, purge, and destroy; our MVP should not imply any of them.

Product language rules:

```text
Move to Trash:
  reversible when platform and Trash state allow it
  not guaranteed restore
  not secure erase

Permanent delete:
  future explicit mode only
  not secure erase
  not recoverability-proof

Secure erase / sanitize:
  non-goal for MVP
  requires separate adapter, platform support, evidence, warnings, and policy
```

UI banned claims:

- "securely deleted";
- "unrecoverable";
- "exactly freed";
- "safe to delete";
- "restorable" without native Trash evidence;
- "system cache" without classifier evidence.

Allowed safer wording:

- "Move selected items to Trash";
- "Estimated reclaim";
- "Observed free-space change";
- "Low confidence because snapshots or shared extents may exist";
- "Blocked because identity changed";
- "Review required because this folder is tool-managed".

### Cloud And Provider-Managed Filesystem Containment

Cloud files are not just files with slow IO. Providers can hydrate on open, expose placeholders, synchronize deletes to cloud, keep server-side recycle bins, and materialize items during metadata access.

Provider states to model:

```text
local_materialized
online_only
placeholder
recall_on_open
recall_on_data_access
sync_pending
conflict
provider_error
unknown_provider_state
```

Rules:

- baseline scan must not intentionally hydrate provider files;
- selected details may request richer provider metadata but must be cancellable;
- cleanup candidates inside sync roots get provider risk labels;
- delete plan must explain whether action affects local placeholder, local content, cloud content, or unknown scope;
- provider-managed roots default to conservative recommendations;
- remote/headless mode must not assume cloud provider UI restore is available.

Kill criteria:

- scanning iCloud/OneDrive/Dropbox hydrates large remote data by default;
- deleting online-only placeholder is shown as freeing local disk space;
- sync-root delete is shown as local-only without evidence;
- provider error is collapsed into generic permission denied;
- UI recommends deleting provider database/cache without official adapter.

### Fault Containment Domains

The app should degrade by domain. One failing subsystem should not turn into a whole-app crash or destructive uncertainty.

Containment domains:

```text
ui_rendering
protocol_client
daemon_control_plane
scanner_adapter
metadata_enrichment
read_model_index
journal
trash_adapter
recommendation_rules
telemetry_export
support_bundle_export
updater
```

Containment rules:

- scanner failure does not corrupt journal;
- metadata enrichment failure does not invalidate scan snapshot;
- WebSocket failure does not kill HTTP query surface;
- recommendation rule failure removes recommendations, not tree browsing;
- telemetry failure is silent and local, never blocks user flow;
- support bundle export failure cannot leak partial unredacted archive;
- journal failure disables cleanup but scan remains available;
- Trash adapter failure returns per-item outcome and leaves journal recoverable.

Open architecture question:

1. **In-process pdu adapter with panic boundaries**
   🎯 7 🛡️ 6 🧠 5, roughly 500-1500 LOC.
   Fastest and simplest, but a severe adapter panic can still threaten daemon stability.

2. **Scanner worker thread pool plus strict adapter containment**
   🎯 8 🛡️ 7 🧠 6, roughly 900-2400 LOC.
   Good default. Keeps control plane responsive and isolates resource budgets without IPC complexity.

3. **Crash-isolated scanner child process**
   🎯 5 🛡️ 9 🧠 9, roughly 2500-7000 LOC.
   Strong fallback if scanner/backend crashes or memory spikes cannot be contained in-process. Too heavy for MVP unless spike proves real instability.

### Observability Without Turning Into Surveillance

Telemetry and diagnostics are useful because this product will hit platform-specific failures. They are also dangerous because paths and filenames are private.

Telemetry field policy:

```text
allowed by default:
  opaque IDs
  OS family/version bucket
  app version
  daemon version
  protocol version
  counts
  durations
  byte quantities
  error codes
  capability states
  confidence buckets

blocked by default:
  full path
  filename
  username
  search text
  delete target
  raw receipt path
  daemon token
  full scan tree
  command payload body
```

Metric rules:

- labels are low-cardinality only;
- path-like data is never a metric label;
- error details use typed codes, not raw OS strings by default;
- raw diagnostic export requires explicit user action and preview;
- support bundles use SQLite backup API or checkpoint-safe copy, never raw WAL-unsafe copy;
- redaction failures fail closed.

### User Trust Failure Modes

Some failures are technically recoverable but product-trust breaking.

Trust-breaking cases:

- user sees a giant reclaim number and free space barely changes;
- app says scan complete while many protected folders were skipped;
- app says moved to Trash but item cannot be found or restored;
- app recommends deleting a developer cache that contains important volumes, simulators, archives, or package stores;
- app shows old scan result as current after reconnect;
- app hides warning state in compact layout;
- app reports "no errors" while capability probe failed.

Rules:

- partial truth must be visible;
- warnings should be queryable, not only toast messages;
- every cleanup recommendation needs evidence and risk tier;
- "review required" is a valid product state;
- old snapshots must be visually distinct from live/current scans;
- compact UI must preserve destructive warnings and confirmation data.

### Non-Goals Until Proven

These features are tempting but should stay out of MVP unless explicitly revisited.

```text
secure erase / media sanitization
remote destructive cleanup
automatic cleanup without review
cloud provider cleanup without provider adapter
snapshot deletion
cross-user machine cleanup
system package manager cleanup
Docker volume deletion without Docker adapter
Homebrew Cellar deletion without Homebrew adapter
Xcode archive/simulator deletion without dedicated classifier
browser-hosted UI pairing to localhost daemon
incremental watcher correctness as source of truth
```

### Sixth-Pass Highest-Risk Unknowns

1. **Evidence model as first-class API**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3500 LOC.
   Most important architecture hardening. It prevents false certainty and makes UI, support, tests, and adapters speak the same language.

2. **Per-target capability matrix**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2600 LOC.
   Needed because OS-level assumptions are too coarse. The same machine can have many filesystem semantics at once.

3. **Cloud/provider containment**
   🎯 6 🛡️ 9 🧠 9, roughly 1500-5000 LOC over time.
   Hard because provider behavior changes and can be expensive to test. MVP should detect and label, not aggressively optimize.

## Seventh-Pass Native Execution And Type-State Layer

This layer is about making the wrong implementation hard or impossible. The goal is to prevent raw paths, random async workers, and protocol DTOs from reaching native destructive APIs.

### Native Adapter Execution Contexts

Native adapters have execution-context rules that do not map cleanly to generic async Rust.

Windows:

- COM must be initialized on the current thread before COM library calls.
- `CoInitialize` initializes the current thread as STA and the concurrency model cannot be changed after it is set.
- COM interface pointers crossing apartments require marshaling.
- Shell file operations and progress sinks should not be invoked from arbitrary Tokio worker threads.

macOS:

- Foundation/FileManager Trash behavior should be behind a small platform adapter boundary.
- Security-scoped access, app/helper identity, and resulting Trash URL handling must stay in the macOS adapter.
- UI prompts and permission remediation should not be triggered from a headless daemon path by accident.

Linux:

- FreeDesktop Trash requires `.trashinfo` semantics and topdir-specific behavior.
- Headless/server/container environments may have no supported Trash.
- Network/FUSE mounts can have locking and rename behavior that differs from local disks.

Top 3 native execution models:

1. Dedicated platform executor per native subsystem - 🎯 8 🛡️ 9 🧠 7, roughly 900-2600 LOC.
   Best fit. `WindowsShellStaExecutor`, `MacosFoundationExecutor`, and `LinuxTrashExecutor` isolate native threading, permission, and error mapping.

2. Call native adapters from generic blocking pool - 🎯 4 🛡️ 5 🧠 4, roughly 300-900 LOC.
   Too risky. It hides COM apartment/threading rules and mixes long-running native calls with unrelated blocking work.

3. Native sidecar process per platform adapter - 🎯 5 🛡️ 9 🧠 9, roughly 2500-7000 LOC.
   Strong isolation, but too much MVP complexity unless native adapters prove unstable.

Rules:

- Windows Shell adapter runs on a known COM-initialized execution context.
- COM pointers are not moved across threads unless explicitly marshaled.
- Native adapter workers return typed outcomes, never raw HRESULT/NSError/string-only errors.
- Native adapter cancellation is modeled as best-effort, not guaranteed rollback.
- Native adapter executor health is part of daemon health.

Kill criteria:

- `IFileOperation` is called from arbitrary async/blocking pool threads;
- COM initialization errors are collapsed into generic cleanup failure;
- native progress callback writes directly to WebSocket;
- macOS resulting Trash URL is discarded;
- Linux Trash adapter assumes home Trash for every target.

### Type-State Barriers

Types should encode authority. The application should not be able to pass a display path into a destructive adapter.

Recommended authority ladder:

```text
DisplayPath
  UI-only string

RawPathEvidence
  scan-time or probe-time observation

NodeIdentityEvidence
  platform identity facts with confidence and scope

DeleteCandidate
  selected node plus current snapshot and risk evidence

ValidatedDeleteTarget
  live revalidation passed, target is ready for native adapter

NativeTrashRequest
  platform-specific request built by cleanup application service

TrashReceipt
  native adapter result with per-item outcome
```

Rules:

- protocol DTOs can create `DeleteCandidateRequest`, not `ValidatedDeleteTarget`;
- only cleanup application service can create `ValidatedDeleteTarget`;
- only platform adapter can create `TrashReceipt`;
- display names cannot be converted into path authority;
- `ValidatedDeleteTarget` has short lifetime and cannot be cached in Flutter;
- stale `ValidatedDeleteTarget` expires before execution if operation waits too long.

Kill criteria:

- `TrashAdapter` accepts `PathBuf` or raw string directly from application command;
- Flutter can construct delete authority type;
- test can bypass revalidation without an explicit unsafe fixture helper;
- receipt can be fabricated by non-adapter code;
- display path and raw path share the same type.

### Single-Writer Destructive Coordinator

Cleanup needs one authority. Multiple clients can view, but one coordinator owns destructive state.

Coordinator responsibilities:

```text
DeleteCoordinator
  owns DeletePlan lifecycle
  owns idempotency table
  owns target locks
  owns operation journal writes
  owns native adapter dispatch
  owns receipt finalization
```

Lock scopes:

```text
operation_id
delete_plan_id
snapshot_id
target_identity
parent_identity
volume_id
trash_adapter_instance
```

Rules:

- two clients can query same plan;
- only one execution can claim a plan;
- duplicate idempotency key with same payload returns existing operation state;
- duplicate idempotency key with different payload is rejected;
- overlapping destructive operations on same target/root are serialized or blocked;
- update/shutdown asks coordinator to quiesce before replacing binaries.

Kill criteria:

- two WebSocket clients can execute same plan concurrently;
- overlapping delete operations race on parent directory;
- idempotency table is in memory only;
- coordinator dispatches native action before journal intent is persisted;
- update can kill coordinator while native adapter action is in flight without persisted recovery state.

### Schema And Semantic Compatibility Gates

Schema compatibility is not enough. We need semantic compatibility.

Compatibility layers:

```text
protocol_schema:
  HTTP and WebSocket DTO shapes

journal_schema:
  durable destructive operation state

snapshot_semantics:
  pdu version, size policy, traversal policy, hardlink policy

recommendation_semantics:
  cleanup classification and risk-tier rules

ui_semantics:
  confirmation wording and visible warning requirements
```

Rules:

- destructive command requires compatible protocol schema and compatible cleanup semantics;
- old UI can browse read-only if protocol permits, but cannot execute cleanup when semantics are unknown;
- stale scan snapshots are read-only when semantic fingerprint differs;
- journal migrations are allowed to disable cleanup until complete;
- support tools must read old receipts without needing old binaries.

Kill criteria:

- protocol major compatibility passes while cleanup semantic version is incompatible;
- old recommendation rule makes a target look safer after update;
- journal migration changes interpretation of previous native result;
- UI wording changes destructive meaning without design-system version bump;
- support bundle cannot identify semantic versions used to make a decision.

### Filesystem And Database Storage Boundaries

The app will touch user files and its own database. These must be treated differently.

SQLite rules:

- use SQLite backup API or checkpoint-safe export for support bundles;
- never read raw database bytes from another thread/process while SQLite connections are active;
- never delete `-wal`, `-shm`, or hot journal files manually;
- operation journal database should live on local app data storage, not network shares;
- if database integrity check fails, cleanup is disabled and recovery mode starts.

Filesystem rules:

- app-owned temp files have exact prefix, owner, and location checks;
- app never recommends deleting its own active journal, lock, token, or receipt store;
- scan of app data should classify active Clean Disk state as protected;
- low disk space on app data volume disables cleanup execution if receipts cannot be persisted.

Kill criteria:

- support bundle copies SQLite `.db` file raw while WAL may contain committed state;
- cleanup can run when journal storage is unavailable;
- app can delete its active receipt database as cleanup candidate;
- app data path is stored only as display string;
- database on network filesystem is treated as equally safe for destructive journal.

### Formal Impossible States

These states must be impossible by code structure or caught in tests before release.

```text
DeletePlan.executing without Journal.intent_persisted
TrashReceipt.completed without per-item outcomes
ProtocolClient.live with incompatible protocol major
Cursor.valid with mismatched snapshot_id
ValidatedDeleteTarget without fresh identity evidence
Cleanup enabled while journal migration failed
Remote destructive action enabled without authz policy
UI queue item without node_id and snapshot_id
MoveToTrash success without native adapter evidence
Scan complete while skipped/protected paths hidden
```

Implementation rule:

- every impossible state gets either type-level prevention, state-machine test, or startup recovery assertion;
- destructive impossible states must prefer type-level prevention;
- scan/UI impossible states can use tests and runtime assertions;
- startup recovery asserts journal consistency before enabling cleanup.

### Seventh-Pass Hardest Spikes

1. **Native adapter executor spike**
   🎯 7 🛡️ 10 🧠 8, roughly 1200-3200 LOC.
   Prove Windows COM STA executor, macOS FileManager wrapper, Linux FreeDesktop adapter contract, typed errors, and no raw native callbacks into transport.

2. **Type-state cleanup boundary spike**
   🎯 8 🛡️ 10 🧠 7, roughly 900-2400 LOC.
   Make it impossible for raw path strings or protocol DTOs to reach `TrashAdapter`.

3. **Single-writer coordinator and idempotency spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3000 LOC.
   Prove duplicate commands, multi-client execution, crash before/after native dispatch, and update quiesce.

## Eighth-Pass Lease, Epoch, And Native Side-Effect Semantics

This layer fixes the hardest semantic truth: native filesystem operations are not database transactions. Clean Disk can make command acceptance idempotent, target validation fresh, and receipts durable. It cannot make every OS Trash call exactly-once in the distributed-systems sense.

### Exactly-Once Is Not The Contract

For destructive operations, the correct target is:

```text
at-most-one native dispatch per accepted operation
  + durable record before dispatch
  + durable per-item observation after native result
  + recovery state when observation is incomplete
```

Not:

```text
exactly-once native Trash side effect
```

Why:

- UI can retry after timeout;
- browser can reconnect after command result is lost;
- daemon can crash after native side effect and before response;
- native adapter can partially complete;
- OS may move item but return incomplete restore evidence;
- app can update or shutdown while work is in progress;
- file can be externally changed during operation.

Rules:

- accepting a destructive command creates durable operation identity before native side effect;
- idempotency key maps to operation identity, not directly to final success;
- retry returns existing operation state;
- if native result is unknown, state is `reconciliation_required`;
- recovery never repeats native side effect automatically;
- user-visible success only happens after receipt evidence is persisted.

Top 3 command semantics:

1. Idempotent command acceptance plus recovery-aware operation state - 🎯 9 🛡️ 10 🧠 7, roughly 900-2400 LOC.
   Best fit. It avoids duplicate native dispatch while admitting unknown outcomes.

2. Try to make native Trash exactly-once by locking and retries - 🎯 3 🛡️ 5 🧠 8, roughly 1200-3000 LOC.
   Misleading. Locks help inside our daemon, but do not cover crashes, OS side effects, and external actors.

3. No idempotency, rely on disabled buttons - 🎯 1 🛡️ 2 🧠 2, roughly 100-300 LOC.
   Not acceptable. Multi-client, retry, reconnect, and crash cases break it.

Kill criteria:

- retry can call native Trash twice for the same accepted operation;
- command response is the only place operation identity exists;
- unknown native result is collapsed into success or failure;
- idempotency key is accepted without payload hash;
- operation state is lost before receipt retention ends.

### Lease And Epoch Ownership

Use leases and epochs for authority that expires or changes. This prevents stale clients, stale validators, and stale permissions from acting with old assumptions.

Suggested epochs:

```text
daemon_epoch:
  changes on daemon restart or token rotation

protocol_epoch:
  changes on incompatible protocol/UI bundle change

snapshot_epoch:
  changes on scan snapshot replacement/disposal

capability_epoch:
  changes on permission probe, app identity, package mode, target remount, or provider state

delete_plan_epoch:
  changes whenever plan content, warnings, risk, or evidence changes

journal_epoch:
  changes on schema migration or recovery mode

native_executor_epoch:
  changes when native adapter executor restarts or loses platform state
```

Rules:

- every mutating command carries the epochs it was built against;
- server rejects stale epochs with typed `stale_epoch`;
- DeletePlan confirmation is bound to `delete_plan_epoch`;
- capability evidence includes `capability_epoch`;
- WebSocket reconnect reports current daemon/protocol/snapshot epochs;
- UI treats epoch mismatch as resync, not silent refresh.

Kill criteria:

- old UI can execute a plan after daemon restart without epoch validation;
- capability probe result survives app identity change;
- native executor restarts but operation continues as if context did not change;
- snapshot cursor remains valid after snapshot epoch changes;
- DeletePlan warning changes without invalidating confirmation.

### Windows STA Message Pump Constraint

Windows COM STA is not just "run it on one thread". Microsoft documents that each STA must have a message loop, COM objects live in one apartment, and cross-apartment interface pointers must be marshaled.

Implications for `WindowsIFileOperationTrashAdapter`:

- create a dedicated Shell STA thread;
- initialize COM with apartment-threaded model on that thread;
- run a message loop or combined wait/message loop;
- create and use Shell COM objects on that thread;
- marshal any interface pointers crossing thread boundaries, or avoid crossing them;
- route adapter requests into that executor as typed commands;
- route progress sink results back as typed events, not direct transport writes;
- treat reentrancy as possible when messages are pumped.

Top 3 Windows adapter shapes:

1. Dedicated STA executor with internal command queue and message pump - 🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC.
   Best safety fit for Shell operations.

2. MTA/free-threaded attempt from generic worker pool - 🎯 3 🛡️ 5 🧠 5, roughly 400-1200 LOC.
   Risky unless IFileOperation behavior is proven under MTA and callbacks. Not a good default.

3. Small native helper process for Windows Shell operations - 🎯 5 🛡️ 9 🧠 9, roughly 2500-7000 LOC.
   Strong isolation, useful if in-process COM becomes unstable or hard to test.

Kill criteria:

- no message pump on STA executor;
- progress sink calls back into daemon state without queue boundary;
- COM interface pointer is stored and used from arbitrary Rust threads;
- `RPC_E_CHANGED_MODE` is treated as generic unknown error;
- Shell adapter reentrancy can call cleanup coordinator recursively.

### Identity Evidence Is A Lease, Not A Fact Forever

File IDs, inodes, generation identifiers, paths, and metadata fingerprints are evidence. They are not permanent truth.

Reasons:

- file IDs/inodes can be reused;
- macOS file resource identifiers are session-like evidence, not restart-stable identity;
- Windows file index fallback can be filesystem-specific and weaker than `FILE_ID_INFO`;
- FAT/exFAT/network/provider filesystems can have weaker identity;
- timestamps can be coarse or provider-generated;
- paths can be deleted and recreated;
- parent identity can change while child name is the same.

Rules:

- identity evidence has `observed_at`, `source`, `scope`, and `expires_at` or freshness policy;
- high-risk operations require fresh live evidence;
- directories require parent and target evidence where possible;
- weak identity prevents automatic cleanup recommendation;
- evidence from one mount/provider cannot be generalized to another;
- startup after daemon restart lowers confidence for ephemeral identity fields.

Kill criteria:

- scan-time identity alone authorizes cleanup after long delay;
- inode/file-id match without parent/metadata evidence authorizes high-risk directory cleanup;
- identity confidence survives remount without re-probe;
- network share identity is treated like local APFS/NTFS identity;
- user can confirm with expired identity evidence.

### Capability Leases

Permission and capability are not static. They can change when the app is moved, updated, re-signed, sandboxed, granted Full Disk Access, denied Full Disk Access, target is remounted, cloud provider changes state, or enterprise policy changes.

Capability lease fields:

```text
capability_id
capability_epoch
process_identity
package_mode
target_root
volume_id
filesystem_type
provider_state
permission_scope
probed_at
expires_at
invalidated_by
```

Rules:

- scan uses capability lease for scan claims;
- delete requires stronger, fresher capability lease;
- UI cannot convert scan capability into delete capability;
- capability lease is invalidated by process identity or target identity change;
- permission doctor reports stale capability separately from unsupported capability.

Kill criteria:

- capability is a global boolean like `canDelete`;
- capability survives app move/re-sign/update without identity check;
- scan of one volume enables cleanup on another volume;
- UI shows full scan capability after protected-path denial;
- delete executes after capability lease expiration without re-probe.

### Native Side-Effect Reconciliation

When crash or adapter failure interrupts observation, the app should reconcile by evidence, not replay the side effect.

Reconciliation steps:

```text
load journal operation
read last persisted item outcome
probe original target path
probe possible Trash result reference if available
probe parent/root evidence
classify:
  not_started
  moved_to_trash_observed
  original_still_present
  original_missing_trash_unknown
  partial_unknown
  adapter_state_unknown
  manual_review_required
```

Rules:

- reconciliation is read-only by default;
- reconciliation never repeats native Trash action automatically;
- if both original and Trash evidence are missing, state is unknown, not success;
- if original still exists after native action started, retry still requires user confirmation or safe idempotent adapter proof;
- support bundle can explain reconciliation evidence without raw paths by default.

Kill criteria:

- startup recovery repeats native Trash because operation was "not terminal";
- missing original path is treated as moved-to-trash without Trash evidence;
- receipt is finalized from absence of path only;
- user sees completed when reconciliation confidence is unknown;
- operation journal cannot represent per-item `manual_review_required`.

### Scan Snapshot Leases And Cursor Lifetimes

Read-model memory and UI correctness need explicit lifetime ownership.

Rules:

- each snapshot has a lease count or scoped handle registry;
- active cursors hold a short-lived query lease, not whole UI session authority;
- snapshot disposal waits only for bounded active leases;
- old snapshots become read-only and eventually expire;
- UI selection against expired snapshot must create a fresh plan or rescan;
- `NodeId` is meaningless without `snapshot_epoch`.

Kill criteria:

- `NodeId` alone can query current daemon state;
- cursor keeps snapshot memory forever;
- UI selection survives snapshot disposal silently;
- expanded rows from one snapshot apply to another without remapping;
- cleanup can be built from an expired snapshot without high-risk review.

### Eighth-Pass Hardest Spikes

1. **Lease/epoch protocol spike**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2200 LOC.
   Prove stale daemon, stale capability, stale snapshot, stale plan, and stale native executor are rejected cleanly.

2. **Windows STA adapter executor spike**
   🎯 7 🛡️ 10 🧠 8, roughly 1200-3200 LOC.
   Prove message pump, COM init/uninit, progress sink routing, typed HRESULT mapping, and no arbitrary-thread COM use.

3. **Native side-effect reconciliation spike**
   🎯 7 🛡️ 10 🧠 9, roughly 1400-3600 LOC.
   Prove crash after dispatch, crash after item result, missing receipt, partial batch, and unknown Trash reference handling.

## Ninth-Pass Blast Radius And Trust Recovery Layer

This layer assumes some bug or platform edge case will eventually bypass earlier gates. The design must limit damage, preserve recovery evidence, and keep user trust by refusing silent optimism.

### Blast-Radius Budgets For Cleanup

Cleanup should have explicit budgets before native execution. Budgets are not only UX warnings; they are runtime limits enforced by the daemon.

Budget dimensions:

```text
max_items_per_operation
max_bytes_logical_per_operation
max_estimated_reclaim_per_operation
max_top_level_targets_per_operation
max_directories_per_operation
max_unknown_confidence_items
max_high_risk_items
max_provider_managed_items
max_cross_volume_targets
max_operation_duration_before_pause
```

Rules:

- default budget is conservative;
- high-risk items consume a stricter budget;
- budget override requires separate confirmation and is recorded in receipt;
- remote/headless cleanup budget is lower than local UI budget until proven;
- first public cleanup releases should bias toward smaller batches;
- operation stops at budget boundary with `needs_review`, not a generic error.

Kill criteria:

- one click can queue arbitrary number of items without daemon-side budget;
- budget checks exist only in Flutter;
- high-risk provider-managed roots count the same as ordinary cache files;
- budget override is not persisted in receipt;
- operation continues after many unknown outcomes.

### Staged Cleanup Execution

Do not treat a large cleanup as one opaque call. Execute in stages with circuit breakers.

Recommended stages:

```text
1. plan build
2. live revalidation
3. preflight summary
4. confirmation
5. small canary batch for high-risk or large operations
6. checkpoint receipt
7. remaining batches
8. free-space observation
9. final receipt
```

Circuit breakers:

- stop if stale identity rate exceeds threshold;
- stop if native Trash unknown rate exceeds threshold;
- stop if provider-managed/hydration warning appears during execution;
- stop if journal write latency or disk-full risk appears;
- stop if observed free-space delta is wildly inconsistent and accounting claimed high confidence;
- stop if user/system sleep or update starts during sensitive phase.

Top 3 execution strategies:

1. **Batched execution with circuit breakers**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC.
   Best safety fit. Adds complexity, but it reduces worst-case damage.

2. **One native operation per confirmed plan**
   🎯 5 🛡️ 6 🧠 5, roughly 600-1600 LOC.
   Simpler but poor visibility and harder partial recovery.

3. **One native operation per item only**
   🎯 6 🛡️ 8 🧠 7, roughly 900-2400 LOC.
   Strong per-item receipts but can be slow and may behave differently from user-visible OS batch Trash behavior.

### Local Tamper And Same-User Attack Model

A local disk utility cannot fully defend against the same OS user with full filesystem access. But it must defend against accidental corruption, browser-origin attacks, stale daemons, and low-effort tampering of app state.

Threat categories:

```text
same_user_accidental:
  user edits files, moves app, deletes app data, restores old backup

same_user_malicious:
  user modifies local DB/config intentionally

other_local_process:
  browser page, extension, malware, another app in same user session

other_os_user:
  another account on same machine

remote_client:
  future headless/remote API caller
```

Rules:

- do not promise protection against a malicious same-user attacker;
- do protect against web origin and stale local clients;
- local DB tamper detection should disable cleanup, not crash;
- daemon token file permissions are checked at startup;
- app state ownership and permissions are part of health check;
- support bundle must identify possible local-state tamper without exposing secrets.

Kill criteria:

- modified journal DB can make cleanup look completed;
- token file world-readable still starts daemon normally;
- stale daemon from old install keeps destructive access;
- browser-origin attack can use local user authority;
- support mode trusts modified local DB as authoritative without integrity warning.

### Data Retention And Privacy Lifecycle

Scan snapshots, receipts, search history, telemetry, and support bundles are privacy-sensitive because filenames and paths reveal behavior.

Data classes and default retention:

```text
live_scan_snapshot:
  retained while session is active
  expires when user closes or configured history limit reached

scan_summary:
  retained for recent scans if user wants history
  no full tree by default

delete_receipt:
  retained long enough for user review and support
  redacted view by default

operation_journal:
  retained while recovery or receipt audit is needed
  compacted after final receipt and retention window

search_text:
  not persisted by default

support_bundle:
  generated by explicit user action
  redacted by default

telemetry:
  aggregate operational fields only
  no paths, filenames, search text, or target payloads
```

Rules:

- retention policy is visible in settings;
- user can clear scan history;
- clearing history does not delete recovery-critical receipts until safe;
- raw support bundle requires explicit mode and preview;
- telemetry opt-in/opt-out is separate from local diagnostics;
- deletion of Clean Disk's own state should not break recovery of an active destructive operation.

Kill criteria:

- search text is stored silently;
- full scan tree is retained by default after app close;
- clearing history removes active recovery data;
- telemetry includes path-like labels;
- support bundle silently exports raw paths.

### Safety-Critical UI Contracts

The design system should make dangerous UI misuse hard.

Safety-critical components:

```text
DestructiveActionButton
DeletePlanSummary
RiskTierBadge
EvidenceConfidenceBadge
ConfirmationPanel
PartialScanBanner
StaleSnapshotBanner
ReceiptViewer
SupportBundleExportDialog
```

Rules:

- destructive button requires capability, plan epoch, confirmation state, and visible summary;
- destructive button cannot be enabled inside a hidden/collapsed warning context;
- compact layout must show total items, high-risk count, confidence, Trash mode, and expiration before confirm;
- row actions must use node/snapshot identity, never visual index;
- design-system primitives should enforce disabled reasons and tooltips;
- if Headless/design_system cannot express this safely, upgrade the library rather than local workaround.

Kill criteria:

- destructive action can be triggered while warning panel is collapsed;
- compact layout hides plan changes;
- button enabled state is computed from local widget state only;
- confirmation copy does not include significant transaction data;
- design system allows destructive button without disabled reason or audit label.

### Incident Recovery And User Communication

When something goes wrong, we need a recovery path that does not depend on chat logs or developer memory.

Incident artifacts:

```text
operation_id
receipt_id
scan_snapshot_id
semantic_fingerprint
capability_epoch
delete_plan_hash
per_item_outcome_summary
unknown_outcome_count
native_adapter
app_version
daemon_version
redacted evidence summary
support_bundle_id
```

Rules:

- every destructive incident can be described without raw paths by default;
- user can export a redacted receipt;
- raw-path export requires explicit consent;
- app shows recovery state after restart before allowing new cleanup;
- app offers "review unresolved operations" when journal has unknown outcomes;
- release notes should mention cleanup safety changes and known limitations.

Kill criteria:

- app restarts after partial cleanup and hides unresolved operation;
- support cannot correlate user report to operation without full paths;
- unknown outcomes are reported as "failed" only;
- app allows new cleanup while previous destructive recovery is unresolved;
- receipt lacks app/daemon/semantic versions.

### Recommendation Confidence Decay

Cleanup recommendations should age and decay. A recommendation from yesterday's scan is not equal to live evidence.

Decay inputs:

```text
time_since_scan
target_mutability
provider_managed_state
tool_managed_class
permission_changes
snapshot_semantic_version
recent_errors
watcher_health
```

Rules:

- recommendation has `generated_at`, `valid_until`, `risk_tier`, and evidence list;
- recommendation becomes `review_required` after expiry;
- tool-managed recommendations require classifier version and evidence;
- recommendation cannot raise confidence after scan without new evidence;
- watcher updates can invalidate recommendation, but should not silently authorize cleanup.

Kill criteria:

- old recommendation can be executed without live revalidation;
- recommendation risk tier changes without rule version;
- failed watcher state leaves recommendation looking fresh;
- tool-managed cache classification lacks source/evidence;
- UI sorts by reclaim size without showing risk/confidence.

### Damage-Containment Quality Gates

Required before enabling cleanup for broad public testing:

```text
daemon-side cleanup budgets
staged batch execution
circuit breaker tests
local DB tamper detection
history/retention settings
redacted receipt export
support bundle redaction test
safety-critical UI component tests
partial cleanup restart UX
recommendation confidence expiry
```

Required before enabling remote/headless cleanup:

```text
all local gates
remote smaller budgets
authz-scoped target roots
audit trail without raw paths by default
rate limits
operator confirmation flow
emergency remote cleanup kill switch
```

### Ninth-Pass Highest-Risk Unknowns

1. **Staged cleanup with circuit breakers**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC.
   Biggest reduction in worst-case damage after DeletePlan correctness.

2. **Safety-critical design-system primitives**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2500 LOC across design system and UI.
   Important because destructive safety must not be rebuilt ad hoc in each screen.

3. **Retention and support evidence model**
   🎯 7 🛡️ 9 🧠 7, roughly 800-2200 LOC.
   Necessary for trust, support, and privacy. Hard part is retaining enough to recover without storing too much private data.

## Tenth-Pass File Namespace, Path Authority, And UI Serialization Layer

This layer treats path handling as a security and correctness boundary, not a formatting detail. The product has Rust native paths, JSON DTOs, Flutter strings, web UI display, receipts, search, user-entered custom paths, Trash metadata, and platform file pickers. If these are not separated, the UI can accidentally turn display text into destructive authority.

### Path Strings Are Display Data, Not Authority

A displayed path is useful for user understanding, but it is not enough to identify or authorize a filesystem operation.

Reasons:

- Rust `Path` and `OsStr` can represent platform-native paths that are not valid UTF-8 on Unix;
- Windows paths are wide strings with namespace prefixes, device names, verbatim `\\?\` behavior, and filesystem-specific normalization rules;
- APFS preserves case and normalization while lookup behavior depends on volume mode and Unicode rules;
- JSON strings and Dart strings are Unicode text, not lossless cross-platform native path containers;
- `to_string_lossy` can make two different native paths look identical;
- UI redaction, ellipsis, sorting, search, and copy-to-clipboard can all mutate what the user sees;
- web UI cannot be trusted to reconstruct native paths from display text.

Required model:

```text
NativePathEvidence
  path_ref
  parent_ref
  native_encoding
  display_path
  display_lossy
  display_redaction_class
  native_name_hash
  parent_identity
  target_identity
  observed_at
  snapshot_epoch
  capability_epoch
```

Rules:

- Flutter receives `display_path` for display and `path_ref` or `node_id + snapshot_epoch` for queries;
- destructive commands use DeletePlan target ids, not raw display paths;
- custom path input is converted to native evidence only by the daemon adapter;
- lossy display is allowed only if marked;
- receipts store enough native evidence to reconcile, but support exports redact by default;
- path hashes for support should be keyed/HMAC-like per export context, not plain global hashes of common names.

Top 3 protocol shapes:

1. **Daemon-owned opaque target references plus display DTOs** - 🎯 9 🛡️ 10 🧠 7, roughly 800-2200 LOC.
   Best fit. Flutter cannot accidentally convert a pretty string into native authority.

2. **UTF-8 path strings everywhere** - 🎯 3 🛡️ 4 🧠 3, roughly 200-600 LOC.
   Tempting, but breaks non-UTF-8 Unix names, lossy display, Windows namespaces, redaction, and stale identity.

3. **Base64 native path bytes in every DTO** - 🎯 5 🛡️ 7 🧠 6, roughly 500-1400 LOC.
   More lossless, but leaks sensitive raw path data widely and pushes too much platform logic into clients.

Kill criteria:

- `PathBuf` is serialized as ordinary string for authority;
- `to_string_lossy` output can be sent back to delete;
- support bundle uses plain unsalted path hashes;
- UI row visual index or text path identifies a cleanup target;
- path display redaction changes the value used by daemon operations.

### Target Acquisition Is A Platform Capability

Choosing a scan target is not the same on desktop Flutter, daemon-served web UI, hosted web UI, and future remote/headless mode.

Target acquisition modes:

```text
system_target:
  daemon exposes known safe roots such as Home, Downloads, Library, Applications

desktop_picker_target:
  desktop UI asks OS picker, daemon validates and creates native evidence

manual_path_target:
  user types or pastes a path, daemon resolves under strict capability policy

remembered_target:
  previously granted bookmark/capability is refreshed and checked for staleness

remote_target:
  remote server exposes scoped roots, not arbitrary client-local paths
```

Rules:

- web UI should not pretend the browser can grant full local disk access;
- daemon-served web can show daemon-known roots and allow explicit typed paths only with validation;
- desktop Flutter can use native pickers, but the daemon still validates identity and capability;
- macOS sandbox/security-scoped bookmark state is a capability lease, not a path string;
- remote/headless targets are scoped by server-side policy;
- typed paths should start in scan-only mode until permission and traversal policy are proven.

Top 3 target acquisition strategies:

1. **Desktop picker plus daemon validation, web roots/manual path only** - 🎯 8 🛡️ 9 🧠 5, roughly 300-900 LOC.
   Best first implementation. Honest about browser limits and keeps custom target authority in the daemon.

2. **Daemon-owned native picker service for web UI** - 🎯 5 🛡️ 7 🧠 8, roughly 1200-3000 LOC.
   Possible later, but platform dialogs from a background daemon are fragile and packaging-sensitive.

3. **Browser File System Access API as full solution** - 🎯 2 🛡️ 3 🧠 6, roughly 800-2200 LOC.
   Wrong default for this product. It does not provide a general full-disk scanner authority model.

Kill criteria:

- hosted web UI is documented as able to scan arbitrary local disk without a daemon grant;
- manual path becomes delete-capable without live capability and identity evidence;
- desktop picker result bypasses daemon validation;
- stored bookmark/capability is reused after stale bookmark or process identity change;
- remote mode accepts client-local paths as if they were server paths.

### Namespace Resolution Policy Per Operation

The app needs operation-specific resolution policies. A scanner can record symlinks and mount crossings. A cleanup executor must be stricter and evidence-based.

Suggested policy families:

```text
scan_resolution_policy:
  follows configured symlink and mount rules
  records link/reparse/mount states
  never treats link traversal as silent ordinary directory traversal

query_resolution_policy:
  reads from snapshot and indexes
  does not touch live filesystem unless details refresh is requested

delete_preflight_resolution_policy:
  opens or probes target with parent-bound identity checks
  rejects stale evidence
  rejects unexpected symlink, reparse, mount, provider, or type change

trash_execution_resolution_policy:
  uses platform Trash API where possible
  executes only after journal intent and preflight pass
  persists per-item outcome and native adapter evidence
```

Platform guidance:

- Linux should use `openat2` with restrictive flags where available for high-risk path resolution, then fall back with explicit lower confidence;
- `RESOLVE_NO_SYMLINKS` and `RESOLVE_NO_XDEV` must be policy choices, because symlinks and bind mounts are legitimate in user systems;
- Windows should prefer handle-based identity and Shell item operations over string-only canonicalization;
- Windows long path and `\\?\` behavior must be adapter concerns, not UI string rules;
- macOS should prefer Foundation URL/FileManager paths for user-facing file operations and keep `fileSystemRepresentation` conversion inside the platform adapter;
- all platforms should treat namespace escape or ambiguous resolution as a typed blocker.

Kill criteria:

- delete preflight follows a symlink that scan recorded as a symlink target change;
- mount boundary policy is checked only during scan but not during delete;
- Windows verbatim paths are normalized by generic string code;
- Linux fallback path resolution has the same confidence as `openat2`;
- path canonicalization is used as identity.

### Case, Unicode, Sorting, And Search Are Not Identity

The UI needs friendly sorting and search. The daemon needs stable identity and stable pagination. These are different contracts.

Rules:

- node identity is not lowercased path text;
- sibling lookup key uses parent identity plus native name/evidence, not display name alone;
- sorting can use display collation, but cursor stability must use deterministic tie-breakers;
- search should match display text and expose lossy/normalized caveats when relevant;
- duplicate-looking names must get disambiguators in UI if native evidence differs;
- path comparison rules are volume-specific and capability-specific.

Kill criteria:

- case-insensitive search result can be executed as if it is exact identity;
- two visually identical Unicode names collapse into one UI row;
- pagination cursor uses display name only;
- APFS, HFS+, NTFS, SMB, and Linux ext filesystems share one global path comparison rule;
- sort/search normalization changes receipt target evidence.

### Trash Names Are Not Restore Identity

Trash locations are implementation details. The visible filename inside Trash is not always original identity.

Relevant facts:

- FreeDesktop Trash requires separate `files` and `info` entries, and the file name in `files` must not be used to recover the original filename;
- FreeDesktop implementations must create the info entry first and handle name collisions atomically;
- Windows `IFileOperation` uses flags such as `FOFX_RECYCLEONDELETE`, while shell undo/recycle behavior can differ from direct filesystem delete;
- macOS `FileManager.trashItem` returns a resulting URL, but restore semantics are still platform behavior, not our own guarantee.

Rules:

- receipt stores original target evidence and native Trash adapter evidence separately;
- UI says "Move to Trash" only when the adapter confirms Trash/recycle semantics for that item;
- remote/network/provider targets can downgrade to "cannot safely Trash" or "requires platform-specific delete mode";
- restore hints are hints unless the platform gives durable restore capability;
- Trash display name is never used as original path.

Kill criteria:

- receipt reconstructs original path from Trash filename;
- failure to create FreeDesktop `.trashinfo` still moves payload;
- Windows direct delete is shown as Recycle Bin;
- macOS result URL absence is treated as full failure or full success without adapter-specific classification;
- network share permanent delete is hidden behind "Move to Trash" copy.

### Path Privacy And Redaction Are Protocol Features

Paths are private. They can reveal customer names, projects, passwords, health data, source repositories, employers, adult content, legal matters, and internal infrastructure.

Rules:

- every protocol field that can contain path-like text has a privacy class;
- telemetry never includes path text, search text, raw target roots, or high-cardinality path hashes;
- support bundle redaction is deterministic within a bundle so support can correlate rows;
- support bundle redaction is not globally linkable across users or exports;
- copy-path UI is explicit user action, not automatic log content;
- screenshots in support mode should offer path redaction.

Kill criteria:

- path hashes are stable across users and releases;
- log line includes raw path by default;
- WebSocket events include full path for every scanned file;
- support export cannot be previewed before sharing;
- redacted UI state can still leak full path through tooltip, accessibility label, or error detail.

### Tenth-Pass Hardest Spikes

1. **Lossless path DTO and opaque target reference spike**
   🎯 8 🛡️ 10 🧠 7, roughly 900-2400 LOC.
   Prove non-UTF-8 Unix names, Windows long/verbatim paths, lossy display markers, redacted support export, and delete commands without raw path authority.

2. **Cross-platform namespace fixture spike**
   🎯 8 🛡️ 9 🧠 8, roughly 1200-3200 LOC.
   Build fixtures for symlink swap, mount boundary, case collisions, Unicode normalization variants, long paths, reserved Windows names, ADS-like caveats, and Trash collision cases.

3. **Target acquisition authority spike**
   🎯 7 🛡️ 8 🧠 7, roughly 700-1800 LOC.
   Prove desktop picker, daemon-known roots, manual path validation, stale bookmark/capability, and web UI limitations under the same application port.

## Eleventh-Pass Assurance Case And Release Governance Layer

This layer turns critical-zone research into a release proof model. The project should not rely on "we discussed this risk" when a local daemon can scan private files, expose paths, recommend deletion, or move user data to Trash.

The useful shared pattern from NASA software assurance, NIST systems security engineering, STPA, FMEA, OWASP ASVS, and secure-by-design guidance is:

```text
claim
  -> hazard or failure mode
  -> safety/security constraint
  -> architecture decision
  -> implementation invariant
  -> objective evidence
  -> release gate
```

If a feature can delete, hide, expose, or misrepresent user data, it needs this chain before public release.

### Assurance Case Structure

Every high-risk capability should have a lightweight assurance case. This is not a formal certification package. It is a practical way to make release arguments falsifiable.

Example:

```text
Claim:
  Clean Disk can scan a target without hiding partial-truth states from the user.

Hazards:
  skipped protected paths are invisible;
  scan completion is shown while permission failures exist;
  UI sorts recommendations by size without showing confidence.

Constraints:
  every scan snapshot has completeness status;
  skipped bytes and skipped paths are queryable;
  partial scan state is visible in wide and compact layouts.

Evidence:
  permission-denied fixture;
  protected macOS Library fixture;
  protocol snapshot test;
  compact-layout golden test;
  accessibility assertion for partial-scan warning.

Gate:
  scanner beta cannot ship if partial scans can be represented as complete.
```

Required assurance-case categories:

| Category | Required claim | Minimum evidence |
| --- | --- | --- |
| scan truthfulness | UI cannot hide partial scans, skipped paths, or stale snapshots | fixture tests, protocol tests, compact UI tests |
| cleanup safety | DeletePlan cannot target a stale or wrong identity | identity fixtures, platform adapter tests, journal replay tests |
| protocol recoverability | reconnect cannot create impossible UI state | sequence/epoch tests, dropped-event tests, stale cursor tests |
| privacy containment | logs, metrics, and support bundles do not leak raw paths by default | redaction tests, snapshot tests, telemetry schema tests |
| package/runtime identity | the process with permissions is the process we expect | installer tests, permission probe, signed binary checks |
| rollback/recovery | a failed cleanup or bad update can be contained | crash injection, receipt replay, kill-switch tests |
| recommendation safety | cleanup advice is evidence-backed and expires | rule fixtures, rule version tests, recommendation decay tests |
| remote/headless safety | remote mode cannot expand authority by accident | authz tests, scope tests, audit tests, read-only default tests |

Kill criteria:

- a P0/P1 claim has no objective evidence;
- a destructive feature depends on manual QA only;
- release gate says "reviewed" without a reproducible test or fixture;
- UI safety claim is tested only in wide desktop layout;
- daemon security claim has no adversarial test case.

### Hazard Register

The hazard register should stay compact and painful. If it becomes a generic wiki dump, it will stop changing engineering decisions.

| Hazard | Unsafe control action | Required constraint | Evidence gate |
| --- | --- | --- | --- |
| wrong target deleted | execute DeletePlan after filesystem identity changed | revalidate path, identity, metadata, epoch, and plan hash immediately before side effect | stale-identity fixture and journal replay test |
| false reclaim promise | show exact freed bytes before platform evidence supports it | distinguish logical size, allocated size, exclusive estimate, confidence, and observed delta | reclaim fixture matrix and UI copy test |
| browser origin controls daemon | accept localhost request from untrusted origin | local token, origin allowlist, loopback bind, destructive transaction auth | browser-origin attack test |
| partial scan shown as complete | emit completed state while protected paths were skipped | completeness state and skipped summary are mandatory in snapshot | protected-path fixture and UI golden |
| old UI controls newer daemon | accept incompatible protocol messages silently | protocol version negotiation and capability gates | compatibility matrix test |
| support bundle leaks paths | export raw paths by default | redacted export by default, raw export requires explicit consent | support-bundle redaction test |
| cloud placeholder hydrated by scan | metadata enrichment opens or reads placeholder data | no recall-on-open operations in normal scan | cloud placeholder fixture or mocked adapter test |
| recommendation deletes valuable tool state | classify unknown tool-managed folder as ordinary cache | unknown classes are review-only or blocked | rule evidence and denylist fixture |
| update interrupts cleanup | replace daemon while destructive operation is active | update waits, pauses, or enters recovery mode | update-during-cleanup integration test |
| telemetry leaks private high-cardinality data | emit path, search term, node name, or user identifier as metric label | telemetry schema denies path-like labels and raw user strings | metric schema policy test |
| compact UI hides warning | enable destructive button while risk summary is collapsed | destructive confirmation needs visible risk summary | compact golden and widget state test |
| remote cleanup escapes target scope | follow symlink, reparse point, or mount out of authorized root | scope-aware resolution with no-cross-boundary policy | scope escape fixture |

Hazards are not tasks. A hazard stays open until there is a constraint, an owner, an evidence artifact, and a release gate.

### Traceability Matrix

For every P0/P1 hazard, keep a machine-readable traceability row.

Suggested shape:

```text
hazard_id
safety_constraint_id
architecture_decision_id
domain_invariant_id
protocol_contract_id
platform_adapter_id
test_fixture_id
property_test_id
fault_injection_id
release_gate_id
doc_source
owner
status
last_verified_at
```

Rules:

- every P0/P1 hazard maps to at least one automated test and one release gate;
- every destructive capability maps to a state machine, evidence object, receipt path, and recovery path;
- every external source of truth has a freshness date and source URL;
- every protocol event that can change user-visible safety state has a contract test;
- every recommendation rule maps to a rule version, evidence class, and rollback path;
- no release gate can be "manual judgment only";
- traceability rows should be reviewed when dependencies, OS versions, protocol versions, or platform adapters change.

This gives us one hard advantage: when implementation starts, we can ask "which safety claim did this code satisfy?" If the answer is unclear, the code probably belongs behind a feature flag or in a spike.

### Policy-As-Code Gates

Architecture and safety constraints should become tests where possible.

Candidate gates:

```text
forbid parallel_disk_usage imports outside fs_usage_pdu
forbid protocol DTOs in domain crates
forbid Flutter/Dart naming in reusable Rust crates
forbid raw PathBuf in TrashAdapter public commands except platform adapter internals
forbid cleanup enablement unless journal, identity, and Trash gates pass
forbid telemetry labels named path, file, folder, query, username, user_home
forbid support bundle export without redaction test coverage
forbid recommendation rules without evidence source and risk tier
forbid frontend destructive buttons without disabled reason and visible summary
require protocol schema compatibility tests for every DTO change
require migration tests for every persisted schema change
```

Possible tooling:

```text
cargo-deny for license and advisory policy
cargo-audit or RustSec advisory checks
custom cargo tests for import boundaries
custom rg-based CI checks for forbidden imports and labels
schema compatibility tests for OpenAPI/protocol DTOs
golden tests for compact destructive UI states
Dart import-boundary tests for feature packages
fixture lab for filesystem edge cases
fault-injection harness for daemon and cleanup state machines
```

Kill criteria:

- policy gates exist only in docs;
- import-boundary drift is discovered by code review instead of CI;
- dangerous feature flags can be enabled without prerequisite gates;
- policy failures are warnings instead of release blockers for destructive features.

### Evidence Freshness Levels

Not all evidence is equal. A scan result, DeletePlan, recommendation, or support artifact needs freshness semantics.

```text
live:
  current platform identity was revalidated and can authorize a side effect now

fresh:
  good for display or planning, but destructive side effects require revalidation

stale:
  view-only; can explain history but cannot feed cleanup without rebuilding plan

historical:
  support, analytics, and receipts only; never feeds current decisions

invalidated:
  explicitly superseded by filesystem change, daemon restart, permission change, protocol mismatch, or rule withdrawal
```

Rules:

- UI labels must not blur `fresh` and `live`;
- cleanup requires live evidence at the moment of side effect;
- recommendations can be fresh for review but not live for execution;
- evidence freshness is part of protocol DTOs, not just frontend state;
- stale evidence can still be valuable for support, but must not look actionable.

### Release Authorization Board Lite

Use a small release checklist per capability class. This is intentionally lighter than enterprise governance, but stricter than "tests pass".

| Capability | Required before enabling |
| --- | --- |
| scanner public beta | pdu adapter gate, read-model gate, skipped-path UI, performance fixture, crash-free cancellation |
| cleanup local beta | DeletePlan state machine, identity revalidation, Trash adapter receipt, journal replay, staged execution, compact warning UI |
| desktop installer | signing/notarization or platform equivalent, permission probe, app/daemon identity test, update compatibility test |
| web UI over local daemon | token/origin gate, loopback bind, PNA/CORS decision, version compatibility gate, hosted-web disabled or paired explicitly |
| remote/headless read-only | authn/authz, target-scope policy, audit log, rate limits, read-only operation set |
| remote/headless cleanup | all read-only gates plus smaller budgets, two-step confirmation, immutable audit receipt, emergency kill switch |
| recommendations | rule source, evidence model, false-positive review, rollback, expiry, risk-tier display |
| telemetry/support bundles | privacy classification, redaction tests, user consent boundary, high-cardinality denial |

Kill criteria:

- capability ships because an adjacent feature is ready;
- release checklist has no owner;
- beta flag can be toggled without gate status;
- public build includes hidden destructive endpoint not visible in product UI.

### Human-Factors Safety Tests

Destructive product safety is partly a UI problem. The user can technically confirm the right thing and still misunderstand what will happen.

Test questions:

- can the user identify the exact target root before scan and before cleanup?
- can the user distinguish Trash, quarantine, and permanent delete?
- can the user see skipped paths and partial scan state in compact layout?
- can the user see low-confidence reclaim estimates before confirmation?
- can the user tell whether bytes are logical, allocated, estimated reclaim, or observed delta?
- can the user understand why a destructive action is disabled?
- does the confirmation reset when DeletePlan changes?
- does the screen reader announce risk tier, disabled reason, and stale evidence?
- does keyboard-only navigation keep selected row and queued item aligned?
- does the UI keep warnings visible when the window is narrow?

These should become widget tests, golden tests, accessibility checks, and manual release scripts for the narrow cases automation cannot prove.

### Rollback And Feature Withdrawal

Rollback must be designed before recommendations and cleanup are trusted.

Rules:

- remote config or local kill switch can disable cleanup, recommendations, and remote/headless cleanup independently;
- bad recommendation rule can be withdrawn and old recommendations are invalidated by rule version;
- unsafe protocol version can force daemon/UI read-only mode;
- unsafe build can quarantine cleanup and show recovery mode;
- unsupported platform adapter can disable cleanup while scan remains available;
- telemetry/export schema issue can disable support bundle export without disabling scan;
- rollback state is visible to support without raw private paths.

Kill criteria:

- kill switch only hides UI but endpoint remains active;
- withdrawn recommendation remains executable from old cache;
- downgrade/rollback cannot read operation journal;
- forced read-only state looks like a crash or generic error to users;
- rollback disables too much because features are not isolated.

### Eleventh-Pass Highest-Risk Unknowns

1. **Assurance traceability as release gate**
   🎯 8 🛡️ 10 🧠 7, roughly 800-2200 LOC/tests/scripts.
   This is the highest leverage governance layer. It prevents "we tested something like this" from becoming a release argument for destructive features.

2. **Policy-as-code architecture constraints**
   🎯 8 🛡️ 9 🧠 6, roughly 700-1800 LOC.
   The risk is not conceptual complexity, it is drift. Boundary rules should fail in CI before pdu, protocol DTOs, raw paths, or unsafe labels leak into the wrong layers.

3. **Human-factors destructive UX testing**
   🎯 7 🛡️ 9 🧠 7, roughly 600-1600 LOC/tests.
   Users make cleanup decisions through UI, not architecture docs. Compact layout, disabled reasons, stale evidence, and low-confidence reclaim warnings must be treated as safety surfaces.

## Twelfth-Pass Long-Term Compatibility, Migration, And Replay Layer

This layer handles what breaks after the first good implementation ships. Clean Disk will have multiple long-lived contracts:

```text
Rust public crates
daemon HTTP API
WebSocket event envelope
Flutter DTOs
SQLite/Drift cache
operation journal
delete receipts
support bundles
recommendation rule data
telemetry schema
installer/update metadata
```

The critical risk is silent semantic drift. Version `1.5` may still parse data from version `1.1`, but interpret it differently enough to show the wrong reclaim estimate, replay a cleanup receipt incorrectly, or hide a protocol mismatch.

### Persistent Data Is A Product API

Anything persisted beyond the current process should be treated like a public contract.

Persistent artifacts:

```text
scan_snapshot
node_read_model_cache
target_capability_cache
operation_journal
delete_plan
delete_receipt
recommendation_cache
support_bundle
telemetry_export
daemon_config
trusted_origin_config
feature_flag_state
```

Rules:

- every persistent artifact has `schema_version`, `semantic_version`, `created_by_app_version`, and `created_by_daemon_version`;
- old artifacts are classified as `read_write`, `read_only`, `migrate_required`, `support_only`, or `invalid`;
- destructive operations never execute from migrated data unless the target identity is revalidated live;
- receipts are immutable once written, but can be supplemented by later reconciliation records;
- support bundles must include schema versions and redaction policy versions;
- delete journals must be replayable or explicitly marked `unknown_outcome`.

Kill criteria:

- app opens old journal and assumes current semantics;
- migration rewrites receipt facts instead of appending reconciliation;
- recommendation cache survives a rule semantic change without invalidation;
- persistent data lacks producer version and schema version;
- old data parse failure becomes generic "database corrupted".

### Version Matrix, Not Single Version

The UI and daemon can be mismatched during update, crash recovery, manual launch, remote/headless use, or stale browser tabs.

Minimum compatibility matrix:

| Producer | Consumer | Contract |
| --- | --- | --- |
| old UI | new daemon | commands rejected or downgraded by capability negotiation |
| new UI | old daemon | UI hides unsupported actions and explains daemon update need |
| old daemon | new DB | daemon refuses write and offers recovery/update path |
| new daemon | old DB | migration or read-only recovery path |
| old support bundle | new support tooling | schema-aware read with privacy policy preservation |
| old receipt | new cleanup code | read-only display, never re-execution |
| old recommendation | new rules | invalidated or re-ranked with explicit rule version |

Rules:

- protocol handshake returns daemon version, protocol version, feature flags, schema versions, and minimum compatible UI version;
- unsupported destructive capability fails closed;
- read-only compatibility is allowed where write compatibility is unsafe;
- stale browser tab must be forced through capability refresh before issuing commands;
- release notes should state compatibility breakpoints for DB, protocol, and receipts.

Top 3 compatibility policies:

1. **Strict capability negotiation plus read-only downgrade** - 🎯 9 🛡️ 10 🧠 6, roughly 900-2200 LOC.
   Best fit. It lets mixed versions display state safely without allowing stale clients to mutate data.

2. **Always force UI and daemon to exactly same version** - 🎯 6 🛡️ 8 🧠 5, roughly 500-1400 LOC.
   Simpler for desktop bundles, but weak for daemon-served web, stale tabs, remote/headless mode, and support tooling.

3. **Best-effort compatibility with warnings** - 🎯 3 🛡️ 4 🧠 3, roughly 200-700 LOC.
   Too risky. A warning does not protect destructive operations or old receipts.

### Event And DTO Evolution Rules

Even if MVP uses JSON, use the discipline from Protobuf, CloudEvents, OpenAPI, and schema registries.

Event envelope should include:

```text
event_id
event_type
event_type_version
schema_id
schema_version
session_id
sequence
epoch
producer_version
compatibility_min_consumer_version
payload
unknown_field_policy
```

Rules:

- event names and enum values are stable API, not refactorable labels;
- new optional fields are safer than changing existing meaning;
- removed fields become reserved in docs/schema, not silently reused;
- unknown event types are ignored only if they are non-safety-critical;
- unknown safety-critical event types force snapshot refresh or read-only state;
- DTO enums need `unknown`/`unsupported` variants on the Flutter side;
- large counters and IDs stay strings or typed wrappers where JSON precision matters;
- every schema change has compatibility tests with old fixtures.

Kill criteria:

- enum parse failure crashes event stream;
- event type is renamed without compatibility alias or major version;
- new safety-critical event is ignored by old UI;
- JSON number precision can alter bytes, IDs, cursors, or sequence values;
- schema docs exist but no old-payload fixture exists.

### Journal Upcasters And Receipt Immutability

Operation journals are not just caches. They are recovery evidence. Receipts are user trust artifacts.

Rules:

- operation journal events can be upcast into current internal recovery model;
- original journal payload is preserved or hash-linked before migration;
- upcasters are pure, tested, and version-specific;
- receipt facts are append-only;
- receipt display can improve, but original claims and adapter evidence remain visible;
- cleanup cannot resume from a journal if upcasting loses safety-critical fields;
- a migration that cannot prove outcome keeps item as `unknown_outcome`.

Suggested journal event envelope:

```text
journal_event_id
operation_id
event_type
event_schema_version
payload_hash
previous_event_hash
created_at
producer_version
payload
```

Kill criteria:

- migration deletes old raw journal after partial conversion;
- receipt is rewritten in place to match new UI wording;
- previous event hash is optional for destructive operation journal;
- upcaster guesses missing identity fields;
- unknown outcome is collapsed into success or failure.

### Database Migration Safety

SQLite/Drift migrations can silently corrupt product meaning even when SQL succeeds.

Rules:

- use explicit database `user_version` and app-level semantic schema version;
- use SQLite `application_id` to avoid opening the wrong database file as our app DB;
- migration tests run from every supported old version to current;
- destructive-operation tables migrate before feature code starts accepting new cleanup commands;
- WAL/checkpoint behavior is part of backup/support bundle design;
- multi-process access is either forbidden or explicitly handled with connection ownership and `data_version` awareness;
- database downgrade is not automatic unless a tested downgrade path exists.

Kill criteria:

- migration test covers only previous version;
- DB backup copies main file but not WAL state when WAL is active;
- daemon and UI open same DB independently without ownership rules;
- failed migration leaves app half-upgraded without recovery marker;
- downgrade opens newer DB and writes old schema.

### Update, Downgrade, And Anti-Rollback Semantics

Software updates are part of the safety model because an update can change daemon behavior, rules, adapters, schema, and cleanup code.

Threat classes to consider from secure update systems:

```text
rollback to vulnerable build
freeze on old metadata or rules
mix-and-match UI/daemon/rule bundle
partial update where daemon and UI disagree
arbitrary replacement by unsigned binary
stale recommendation rules after app update
```

Rules:

- app, daemon, protocol schema, DB schema, and recommendation rule bundle have independent versions but one compatibility manifest;
- destructive operations pause or enter recovery mode during updates;
- update cannot replace daemon while a cleanup transaction is active;
- rollback requires compatibility check against DB and journal;
- rule bundle updates are signed or hash-verified before use;
- stale update metadata must not be accepted forever;
- downgrade can force read-only mode instead of trying unsafe conversion.

Kill criteria:

- UI is updated but old daemon still accepts now-dangerous command shape;
- rule bundle changes without invalidating old recommendation cache;
- rollback loads newer DB in writable mode;
- update process loses operation journal lock;
- mixed UI/daemon versions can trigger cleanup without refreshed capability negotiation.

### Golden Artifact Corpus

Compatibility cannot be proven with only current-version tests. Keep old artifacts forever, with privacy-safe synthetic data.

Corpus contents:

```text
old protocol event streams
old HTTP request/response payloads
old scan snapshots
old delete plans
old receipts
old operation journals
old recommendation caches
old support bundles
old telemetry payloads
old DB files
```

Rules:

- every release adds at least one golden artifact per changed contract;
- golden artifacts use synthetic paths that cover Unicode, lossy display, long paths, reserved names, and privacy redaction;
- destructive artifacts are replayed only in a fake platform adapter;
- support tooling must read historical bundles without leaking raw paths;
- corpus is versioned with compatibility expectations.

Kill criteria:

- old payload tests are generated from current serializers only;
- no artifact covers unknown enum values;
- support bundle compatibility is tested by opening current bundle only;
- golden DB lacks failed/partial cleanup cases;
- artifact corpus contains real user paths.

### Twelfth-Pass Highest-Risk Unknowns

1. **Mixed-version daemon/UI/DB compatibility matrix**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC/tests.
   This protects real update flows. It is more important than polished API ergonomics because mixed versions are unavoidable with daemon-served web UI and stale browser tabs.

2. **Journal upcasting plus receipt immutability**
   🎯 7 🛡️ 10 🧠 8, roughly 1000-2800 LOC/tests.
   Necessary before cleanup beta. Recovery evidence must survive app upgrades without rewriting history.

3. **Golden artifact compatibility corpus**
   🎯 8 🛡️ 9 🧠 7, roughly 800-2200 LOC plus fixtures.
   The practical way to prevent silent contract drift across protocol, DB, telemetry, support bundles, and rule data.

## Thirteenth-Pass Volume Topology, Mount Leases, And Disappearing Storage Layer

This layer treats volumes and mounts as dynamic runtime objects. A disk usage tool is not operating over one stable tree. It is operating over a changing graph of local volumes, APFS containers, Windows volume GUID paths, drive letters, mounted folders, bind mounts, FUSE mounts, SMB/NFS shares, cloud provider roots, disk images, removable drives, and containers.

### Volume Identity Is Not A Path Prefix

The same path prefix can point to different storage over time, and the same storage can appear through multiple paths.

Examples:

- Windows drive letters can change when volumes are added or removed;
- Windows volumes can be reached by drive letter, volume GUID path, or mounted folder;
- Linux mount IDs in `/proc/pid/mountinfo` can be reused after unmount;
- Linux bind mounts and stacked mounts can hide previous trees at the same path;
- macOS volumes can appear, disappear, rename, remount, or be unplugged unexpectedly;
- APFS volumes can share one container, so volume-level free space is not always independent;
- network shares can reconnect, stale, or serve cached state;
- cloud and FUSE mounts can expose virtual trees whose backing store is elsewhere.

Required model:

```text
VolumeEvidence
  volume_ref
  display_name
  mount_points
  filesystem_kind
  provider_kind
  local_or_remote
  removable_or_fixed
  readonly_state
  volume_identity_strength
  platform_volume_id
  platform_mount_id
  container_or_pool_id
  mount_namespace_id
  observed_at
  expires_at
  capability_epoch
  volume_epoch
```

Rules:

- path prefix is not volume identity;
- volume label is display data only;
- drive letter is display and access path, not durable identity;
- mount ID is evidence scoped to current OS session and namespace;
- volume evidence expires on remount, rename, provider state change, daemon restart, sleep/wake, and mount event;
- cleanup plans bind to both target identity and volume evidence.

Top 3 identity strategies:

1. **VolumeEvidence aggregate with platform-specific adapter facts** - 🎯 9 🛡️ 9 🧠 7, roughly 900-2400 LOC.
   Best fit. It captures strong and weak identity without forcing a fake universal volume id.

2. **Use path root as volume identity** - 🎯 2 🛡️ 3 🧠 2, roughly 100-300 LOC.
   Not acceptable. It breaks mounted folders, bind mounts, drive-letter changes, and remount replacement.

3. **Require globally stable volume UUID everywhere** - 🎯 5 🛡️ 7 🧠 6, roughly 500-1400 LOC.
   Too optimistic. Some filesystems, network shares, virtual mounts, and sandbox contexts do not expose strong stable IDs.

Kill criteria:

- `C:\` or `/Volumes/Foo` is treated as durable volume identity;
- drive label collision is not handled;
- Linux mount ID survives unmount/remount without epoch invalidation;
- APFS sibling volumes are shown as fully independent disks when space is shared;
- cleanup plan survives target remount without revalidation.

### Mount Leases And Volume Epochs

Mount state is a lease, not a fact. Every scan snapshot and DeletePlan needs to know which mount lease it was built under.

Suggested lifecycle:

```text
unknown
  -> probing
  -> mounted_live
  -> degraded_network_or_provider
  -> unmount_pending
  -> disappeared
  -> remounted_needs_reprobe
  -> unsupported
```

Rules:

- daemon maintains `volume_epoch` per observed volume evidence;
- mount/unmount/rename/provider events invalidate related capabilities and snapshots;
- DeletePlan confirmation includes the `volume_epoch`;
- volume disappearance turns scans into partial results with typed reason;
- cleanup execution pauses or aborts if volume lease changes before native dispatch;
- stale volume events are coalesced and exposed as `volume_state_changed`, not generic IO failure.

Platform facts:

- macOS Disk Arbitration can notify about disk appearance, disappearance, mount, unmount, and description changes, but approval callbacks cannot guarantee that media will not vanish;
- Windows volume GUID paths are stronger than drive letters, but a volume can have more than one volume GUID path;
- Linux `/proc/pid/mountinfo` describes the current mount namespace, including parent mount IDs and stacked mounts;
- Linux `statx` can expose mount IDs and `STATX_ATTR_MOUNT_ROOT`, but support and uniqueness vary by kernel and flags.

Kill criteria:

- unmount event is logged but active scan keeps presenting complete state;
- sleep/wake does not trigger volume capability refresh;
- DeletePlan executes on remounted target with same path and different volume evidence;
- UI cannot distinguish permission denied from volume disappeared;
- volume event handling is only in Flutter and not enforced by daemon.

### Cross-Volume Trash Is Not Atomic

Moving to Trash can be cheap rename-like behavior on one volume, but copy/delete-like behavior or unsupported behavior across volumes, providers, or network shares.

Risk cases:

- external drive has no usable Trash location;
- home Trash fallback would copy a huge file across volumes;
- network share deletion is permanent or server-side;
- provider-managed folder deletes remote cloud object instead of local cache;
- Recycle Bin is disabled or unavailable for a drive;
- removable volume is unplugged during Trash operation;
- Trash metadata succeeds but payload move fails, or vice versa.

Rules:

- Trash capability is per target volume/provider, not per OS;
- DeletePlan shows Trash mode: local_trash, volume_trash, provider_trash, recycle_bin, unsupported, unknown;
- cross-volume Trash must show copy/delete risk and disk-space requirement if supported;
- large cross-volume Trash requires separate budget and circuit breaker;
- unsupported Trash blocks MVP cleanup rather than falling back to permanent delete;
- receipt records source volume evidence and Trash destination evidence separately.

Kill criteria:

- app says "Move to Trash" for network share without adapter proof;
- cross-volume copy to Trash can fill the destination volume without preflight;
- Recycle Bin disabled becomes permanent delete silently;
- FreeDesktop home-trash fallback for huge external file is automatic without warning;
- receipt stores only original path and not source/destination volume evidence.

### Free-Space Observation Is Volume-Scoped

Observed free-space delta must be tied to the correct volume or container. A cleanup can move bytes from one volume to another, affect a shared container, or free nothing immediately due to snapshots/open handles/provider state.

Rules:

- before/after free-space observation records volume/container evidence;
- APFS container-level observations are separate from volume-level observations;
- network share free-space changes are remote capacity signals, not local disk reclaim;
- provider cache cleanup can free local app data volume while visible sync root stays unchanged;
- moved-to-Trash is not the same as freed bytes;
- receipts report `observed_delta` per affected volume/container.

Kill criteria:

- one global "freed bytes" number is shown after multi-volume operation;
- moving a file to Trash on same volume is claimed as freed local space;
- cloud placeholder deletion is reported as local reclaim;
- APFS shared container delta is attributed to wrong volume;
- free-space observation fails and receipt still says exact reclaimed bytes.

### Scan Scope Must Be A Volume Graph

The UI scan target tree should not imply that the filesystem is one normal directory hierarchy.

Required concepts:

```text
scan_root
  target_path_ref
  volume_ref
  traversal_policy
  mount_boundary_policy
  provider_policy
  discovered_child_volumes
  skipped_mounts
  partial_volume_states
```

Rules:

- scan results include discovered mount boundaries and skipped child volumes;
- "Home" scan should not silently include external, network, backup, container, or mounted provider trees;
- user can explicitly opt into crossing mount boundaries later;
- scan summary shows included volumes and skipped volumes;
- top-level disk cards use volume/container facts, not only target path facts.

Kill criteria:

- pdu adapter crosses devices without UI knowing;
- scan target path and included volume set are not persisted in snapshot metadata;
- a mounted backup volume under Home is counted as ordinary Home data;
- skipped mount boundary is invisible in UI;
- query API cannot filter by volume/provider.

### Volume Event Storms And Debounce

Mount/provider events can arrive in bursts: sleep/wake, external hub reconnect, VPN reconnect, cloud provider restart, FUSE remount, or system update.

Rules:

- volume monitor has bounded queue and coalescing;
- event storm degrades to capability refresh and selective rescan hints;
- destructive operations prefer pause/revalidate over trying to chase every event;
- UI receives a concise volume state event, not thousands of raw platform callbacks;
- support logs include event class counts, not raw mount paths by default.

Kill criteria:

- volume event storm can OOM daemon;
- every raw mount event becomes WebSocket event;
- cleanup continues while volume monitor is overloaded;
- volume monitor failure is invisible to capability decisions;
- reconnecting network share triggers automatic destructive retry.

### Thirteenth-Pass Hardest Spikes

1. **VolumeEvidence and MountLease spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC.
   Prove path root changes, drive-letter changes, Linux mount ID reuse, macOS unmount/remount, APFS shared container, and target remount invalidation.

2. **Per-volume Trash capability spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1000-2800 LOC.
   Prove local disk, external disk, network share, provider root, disabled Recycle Bin, FreeDesktop topdir Trash fallback, and unsupported Trash paths.

3. **Volume-scoped free-space observation spike**
   🎯 7 🛡️ 9 🧠 7, roughly 700-1800 LOC.
   Prove same-volume Trash, cross-volume Trash, APFS container sharing, provider cache cleanup, and observed-delta receipt semantics.

## Fourteenth-Pass Extensibility, Rule Safety, And Plugin Capability Layer

This layer handles the risk created by making the Rust library reusable and extensible. Extensibility is useful, but it can silently turn a safe scanner into a platform for executing third-party logic near private filesystem data.

Focused split-out file for recommendation false positives and rule-pack safety:
`critical-zones/recommendation-policy-rule-pack-safety.md`.

Focused split-out file for official command execution sandboxing:
`critical-zones/tool-command-execution-sandbox.md`.

Critical distinction:

```text
recommendation rule:
  side-effect-free decision over provided facts

cleanup adapter:
  trusted code that can create a DeletePlan or perform a platform-specific cleanup

scanner/metadata adapter:
  trusted code that can touch filesystem APIs

future plugin:
  untrusted or semi-trusted code with explicit capabilities, budget, signature, and review state
```

The default should be conservative: MVP has no arbitrary plugin execution. Rules are data, adapters are compiled trusted code, and any future plugin system needs capability gating before it can observe paths or propose deletion.

### Extension Types And Trust Classes

Every extension point needs an explicit trust class.

| Extension type | Examples | Trust class | Allowed side effects |
| --- | --- | --- | --- |
| built-in scanner adapter | pdu adapter, future custom scanner | trusted core adapter | filesystem read according to traversal policy |
| built-in metadata adapter | platform identity, permissions, xattrs, provider state | trusted core adapter | bounded metadata reads |
| declarative recommendation rule | "old Xcode DerivedData", "large cache folder" | side-effect-free data rule | none |
| official cleanup adapter | Docker prune, Xcode cache cleanup, package manager cache cleanup | trusted cleanup adapter | only through DeletePlan and operation journal |
| third-party rule pack | community cleanup recommendations | untrusted data, reviewed before enable | none |
| third-party executable plugin | future WASM/WASI component | untrusted code unless proven otherwise | none by default, explicit capabilities only |

Rules:

- recommendation rules never execute delete, scan, network, or arbitrary filesystem operations;
- cleanup adapters cannot be installed by rules;
- scanner adapters cannot directly enqueue cleanup candidates;
- rule packs can produce candidates, evidence, warnings, and confidence, not side effects;
- executable plugins are out of MVP unless sandboxing, signing, capability manifests, and revocation exist.

Kill criteria:

- a rule can call a platform cleanup API;
- a third-party pack sees raw paths by default;
- plugin capability is implicit from installation;
- cleanup adapter bypasses DeletePlan and journal;
- user cannot distinguish official, community, and local rules.

### Capability Manifest For Extension Packs

Every non-core extension should declare what it needs before it is loaded.

Suggested manifest:

```text
extension_id
extension_version
extension_kind
publisher
signature
provenance_ref
rule_schema_version
min_engine_version
max_engine_version
requested_fact_classes
requested_path_privacy_level
requested_filesystem_capabilities
requested_network_capabilities
target_platforms
target_tool_classes
output_schema
risk_tier
review_state
revocation_epoch
```

Rules:

- default fact access is minimal and redacted;
- raw path access is exceptional and requires explicit user-visible reason;
- network is disabled by default;
- write/delete capability is not available to declarative rules;
- extension compatibility is checked before loading;
- revoked extensions invalidate cached recommendations produced by them;
- support bundles include extension ids and versions, but redact private extension inputs.

Kill criteria:

- extension loads without schema version and min engine version;
- unsigned third-party extension is enabled silently;
- revoked rule pack keeps old executable candidates;
- manifest requests are not displayed for user review when risk tier is high;
- support cannot identify which extension produced a recommendation.

### Rule Engine Shape

Recommendation rules should operate on curated facts, not the live filesystem.

Allowed input examples:

```text
node_kind
logical_size
allocated_size
exclusive_reclaim_estimate
modified_at_bucket
path_tokens_redacted
tool_classifier_evidence
provider_state
volume_class
permission_summary
known_cache_marker
scan_completeness
```

Allowed output examples:

```text
candidate_kind
risk_tier
confidence
evidence_refs
required_preflight_checks
requires_user_review
explanation_key
invalidates_on
```

Rules:

- rule output is advisory only;
- DeletePlan builder revalidates every candidate independently;
- rule cannot select by full raw path string unless it has an explicit raw-path capability;
- rule confidence cannot exceed the weakest required evidence source;
- rule evaluation is deterministic for the same facts and rule version;
- rule execution has CPU, memory, and result-count budgets;
- rule errors downgrade to no recommendation, not cleanup approval.

Top 3 rule engine approaches:

1. **Typed internal declarative DSL with CEL-like limits**
   🎯 8 🛡️ 9 🧠 7, roughly 1200-3200 LOC.
   Best first serious design. We control facts, output, cost model, privacy classes, and rule compatibility. More work than JSON-only rules, but much safer for cleanup advice.

2. **OPA/Rego or Cedar-style policy engine adapter**
   🎯 6 🛡️ 8 🧠 8, roughly 1800-4500 LOC.
   Strong for structured policy and validation, especially authz-like decisions. It may be too heavy for user-facing cleanup recommendations unless we invest in data slicing, rule UX, and explanation mapping.

3. **JSONLogic-style minimal rule format**
   🎯 6 🛡️ 7 🧠 4, roughly 500-1600 LOC.
   Attractive for simple deterministic decisions, but weaker type validation, weaker static analysis, and cross-implementation semantics can become painful as rules grow.

### Executable Plugins Are A Separate Product

WASM/WASI can be a future option, but it should not be conflated with MVP recommendation rules.

Why it is hard:

- sandbox escape is not the only risk; overbroad host capabilities are enough to leak data;
- path privacy still matters even inside a sandbox;
- deterministic resource limits need enforcement;
- plugin upgrades need compatibility and revocation;
- plugin outputs need schema validation and safety gates;
- users need to understand who authored the plugin and what it can access;
- WASI security depends on the embedding runtime and the exact capabilities exposed.

Rules for future executable plugins:

- no filesystem preopens by default;
- no network by default;
- no raw paths unless manifest and user consent allow it;
- host API is fact-query based, not arbitrary filesystem access;
- plugin output is advisory unless a trusted adapter turns it into a DeletePlan candidate;
- every plugin run has timeout, memory budget, output size limit, and audit summary;
- plugin artifacts are signed or locally trusted with an explicit warning;
- plugin revocation invalidates cached outputs.

Kill criteria:

- WASM plugin receives Home directory as a preopened root;
- plugin can call delete or move-to-trash host APIs;
- plugin can emit unbounded result lists;
- plugin gets raw scan tree by default;
- plugin update changes behavior without compatibility and provenance record.

### Extension Supply Chain And Provenance

Rule packs and plugins are software components. Treat them like dependencies, not user preferences.

Rules:

- official rule packs are built, versioned, and signed with release artifacts;
- third-party rule packs are disabled by default unless user explicitly trusts them;
- extension lockfile records id, version, digest, publisher, source, and review state;
- update process verifies digest/signature before replacing active extension;
- rollback preserves rule compatibility and invalidates unsafe cached outputs;
- extension review can mark capabilities as denied even if manifest requests them;
- extension repositories are not live code execution sources.

Possible evidence:

```text
SBOM entry
signature bundle
provenance statement
review status
compatibility test result
rule fixture coverage
revocation list version
```

Kill criteria:

- extension update pulls latest branch or URL without digest pin;
- extension provenance is not visible in support bundle;
- official and community rules share the same UI trust marker;
- unsigned update can replace a signed installed rule pack;
- old recommendation survives extension revocation.

### Adapter API Stability For Reusable Library Users

If `fs_usage_*` becomes a reusable open-source library, its extension APIs are public contracts.

Rules:

- public adapter traits avoid leaking pdu types;
- public traits use capability objects and evidence structs, not raw booleans;
- all callback/event enums have forward-compatible unknown or non-exhaustive handling where appropriate;
- unsafe or platform-specific requirements are sealed behind adapter modules;
- extension authors cannot bypass resource budgets;
- breaking adapter API changes are explicit semver changes;
- sample adapters must demonstrate safe failure, not just happy path.

Kill criteria:

- external adapter can construct trusted DeletePlan without preflight evidence;
- public trait exposes internal arena ids as stable persistent ids;
- API accepts raw path strings for destructive operations;
- public errors lose skip reason, confidence, or privacy class;
- semver tests do not cover public extension API.

### Fourteenth-Pass Hardest Spikes

1. **Declarative recommendation rule engine spike**
   🎯 8 🛡️ 9 🧠 7, roughly 1200-3200 LOC.
   Prove typed facts, privacy classes, deterministic evaluation, cost limits, rule versioning, fixture tests, and advisory-only outputs.

2. **Extension capability manifest and lockfile spike**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2600 LOC.
   Prove signed/digested packs, revocation, compatibility checks, user-visible trust state, support-bundle metadata, and cached recommendation invalidation.

3. **WASM/WASI plugin feasibility spike**
   🎯 5 🛡️ 7 🧠 9, roughly 2500-7000 LOC.
   Only worth doing after declarative rules are insufficient. The spike must prove capability-denied filesystem access, bounded execution, schema-validated output, and privacy-safe host APIs.

## Fifteenth-Pass Privilege, Elevation, And Helper-Process Boundary Layer

This layer handles the temptation to make scanning and cleanup "just work" by running more code with higher privilege. That would be a major architecture mistake. A disk cleanup tool sits directly on private data and destructive filesystem APIs. Extra privilege should be a narrow exception, not the runtime default.

Default rule:

```text
Clean Disk runs as the current user.
It scans what the current user can read.
It cleans only what the current user can safely move to Trash or cleanup through trusted adapters.
It does not bypass OS privacy or enterprise controls by becoming root/admin.
```

### Privilege Classes

Use explicit privilege classes instead of a boolean like `is_admin`.

```text
user_process:
  normal desktop app or per-user daemon

user_with_privacy_grant:
  same user process identity with OS privacy grant such as Full Disk Access

elevated_interactive_operation:
  one user-approved operation with elevated token or admin authorization

privileged_helper:
  small signed helper installed through platform service management

system_service:
  long-running service account, LocalSystem/root equivalent, or launch daemon

remote_admin_context:
  server or headless agent running with broader machine authority
```

Rules:

- privilege class is part of capability evidence;
- DeletePlan records privilege class required and privilege class actually used;
- UI distinguishes "permission denied", "privacy grant missing", and "admin required";
- scans do not auto-upgrade privilege after hitting access denied;
- elevated operations expire and require fresh transaction authorization;
- a root/admin context does not remove the need for target scope, Trash capability, and identity revalidation.

Kill criteria:

- app silently retries scan or cleanup as admin;
- UI says "needs permission" without saying which process needs it;
- receipt does not record privilege class;
- root/admin mode bypasses DeletePlan safeguards;
- remote/headless root context enables cleanup by default.

### User-Scoped Daemon Is The Baseline

For local desktop and daemon-served web UI, the baseline should be a per-user process.

Reasons:

- user files, user privacy grants, network drives, cloud provider roots, and Trash semantics are often user-session concepts;
- Windows services run outside the interactive session and can behave differently around user profiles, mapped drives, shell operations, and UI;
- macOS TCC/privacy behavior is tied to code identity and user decisions, not generic "root can read everything" product semantics;
- Linux root scanning can cross user boundaries and leak data the user did not intend to inspect;
- least privilege keeps a compromised UI or WebSocket token from becoming machine-wide authority.

Rules:

- local daemon binds to loopback and runs as current user by default;
- daemon data directory is per-user unless explicitly in managed remote/headless mode;
- per-user daemon owns scan sessions, read model, protocol tokens, and operation journals;
- app startup should detect wrong-user daemon and refuse to attach;
- system-wide daemon is a separate deployment mode with stricter scope defaults.

Top 3 local runtime privilege strategies:

1. **Per-user daemon only for MVP**
   🎯 9 🛡️ 9 🧠 5, roughly 500-1500 LOC.
   Best fit. It preserves OS user boundaries and keeps permission failures honest. Some protected/system folders remain partial scans, which is acceptable if UI is truthful.

2. **Per-user daemon plus narrow privileged helper later**
   🎯 7 🛡️ 8 🧠 9, roughly 2500-7000 LOC.
   Viable only for specific tasks like installing services, touching protected system caches, or enterprise-managed cleanup. Requires signed helper, client validation, tiny RPC surface, and separate release gates.

3. **Always root/admin daemon or Windows LocalSystem service**
   🎯 2 🛡️ 2 🧠 4, roughly 800-2500 LOC.
   Avoid. It appears simpler but creates a high-value local privilege escalation and privacy target, complicates user-session semantics, and makes cleanup mistakes machine-wide.

### Privileged Helper Is A Broker, Not A Scanner

If a privileged helper is ever added, it should not scan the disk or accept arbitrary paths.

Allowed helper responsibilities:

```text
install_or_remove_service
probe_specific_protected_capability
perform_narrow_platform_cleanup_adapter
return signed capability evidence
move one prevalidated target using platform-specific safe API
```

Forbidden helper responsibilities:

```text
scan arbitrary directory trees
accept raw path delete command
return full protected file tree to UI
hold long-lived broad filesystem handles
download or update rule packs
host WebSocket or HTTP API
parse untrusted plugin code
```

Rules:

- helper RPC is tiny and command-specific;
- helper validates client code identity where platform supports it;
- helper validates operation id, plan hash, target evidence, and expiration;
- helper writes its own minimal audit record;
- helper never trusts UI-provided paths as authority;
- helper can refuse if app/daemon version or signing identity does not match policy;
- helper is disabled by default in community/dev builds unless explicitly installed.

Kill criteria:

- helper exposes `delete(path)` or `scan(path)`;
- helper accepts requests from any local process with same user token;
- helper owns the operation journal alone;
- helper has network access without an explicit reason;
- helper logs raw protected paths by default.

### Platform-Specific Privilege Notes

macOS:

- `SMAppService` is the modern route for app-managed helpers on recent macOS; older `SMJobBless` patterns are deprecated but useful for understanding signing requirements;
- Authorization Services privilege escalation is not available inside App Sandbox;
- Full Disk Access and other privacy grants are separate from root/admin thinking;
- a helper installed as a LaunchDaemon must be treated as a different process identity with different TCC and audit implications;
- GUI prompts and file pickers belong to the user app, not a background root daemon.

Windows:

- UAC split-token behavior means an administrator account is not always running with elevated privileges;
- LocalSystem has very broad local authority and should not be the default scanner context;
- Windows services have service security descriptors and access rights that must not be overly permissive;
- Shell/Recycle Bin operations often need the right user/session context, not just more privilege;
- Controlled Folder Access and enterprise policies should be surfaced as capability failures, not bypass targets.

Linux:

- prefer user service/process for desktop mode;
- if a systemd service is needed, harden it with least privilege controls such as `NoNewPrivileges`, `CapabilityBoundingSet`, `DynamicUser`, `PrivateTmp`, `ProtectSystem`, and restricted address families where compatible;
- root inside a container is not the same as host root, but bind mounts can still expose host data;
- package-manager cleanup adapters should prefer official commands and explicit user review over raw root deletion.

Kill criteria:

- macOS helper is treated as if it inherits app privacy grants automatically;
- Windows service runs as LocalSystem because it was easier;
- Linux system service has no capability bounding or filesystem protection plan;
- container/headless mode cannot explain whether it sees container filesystem or host bind mounts;
- app tells user to grant admin/root to fix ordinary scan errors.

### Elevation UX And Transaction Authorization

Elevation is a user decision and a transaction boundary.

Rules:

- elevation prompt follows a visible operation summary;
- prompt explains target, operation class, estimated risk, and why normal user authority is insufficient;
- confirmation expires after plan change, target change, daemon restart, helper restart, timeout, or privilege context change;
- elevated cleanup uses smaller blast-radius budgets than ordinary cleanup;
- elevated operations are never started from stale scan snapshots;
- compact UI must show elevated mode as a persistent risk marker.

Kill criteria:

- elevation prompt appears before the user sees the concrete plan;
- user approves admin once and app keeps broad authority for the session;
- elevated mode is shown only in settings, not near the destructive action;
- helper authorization outlives the plan hash;
- failed elevation becomes generic cleanup failure.

### Remote And Headless Privilege Boundaries

Remote/headless mode makes privilege harder because the user may not be physically present at the machine.

Rules:

- remote/headless defaults to read-only scan;
- cleanup requires scoped roots, explicit authz, audit, and smaller budgets;
- root/admin headless process is treated as high-risk deployment mode;
- remote API cannot expose "scan all host disks" without policy;
- container deployments must label host bind mounts, container root, and volume scopes;
- remote receipts include actor, authz scope, privilege class, and target scope.

Kill criteria:

- remote cleanup is enabled because local cleanup exists;
- root daemon accepts browser-origin local token logic;
- remote UI can request arbitrary absolute host path;
- audit log lacks actor and privilege class;
- headless root mode uses same defaults as desktop user mode.

### Fifteenth-Pass Hardest Spikes

1. **Per-user daemon identity and wrong-user detection spike**
   🎯 9 🛡️ 9 🧠 6, roughly 700-1800 LOC.
   Prove daemon identity, token storage, data directory ownership, stale daemon detection, and refusal to attach across users or privilege classes.

2. **Privileged helper threat-model spike**
   🎯 7 🛡️ 10 🧠 9, roughly 1800-5000 LOC docs/tests/prototype.
   Do this before writing a helper. It must define RPC surface, client validation, signing requirements, audit, forbidden commands, and rollback/uninstall behavior.

3. **Elevation UX and transaction authorization spike**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2400 LOC/tests.
   Prove visible plan summary, expiring authorization, compact warning state, receipt privilege class, and post-failure recovery.

## Sixteenth-Pass Execution Authority Leases And Confused-Deputy Defense Layer

The fifteenth pass defines privilege classes. This pass goes one layer deeper: how the product prevents a less trusted actor from causing a more trusted actor to perform an operation under the wrong authority.

This is the core confused-deputy risk:

```text
Browser/UI client:
  has user intent, but no filesystem authority.

User daemon:
  has filesystem authority for one user/session, but must not trust arbitrary UI commands.

Privileged helper:
  may have stronger authority, but must not accept product-level decisions directly.
```

The safe architecture is not "trusted UI talks to trusted daemon". The safe architecture is "each boundary carries typed authority leases, policy decisions, operation ids, and short-lived proof of user intent".

### Authority Lease Instead Of Authority Flag

A boolean `is_elevated` or enum `PrivilegeClass` is not enough. Authority must be a lease with scope, expiry, and invalidation causes.

Required model:

```text
AuthorityLease
  authority_ref
  lease_epoch
  principal_kind
  principal_redacted_ref
  session_ref
  process_identity_ref
  package_identity_ref
  helper_identity_ref
  privilege_class
  privacy_grant_scope
  allowed_target_roots
  allowed_operation_kinds
  max_blast_radius
  user_presence_required
  issued_at
  expires_at
  invalidation_reasons
```

Rules:

- every scan snapshot stores `scan_authority_lease_ref`;
- every query response can expose authority class and partial-coverage state without leaking raw user identifiers;
- every DeletePlan stores `plan_authority_lease_ref`;
- every destructive execution requires a fresh `execution_authority_lease_ref`;
- lease equality is structural, not just same privilege class;
- authority leases expire on process restart, app update, helper update, permission change, user switch, logout, sleep/wake, volume remount, or policy refresh;
- authority downgrade is safe by default; authority upgrade requires explicit transaction authorization.

Kill criteria:

- scan cache has no authority lease;
- authority is represented only as `admin: true`;
- helper request accepts an authority string from Flutter;
- user approves elevation once and stale queued deletes keep using it;
- support bundle cannot explain why a scan became partial after permission changes.

### User Intent Proof Is Separate From Transport Token

The local token says "this client may connect". It does not say "the user approved this delete under this authority".

Required model:

```text
UserIntentProof
  operation_id
  plan_hash
  selected_target_refs
  displayed_risk_version
  confirmation_surface
  user_presence_kind
  locale
  issued_at
  expires_at
```

Rules:

- delete confirmation binds to the exact plan hash and authority lease;
- sort/filter/search state cannot alter confirmed target set after confirmation;
- reconnecting WebSocket clients must fetch current operation state before enabling action buttons;
- UI cannot create `UserIntentProof` alone; daemon validates against current plan and session;
- compact layout must show the same risk facts as wide layout before proof is issued;
- queued items require re-confirmation after target identity, volume, authority, or recommendation evidence changes.

Kill criteria:

- delete button can be triggered from stale browser tab after plan changed;
- confirmation is stored as "user clicked checkbox" without plan hash;
- WebSocket reconnect replays old confirm command without idempotency and expiry checks;
- UI generates proof while daemon has newer snapshot state;
- helper receives user intent proof without daemon-side validation.

### Helper Calls Need Capability Intersection

The helper must execute only the intersection of four scopes:

```text
allowed_by_helper_install_policy
AND allowed_by_daemon_policy
AND allowed_by_user_intent_proof
AND allowed_by_current_platform_authority
```

If any part is missing, the helper refuses. This avoids "higher privilege means broader action".

Rules:

- helper requests contain operation id, plan hash, authority lease ref, user intent proof ref, target evidence, and expiry;
- helper validates caller identity independently of the daemon's JSON payload;
- helper never expands target scope;
- helper never fetches additional target paths from UI;
- helper returns typed denial causes: `caller_identity_mismatch`, `expired_request`, `scope_not_allowed`, `user_presence_missing`, `authority_changed`, `platform_denied`;
- helper result is advisory until the daemon journals it.

Kill criteria:

- helper can turn a folder ref into recursive delete without daemon-provided target manifest;
- helper trusts daemon-provided caller name instead of platform identity;
- helper has a generic "run with admin" RPC;
- helper denial is collapsed into generic failure;
- helper writes final receipt before daemon records operation state.

### Mixed-Authority Snapshots Must Not Merge

A full product can have multiple snapshots: user-mode scan, Full Disk Access scan, elevated Windows metadata scan, remote/headless scan, or root container scan. These are not one tree.

Rules:

- snapshot key includes authority lease class and lease epoch;
- node IDs are unique only inside snapshot scope;
- search/top-files indexes are per snapshot authority;
- UI can compare snapshots, but cannot merge cleanup candidates without new preflight;
- elevated visibility is displayed as stronger read evidence, not stronger delete evidence;
- cache eviction cannot keep child nodes without the authority metadata that explains them.

Kill criteria:

- node ID from elevated snapshot is accepted in user-mode DeletePlan;
- query API returns mixed-authority rows in one page without authority markers;
- "largest files" combines user and elevated scans under one total;
- user-mode rescan updates an elevated snapshot in place;
- cache compaction drops authority lease refs.

### Session Reconnect And Multi-Client Rules

HTTP plus WebSocket makes reconnect normal. Reconnect must not accidentally preserve obsolete authority or user intent.

Rules:

- command endpoints check current authority before accepting mutation;
- event stream includes `authority_changed`, `authority_expired`, `session_invalidated`, and `operation_requires_reconfirmation`;
- terminal operation state is durable and queryable after reconnect;
- multiple clients can observe one session, but only one active destructive coordinator can execute;
- client-visible action state is always derived from daemon state after reconnect;
- old browser tabs cannot reuse old confirm proof after daemon restart or lease epoch change.

Kill criteria:

- UI locally re-enables delete after WebSocket reconnect without querying daemon;
- two browser tabs can submit conflicting cleanup commands;
- authority change event is coalesced away as ordinary progress event;
- operation continues after session invalidation without explicit durable state;
- multi-client test suite covers scan only, not cleanup.

### Cross-Layer Placement

Reusable `fs_usage_*` library:

- defines `AuthorityLease`, `UserIntentProof` input contracts, and typed denial causes;
- does not implement HTTP auth, browser token storage, TCC prompts, UAC prompts, or polkit UI;
- exposes ports for authority probing, helper invocation, and policy decisions;
- keeps pdu adapter authority-agnostic except for receiving scan context.

Clean Disk server:

- binds local token to user/session authority;
- creates and expires authority leases;
- owns operation coordinator, idempotency, journal, and receipt mapping;
- prevents Flutter or helper from directly creating trusted proofs;
- maps platform adapter facts into protocol DTOs.

Flutter app:

- displays risk and authority state;
- asks for user confirmation;
- treats daemon as source of truth after every reconnect;
- never stores authority proofs as durable app state.

Boundary tests:

- HTTP handlers cannot construct `ValidatedExecutionAuthority`;
- Flutter DTOs cannot be passed into helper adapter directly;
- helper adapter cannot import recommendation engine;
- pdu adapter cannot import cleanup policy;
- fake elevated fixtures require explicit test marker.

### Sixteenth-Pass Hardest Spikes

1. **AuthorityLease state-machine spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC.
   Prove lease issue, expiry, downgrade, upgrade, app update, helper update, permission refresh, daemon restart, and snapshot invalidation.

2. **Confused-deputy attack simulation spike**
   🎯 8 🛡️ 10 🧠 9, roughly 1400-3800 LOC/tests.
   Build tests where stale browser tabs, another same-user process, wrong-user daemon, elevated helper, and replayed commands try to execute cleanup outside their authority.

3. **Mixed-authority snapshot isolation spike**
   🎯 7 🛡️ 9 🧠 8, roughly 1000-2600 LOC/tests.
   Prove separate node ids, indexes, query pages, DeletePlan preflight, UI labels, cache eviction, and receipt evidence for user-mode versus elevated scans.

## Seventeenth-Pass Content Boundary, Hashing, And Preview Safety Layer

This layer separates disk usage analysis from file content processing. A disk usage tool can be metadata-first. A duplicate finder, preview generator, content hasher, malware scanner, or smart classifier is a different product surface.

Default rule:

```text
MVP scans metadata, not file contents.
It does not hash file bodies.
It does not generate previews.
It does not parse arbitrary documents.
It does not intentionally hydrate cloud placeholders.
```

### Metadata Facts Versus Content Facts

We need explicit fact classes so future features cannot quietly start reading content.

```text
metadata_fact:
  name, type, size, allocated size, timestamps, permissions, file identity, provider state

derived_metadata_fact:
  path tokens, known cache marker, tool-managed folder marker, package-manager state

content_fingerprint_fact:
  hash, chunk hash, perceptual hash, media fingerprint

content_preview_fact:
  thumbnail, extracted text, PDF page preview, image dimensions from decoded content

content_classification_fact:
  duplicate group, media type inferred from bytes, sensitive-data classification
```

Rules:

- `metadata_fact` is allowed in normal scan;
- `content_fingerprint_fact`, `content_preview_fact`, and `content_classification_fact` require explicit feature mode;
- protocol DTOs include fact provenance and fact class;
- recommendation rules declare which fact classes they consume;
- content facts never become mandatory for basic size tree UI;
- cleanup candidates based on content facts are higher risk than metadata-only candidates.

Kill criteria:

- a details panel reads file bytes without showing content mode;
- duplicate detection runs as part of baseline scan;
- recommendation rule requires content hash but UI labels it ordinary cache cleanup;
- preview thumbnail is logged, cached, or exported without privacy class;
- content parser error becomes generic scan failure.

### Cloud Hydration And Content Reads

Cloud placeholders make content reads expensive and privacy-sensitive. Opening or reading a placeholder can materialize remote data locally.

Rules:

- normal scan uses metadata APIs that avoid recall-on-data-access where possible;
- content features must show estimated hydration risk before starting;
- hydrated bytes are measured separately from scanned bytes;
- content features should skip offline/provider-managed files by default;
- user can limit content work to selected subtree, file size range, and provider class;
- content job has cancel, pause, IO budget, and partial result state;
- receipt/support data must say whether cleanup changed local cache, cloud object, or unknown provider state.

Kill criteria:

- content hashing downloads cloud files silently;
- preview generation hydrates provider content during ordinary navigation;
- progress bar mixes scan bytes and hydrated bytes;
- content job ignores battery/thermal/background profile;
- cloud hydration side effect is missing from support bundle evidence.

### Duplicate Finder Is Destructive-Risk Multiplication

Duplicate detection is tempting, but it is not just "hash files and delete extras".

Risks:

- same content does not mean same user value;
- hardlinks, reflinks, APFS clones, dedupe, and snapshots can make duplicates cheap or shared;
- cloud placeholders may represent remote content not locally present;
- case, Unicode, and path display can make duplicate groups confusing;
- packages, app bundles, VMs, containers, photo libraries, mail stores, and backups can contain intentional repeated files;
- deleting one duplicate can break references, projects, build caches, or application indexes.

Rules:

- duplicate finder is opt-in and outside MVP cleanup;
- duplicate groups are advisory by default;
- group evidence distinguishes same identity, hardlink, same content hash, same size only, and weak similarity;
- automatic duplicate deletion is disabled until a separate DeletePlan policy exists;
- duplicate cleanup requires per-group keeper strategy and user review;
- file-type and folder-class risk labels are mandatory;
- reclaim estimate for duplicates must account for hardlinks, clones, snapshots, and shared extents.

Top 3 duplicate approaches:

1. **No duplicate finder in MVP**
   🎯 9 🛡️ 10 🧠 2, roughly 0-200 LOC.
   Best decision now. It keeps the product focused on fast metadata scan and safe cleanup.

2. **Opt-in duplicate analysis with metadata prefilter plus content hash**
   🎯 7 🛡️ 7 🧠 8, roughly 2500-7000 LOC.
   Viable later. Needs budgeted IO, cloud-skip defaults, hash cache, group evidence, keeper UX, and no automatic deletion.

3. **Always-on duplicate detection during scan**
   🎯 2 🛡️ 3 🧠 7, roughly 1800-5000 LOC.
   Avoid. It damages scan performance and crosses the content/privacy boundary by default.

### Hashes Are Content-Derived Private Data

Hashes can prove equality or integrity, but they are not automatically privacy-safe.

Rules:

- content hashes are privacy-classified data;
- content hash storage is opt-in and retention-limited;
- support bundles never export raw content hashes by default;
- telemetry never emits content hashes or duplicate group signatures;
- keyed/local fingerprints are preferred for support correlation when global comparability is unnecessary;
- hash algorithm and chunking strategy are versioned;
- weak hashes can prefilter but cannot justify equality or deletion;
- content hash cache invalidates on identity, size, mtime, provider state, and content version evidence.

Kill criteria:

- content hashes are treated like harmless metadata;
- hash of a sensitive file appears in logs or telemetry;
- hash algorithm changes without invalidating cache;
- duplicate group is based on size and mtime only but shown as exact duplicate;
- hash cache survives provider rehydrate/dehydrate without evidence refresh.

### Preview And Thumbnail Safety

Previews and thumbnails are content derivatives. They can leak document content and create persistent artifacts outside the original file.

Rules:

- no thumbnails/previews in MVP unless explicitly scoped;
- details panel uses icons and metadata, not content previews, by default;
- generated previews have explicit cache location, retention, redaction, and deletion policy;
- preview generation should not call arbitrary third-party parsers without sandbox/budget;
- OS thumbnail caches are not ours to promise deletion or privacy over;
- support screenshots need optional path and preview redaction;
- UI should distinguish system-provided icon from app-generated content preview.

Kill criteria:

- app generates previews for protected or encrypted-container files silently;
- thumbnail cache path or source URI leaks into support bundle;
- preview generation is triggered by row hover;
- parser crash kills scan session;
- preview cache has no retention or purge path.

### Content Parser Attack Surface

Reading bytes is not the only cost. Parsing file formats is historically risky because parsers handle untrusted complex input.

Rules:

- avoid content parsing in core scanner;
- content parsers run in isolated jobs with time, memory, and output limits;
- parser dependencies go through stricter supply-chain review than metadata-only dependencies;
- parser errors are typed and local to the content feature;
- content extraction output is privacy-classified and not fed into telemetry;
- parser features have kill switches independent from scanning.

Kill criteria:

- metadata scan imports image, PDF, archive, or media parsers;
- parser dependency is added for UI convenience without threat model;
- parser panic aborts daemon;
- extracted text enters search index by default;
- parser output is cached without schema/privacy version.

### Seventeenth-Pass Hardest Spikes

1. **Content fact-class and protocol provenance model**
   🎯 8 🛡️ 9 🧠 6, roughly 700-1800 LOC.
   Needed before any duplicate, preview, or content classifier feature. It prevents content-derived data from masquerading as metadata.

2. **Opt-in duplicate analysis spike**
   🎯 6 🛡️ 7 🧠 9, roughly 2500-7000 LOC.
   Worth postponing. It needs hash cache, cloud-skip policy, IO budgets, group evidence, keeper UX, and clone/hardlink/reclaim accounting.

3. **Preview sandbox and retention spike**
   🎯 5 🛡️ 7 🧠 8, roughly 1800-5000 LOC.
   Only useful if previews become a product requirement. Otherwise icons plus metadata are safer and cheaper.

## Eighteenth-Pass Clock, Causality, And Timestamp Semantics Layer

This layer separates time used for human display from time used for correctness. Clean Disk has leases, evidence freshness, operation expiry, event ordering, recommendation decay, receipt audit, retention, and file modified dates. These must not all use the same timestamp model.

Default rule:

```text
wall-clock time is for display, audit, and persisted chronology
monotonic time is for in-process deadlines and timeouts
sequence and epoch are for protocol ordering
filesystem timestamps are evidence, not identity
```

### Time Classes

Use explicit time classes in DTOs and domain models.

```text
wall_time_utc:
  RFC3339/Unix epoch value used for display, receipts, logs, support, retention

monotonic_deadline:
  in-process timeout or lease deadline that is not persisted across process restart

sequence_time:
  session sequence, event sequence, operation sequence, journal append sequence

filesystem_time:
  mtime, ctime, atime, birthtime, provider timestamp, backup timestamp

derived_age:
  computed freshness/decay value with clock source and confidence
```

Rules:

- protocol events are ordered by sequence and epoch, not wall time;
- operation journal order is append sequence plus hash chain, not timestamp sort;
- UI display can sort by modified time, but destructive decisions cannot rely on it alone;
- persisted wall time uses UTC and explicit format/version;
- in-process expiry uses monotonic deadlines where possible;
- persisted expiry stores wall time plus policy version and is revalidated after restart;
- every time-derived decision records clock source and confidence.

Kill criteria:

- WebSocket event ordering uses `created_at`;
- DeletePlan expires only by comparing wall-clock strings;
- journal replay sorts events by timestamp;
- recommendation freshness is computed on Flutter only;
- support bundle cannot show whether device clock changed during operation.

### Clock Changes And Sleep/Wake

System clocks can move forward, backward, or jump after NTP, manual user change, VM resume, laptop sleep/wake, dual-boot, timezone changes, or enterprise time sync.

Rules:

- daemon detects suspicious wall-clock jumps by comparing wall time delta with monotonic elapsed delta during process lifetime;
- clock jump invalidates freshness-sensitive UI state and forces capability refresh for destructive operations;
- sleep/wake invalidates volume, authority, and content-job leases unless proven safe;
- retention deletion should not run immediately after a large backward/forward jump without guardrails;
- elapsed scan duration uses monotonic time, not wall time;
- support logs record clock-jump class without leaking local timezone history unless user opts in.

Kill criteria:

- user sets clock back and stale recommendation becomes fresh;
- user sets clock forward and operation journal retention purges active evidence;
- sleep/wake keeps DeletePlan executable without revalidation;
- scan throughput uses wall-clock delta and becomes negative or huge;
- clock jump is logged only as ordinary warning.

### File Timestamps Are Weak Evidence

File timestamps differ across filesystems and platforms. They can have different precision, timezone behavior, update semantics, and availability.

Important distinctions:

```text
mtime:
  content modification time

ctime:
  Unix status change time, not creation time

birthtime/creation time:
  optional or filesystem-specific

atime:
  often disabled, delayed, or noisy

provider time:
  may reflect remote/cloud state, local placeholder state, or sync metadata
```

Rules:

- timestamps are never sole identity evidence;
- timestamp precision and source are recorded when available;
- timestamp comparisons use tolerance by filesystem/provider class;
- "last modified" UI labels must not imply "last used" or "safe to delete";
- recommendation rules based on age require evidence class and risk tier;
- moved/copied/imported files may have misleading creation or modification times;
- unknown timestamp precision lowers confidence, not correctness.

Kill criteria:

- duplicate detection uses mtime as equality proof;
- cleanup recommendation says "unused" based only on mtime;
- ctime is displayed as creation time on Unix-like systems;
- FAT/external volume timestamps are treated like APFS/NTFS timestamps;
- timestamp changed during scan is ignored in DeletePlan preflight.

### Freshness And Decay Need A Clock Contract

Freshness is not just `now - observed_at`.

Suggested freshness model:

```text
observed_wall_time
observed_monotonic_ref
producer_process_epoch
source_clock
clock_confidence
filesystem_timestamp_precision
lease_epoch
invalidated_by
freshness_policy_version
```

Rules:

- `live`, `fresh`, `stale`, `historical`, and `invalidated` states are computed by the daemon;
- Flutter displays freshness state but does not author it;
- clock uncertainty can downgrade `fresh` to `review_required`;
- recommendation decay depends on target mutability, watcher health, clock confidence, and scan completeness;
- DeletePlan requires live evidence regardless of old freshness labels;
- stale evidence can remain visible but cannot authorize cleanup.

Kill criteria:

- frontend computes "safe because scanned 5 minutes ago" without daemon confirmation;
- clock rollback extends recommendation validity;
- freshness labels survive daemon restart without re-evaluation;
- watcher failure does not influence freshness;
- freshness policy changes without invalidating cached recommendations.

### Receipts, Audit, And Retention Time

Receipts and support evidence need wall-clock chronology, but wall time alone is not proof of order.

Rules:

- receipt records wall time, operation sequence, journal sequence, process epoch, daemon version, and clock confidence;
- operation journal hash chain defines order;
- retention policy uses wall time but has active-operation and clock-jump safeguards;
- support bundle includes timezone offset only when needed for user-facing chronology or with user consent;
- audit display can show local time, but stored canonical time is UTC;
- imported old artifacts keep original producer timestamp and migration timestamp separately.

Kill criteria:

- receipt only has a localized timestamp string;
- retention cleanup purges unresolved journal events;
- support tooling reorders events by wall clock;
- timezone conversion changes persisted receipt value;
- migration overwrites original event timestamps.

### Protocol And Persistence Timestamp Encoding

JSON and SQLite need disciplined timestamp encoding.

Rules:

- API timestamps use RFC3339 UTC strings for human/debug fields or string/integer epoch wrappers for machine fields;
- do not rely on JavaScript number precision for microsecond timestamps, sequence ids, or cursor ids;
- SQLite stores canonical UTC epoch/string fields consistently, not mixed local formats;
- DTOs distinguish `display_time`, `observed_at`, `expires_at`, `monotonic_duration_ms`, and `sequence`;
- schema evolution reserves old time field names when semantics change;
- tests include DST boundary, timezone change, clock rollback, and far-from-epoch Dart web values where relevant.

Kill criteria:

- timestamp unit is implicit in field name like `time`;
- API returns local time without offset;
- Dart web precision can alter stored microsecond timestamp used for identity or ordering;
- SQLite stores some times as local strings and others as UTC epoch without schema-level distinction;
- event cursor is timestamp-based.

### Eighteenth-Pass Hardest Spikes

1. **Clock source and freshness state-machine spike**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2400 LOC/tests.
   Prove wall-clock jump detection, monotonic elapsed scan timing, sleep/wake invalidation, daemon-side freshness, and recommendation downgrade.

2. **Filesystem timestamp precision fixture spike**
   🎯 7 🛡️ 8 🧠 8, roughly 1000-2800 LOC/tests.
   Prove APFS, NTFS, FAT/exFAT, Linux ext/Btrfs, SMB/NFS, provider roots, copied files, moved files, and timestamp-tolerance behavior.

3. **Protocol timestamp encoding compatibility spike**
   🎯 8 🛡️ 8 🧠 6, roughly 600-1600 LOC/tests.
   Prove RFC3339/epoch wrappers, Dart web precision boundaries, SQLite storage, old DTO compatibility, and non-timestamp event cursors.

## Nineteenth-Pass Host Interference, Runtime Trust, And Security-Product Layer

This layer treats the host as an active participant, not a passive disk. The scanner may be correct and still fail in the real world because Gatekeeper, App Translocation, SmartScreen, Smart App Control, Defender, Controlled Folder Access, EDR, antivirus, Spotlight, Windows Search, backup agents, cloud sync, or enterprise policy changed the runtime conditions.

These are not ordinary IO errors. They are host-state facts that affect launch, scan speed, write permission, delete safety, user trust, and support diagnosis.

### Runtime Trust Is A Capability

Packaging is not complete when binaries compile. The app, daemon, helper, installer, updater, and bundled libraries need runtime trust evidence.

Required model:

```text
RuntimeTrustEvidence
  app_identity_ref
  daemon_identity_ref
  helper_identity_ref
  install_scope
  launch_location
  translocation_state
  quarantine_state
  signing_state
  notarization_state
  certificate_state
  reputation_state
  enterprise_policy_state
  evaluated_at
  expires_at
  remediation_kind
```

Rules:

- daemon launch checks runtime trust before accepting production commands;
- macOS app translocation is a typed degraded state, not a daemon crash;
- relative helper paths are forbidden in production launch code;
- app, daemon, helper, and updater are signed and assessed as one release surface;
- Windows SmartScreen or Smart App Control prompt state is release/support evidence, not a generic install complaint;
- expired, revoked, missing, or changed signing identity invalidates capability leases;
- support bundle includes trust evidence without raw user paths or certificates by default;
- UI never instructs users to disable Gatekeeper, SmartScreen, Defender, SIP, CFA, EDR, or enterprise controls.

Top 3 runtime trust strategies:

1. **Signed/notarized app plus trust probe before daemon start**
   🎯 9 🛡️ 9 🧠 6, roughly 900-2400 LOC/config/tests.
   Best baseline. It turns "daemon did not start" into specific evidence: translocated app, unsigned helper, blocked installer, mismatched identity, or policy denial.

2. **Allow portable/dev runtime with explicit degraded label**
   🎯 7 🛡️ 7 🧠 5, roughly 500-1400 LOC.
   Useful for contributors and internal testing. It must be visibly non-production and must not produce trusted delete receipts or permission conclusions.

3. **Assume launch success means trust is fine**
   🎯 2 🛡️ 3 🧠 2, roughly 100-300 LOC.
   Not acceptable. It hides Gatekeeper, translocation, SmartScreen, enterprise policy, helper identity, and update-trust failures until users hit confusing runtime errors.

Kill criteria:

- production daemon starts from a translocated/read-only app location without warning;
- code uses current working directory to find helper binaries;
- updater replaces signed helper with unsigned or differently signed helper;
- support bundle cannot distinguish "daemon crashed" from "daemon blocked by trust policy";
- docs tell users to remove quarantine attributes or disable platform protections.

### Security-Product Interference Must Be Classified

Security products can block writes, delay reads, quarantine files, intercept process launch, rescan extracted archives, or flag high-volume traversal. A cleanup app must cooperate with those controls.

Required model:

```text
HostInterferenceEvidence
  actor_kind
  actor_confidence
  operation_kind
  target_scope
  symptom_kind
  policy_source
  observed_signal
  retry_policy
  remediation_kind
  user_visible_message_key
  support_evidence_ref
```

Actor kinds:

```text
gatekeeper
smartscreen
smart_app_control
defender_cfa
defender_realtime_scan
third_party_av
enterprise_edr
spotlight
windows_search
backup_agent
cloud_sync_agent
unknown_security_policy
```

Rules:

- Controlled Folder Access denial is `security_policy_blocked_write`, not ordinary permission denied;
- Defender/EDR read slowdown is a throughput and host-interference signal, not scan failure;
- quarantined daemon/helper binary becomes `runtime_trust_blocked`;
- retries use backoff and budgets rather than hammering the same protected path;
- recommendations never advise adding broad antivirus exclusions;
- if user chooses to allowlist, product copy must name exact signed executable and explain the security tradeoff;
- security product evidence is advisory unless a platform API gives a typed signal;
- logs store event class and product category, not raw target paths.

Kill criteria:

- AV/EDR slowdown is shown as app hang;
- cleanup retries blocked writes indefinitely;
- app recommends disabling Defender, Gatekeeper, SIP, SmartScreen, or enterprise EDR;
- deletion of a quarantined or security-managed file is treated as ordinary cleanup;
- support asks users for screenshots of private Defender/EDR event paths because the app has no diagnostic class.

### Indexers, Backup Agents, And Sync Tools Are Workload Peers

Disk usage scanning competes with other filesystem observers. Spotlight, Windows Search, backup agents, cloud sync, antivirus, and developer tools may all observe or mutate the same files.

Platform facts:

- Windows Search indexes file properties, paths, and, for many files, contents; enhanced mode can index the whole PC and use more resources;
- Defender performance analyzer exists because some files, paths, extensions, and processes can cause scan-time overhead;
- FSEvents has privacy constraints and event IDs can be non-consecutive for non-root users;
- backup and sync agents can change files during scan, restore deleted files, hold handles, or create snapshots.

Rules:

- performance benchmarks record indexing, antivirus, backup, sync, thermal, and power states;
- scanner resource governance reacts to sustained throughput collapse and host pressure;
- scan results distinguish "changed during scan" from "blocked by policy";
- UI shows host interference as partial/degraded result where confidence is high;
- product never deletes index databases, event logs, backup metadata, or sync metadata as generic cleanup;
- watcher/incremental scan cannot rely on event streams as complete truth;
- "free space did not change" can be caused by snapshots, Trash, backup agents, open handles, or provider state.

Kill criteria:

- benchmark claims ignore Defender/Spotlight/Windows Search state;
- app treats Windows Search or Spotlight databases as obvious junk;
- `.fseventsd`, `.Spotlight-V100`, Windows Search DB, backup metadata, or sync metadata is recommended for raw deletion by default;
- FSEvents watcher gap updates cleanup-capable tree without full rescan;
- host pressure causes scan to starve UI while progress still says healthy.

### App Translocation And Helper Launch Paths

macOS App Translocation is especially dangerous for a sidecar daemon. It can make the app appear to run while relative resource paths, helper discovery, updater paths, writable locations, and signing assumptions are wrong.

Rules:

- production helper path resolution uses bundle APIs or installer-managed absolute paths, never `cwd`;
- translocated app is a launch health state with guidance to move/install the app before enabling daemon mode;
- updater does not run from a translocated or read-only app location;
- daemon-served web UI refuses to publish stable local URLs until install identity is stable;
- app-child helper identity is tested from mounted DMG, Downloads, extracted archive, `/Applications`, and after update;
- translocation state invalidates runtime trust evidence and authority leases.

Kill criteria:

- helper path works only because development cwd matches expected layout;
- web UI stores daemon URL from a translocated run as persistent config;
- update flow writes beside a read-only translocated bundle;
- support docs say "move the binary manually" without the app detecting the actual state;
- FDA/helper identity tests run only from a development build.

### Enterprise And Managed Environment Policy

Enterprise environments can invert consumer assumptions. Users may not be allowed to bypass SmartScreen, allowlist an executable, access protected folders, run local web servers, install helpers, or grant Full Disk Access.

Rules:

- enterprise policy is a capability source, not an error overlay;
- managed denial is surfaced as `managed_policy_denied` where evidence exists;
- remote/headless and enterprise modes default to read-only scan unless cleanup scope and actor authorization are explicit;
- support bundle can generate an enterprise allowlisting profile: executable names, signing identity, bundle id, local bind behavior, helper identity, and ports;
- product docs explain least-privilege allowlisting, not broad folder or security-product exclusions;
- local daemon can run with TCP disabled or Unix/named-pipe-only transport if enterprise policy blocks loopback browser access.

Kill criteria:

- app assumes user can click through SmartScreen or UAC;
- local daemon failure under enterprise policy is shown as "server unavailable";
- allowlisting guidance uses wildcard paths or unsigned dev binaries;
- enterprise build uses same destructive defaults as consumer local mode;
- network/port behavior is undocumented for IT review.

### Do Not Become An Anti-Security Tool

A disk cleanup app can easily drift into dangerous behavior by trying to be "helpful". It must not remove security metadata, disable protections, or clean around quarantines as an ordinary space-saving workflow.

Non-goals:

- remove `com.apple.quarantine` as cleanup;
- clear SmartScreen markers;
- disable Defender, Gatekeeper, SIP, XProtect, CFA, EDR, Spotlight, or Windows Search;
- delete security product quarantine storage;
- mutate enterprise policy;
- auto-create antivirus exclusions;
- advise permanent-delete to bypass protected-folder failures.

Rules:

- any future security-metadata tool is a separate product mode with explicit user intent and security copy;
- normal cleanup never weakens platform protection;
- security-product quarantine is treated as owned by that product;
- app copy uses "blocked by security policy", not "error, try admin";
- support tooling redacts security event paths by default.

Kill criteria:

- app offers "fix by disabling protection";
- cleanup candidate list includes AV quarantine or EDR storage without official adapter;
- app strips xattrs/tags/quarantine flags to make deletion work;
- user is nudged to run as root/admin after security policy denial;
- support script changes Defender/Gatekeeper/system policy.

### Nineteenth-Pass Hardest Spikes

1. **Runtime trust and translocation probe spike**
   🎯 8 🛡️ 9 🧠 7, roughly 1000-2600 LOC/config/tests.
   Prove signed/notarized app, mounted DMG, Downloads, `/Applications`, translocated state, helper path resolution, updater block, and daemon launch diagnostics.

2. **Security-product interference classifier spike**
   🎯 7 🛡️ 9 🧠 8, roughly 1200-3200 LOC/tests.
   Prove Defender Controlled Folder Access write block, Defender scan overhead classification, quarantined/missing helper handling, retry policy, typed denial, and support-bundle evidence.

3. **Background actor benchmark and degradation spike**
   🎯 7 🛡️ 8 🧠 7, roughly 900-2400 LOC/tests.
   Measure scan behavior with indexing on/off, Defender active, backup/sync activity, low battery/thermal pressure where available, and event-stream gaps. Gate performance claims on documented host state.

## Twentieth-Pass Public Library API, Misuse Resistance, And Tenant Boundary Layer

This layer protects the reusable `fs_usage_*` crates from becoming a footgun. Clean Disk can enforce policy in its app server, but an open-source library will be used in CLIs, desktop apps, remote agents, CI jobs, multi-tenant services, admin tools, and scripts we do not control.

The public API must make the safe path easy and the dangerous path explicit. If it exposes raw path deletion, stable-looking internal ids, global mutable scanner state, or pdu-specific types, downstream projects will accidentally bypass the same protections Clean Disk depends on.

### Public API Must Encode Safety State

The library needs public types that represent trust transitions, not just plain data.

Required public state boundary:

```text
UnvalidatedTarget
  display path or user-selected root, not executable authority

ScanSnapshot
  immutable metadata tree plus authority, traversal, volume, and accounting evidence

PreflightedTarget
  target identity revalidated for one operation window

DeletePlan
  normalized, policy-checked, user-reviewable plan

ValidatedDeletePlan
  fresh authority, target, volume, and user-intent evidence

CleanupReceipt
  immutable result evidence, not a retry command
```

Rules:

- destructive APIs only accept validated domain states, never raw paths;
- constructors for trusted states are private or sealed behind use cases;
- public ids are scoped by session/snapshot and do not look globally durable;
- `unsafe`, privileged, or platform-specific operations live behind named modules and feature gates;
- fallible builders return typed validation errors before side effects;
- docs show safe examples first and include explicit non-goals;
- public APIs expose evidence strength and confidence, not booleans like `safe`, `trusted`, or `admin`.

Top 3 public API shapes:

1. **Type-state public API with sealed trusted constructors**
   🎯 9 🛡️ 9 🧠 7, roughly 1200-3200 LOC/docs/tests.
   Best fit. It makes bypassing scan, preflight, policy, and receipt transitions hard without explicit advanced APIs.

2. **Service-oriented facade plus expert raw modules**
   🎯 8 🛡️ 8 🧠 6, roughly 900-2400 LOC/docs/tests.
   Good pragmatic layer. Most users call `ScannerService` and `CleanupPlanner`; advanced users opt into clearly marked lower-level modules.

3. **Thin wrapper around pdu plus utility delete helpers**
   🎯 2 🛡️ 3 🧠 3, roughly 300-900 LOC.
   Avoid. It is easy to ship but would let downstream users create unsafe workflows that look endorsed by our library.

Kill criteria:

- `fs_usage_*` exposes `delete_path(path)` as a convenience;
- external code can construct `ValidatedDeletePlan` directly;
- public node ids are documented as persistent across scans;
- pdu types appear in stable public contracts;
- examples show cleanup without preflight, authority evidence, or receipt.

### DTO And Domain Binding Must Be Allowlisted

The same mass-assignment pattern that breaks web APIs can break our local daemon and reusable library if external JSON, Flutter DTOs, or plugin outputs bind directly into domain structs.

Rules:

- protocol DTOs, bridge DTOs, persistence rows, and domain models remain separate;
- external inputs map through allowlisted command structs;
- sensitive domain fields such as `authority_ref`, `policy_decision_ref`, `risk_tier`, `trusted_rule_source`, `delete_allowed`, and `blast_radius_budget` are never client-settable;
- unknown fields are rejected for commands and tolerated only for forward-compatible event/data reads where policy allows;
- generated clients cannot create trusted domain objects;
- plugin/rule outputs are advisory facts until accepted by an application service;
- tests fuzz extra fields and privilege-looking field names.

Kill criteria:

- JSON input can set `isTrusted`, `deleteAllowed`, `riskTier`, or `authorityRef`;
- Flutter DTO converts directly into `DeletePlan`;
- plugin output becomes cleanup policy without application-service review;
- unknown command fields are silently accepted;
- persistence row is reused as public API payload.

### Tenant And Embedding Boundaries

Even if Clean Disk is single-user local-first, the library will be embedded elsewhere. Public contracts must not assume one user, one machine, one daemon, one global config, or one process.

Embedding contexts:

```text
single-user desktop app
local CLI
developer tool
remote agent
multi-tenant web service
enterprise admin scanner
CI cleanup job
container sidecar
backup or inventory service
```

Rules:

- every session has explicit owner context supplied by the embedding app;
- no global mutable defaults for traversal policy, delete policy, telemetry, or authority;
- caches are namespaced by tenant/session/snapshot and default to in-memory unless configured;
- callbacks cannot observe other sessions' raw paths or events;
- resource budgets are per session plus process-wide;
- remote/multi-tenant embedders must provide authorization and redaction adapters;
- library docs state which guarantees are core guarantees and which are Clean Disk product policies.

Kill criteria:

- scanner uses global current user or current working directory as hidden authority;
- static cache mixes sessions from different tenants;
- callback gets raw events before redaction policy;
- one tenant's cancellation cancels another tenant's scan;
- library-level telemetry assumes Clean Disk privacy policy.

### Feature Flags Must Not Change Safety Semantics Silently

Rust feature flags are compile-time product surface. A downstream crate can enable combinations we did not test unless we constrain and document them.

Feature categories:

```text
default:
  metadata scan, read model, indexes, safe query APIs

cleanup:
  DeletePlan, preflight, Trash adapters, receipts

privileged:
  helper/authority integration contracts only, no default helper install

content:
  hashing, duplicate analysis, preview/classification contracts

remote:
  protocol DTO helpers, redaction contracts, no auth implementation

platform_native:
  OS-specific adapters behind capability probes
```

Rules:

- default features do not include delete, privileged, content parsing, or network server behavior;
- feature combinations are tested in CI;
- feature enabling cannot replace safe defaults with broader authority;
- semver policy defines which feature-gated APIs are stable;
- docs show feature risk table and required embedders' responsibilities;
- unsafe or privileged features require explicit package feature names, not transitive surprise.

Kill criteria:

- enabling `default` includes cleanup side effects;
- feature flag changes traversal semantics without visible API change;
- downstream dependency enables privileged code by accident;
- docs do not specify security impact of each feature;
- CI tests only all-features and misses minimal/default builds.

### Public Dependency And SemVer Boundary

If a public API leaks pdu, platform crates, generated DTOs, or unstable dependency types, those dependencies become our users' problem.

Rules:

- pdu remains private adapter dependency;
- public errors wrap dependency errors into our stable error taxonomy;
- public structs use private fields or `non_exhaustive` where future growth is likely;
- enums crossing protocol or public crate boundaries are non-exhaustive or include unknown variants where appropriate;
- MSRV and semver commitments are documented before first external release;
- `cargo-semver-checks` or equivalent API diffing gates public crate releases;
- release notes classify safety-affecting behavior changes separately from ordinary API changes.

Kill criteria:

- public trait requires `parallel_disk_usage::DataTree`;
- public error enum exposes foreign dependency variants exhaustively;
- new scanner semantics ship as patch release with no behavior note;
- docs imply stable 1.0-style commitments for 0.x experimental crates;
- public API cannot evolve without breaking Clean Disk and external users simultaneously.

### Documentation Examples Are Safety Tests

For a library like this, docs are not marketing. They are executable safety guidance.

Rules:

- every public example compiles and uses the safe state machine;
- destructive examples use fake adapters or temporary fixtures by default;
- examples show partial scan, skipped path, permission denial, cancellation, and stale preflight handling;
- unsafe/advanced examples are clearly separated from quick-start docs;
- docs explicitly say what the library does not guarantee: exact reclaim, secure erase, complete cloud state, or permission bypass;
- README includes threat-model boundaries for local desktop, remote service, and multi-tenant embedding.

Kill criteria:

- quick start deletes real paths;
- docs hide skip/error handling to look simpler;
- examples unwrap errors in cleanup flows;
- external users can only learn safe cleanup by reading Clean Disk app code;
- docs advertise "exact freed bytes" or "safe cleanup" without confidence qualifiers.

### Twentieth-Pass Hardest Spikes

1. **Public API misuse-resistance spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1500-3800 LOC/docs/tests.
   Prove sealed constructors, type-state transitions, no raw delete helpers, safe examples, and compile-fail tests for invalid state transitions.

2. **DTO/domain allowlist and fuzz spike**
   🎯 8 🛡️ 9 🧠 7, roughly 1000-2600 LOC/tests.
   Prove command DTOs cannot set trusted fields, unknown command fields are rejected, generated clients cannot create domain authority, and plugin outputs remain advisory.

3. **Feature/semver/public-dependency gate spike**
   🎯 8 🛡️ 8 🧠 6, roughly 800-2200 LOC/CI/docs.
   Prove default/minimal/all-feature builds, public dependency leak checks, semver API diffing, MSRV declaration, and safety-impact release notes.

## Twenty-First-Pass Low-Disk, Self-Storage, And Write-Failure Layer

This layer handles the most product-specific failure mode: users open a cleanup app when the disk is already full. The app must still scan, explain, and safely recover while its own writes can fail.

Default rule:

```text
low disk is a normal operating mode
destructive operations require durable intent before side effects
cache is expendable
journal and receipt evidence are not expendable
support export is best-effort and bounded
```

### App Storage Classes

Separate storage by safety value. Do not let cache compete with destructive recovery evidence.

```text
critical_operation_journal:
  append-only intent, dispatch, native outcome, reconciliation

critical_receipt:
  immutable user-facing outcome and recovery evidence

bounded_read_model_cache:
  scan tree cache, indexes, search helper data

transient_runtime_cache:
  query pages, progress snapshots, temporary scan buffers

diagnostic_log:
  bounded logs, traces, metrics snapshots

support_bundle:
  user-triggered redacted export

optional_content_cache:
  future thumbnails, hashes, previews, duplicate analysis
```

Rules:

- cleanup cannot start unless critical journal write and fsync/checkpoint strategy pass preflight;
- scan can run in degraded mode with reduced or no persistent cache;
- optional content cache is disabled under storage pressure;
- logs are ring-buffered and size-capped;
- support bundles stream to a chosen destination and do not require duplicating the full diagnostic set in app storage;
- read-model cache has a hard quota and eviction policy;
- app storage budget is visible in diagnostics without exposing raw private paths.

Kill criteria:

- scan cache can fill the last free space while user is trying to reclaim space;
- cleanup starts after journal preflight failed;
- logs grow unbounded during a large scan;
- support bundle creation copies the full DB/WAL into temp first;
- optional preview/hash cache remains enabled in low-disk mode.

### Durable Intent Before Side Effects

If the app cannot persist intent, it cannot safely mutate the filesystem.

Required sequence:

```text
reserve minimal journal space
write operation intent
fsync or durable-commit equivalent
validate target and authority
dispatch native side effect
write per-item outcome
write receipt or recovery marker
release emergency reserve only when safe
```

Rules:

- destructive coordinator owns an emergency storage reserve for recovery writes;
- reserve is small, fixed, and recreated after successful recovery;
- if final receipt cannot be written, journal stores `receipt_pending` and UI enters recovery mode;
- per-item outcome is written incrementally, not only at batch end;
- native dispatch pauses if journal becomes unwritable mid-batch;
- unknown outcome remains explicit until reconciled.

Kill criteria:

- native delete/move happens before durable intent;
- final outcome exists only in memory;
- batch writes one receipt after 10,000 side effects;
- journal reserve is consumed by ordinary cache/log writes;
- app reports success when receipt write failed.

### Capacity Evidence Is Volume-Scoped And Quota-Aware

Available space is not one global number.

Rules:

- capacity probe is per relevant volume: target volume, app data volume, Trash volume, export destination volume;
- use caller-available capacity where platform exposes quota-aware values;
- UI distinguishes "system free", "available to this user/process", and "estimated reclaim";
- capacity evidence has volume identity, observed time, authority class, and confidence;
- APFS purgeable/opportunistic capacity is not treated like guaranteed writable space;
- browser/web storage quota is separate from daemon/app data capacity.

Kill criteria:

- app checks free space on target volume but writes journal to a full app-data volume;
- APFS purgeable space is used as guaranteed journal capacity;
- Windows quota-aware available bytes are ignored;
- Linux `f_bfree` is used where caller-available `f_bavail` matters;
- web UI stores critical state in best-effort browser storage.

### SQLite, WAL, And Cache Under Disk Pressure

SQLite can fail writes even if reads still work. WAL can also create backup and support-bundle surprises.

Rules:

- typed DB errors distinguish full disk, quota, read-only, busy, corruption, and IO error;
- journal tables are prioritized over cache tables;
- cache writes are allowed to fail without aborting scan if read-model can continue in memory;
- destructive journal writes are not allowed to fail open;
- WAL/checkpoint policy is part of low-disk mode;
- DB backup/support export uses SQLite online backup or a safe equivalent, not raw main-file copy while WAL is active;
- migration refuses destructive feature enablement if DB cannot write safely.

Kill criteria:

- `SQLITE_FULL` is collapsed into generic app failure;
- WAL grows without quota during scan;
- cache insert failure aborts cleanup recovery;
- support bundle copies main DB without WAL awareness;
- DB migration runs while critical journal is unreconciled and disk is low.

### Trash And Reclaim Under Low Space

Moving to Trash usually does not immediately free bytes. It can also require metadata writes or cross-volume copies.

Rules:

- Move to Trash is not presented as immediate reclaim unless observed free-space delta proves it;
- same-volume Trash move may increase neither free space nor available capacity;
- cross-volume Trash can require additional temporary space and can fail mid-operation;
- FreeDesktop Trash needs metadata/info writes and name-collision handling;
- Windows Recycle Bin can be unavailable, corrupted, quota-limited, disabled, or unsuitable for very large items;
- low-space cleanup UI should explain "moved to Trash" versus "space available after emptying Trash";
- permanent delete remains separate from MVP unless explicitly revisited.

Kill criteria:

- UI counts Trash move as freed space immediately;
- app tries cross-volume Trash without capacity preflight;
- FreeDesktop `.trashinfo` write failure still moves payload;
- Recycle Bin failure downgrades silently to permanent delete;
- low-space mode encourages unsafe permanent delete as the default.

### Degraded Mode UX

Low-disk mode needs a clear UX, not a generic warning.

Rules:

- app exposes `Normal`, `LowDisk`, `CriticalDisk`, and `JournalUnsafe` storage states;
- `JournalUnsafe` disables destructive actions;
- low-disk scan disables optional caches and content features;
- UI shows which volume is blocking: app data, target, Trash, export destination, or browser storage;
- support export can stream directly to external/user-selected destination;
- user can purge Clean Disk's own non-critical caches from settings;
- app never asks user to delete unrelated files just to make our cache bigger.

Kill criteria:

- delete button remains enabled while journal storage is unsafe;
- warning says "low disk" without naming the affected volume;
- user cannot clear Clean Disk cache from UI;
- support export fails without offering streaming/export destination choice;
- scan appears broken when only persistent cache is disabled.

### Twenty-First-Pass Hardest Spikes

1. **Journal-safe low-disk cleanup spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC/tests.
   Prove emergency reserve, durable intent, per-item outcome, mid-batch journal-full failure, receipt-pending recovery, and no side effect when journal preflight fails.

2. **Volume-scoped capacity probe spike**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2400 LOC/tests.
   Prove app-data volume, target volume, Trash volume, export destination, APFS capacity variants, Windows quota-aware available bytes, Linux caller-available blocks, and browser quota separation.

3. **Degraded scan/cache mode spike**
   🎯 8 🛡️ 8 🧠 6, roughly 700-1800 LOC/tests.
   Prove scan continues with cache writes disabled, logs capped, WAL bounded, support export streamed, and optional content cache disabled.

## Twenty-Second-Pass Deterministic Fixture Lab, Filesystem Simulation, And Destructive-Test Containment Layer

This layer is about proof quality. A weak test suite can make every previous architecture decision look safer than it is.

Core rule:

```text
test result is not enough
test truth level must be explicit
destructive tests need physical containment
synthetic fixtures prove scale, not platform semantics
golden artifacts prove contracts only when they include semantic evidence
```

### Fixture Truth Levels

Every fixture must declare what kind of truth it can prove.

```text
FixtureTruthLevel:
  pure_model_fixture
  protocol_fixture
  synthetic_tree_fixture
  temp_dir_real_fs_fixture
  platform_capability_fixture
  mounted_volume_fixture
  destructive_os_fixture
  external_provider_fixture
  mocked_adapter_fixture
  golden_artifact_fixture
```

Rules:

- `pure_model_fixture` can prove state machines, invariants, and DTO rules, but not filesystem semantics;
- `synthetic_tree_fixture` can prove memory, pagination, index, sorting, and query scale, but not Trash, permissions, clones, placeholders, or mount behavior;
- `temp_dir_real_fs_fixture` can prove ordinary filesystem calls under a disposable root, but not provider-managed cloud files, enterprise policy, VSS, snapshots, or real Trash edge cases;
- `platform_capability_fixture` must record OS, filesystem type, volume identity, case sensitivity, Unicode behavior, symlink support, hardlink support, clone/reflink support, sparse support, and privilege state;
- `mounted_volume_fixture` is required before claiming mount-boundary, cross-volume Trash, quota, or volume-capacity behavior;
- `destructive_os_fixture` is required before enabling cleanup beta on an OS;
- `external_provider_fixture` is required before claiming iCloud, OneDrive, Dropbox, SMB, NAS, rclone, FUSE, or enterprise-managed behavior;
- `mocked_adapter_fixture` can test decision logic only, never platform truth;
- every release claim maps to the minimum acceptable fixture truth level.

Kill criteria:

- unit tests over fake trees are used to justify delete safety;
- temp directory tests are used to claim APFS, NTFS, Btrfs, ZFS, network share, or cloud-provider semantics;
- a mocked Trash adapter is counted as a platform Trash pass;
- benchmark fixtures are not labeled with filesystem type, cache state, node count, and generation method;
- failed capability fixtures are skipped without a typed reason.

### Destructive Tests Need Physical Containment

Cleanup tests cannot rely on developer caution. They need a containment protocol that the test harness enforces.

```text
DestructiveTestScope:
  test_run_id
  fixture_root
  sentinel_file
  allowed_device_or_volume
  allowed_mount_id
  max_bytes
  max_items
  max_depth
  allowed_operations
  operation_id
  preserve_on_failure
  cleanup_mode
```

Rules:

- destructive adapters refuse to run unless `fixture_root` contains a sentinel created by the current test run;
- destructive tests never target `HOME`, `Downloads`, `Documents`, `Desktop`, `Library`, `/`, drive roots, user profile roots, or shared team folders;
- test root identity is checked before every destructive operation, not only at setup;
- max bytes, max item count, max depth, and allowed operations are enforced by the harness and by the adapter;
- Trash tests preserve the fixture on unexpected outcome when possible;
- permanent-delete tests require a separate profile, separate environment flag, and a fixture root that is impossible to confuse with user data;
- failed destructive tests write a redacted manifest with operation ID, fixture truth level, platform capability facts, and observed outcomes;
- CI cannot run destructive profiles unless the runner image declares the required platform capability manifest.

Kill criteria:

- any test calls raw `remove_file`, `remove_dir_all`, `unlink`, `DeleteFile`, or shell `rm` outside a dedicated cleanup adapter;
- fixture root can be configured by arbitrary user-provided path without sentinel and denylist checks;
- destructive tests run by default in local `cargo test` or Flutter widget tests;
- cleanup test failures delete their evidence before diagnosis;
- a retry can perform a second destructive side effect instead of returning a stored operation result.

### Synthetic Fixtures Are Not Semantic Proof

Synthetic trees are still essential. They are just not evidence for every claim.

Good uses:

- 100k, 1M, and 5M node memory/index/query tests;
- wide-directory pagination and cursor stability;
- deep-tree recursion and stack safety;
- string interning and path-segment deduplication;
- top files, top folders, sort, filter, and search benchmarks;
- protocol batch size, compression, reconnect, and UI virtualization tests.

Bad uses:

- proving "safe to delete";
- proving "space will be freed";
- proving cloud placeholder behavior;
- proving platform Trash behavior;
- proving protected folder permission behavior;
- proving symlink, junction, reparse, or mount boundary semantics without real platform fixtures.

Kill criteria:

- synthetic fixture benchmark passes and product copy says "safe cleanup";
- large generated files are used to infer sparse/compressed/reflink accounting;
- web UI golden tests are treated as proof that selected row identity is safe for delete;
- search fixture with ASCII paths is used to claim Unicode/case correctness.

### Fixture Capability Matrix

The fixture lab needs an explicit matrix. Unknown is a first-class result, not a pass.

```text
FixtureCapability:
  hardlink
  file_symlink
  directory_symlink
  dangling_symlink
  junction_or_reparse_point
  mount_boundary
  permission_denied
  access_granted_after_permission_change
  locked_or_open_file
  case_collision
  unicode_normalization_variant
  reserved_windows_name
  long_path
  alternate_data_stream
  sparse_file
  compressed_file
  clone_or_reflink
  snapshot_or_shadow_copy
  dedupe_or_shared_extent
  quota_limited_volume
  trash_disabled_or_unavailable
  cross_volume_trash
  cloud_placeholder
  network_share
  removable_volume
  fuse_or_virtual_filesystem
```

Rules:

- each capability has `supported`, `unsupported`, `requires_privilege`, `requires_manual_runner`, `blocked_by_policy`, or `not_tested` status;
- feature flags cannot enable user-facing claims when required capabilities are `not_tested`;
- unknown capability status disables exact/safe wording and downgrades recommendation confidence;
- capability fixtures print structured evidence, not only logs;
- fixture output is stable enough for semantic diffing across dependency upgrades;
- fixture generation code is versioned and reviewed like product code.

Kill criteria:

- missing capability fixture silently falls back to generic pass;
- Windows symlink test passes only because Developer Mode was enabled, but capability manifest does not record that;
- macOS APFS clone test runs on a non-APFS volume and still counts;
- Linux reflink test runs on ext4 without shared extents and still counts;
- network share tests are mixed with local disk tests without separate claim scope.

### Golden Artifacts Must Be Semantic, Not Screenshot-Only

Golden files are useful, but screenshots alone are too weak for this product.

Required artifact types:

```text
protocol_golden:
  request, response, event envelope, version, schema fingerprint

semantic_scan_golden:
  fixture manifest, scanner options, node totals, skip reasons, hardlink policy, warnings

delete_plan_golden:
  target IDs, identity evidence, risk flags, confirmation fields, disabled reasons

ui_golden:
  screenshot, theme, viewport, font config, locale, text scale, semantic state hash

receipt_golden:
  operation ID, item outcomes, confidence, observed deltas, recovery markers
```

Rules:

- UI screenshots are paired with semantic state hashes for destructive controls;
- golden snapshots redact machine-specific paths and user names while preserving identity relationships;
- protocol goldens include unknown-field and future-enum fixtures;
- scan goldens include skip/error/warning cases, not only happy path;
- golden updates require reviewer intent, not auto-generated churn;
- visual goldens are split by platform or font environment where needed.

Kill criteria:

- screenshot looks correct while destructive button is enabled with missing semantic warning;
- golden update accepts changed scanner totals without explaining the semantic diff;
- golden files contain raw private paths from a developer machine;
- old protocol fixture is deleted instead of kept for compatibility testing;
- UI golden fails randomly because font/platform setup is uncontrolled.

### Failure Preservation And Replay

The fixture lab should preserve evidence without creating privacy or storage risk.

Rules:

- failed destructive fixtures are preserved only under dedicated test artifact roots;
- preserved artifacts have retention limits and redaction;
- replay starts from a manifest, not from the original absolute path;
- replay can run in `mocked_adapter_fixture` mode for decision logic and in `destructive_os_fixture` mode only with explicit opt-in;
- fuzz and property failures persist minimized seeds and generated fixture manifests;
- concurrency failures store schedule/model parameters where the tool supports it;
- failure manifests include dependency versions and platform facts.

Kill criteria:

- failed fixture evidence requires raw developer path to reproduce;
- replay accidentally targets the original real path;
- fuzz failure is lost after CI cleanup;
- destructive failure artifact is too private to attach to a bug report;
- reproduced failure changes behavior because fixture generator version is not pinned.

### CI Profiles And Release Gates

One test command cannot safely cover this product.

```text
TestProfile:
  fast
  contract
  platform
  destructive
  performance
  fuzz
  concurrency
  ui_golden
  release_gate
```

Recommended split:

- `fast` runs by default locally: unit tests, pure model tests, DTO tests, small synthetic fixtures;
- `contract` runs protocol, schema, event ordering, and compatibility goldens;
- `platform` runs real filesystem capability fixtures without destructive cleanup;
- `destructive` runs disposable Trash/delete fixtures behind explicit runner capability and sentinel checks;
- `performance` runs large synthetic and real-world benchmark fixtures with cold/warm-cache labels;
- `fuzz` targets small deterministic boundaries: DTO parser, path redaction, query parser, cursor codec, policy rules;
- `concurrency` uses deterministic model tests for bounded queues, cancellation, operation journal ordering, and event fanout where practical;
- `ui_golden` runs reference states for wide and compact layouts with fixed fonts and semantic state hashes;
- `release_gate` combines the evidence matrix and blocks release if required claim evidence is stale or missing.

Kill criteria:

- all tests are one undifferentiated CI job;
- flaky destructive tests are retried until green without preserving the first failure;
- benchmark jobs compare different fixture shapes across commits;
- release gate cannot explain which evidence is missing for a feature;
- local default test command can delete anything outside a disposable fixture root.

### Twenty-Second-Pass Hardest Spikes

1. **Fixture truth-level and capability matrix spike**
   🎯 9 🛡️ 10 🧠 7, roughly 1200-3000 LOC/docs/tests.
   Prove typed fixture levels, platform capability manifests, semantic diff output, claim-to-fixture mapping, and release blocking when required evidence is missing.

2. **Destructive-test containment harness spike**
   🎯 9 🛡️ 10 🧠 8, roughly 1000-2600 LOC/tests.
   Prove sentinel roots, denylisted user paths, volume/mount checks, item and byte budgets, preserve-on-failure behavior, and idempotent retry behavior for destructive tests.

3. **Cross-platform semantic fixture corpus spike**
   🎯 7 🛡️ 9 🧠 9, roughly 2000-6000 LOC/CI.
   Build fixtures for symlinks, hardlinks, permissions, long paths, Unicode/case behavior, sparse/compressed files, clone/reflink where available, Trash variants, cloud placeholders, network shares, and removable volumes.

## Twenty-Third-Pass Hostile Names, Display Spoofing, And Export Injection Layer

This layer treats filenames, folder names, volume labels, provider labels, tool names, and user-entered target labels as hostile text. They are not code, but they can still mislead users, forge logs, corrupt exports, break layout, or make confirmation screens point at the wrong-looking target.

Default rule:

```text
native name is authority evidence only inside platform adapters
display name is untrusted UI text
every output context needs its own encoder
destructive confirmation uses stable identity plus sanitized display
logs and exports never receive raw names by default
```

### Hostile Text Classes

Names can be problematic even when the filesystem accepts them.

```text
control_chars:
  newline, carriage return, tab, null-like display, invisible separators

bidi_controls:
  right-to-left override, isolate controls, embedding controls, pop direction markers

confusables:
  visually similar Unicode characters, mixed script names, homoglyph names

layout_stress:
  extremely long segments, no-break text, combining marks, zero-width chars

format_injection:
  CSV formulas, Markdown control text, terminal escape-like text, log delimiter injection

path_illusion:
  names containing slash-like glyphs, backslash-like glyphs, drive-like prefixes, parent-dir-looking text
```

Rules:

- every displayed name has `display_safety_flags`;
- UI can show original-looking text, but must mark suspicious display states;
- destructive confirmation includes stable path breadcrumbs and identity evidence, not just final display name;
- lossy/sanitized display is visually marked where it matters;
- copy-to-clipboard can offer "display path" and "native path/export-safe path" as separate actions;
- search matches user-visible display text but results carry safety flags.

Kill criteria:

- a name with newline creates two apparent rows;
- a bidi control makes `safe.txt` appear as another extension or parent path;
- support logs contain raw CRLF-delimited names;
- CSV export opens with formulas executable by spreadsheet software;
- confirmation modal displays only final filename without parent/identity context.

### Context-Specific Encoding

There is no universal "sanitize filename" function.

Required encoders:

```text
table_cell_display
tree_breadcrumb_display
tooltip_display
confirmation_display
screen_reader_label
clipboard_plain_text
log_field
json_support_bundle
csv_cell
markdown_report
terminal_text
html_text
test_snapshot_text
```

Rules:

- UI display escaping is separate from logging escaping;
- CSV export neutralizes formula-leading cells and preserves clear user-visible warnings;
- logs use structured fields and neutralize CR/LF/delimiters;
- markdown/report export escapes markdown-significant text or stores names as code/data fields;
- terminal output strips or escapes control/escape sequences;
- screen-reader labels avoid misleading hidden control characters;
- all encoders have fixture tests from the same hostile-name corpus.

Kill criteria:

- one sanitizer is reused for HTML, CSV, logs, and terminal;
- raw display name is interpolated into markdown support report;
- structured log viewer can be tricked into showing forged rows;
- tooltip reveals raw path while cell is redacted/sanitized;
- screen reader announces a different effective name than visual UI.

### Bidi, Confusables, And Visual Ambiguity

Unicode support is required. Blocking non-ASCII is not acceptable. But ambiguous display needs flags and UX.

Rules:

- detect bidi controls and mixed-direction names;
- preserve legitimate RTL/LTR text with isolation in UI;
- mark names containing explicit bidi controls in high-risk contexts;
- detect mixed-script/confusable patterns as warning evidence, not automatic rejection;
- never normalize native identity for display convenience;
- duplicate-looking sibling names get disambiguators based on stable parent/identity evidence;
- path breadcrumbs render each segment independently with direction isolation.

Kill criteria:

- legitimate Arabic/Hebrew names are blocked or mangled;
- explicit bidi control characters are invisible in destructive confirmation;
- path breadcrumb direction lets one segment visually reorder adjacent separators;
- two visually confusable siblings collapse in UI search/result list;
- normalization changes the target used by DeletePlan.

### Export And Support Bundle Injection

Support bundles and exports are often opened in tools that interpret text: spreadsheets, terminals, markdown viewers, log viewers, browsers, or AI assistants.

Rules:

- CSV cells are formula-safe by default;
- support bundles prefer JSON with typed fields over free-form text;
- markdown summaries treat names as escaped data, not markdown syntax;
- redacted exports still preserve stable local correlation ids;
- raw-name export is explicit, previewed, and labeled unsafe for sharing;
- support tools verify redaction policy before opening or rendering bundle content;
- generated filenames for exported artifacts do not include raw target names by default.

Kill criteria:

- exported CSV has cells beginning with formula-trigger characters from raw names;
- support bundle includes raw path in generated filename;
- markdown report turns a filename into link/image/code block syntax;
- redaction is applied to table but not to metadata or chart labels;
- raw export can be triggered from automated support workflow without user approval.

### Hostile Names In Destructive UX

The highest-risk context is confirmation and delete queue display.

Rules:

- delete queue row uses stable node id, parent breadcrumb, size, type, and identity evidence;
- suspicious display flags are visible in queue and confirmation;
- confirmation summarises count and parent roots, not just visible row text;
- long names cannot push warnings or buttons off-screen;
- row actions are bound to identity refs, not visible row order or text;
- compact layout must preserve suspicious-name warnings.

Kill criteria:

- a long hostile name hides Move to Trash warnings;
- a newline name creates fake extra queued item;
- user confirms a visually spoofed path with no parent context;
- suspicious display warning appears only in details panel, not confirmation;
- queue removal uses visible name instead of queued item id.

### Twenty-Third-Pass Hardest Spikes

1. **Hostile-name display corpus and encoder matrix spike**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2400 LOC/tests.
   Prove newline, CRLF, tab, bidi, mixed-script, long segment, zero-width, combining mark, slash-like glyph, formula-leading, markdown, and terminal-like cases across every output context.

2. **Destructive confirmation spoof-resistance spike**
   🎯 8 🛡️ 10 🧠 7, roughly 800-2200 LOC/tests.
   Prove delete queue, compact confirmation, breadcrumbs, screen-reader labels, row actions, and suspicious display warnings under hostile names.

3. **Export/support injection safety spike**
   🎯 8 🛡️ 9 🧠 6, roughly 700-1800 LOC/tests.
   Prove CSV formula neutralization, markdown escaping, structured logs, redacted bundle metadata, generated export filenames, and raw-export consent.

## Twenty-Fourth-Pass Memory Pressure, OOM, And Bounded Representation Layer

This layer treats memory as a hard product boundary. A fast scanner can still produce an unusable product if mapping, indexing, sorting, protocol buffering, support export, or Flutter rendering grows until the daemon or UI is killed.

Default rule:

```text
large scans must hit typed resource limits before process OOM
Rust read model owns the full tree, Flutter never does
indexes are optional and bounded
event queues are bounded
cache is evictable
destructive recovery data is not evictable
```

### Memory Classes

Separate memory by safety and rebuild cost.

```text
critical_recovery_state:
  operation coordinator, journal writer state, in-flight destructive receipts

active_scan_state:
  scanner traversal state, pdu tree adapter state, metadata enrichment queues

read_model_arena:
  node arena, parent/child links, compact names, size facts

derived_indexes:
  search index, sort cache, top lists, filters, recommendation helper data

protocol_buffers:
  event queues, query responses, WebSocket fanout, snapshot serialization buffers

flutter_view_state:
  visible rows, selected node, queue state, details panel, charts

diagnostic_export_buffers:
  support bundle, logs, metrics snapshots, fixture dumps
```

Rules:

- every class has a budget, owner, eviction policy, and failure mode;
- critical recovery state is tiny and reserved;
- indexes degrade before node arena is discarded;
- query responses are page-sized and streaming where possible;
- support export streams and never materializes full tree JSON in memory;
- Flutter stores view windows and ids, not complete tree objects;
- memory budget breach returns typed `resource_exhausted` with partial scan evidence.

Kill criteria:

- support export builds full JSON tree in memory;
- WebSocket fanout buffers all events for a slow client;
- search index is required for basic tree navigation;
- Flutter receives all nodes for sorting/filtering;
- memory budget breach becomes process abort or generic crash.

### Fallible Allocation Boundaries

Rust helps, but ordinary allocation can still abort or panic depending on path and allocator behavior. Product-critical growth points need explicit fallible reservation and budget checks.

Required guarded allocations:

```text
node arena growth
child vector growth
path/name interning tables
hash maps for node lookup
sort result pages
search index segments
top-N heaps
event queues
serialization buffers
support export chunks
```

Rules:

- large vectors/maps use `try_reserve` or preflight budget accounting before growth;
- node count, byte budget, child-count budget, and index-budget limits are explicit scan settings;
- fallible allocation maps to typed `MemoryLimitExceeded` or `ResourceExhausted`;
- unsafe "reserve huge and hope" code is forbidden in scanner/read-model/indexer;
- allocation failures in non-critical indexes disable the index and keep the snapshot navigable;
- allocation failures in recovery/journal code enter recovery mode, not cleanup continuation.

Kill criteria:

- `Vec::reserve` is used in unbounded read-model growth path;
- one huge directory allocates direct-child list without limit;
- `collect::<Vec<_>>()` appears on unbounded query results;
- JSON serialization allocates one full response string for large exports;
- failed index allocation invalidates DeletePlan recovery state.

### Partial Snapshot Under Memory Pressure

Out of memory should not mean "no data". The app can return a partial but honest snapshot.

Snapshot states:

```text
complete:
  all reachable entries processed within budgets

partial_budget_limited:
  scan stopped or pruned because node, memory, time, or index budget was reached

partial_index_limited:
  tree exists but search/sort/top indexes are incomplete or disabled

partial_metadata_limited:
  size tree exists but details/enrichment were skipped or sampled

aborted_resource_exhausted:
  scan stopped before useful snapshot, but summary evidence and diagnostics remain
```

Rules:

- partial state is first-class in protocol and UI;
- cleanup is disabled or narrowed for incomplete subtrees;
- details panel shows which budgets were hit;
- search/top results show index completeness;
- recommendation engine cannot treat budget-pruned areas as absent;
- support bundle records budget and peak memory evidence.

Kill criteria:

- budget-limited scan is displayed as complete;
- missing nodes are counted as zero size;
- recommendation says "safe cleanup" from partial index;
- cleanup candidate points into a pruned subtree without live preflight;
- UI hides budget errors in a generic warning icon.

### Backpressure Is A Memory Feature

Protocol backpressure is not just network correctness. It is memory safety.

Rules:

- WebSocket event streams use bounded queues;
- slow clients get coalesced progress, lag markers, or reconnect-required state;
- scan progress events are sampled/coalesced before allocation-heavy fanout;
- query endpoints have page limits and response-size limits;
- expensive sort/filter/search queries have cancellable budgets;
- multiple clients share snapshot references but not unbounded per-client buffers;
- event replay uses sequence windows, not infinite history.

Kill criteria:

- every file entry creates a WebSocket event;
- slow browser tab keeps daemon events forever;
- query `limit` can request millions of rows;
- sort/filter materializes full result for each client;
- reconnect replay buffers from scan start for every session.

### Flutter Heap And Render Memory

The frontend can OOM independently from Rust.

Rules:

- Flutter receives paged rows and stable ids only;
- tree expansion state is compact and bounded;
- charts/details use aggregates, not child lists;
- delete queue stores selected target refs and summaries, not full node DTOs;
- row widgets are virtualized and disposed;
- large image/preview/content caches are disabled for MVP;
- DevTools memory profiling is a release gate for large synthetic and real scans.

Kill criteria:

- Flutter repository caches full scan tree;
- expanded tree state stores all descendant DTOs;
- details donut chart fetches every child row for large folders;
- compact layout duplicates wide layout state objects;
- navigation away leaves scan stream subscriptions alive.

### Memory Pressure Signals And Degradation

Platform memory-pressure signals are useful hints, not correctness guarantees.

Rules:

- macOS memory pressure, Windows memory resource notifications, and Linux PSI/cgroup hints feed a `MemoryPressureState`;
- pressure state can pause metadata enrichment, disable optional indexes, lower event rate, and evict caches;
- pressure state cannot skip durable journal writes required for destructive safety;
- pressure state is included in benchmark/support evidence;
- absence of platform signal does not mean memory is safe;
- memory budgets remain enforced even when no OS pressure API is available.

Kill criteria:

- app waits for OS pressure signal before enforcing budgets;
- pressure signal drops operation journal state;
- Linux PSI unavailable disables memory limits;
- pressure downgrade is invisible to UI;
- benchmark ignores memory-pressure state.

### Twenty-Fourth-Pass Hardest Spikes

1. **Bounded read-model arena and fallible allocation spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1500-4200 LOC/tests.
   Prove node arena budgets, child-list limits, `try_reserve` growth, partial snapshot states, huge-directory behavior, and no process OOM for synthetic 1M/5M fixtures within configured limits.

2. **Protocol/UI memory backpressure spike**
   🎯 8 🛡️ 9 🧠 7, roughly 1000-2800 LOC/tests.
   Prove slow WebSocket client, huge query limit rejection, page-size enforcement, coalesced progress, Flutter virtualized rows, and no full-tree DTO retention.

3. **Memory-pressure degradation spike**
   🎯 7 🛡️ 8 🧠 8, roughly 900-2600 LOC/tests.
   Prove macOS/Windows/Linux pressure adapter behavior where available, optional index eviction, metadata pause, support evidence, and fallback budgets when pressure APIs are unavailable.

## Twenty-Fifth-Pass Watcher Freshness, Incremental Rescan, And Stale-UI Invalidation Layer

This layer handles a tempting future feature: live updates after the first scan. Filesystem watchers are useful, but they are not an authoritative change log. They can coalesce, drop, reorder, miss, delay, or represent changes differently per platform and filesystem.

Core rule:

```text
watcher event is a hint
freshness is a lease
incremental update is a proof obligation
delete plan always revalidates from live filesystem facts
lost watcher confidence triggers rescan or stale UI
```

### Watch Events Are Invalidators, Not Truth

The safest product model is to treat watcher events as invalidation hints.

```text
WatcherEventRole:
  invalidate_subtree
  invalidate_snapshot
  refresh_visible_page
  mark_stale
  trigger_rescan
  update_progress_hint
```

Rules:

- watcher events never directly mutate authoritative size, identity, recommendation, or delete-plan facts;
- events mark nodes/subtrees/snapshots stale, then scanner/read-model workers refresh current facts;
- event payload paths are display/debug hints until revalidated through platform adapters;
- missed event signals force subtree or full-scope rescan depending on platform evidence;
- stale UI states are visible: `fresh`, `possibly_stale`, `rescan_required`, `watcher_unavailable`, `watcher_overflowed`;
- delete queue items created before watcher invalidation require revalidation before confirmation and again before side effect.

Kill criteria:

- UI updates node size directly from watcher event without stat/rescan;
- deletion remains enabled after watched parent/root was moved, deleted, or watcher overflowed;
- event path string is treated as stable identity;
- event loss is logged but UI still claims scan is fresh;
- watcher unavailable silently disables freshness tracking.

### Platform Watcher Failure Modes

Each OS has different failure semantics. The abstraction must not flatten them into "changed".

```text
WatcherFailureKind:
  coalesced_events
  kernel_dropped_events
  user_dropped_events
  queue_overflow
  root_changed
  volume_identity_changed
  event_id_invalidated
  rename_pair_incomplete
  watch_limit_exceeded
  permission_or_ownership_gap
  network_fs_no_events
  pseudo_fs_no_events
  provider_delayed_events
  backend_unavailable
```

Rules:

- macOS FSEvents `MustScanSubDirs`, dropped events, root changes, volume UUID changes, and event ID invalidation map to typed freshness loss;
- Windows buffer overflow, zero-byte notification, `ERROR_NOTIFY_ENUM_DIR`, short-name events, network buffer limits, and NTFS-only extended APIs map to typed freshness loss;
- Linux `IN_Q_OVERFLOW`, non-recursive watch gaps, watch descriptor reuse risk, racy rename pairs, network filesystem misses, pseudo-filesystem misses, and watch-limit failures map to typed freshness loss;
- cross-platform `notify` events are adapter output, not domain facts;
- PollWatcher fallback is explicitly slower and less precise, with resource budgets;
- watcher backend capability is part of scan session capability report.

Kill criteria:

- one `WatcherError` loses overflow versus permission versus network unsupported;
- inotify recursive watch setup races are ignored for newly-created subdirectories;
- FSEvents dropped events do not force rescan;
- Windows zero-byte `ReadDirectoryChanges` result is treated as "no changes";
- network share watcher mode claims live freshness without polling or rescan policy.

### Freshness Leases And Epochs

A scan snapshot is not permanently current.

```text
FreshnessLease:
  snapshot_id
  root_identity
  volume_identity
  watcher_backend
  watcher_epoch
  last_verified_at_monotonic
  last_event_sequence_or_marker
  stale_reason
  confidence
```

Rules:

- every query page includes freshness state and snapshot epoch;
- search results and top lists carry the same freshness state as their source snapshot;
- stale visible rows are marked without changing row identity;
- snapshot epoch increments on rescan, root change, volume change, watcher restart, or event-loss recovery;
- cursors include snapshot epoch and fail with `resync_required` when the epoch is no longer query-compatible;
- delete-plan creation requires a compatible freshness lease, but execution still performs live revalidation.

Kill criteria:

- stale rows visually look identical to fresh rows;
- search result from old epoch can be queued without warning;
- cursor from old snapshot returns rows from new snapshot as if continuous;
- watcher restart keeps the same epoch after possible event loss;
- freshness state is only local Flutter state and missing from daemon queries.

### Incremental Rescan Budgeting

Incremental refresh can be more expensive than full rescan if implemented badly.

Rules:

- batch event storms into bounded refresh jobs;
- prioritize visible subtree refresh over background indexes;
- collapse repeated invalidations by subtree and epoch;
- use backpressure so watcher events cannot starve scan, protocol, or cleanup workers;
- fall back to full rescan when invalidated subtree count, depth, or uncertainty exceeds thresholds;
- resource profile controls watcher refresh: background, balanced, fast;
- refresh job telemetry uses counts and reason codes, not raw paths.

Kill criteria:

- one save operation creates hundreds of unbounded refresh tasks;
- refresh storms block cancel/delete revalidation commands;
- incremental refresh consumes more IO than a full scan but still runs repeatedly;
- event queue keeps raw paths forever while waiting for refresh;
- UI thrashes expanded rows or selection during refresh.

### Watcher Integration With DeletePlan

Watcher invalidation must make destructive workflows more conservative, not more automatic.

Rules:

- if a selected node or ancestor is invalidated, delete queue marks item `requires_revalidation`;
- if root/volume identity changes, related delete plans are invalidated;
- if watcher overflow happens, cleanup for affected scope is disabled until rescan or explicit revalidation;
- if a queued item disappears, UI shows `already_gone_or_moved` and requires user review;
- if a queued item changes identity, DeletePlan blocks with identity mismatch;
- watcher events never auto-remove queued items without preserving explanation.

Kill criteria:

- watcher delete event silently removes item from queue and hides the risk;
- watcher create/rename event updates queued path without identity check;
- overflowed watcher still lets old DeletePlan execute;
- stale recommendation remains high confidence after parent subtree invalidation;
- concurrent refresh rewrites delete queue ordering while user is confirming.

### Watcher Persistence And Recovery

Persistent event APIs are useful, but they are not portable enough to be the product contract.

Rules:

- persisted watcher state is advisory and tied to volume/root identity;
- app startup validates persisted watcher markers before incremental catch-up;
- if markers are invalid, purged, wrapped, restored, or unsupported, snapshot becomes stale and needs rescan;
- watch state is not a substitute for operation journal or receipt state;
- support bundle records watcher backend, freshness transitions, event-loss counters, and rescan decisions;
- remote/headless mode can disable watchers and use scheduled rescans if runtime environment is unreliable.

Kill criteria:

- app restarts and assumes old watcher marker proves current state;
- restored Time Machine/APFS volume keeps old freshness lease;
- persistent event IDs are treated as globally comparable across volumes;
- watcher catch-up runs before checking package/version compatibility;
- support cannot explain why tree became stale.

### Twenty-Fifth-Pass Hardest Spikes

1. **Watcher freshness lease and stale-query protocol spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC/tests.
   Prove freshness states, snapshot epochs, stale rows, cursor invalidation, resync behavior, search/top-list freshness, and delete-plan invalidation.

2. **Cross-platform watcher adapter fault matrix spike**
   🎯 7 🛡️ 9 🧠 9, roughly 1600-4200 LOC/tests.
   Prove FSEvents dropped/root/volume cases, Windows overflow/zero-byte/enum-dir cases, Linux inotify overflow/rename/watch-limit cases, network/pseudo filesystem fallback, and PollWatcher capability reporting.

3. **Incremental rescan resource-budget spike**
   🎯 8 🛡️ 8 🧠 7, roughly 900-2400 LOC/tests/benchmarks.
   Prove event storm batching, visible-subtree priority, backpressure, fallback-to-full-rescan thresholds, cancellation responsiveness, and UI stability during refresh.

## Twenty-Sixth-Pass Size Units, Numeric Precision, And Rounding Truth Layer

This layer prevents a subtle but very real product failure: the scanner can be correct while the UI, protocol, export, or recommendation engine lies through unit confusion, rounding, overflow, or precision loss.

Default rule:

```text
raw byte quantities are exact typed values
display size strings are never used for decisions
unit base is explicit
rounding policy is explicit
JSON/web transports do not rely on unsafe numeric precision
percent bars are visual summaries, not accounting facts
```

### Quantity Taxonomy

Do not collapse every number into `size`.

Required quantity kinds:

```text
logical_size_bytes:
  app-visible file length or logical directory sum

allocated_size_bytes:
  local filesystem blocks allocated to the item where known

exclusive_reclaim_estimate_bytes:
  estimated bytes likely to become available after cleanup

observed_free_space_delta_bytes:
  measured change on a specific volume after operation

quota_effect_bytes:
  effect on caller-visible quota or provider quota when known

hydrated_bytes:
  cloud/provider bytes materialized locally by content work

trash_payload_bytes:
  bytes moved to Trash, not necessarily freed

skipped_unknown_bytes:
  unknown or unmeasured portion due to permissions, budget, or provider behavior
```

Rules:

- DTO field names include quantity kind and unit;
- UI labels use the same quantity taxonomy as protocol;
- recommendation rules declare which quantity kind they optimize;
- cleanup totals show estimate confidence and observed delta separately;
- unknown/skipped portions are never treated as zero;
- logical and allocated size can be shown together only with clear labels.

Kill criteria:

- field named `size` crosses a protocol boundary without unit and semantic kind;
- moved-to-Trash bytes are shown as freed bytes;
- unknown/skipped subtree size contributes zero to reclaim confidence;
- UI compares logical size from one node to allocated size from another;
- recommendation sorts by "largest cleanup" without stating quantity kind.

### Unit Base And Display Policy

MB, GB, MiB, and GiB are not interchangeable. Users also expect platform-specific conventions.

Rules:

- exact stored values are bytes;
- display formatter has explicit base: decimal 1000 or binary 1024;
- displayed unit label matches base, for example GB for decimal and GiB for binary;
- app can follow OS convention by default, but export/protocol still records base;
- settings can change display base without changing stored quantities;
- support bundles include both raw bytes and display policy;
- screenshots and docs avoid ambiguous "GB" unless the chosen base is clear.

Top 3 display policies:

1. **Exact bytes internally, OS-style display by default, explicit unit base in tooltip/details**
   🎯 8 🛡️ 9 🧠 5, roughly 400-1000 LOC.
   Best product fit. Users get familiar display, while details/export stay auditable.

2. **Always binary units GiB/MiB everywhere**
   🎯 6 🛡️ 9 🧠 4, roughly 300-800 LOC.
   Technically clean, but may look inconsistent with OS storage UI and confuse non-technical users.

3. **Always decimal GB/MB everywhere**
   🎯 6 🛡️ 8 🧠 4, roughly 300-800 LOC.
   Simpler and often matches storage vendors, but can surprise users comparing with tools that use binary units.

Kill criteria:

- same raw byte value appears as "GB" in one panel and binary-like "GB" elsewhere;
- unit setting changes export machine columns;
- displayed rounded value is persisted as source of truth;
- tooltip/details cannot explain exact bytes and unit base;
- totals compare our display to OS display without base note.

### Numeric Precision And Overflow

Disk quantities can exceed JavaScript's safe integer range in large local, NAS, enterprise, or remote/headless deployments. Aggregates, products, percentages, and indexes can overflow earlier than a single file size.

Rules:

- Rust domain uses checked arithmetic for safety-critical aggregates;
- use wider internal types such as `u128` where aggregate policies can exceed `u64`;
- never use saturating arithmetic for safety-critical totals unless the saturated state is explicit;
- protocol represents large byte quantities as strings or typed decimal wrappers when web clients are in scope;
- Dart web must not parse large counters into unsafe `Number`-backed semantics;
- SQLite storage schema documents whether value is signed 64-bit integer, text decimal, or split high/low representation;
- overflow maps to typed `quantity_overflow` or `unsupported_quantity_range`, not wraparound.

Kill criteria:

- Rust aggregate uses unchecked `+` in release mode for unbounded tree totals;
- `u64` is multiplied by block size without checked conversion;
- JSON byte field is a number used by Flutter web for exact decisions;
- overflow clamps to max and still displays as exact;
- SQLite signed integer column stores values that can exceed its range.

### Rounding, Percentages, And Sorting

Rounding is display behavior. It must not change ordering, thresholds, confirmation, or reclaim claims.

Rules:

- sort and filter use exact raw quantities, not display strings;
- displayed children may not sum exactly to displayed parent due to rounding, and UI tolerates that;
- percentages are computed from exact numerator/denominator plus completeness policy;
- percent bars are clamped for display but raw values remain available for diagnostics;
- show `< 0.1%`, `~`, or confidence markers where exact-looking values would mislead;
- destructive thresholds use raw bytes and explicit quantity kind;
- charts group tiny values into "Other" without losing exact table access.

Kill criteria:

- table sorts `9.9 GB` above `10.1 GB` because strings are sorted;
- delete budget compares rounded display values;
- percentages add to 101% and UI treats that as accounting truth;
- `0 B` is shown for a non-zero rounded-away value without `<` marker;
- chart "Other" hides a high-risk cleanup candidate.

### Cross-Node Size Invariants Are Conditional

Parent size and child sizes are not always simple arithmetic.

Reasons:

```text
hardlink policy
reflink/shared extents
snapshots
dedupe
compression
sparse files
permission-skipped children
provider placeholders
mount boundaries
partial budget-limited scan
different quantity kinds
```

Rules:

- every aggregate has `aggregate_policy`;
- hardlink/reflink/dedupe policy is visible in details/export;
- parent-child invariant tests include complete and partial cases;
- UI never assumes parent logical size equals sum of visible child displayed sizes;
- reclaim estimate does not inherit logical aggregate blindly;
- partial scans expose lower/upper/unknown bounds where feasible.

Kill criteria:

- assertion `parent == sum(children)` is used across all quantity kinds;
- hidden/skipped children make parent look smaller without partial marker;
- hardlink dedup policy changes between scan and export;
- compressed/sparse file display has no allocated/logical distinction;
- reclaim estimate is copied from logical parent size.

### Export, Localization, And Machine Columns

Exports must serve humans and machines without mixing their contracts.

Rules:

- CSV/JSON exports include exact machine columns and separate localized display columns;
- machine columns use stable locale-independent formats;
- localized decimal separators are display-only;
- unit base and quantity kind are explicit in export metadata;
- percentages have raw numerator/denominator columns when used for decisions;
- support bundles preserve exact quantities even when paths are redacted;
- generated reports state whether totals are exact, estimated, observed, partial, or unknown.

Kill criteria:

- CSV machine column contains localized `1,23 GB`;
- JSON export has only formatted size strings;
- support bundle loses exact bytes during redaction;
- report title says "freed" when data is moved-to-Trash estimate;
- locale change alters persisted values or tests.

### Twenty-Sixth-Pass Hardest Spikes

1. **Quantity type system and DTO naming spike**
   🎯 8 🛡️ 10 🧠 6, roughly 700-1800 LOC/tests.
   Prove typed quantity kinds, explicit byte units, schema checks rejecting generic `size`, and Flutter UI labels tied to quantity semantics.

2. **Web-safe numeric transport spike**
   🎯 8 🛡️ 9 🧠 6, roughly 600-1600 LOC/tests.
   Prove large counters over JSON, Dart web precision boundaries, string/decimal wrappers, SQLite storage range, and no exact decision from unsafe numbers.

3. **Rounding/display/export consistency spike**
   🎯 8 🛡️ 9 🧠 5, roughly 500-1400 LOC/tests.
   Prove decimal/binary display policy, exact sorting, percent bars, localized exports, CSV machine columns, and screenshot/tooltip explanations.

## Twenty-Seventh-Pass Process Lifecycle, Single-Instance Ownership, And Graceful Quiesce Layer

This layer treats daemon/app lifecycle as a correctness boundary. A local utility still faces app quit, web tab close, daemon restart, installer update, OS logout, shutdown, service stop, system sleep, crash, and force kill. Cleanup safety depends on what the process was doing when that happened.

Core rule:

```text
process exit is an operation input
one daemon owns one local authority scope
shutdown enters quiesce before termination
cleanup never starts during quiesce
after forced termination, journal recovery is the source of truth
```

### Lifecycle Events Are Commands

Lifecycle events must enter the same operation model as user commands.

```text
LifecycleEvent:
  client_disconnect
  app_quit_requested
  web_tab_closed
  daemon_idle_timeout
  installer_update_requested
  protocol_incompatible_client_connected
  os_sleep_or_suspend
  os_wake
  user_logout
  os_shutdown_or_restart
  service_stop
  signal_term
  signal_interrupt
  watchdog_timeout
  force_kill_or_crash
```

Rules:

- lifecycle events create typed operation events, not ad hoc booleans;
- scans can cancel, pause, or checkpoint depending on state and resource profile;
- cleanup enters a stricter state machine: no new items, finish or mark current item, persist outcome, write receipt/recovery marker if possible;
- update/restart first requests quiesce, then starts replacement only after safe terminal state or explicit recovery state;
- client disconnect never means daemon should forget destructive operation state;
- web UI reconnect queries current operation state instead of assuming its previous local state is current.

Kill criteria:

- app close kills daemon while cleanup is in an unknown native side-effect window;
- update replaces binary while old daemon owns active journal lock;
- scan cancellation and destructive quiesce use the same generic cancel path;
- browser tab close deletes operation state;
- lifecycle events are only logs and not queryable state.

### Single-Instance Ownership

Two daemons operating on the same journal, port file, cache, or cleanup scope can corrupt safety guarantees.

```text
InstanceLease:
  instance_id
  process_id
  process_start_time
  executable_identity
  user_identity
  data_dir_identity
  journal_lock_identity
  port_or_socket_identity
  token_file_identity
  protocol_version
  acquired_at_monotonic
```

Rules:

- one local daemon owns one app data directory and operation journal at a time;
- instance lease is acquired before opening HTTP/WebSocket control surface;
- stale lock detection checks process identity, start time where available, executable identity, and data directory identity;
- port/socket files and token files are bound to the active instance lease;
- old daemon and new daemon cannot both accept destructive commands;
- if ownership is ambiguous, daemon starts read-only diagnostics mode or refuses to start;
- support bundle can explain active instance, stale lock, port collision, and data-dir ownership without exposing token secrets.

Kill criteria:

- new daemon steals port while old daemon still owns cleanup journal;
- stale lock is deleted based only on PID number;
- port collision falls back to random port without updating token/origin binding;
- two app versions write the same journal schema concurrently;
- read-only support tooling accidentally acquires destructive ownership.

### Graceful Quiesce State Machine

Shutdown is not one state. It has phases and deadlines.

```text
QuiesceState:
  running
  accepting_read_only
  rejecting_new_mutations
  draining_scan_workers
  draining_protocol_clients
  finishing_current_destructive_item
  writing_recovery_marker
  ready_to_exit
  forced_exit_possible
  recovery_required_on_next_start
```

Rules:

- quiesce rejects new mutating commands immediately;
- scan workers receive cancellation token and deadline;
- blocking workers have bounded join/abandon policy;
- destructive coordinator stops between items, not in the middle of an item when avoidable;
- if native side effect is in-flight and cannot be observed before deadline, journal records `outcome_unknown_requires_reconciliation`;
- service/system stop deadlines are recorded as evidence;
- UI shows shutdown/restart state and disables destructive controls.

Kill criteria:

- shutdown waits forever for scan worker blocked on filesystem;
- forced kill after timeout leaves no recovery marker;
- destructive batch continues starting new items after service stop;
- quiesce status is hidden behind generic "closing" UI;
- shutdown path bypasses idempotency and receipt writer.

### Supervisor-Specific Contracts

The daemon may run under different supervisors. The architecture needs one internal lifecycle port with platform adapters.

```text
LifecycleSupervisor:
  app_embedded_process
  manually_launched_process
  macos_launch_agent
  macos_launch_daemon
  windows_user_process
  windows_service
  linux_user_systemd_service
  linux_system_service
  container_entrypoint
```

Rules:

- Tokio cancellation is the internal propagation mechanism, not the whole lifecycle policy;
- macOS launchd/user-agent mode expects `SIGTERM` on logout/shutdown and should not daemonize behind launchd;
- Windows service mode returns quickly from control handler and moves work to a shutdown thread/state machine;
- systemd mode treats `SIGTERM`, `TimeoutStopSec`, `FinalKillSignal`, `WatchdogSec`, and restart policy as explicit runtime constraints;
- container mode treats SIGTERM and orchestrator grace period as normal lifecycle input;
- desktop embedded mode treats app quit as a quiesce request, not immediate child kill;
- each supervisor reports capability and deadline to the operation coordinator.

Kill criteria:

- Windows service control handler performs long cleanup directly and blocks control dispatcher;
- systemd stop timeout is longer in docs than actual unit config;
- launchd job daemonizes itself and launchd thinks it exited;
- container SIGTERM is handled like Ctrl+C only in dev builds;
- supervisor deadline is unknown to destructive coordinator.

### Client Lifecycle Is Separate From Daemon Lifecycle

Flutter desktop, Flutter web, and daemon do not share the same lifetime.

Rules:

- UI closing does not imply destructive operation is gone;
- daemon exposes operation recovery state to any reconnecting compatible client;
- web tab freeze/background/reload is treated like client disconnect plus later state query;
- desktop app can request daemon shutdown only when no active unsafe operation exists or after recovery marker is durable;
- multiple clients can observe, but only coordinator owns mutating state;
- client-specific view state is disposable, daemon operation state is not.

Kill criteria:

- UI stores the only copy of delete confirmation or operation status;
- reconnect creates a duplicate cleanup operation;
- web reload loses delete queue warnings while daemon still has queued operation;
- desktop app quit kills daemon to "clean up" while journal has in-flight operation;
- old incompatible client can resume mutation after daemon update.

### Forced Termination And Recovery

Graceful shutdown is best effort. The design must assume it can fail.

Rules:

- startup always runs recovery scan for unfinished destructive operations before accepting cleanup commands;
- recovery state distinguishes `not_started`, `started_unknown`, `item_outcome_known`, `receipt_pending`, and `reconciliation_required`;
- forced termination during scan invalidates snapshot freshness but does not imply filesystem mutation;
- forced termination during cleanup requires DeletePlan/item reconciliation before new cleanup;
- crash loops enter safe mode after threshold;
- support bundle can be generated in recovery/read-only mode.

Kill criteria:

- daemon starts normally after crash with unresolved cleanup journal;
- crash loop keeps retrying destructive recovery automatically;
- scan snapshot from killed process is shown as fresh;
- update process deletes old crash/recovery evidence;
- support bundle requires the daemon to be fully healthy.

### Twenty-Seventh-Pass Hardest Spikes

1. **Single-instance lease and stale ownership spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3000 LOC/tests.
   Prove lock acquisition, stale lock detection, PID/start-time/executable checks, port/token binding, old/new daemon collision, schema mismatch, and read-only safe mode.

2. **Graceful quiesce and forced-termination recovery spike**
   🎯 8 🛡️ 10 🧠 9, roughly 1600-4200 LOC/tests.
   Prove scan cancel, blocking worker timeout, cleanup stop-between-items, in-flight unknown outcome marker, receipt-pending recovery, forced kill at each state, and startup reconciliation.

3. **Supervisor adapter deadline matrix spike**
   🎯 7 🛡️ 9 🧠 8, roughly 1000-2800 LOC/tests/docs.
   Prove app-embedded, launchd, Windows service, systemd user service, manual CLI, and container SIGTERM behavior with typed deadlines, status reporting, and safe degradation.

## Twenty-Eighth-Pass Cancellation, Pause, Abortability, And User Promise Layer

This layer separates "the user asked us to stop" from "all work is already stopped". The distinction matters because Rust async cancellation, blocking filesystem I/O, Rayon workers, native Trash operations, OS drivers, and WebSocket disconnects all have different stop semantics.

Core rule:

```text
cancel is a requested transition
abortability is capability-specific
pause is not cancel
destructive cancel never means rollback
UI shows requested, stopping, stopped, completed, or unknown outcome explicitly
```

### Cancellation Domains Must Be Separate

One generic cancellation token is too vague for this product.

```text
CancellationDomain:
  scan_traversal
  scan_metadata_enrichment
  read_model_index_build
  protocol_event_delivery
  query_execution
  search_export
  delete_plan_preflight
  native_trash_item
  cleanup_batch
  daemon_quiesce
```

Rules:

- each domain declares whether cancellation is cooperative, bounded, immediate, best-effort, or unsupported;
- scan cancellation can discard partial snapshot state unless explicitly saved as partial;
- query cancellation must not cancel the underlying scan session unless requested at session scope;
- WebSocket client disconnect cancels only client delivery work, not scanner or cleanup ownership;
- cleanup batch cancellation stops between items where possible and records current item state;
- native Trash cancellation is modeled as best-effort or unavailable unless the platform adapter proves otherwise;
- domain cancellation reason is persisted for audit and support.

Kill criteria:

- closing a web tab cancels an active scan or cleanup by accident;
- canceling a search kills the scan session;
- scan cancel and cleanup cancel use the same terminal states;
- UI has only "canceled" when the daemon is still draining workers;
- no evidence exists for who requested cancellation and at which domain.

### Blocking Worker Abortability Is Not Guaranteed

Tokio explicitly warns that started `spawn_blocking` tasks cannot be aborted. Windows I/O cancellation is also best-effort: drivers may complete normally after cancellation was requested. POSIX-style cancellation points do not make arbitrary Rust code safe to kill.

Rules:

- long scanner work runs in owned worker pools with cooperative stop checks, not unbounded `spawn_blocking`;
- each worker loop checks cancellation between filesystem calls and between batches;
- every blocking operation has a measured worst-case stop latency per platform and volume type;
- workers that cannot stop before deadline are marked abandoned or draining, never silently forgotten;
- resource budgets reserve capacity for cancellation, journal writes, and recovery even during overload;
- adapter capability reports include `cancel_latency_class` and `hard_abort_supported`;
- product copy avoids "instant stop" unless the spike proves it.

Kill criteria:

- code relies on `JoinHandle::abort` to stop a started blocking scanner task;
- shutdown waits forever for a blocked worker;
- a canceled operation continues consuming worker-pool capacity without visible status;
- cancellation success is inferred from sending a token rather than observing terminal state;
- timeout code drops state needed to reconcile late worker results.

### Pause And Resume Are Separate Product Contracts

Pause sounds simple but can mean at least three different things.

```text
PauseMode:
  throttle_to_background
  stop_scheduling_new_work
  checkpoint_and_release_workers
```

Top 3 pause contracts:

1. **Pause means stop scheduling new work and let in-flight batches drain**
   🎯 8 🛡️ 9 🧠 6, roughly 700-1800 LOC/tests.
   Best default. It is honest, bounded, and compatible with pdu-style final-tree scanning if we wrap it at the adapter/session boundary.

2. **Pause means throttle to background profile**
   🎯 7 🛡️ 8 🧠 5, roughly 500-1400 LOC/tests.
   Good UX for long scans, but users may expect no disk activity. Needs explicit label such as "Background".

3. **Pause means checkpoint and release all workers, then exact resume**
   🎯 4 🛡️ 7 🧠 9, roughly 2500-6500 LOC/tests.
   Strongest user promise, but hard with pdu final-tree behavior, changing filesystems, watcher freshness, and metadata indexes.

Rules:

- MVP should prefer "Pause Scan" only if it really stops scheduling new traversal work;
- otherwise call it "Background" or "Slow Down";
- resume creates a new epoch if snapshot freshness cannot be proven;
- pause state survives client disconnect, but not necessarily daemon restart unless checkpoint support exists;
- UI displays whether disk activity may continue while draining.

Kill criteria:

- UI says paused while workers are still walking new directories;
- resume continues from stale path identity without freshness check;
- background throttle is marketed as pause;
- pause loses skipped-path, progress, or hardlink policy state;
- pause during cleanup is allowed without per-item receipt boundaries.

### Destructive Cancellation Never Means Rollback

Move-to-Trash, shell recycle, cross-volume move, provider-managed delete, and cloud-sync propagation can cross side-effect boundaries. Cancel can stop future items, but current item outcome may already be changed or unknown.

Rules:

- DeletePlan has per-item state: `queued`, `preflighting`, `dispatching_native`, `native_inflight`, `moved_to_trash`, `failed`, `unknown_requires_reconcile`;
- cancellation only prevents new item dispatch after the current item reaches a known or unknown boundary;
- item identity is revalidated again before native dispatch if cancellation or pause delayed execution;
- receipt writer is higher priority than starting the next item;
- platform adapters report whether they can cancel native operation, observe destination, and produce resulting item URL/path;
- UI labels are "stopping cleanup" or "reconciling item", not "canceled", until outcomes are known.

Kill criteria:

- cancel button promises undo;
- current native Trash item has no post-cancel reconciliation path;
- batch cancel leaves user with total reclaim number but no per-item outcome;
- receipt is written only after the full batch, not per item;
- app starts next delete item after cancellation request is accepted.

### Protocol Cancellation Is Idempotent And Observable

HTTP commands and WebSocket events need a clear cancellation contract.

```text
CancelCommand:
  operation_id
  domain
  reason
  client_command_id
  expected_epoch
```

```text
CancelEvent:
  cancellation_requested
  cancellation_acknowledged
  stopping
  canceled_terminal
  completed_before_cancel
  cancel_failed
  outcome_unknown
```

Rules:

- cancel command is idempotent by `client_command_id`;
- stale epoch cancel returns a typed conflict instead of canceling a new operation accidentally;
- every cancellation request has an event trail visible to reconnecting clients;
- event stream distinguishes requested, acknowledged, observed stop, terminal, and unknown;
- canceling an already-completed operation returns `completed_before_cancel`;
- server owns terminal status, client only requests transition.

Kill criteria:

- WebSocket reconnect resends cancel and cancels a new scan with reused local state;
- HTTP timeout causes duplicate cancel side effects;
- UI transitions to terminal canceled before daemon emits terminal event;
- cancel event has no sequence number or operation epoch;
- stale client can cancel operation after update/migration without compatibility check.

### Testing Must Inject Slow And Stuck Boundaries

Normal local SSD tests will lie about cancellation quality.

Test fixtures:

```text
slow_read_dir_adapter
blocked_metadata_adapter
permission_flap_adapter
removable_volume_disappears_during_cancel
network_share_timeout
native_trash_hangs
native_trash_completes_after_cancel
worker_panics_after_cancel
client_disconnect_during_cancel
daemon_forced_kill_during_stopping
```

Rules:

- every cancellation domain has a deterministic fake adapter;
- tests assert maximum time to visible state change and maximum time to terminal state where guaranteed;
- tests allow explicit `draining` or `unknown` when hard stop is not guaranteed;
- late worker results after cancel are either ignored by epoch or reconciled into operation journal;
- fault-injection covers cancel-before-start, cancel-during-dispatch, cancel-after-completion, and duplicate cancel.

Kill criteria:

- tests only cover cancel on small fast local fixtures;
- cancellation timeout is not measured in CI;
- late events after cancel update the wrong scan epoch;
- fake adapters cannot simulate native completion after cancel request;
- crash recovery tests do not cover `stopping` state.

### Twenty-Eighth-Pass Hardest Spikes

1. **Scanner cancellation latency and worker drain spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1400-3600 LOC/tests.
   Prove pdu adapter stop behavior, owned worker pool boundaries, draining state, late-result epoch handling, slow filesystem fixtures, and user-visible stop latency.

2. **Cleanup cancellation and unknown-outcome reconciliation spike**
   🎯 8 🛡️ 10 🧠 9, roughly 1800-4800 LOC/tests.
   Prove stop-between-items, native Trash in-flight state, per-item receipts, cancellation after dispatch, forced kill during stopping, and startup reconciliation.

3. **Protocol cancel idempotency and reconnect spike**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2400 LOC/tests.
   Prove `CancelCommand`, operation epoch conflicts, duplicate commands, client timeout retries, WebSocket reconnect, event ordering, and terminal-state ownership by daemon.

## Twenty-Ninth-Pass Error Taxonomy, Recovery Actions, And User-Safe Diagnostics Layer

This layer prevents raw platform errors, Rust errors, HTTP errors, UI copy, support bundles, and telemetry from collapsing into one string. That collapse is dangerous: a wrong error class can enable unsafe retries, hide unsupported cleanup, leak private paths, or make support impossible.

Core rule:

```text
raw native error is evidence
domain failure is product behavior
protocol problem is transport shape
user message is localized copy
recovery action is typed and testable
logs carry codes, not private text
```

### Error Layers Must Not Collapse

The architecture needs explicit layers for failures.

```text
ErrorLayer:
  native_error_evidence
  adapter_error
  domain_failure
  application_failure
  protocol_problem
  ui_message
  support_diagnostic
  telemetry_event
```

Rules:

- adapters preserve native error evidence, but map it into stable product codes;
- domain and application logic never match on localized OS messages;
- domain errors do not depend on `HRESULT`, `GetLastError`, `NSError`, POSIX `errno`, or `std::io::ErrorKind` directly;
- protocol errors carry stable code, problem type, operation id, retryability, severity, safety impact, and privacy class;
- UI copy is selected from stable error code plus recovery action, not from raw platform text;
- support diagnostics can include redacted native evidence ids, not raw path-heavy error strings by default;
- unknown native codes map to a safe generic product code while preserving redacted evidence for support.

Kill criteria:

- UI displays raw `FormatMessage`, `localizedDescription`, or `io::Error` text by default;
- cleanup retry decision is made from a string contains check;
- platform adapter discards native domain/code and leaves only English text;
- protocol response has HTTP status but no product code or retryability;
- telemetry logs raw paths, search text, tokens, or full native messages.

### Product Error Contract

Clean Disk needs its own stable error object.

```text
CleanDiskError:
  code
  category
  severity
  retryability
  safety_impact
  affected_scope
  operation_id
  operation_epoch
  node_ref_or_path_ref
  native_evidence_ref
  recovery_actions
  privacy_class
  support_hint_id
```

Initial categories:

```text
permission_denied
privacy_grant_missing
path_not_found
identity_mismatch
stale_snapshot
watcher_overflowed
trash_unavailable
trash_partial_unknown
resource_exhausted
journal_unsafe
protocol_version_unsupported
auth_failed
rate_limited
platform_policy_blocked
cloud_placeholder
network_unavailable
volume_disappeared
unsupported_filesystem
internal_invariant_violation
unknown_platform_error
```

Rules:

- `code` is stable and documented;
- `category` groups codes for UI and support, but code remains the exact contract;
- `severity` is not the same as HTTP status;
- `safety_impact` tells whether scan, query, cleanup, or delete confirmation must be blocked;
- `affected_scope` says file, directory, subtree, volume, session, daemon, or client;
- `native_evidence_ref` points to redacted diagnostics, not directly to raw details in API responses;
- `recovery_actions` is an array because one error can support rescan, grant access, reveal in file manager, retry later, export support bundle, or contact support.

Kill criteria:

- new errors are added without code ownership and compatibility tests;
- frontend treats category as the exact decision key;
- one error says both retry and do-not-retry;
- support cannot map user screenshot/error id back to a redacted native evidence bundle;
- internal invariant errors continue normal cleanup flow.

### Retryability Is A Safety Contract

Retry is not just UX. For destructive operations, retry can repeat a native side effect.

```text
Retryability:
  never_retry
  safe_retry_same_request_id
  retry_after_revalidation
  retry_after_user_action
  retry_after_rescan
  retry_read_only_only
  support_only
```

Rules:

- destructive retry requires idempotency key, operation epoch, and recovery of previous attempt state;
- `permission_denied` usually means user action or narrower scope, not an immediate loop;
- `identity_mismatch` never retries the same DeletePlan item without rebuilding the plan;
- `stale_snapshot` points to rescan or subtree refresh, not direct cleanup continuation;
- `trash_partial_unknown` enters reconciliation before any retry;
- `resource_exhausted` may retry after changing profile, freeing app storage, or disabling optional indexes;
- read-only operations can have broader retry policy than mutating operations.

Kill criteria:

- HTTP client auto-retries a cleanup command after timeout;
- WebSocket reconnect replays a mutation without idempotency and epoch check;
- retry button is shown for identity mismatch;
- rate limit and resource exhaustion share the same user copy;
- protocol hides whether operation completed before the error was observed.

### User-Safe Messages And Recovery Actions

Native systems already have localized messages, but they are not enough for our product. They can be developer-oriented, path-heavy, inconsistent across platforms, or unsafe to parse.

```text
RecoveryAction:
  grant_full_disk_access
  choose_narrower_folder
  rescan_target
  refresh_subtree
  reveal_in_file_manager
  remove_from_delete_queue
  retry_after_closing_apps
  switch_to_background_profile
  export_support_bundle
  open_platform_settings
  run_read_only_diagnostics
```

Rules:

- user copy names what happened, why product behavior is blocked, and what action is safe;
- raw OS text can be shown only in an expanded diagnostic area after redaction and classification;
- delete/cleanup errors distinguish "not deleted", "moved to Trash", "partially moved", and "unknown, reconciling";
- warning copy never claims exact freed bytes unless observed or proven;
- accessibility labels use the same stable code and recovery action semantics;
- localization keys are tied to stable product codes, not native message strings.

Kill criteria:

- UI says "failed" for unknown cleanup outcome;
- support message tells user to retry a stale DeletePlan;
- OS message with private path is copied into notification, log, or telemetry;
- localized user copy is used as a machine-readable branch condition;
- screen reader text omits safety impact for destructive failures.

### Problem Details And Protocol Mapping

HTTP errors should use RFC 9457 style Problem Details, but the product contract still needs stable extension fields.

```json
{
  "type": "https://clean-disk.local/problems/stale-snapshot",
  "title": "Scan snapshot is stale",
  "status": 409,
  "code": "stale_snapshot",
  "operationId": "op_01",
  "operationEpoch": "7",
  "retryability": "retry_after_rescan",
  "safetyImpact": "cleanup_blocked",
  "privacyClass": "user_sensitive_redacted",
  "recoveryActions": ["rescan_target"]
}
```

Rules:

- `type` is the primary protocol problem identity;
- `code` is the product decision key used by clients;
- `title` and `detail` are advisory human-readable text and never parsed by clients;
- clients ignore unknown extension fields but fail closed on unknown safety impact for mutating operations;
- batch endpoints report the most urgent top-level problem plus per-item typed failures when useful;
- WebSocket error events use the same error object shape where practical;
- old clients map unknown codes to safe generic UI and disable mutation if safety impact is unknown.

Kill criteria:

- clients parse `detail`;
- server returns plain string errors from daemon routes;
- HTTP status is the only error contract;
- WebSocket and HTTP use different code names for the same failure;
- unknown error from newer daemon leaves old UI with enabled cleanup controls.

### Native Error Evidence Mapping

Native errors are evidence, not product logic.

```text
NativeErrorEvidence:
  platform
  subsystem
  native_domain
  native_code
  rust_io_error_kind
  syscall_or_api
  operation_context
  redacted_message
  redaction_status
  captured_at_monotonic
  correlation_id
```

Rules:

- Rust `ErrorKind` is non-exhaustive, so mappings must include wildcard/future handling;
- Windows `GetLastError` is thread-local and must be captured immediately after the failing API call;
- Windows formatted messages are diagnostic text and must be generated with safe insert handling;
- Apple `NSError` carries domain, code, userInfo, localized strings, and underlying error chain; preserve chain shape but redact path-heavy keys;
- POSIX `errno` must be captured before any call can overwrite it;
- native message text is never a stable enum;
- platform adapters own native mapping, while domain owns product failure meaning.

Kill criteria:

- native error is captured after another API call overwrote it;
- Rust match over `ErrorKind` is exhaustive in public behavior;
- `NSError` underlying chain is flattened into one string;
- Windows system message inserts are formatted unsafely;
- POSIX errno numbers from different domains are merged without subsystem context.

### Error Taxonomy Drift Control

Error codes tend to grow chaotically unless governed.

Rules:

- each product error code has owner, description, safety impact, retryability, UI copy key, support hint, and test fixture;
- adding a code requires compatibility tests for old clients and unknown-code behavior;
- removing or renaming a code is a protocol-breaking change unless aliased;
- every release reports unknown error counts in test telemetry/support fixtures;
- support bundles include taxonomy version and daemon/client protocol versions;
- boundary tests ensure domain does not import platform error types;
- schema/codegen tests ensure Dart and Rust agree on exact enum values and fallback behavior.

Kill criteria:

- broad `internal_error` absorbs common user-action cases;
- release notes cannot explain new safety-impact codes;
- old web UI enables cleanup after receiving unknown new error;
- docs list code but no recovery action;
- tests never assert localized copy exists for a new user-visible code.

### Twenty-Ninth-Pass Hardest Spikes

1. **Error taxonomy and recovery-action contract spike**
   🎯 8 🛡️ 10 🧠 7, roughly 900-2400 LOC/tests.
   Prove stable product codes, retryability, safety impact, recovery actions, localization keys, unknown-code fallback, and protocol compatibility gates.

2. **Native error evidence mapper spike**
   🎯 7 🛡️ 9 🧠 8, roughly 1200-3200 LOC/tests.
   Prove Rust `ErrorKind`, POSIX `errno`, Windows `GetLastError`/`HRESULT`, Apple `NSError`, redaction, underlying-error chains, and immediate capture semantics.

3. **Problem Details and UI diagnostics safety spike**
   🎯 8 🛡️ 9 🧠 6, roughly 700-1800 LOC/tests.
   Prove RFC 9457 envelopes, HTTP/WebSocket shared error shape, client fallback, no parsing of `detail`, redacted diagnostics, and disabled mutation on unknown safety impact.

## Thirtieth-Pass Power, Thermal, IO Priority, And Responsiveness Budget Layer

This layer treats "fast scan" as a negotiated resource policy, not an absolute goal. A scanner can be technically fast and still feel broken if it drains a laptop, spins fans, triggers OS throttling, saturates IO, makes the UI miss frames, or slows the user's foreground work.

Core rule:

```text
performance mode is a user-visible contract
OS QoS is a hint, not a guarantee
budgets are measured, not assumed
foreground responsiveness wins over raw scan throughput by default
thermal, battery, and IO pressure can downgrade scan policy at runtime
```

### Resource Profiles Need Effective Policy

The product profile selected by the user is not the same as the policy actually applied by the host OS.

```text
RequestedProfile:
  background
  balanced
  fast
  benchmark
```

```text
EffectiveResourcePolicy:
  cpu_worker_limit
  metadata_worker_limit
  max_open_handles
  io_priority_class
  os_qos_hint
  event_emit_rate_limit
  query_concurrency_limit
  cache_write_budget
  battery_policy
  thermal_policy
  foreground_interaction_policy
```

Rules:

- default profile is `balanced`;
- `fast` is opt-in and reversible during scan;
- `benchmark` is hidden or developer-only and records host power/thermal/indexing/antivirus state;
- effective policy can be lower than requested profile due to battery saver, thermal state, OS backgrounding, or host pressure;
- daemon reports requested profile and effective policy separately;
- UI displays why a scan slowed down when policy is downgraded;
- Rust core owns budgets, platform adapters only provide signals and knobs.

Kill criteria:

- profile enum exists only in UI and does not change worker limits;
- `fast` bypasses cancellation, event, journal, or UI responsiveness budgets;
- benchmark numbers are published without power/thermal/host-state evidence;
- daemon applies platform QoS silently and cannot explain active policy;
- profile switch mid-scan leaves workers with mixed untracked budgets.

### OS QoS And Priority APIs Are Hints

Apple QoS can affect CPU, IO throughput, scheduling, and timer latency. Windows EcoQoS is a process/thread hint for efficient scheduling. Linux has `ionice`, `ioprio_set`, cgroup v2, and systemd controls, but support depends on scheduler, cgroup mode, privileges, service mode, and device topology.

Rules:

- QoS adapters return `applied`, `partially_applied`, `unsupported`, or `failed`;
- unsupported priority controls degrade to internal throttling;
- Linux IO priority is applied per relevant thread where needed, not assumed process-wide;
- Linux cgroup/systemd budgets are optional host integration, not a desktop MVP dependency;
- never use realtime IO priority for this app;
- Windows EcoQoS is appropriate for background/balanced maintenance work, not user-requested immediate UI actions;
- macOS uses utility/background-style work classification for long scans and avoids user-interactive QoS for scanner workers.

Kill criteria:

- product assumes `ionice` works on every Linux filesystem/device;
- code applies EcoQoS to the UI thread while user is actively interacting;
- macOS scanner workers run as user-interactive;
- Linux thread pool creates threads after IO priority was applied only to the parent thread;
- unsupported OS priority silently falls back to unlimited work.

### Battery And Thermal State Are Runtime Inputs

Battery and thermal state can change mid-scan. On macOS, ThermalState can reach serious/critical; Low Power Mode asks apps to reduce activity. On Windows, Battery Saver and power-source notifications are explicit signals. Linux desktop signals vary by environment, so the adapter must be capability-based.

```text
PowerThermalSignal:
  on_ac_power
  on_battery
  battery_saver_enabled
  low_power_mode_enabled
  battery_percent_known
  thermal_nominal
  thermal_fair
  thermal_serious
  thermal_critical
  signal_unsupported
```

Rules:

- `thermal_serious` downgrades to background or pauses metadata-heavy enrichment;
- `thermal_critical` stops scheduling new scan work and drains safely;
- battery saver or low power mode downgrades `fast` unless user explicitly reaffirms;
- unknown battery/thermal state does not block scanning, but it weakens performance claims;
- power/thermal changes create protocol events with sequence numbers;
- UI distinguishes "slowed by system power mode" from "scan is stuck";
- support bundle records redacted power/thermal capability and state transitions.

Kill criteria:

- app keeps Fast mode unchanged under thermal critical;
- low battery warning appears after app has already exhausted battery due to hidden work;
- user sees throughput collapse but no reason;
- performance tests ignore battery saver and plugged/unplugged state;
- power-state adapter failures are logged as scanner errors instead of capability gaps.

### Responsiveness Is A First-Class Budget

For a desktop utility, "fast" must not mean "the computer feels frozen".

```text
ResponsivenessBudget:
  flutter_frame_p95_ms
  command_ack_p95_ms
  query_page_p95_ms
  cancel_visible_state_p95_ms
  foreground_io_latency_proxy
  event_loop_lag_p95_ms
  worker_queue_depth
```

Rules:

- scanner budgets reserve capacity for command handling, cancel, journal writes, and selected-node queries;
- protocol event batching must not starve query responses;
- large cache/index writes are chunked and backpressured;
- UI frame health can request daemon downgrade through a typed pressure signal;
- sustained query latency above threshold downgrades metadata enrichment before traversal;
- daemon never uses all logical cores by default;
- worker pools are split by traversal, metadata, indexing, and cleanup so one class cannot starve all others.

Kill criteria:

- scan throughput improves while search/details UI becomes unusable;
- protocol events fill queues and delay cancel command handling;
- cache writer monopolizes IO during delete receipt write;
- pdu adapter worker pool starves daemon control plane;
- benchmark reports GB/s but not UI responsiveness metrics.

### Host Activity And Co-Tenant Fairness

The user's machine is shared with Spotlight/Windows Search, antivirus, backup, sync engines, browsers, IDEs, and other users.

Rules:

- scanner watches its own throughput collapse and queue latency as pressure signals;
- optional host-state detectors classify indexing, antivirus, backup, and sync interference where available;
- background mode assumes the app is a polite co-tenant;
- remote/headless mode exposes explicit quotas and operator-selected resource caps;
- multiple clients cannot each request Fast and multiply worker counts;
- per-session budgets roll up to daemon-wide budgets;
- cleanup receipt/journal work has priority over opportunistic scan/index work.

Kill criteria:

- each browser tab or Flutter window creates its own full worker pool;
- scan keeps aggressive profile while Defender/Spotlight/backup is clearly active;
- remote API lets several users launch unlimited scans on same host;
- background scan competes with delete journal writes;
- daemon cannot explain resource sharing decisions in diagnostics.

### Benchmark Claims Must Include Host State

Disk scanning benchmark numbers are easy to mislead with warm cache, cold cache, indexing state, SSD/HDD/NAS differences, thermal state, and power mode.

Required benchmark metadata:

```text
filesystem_type
volume_kind
storage_medium
node_count
logical_bytes
allocated_bytes_known
cache_state
power_source
battery_saver_or_low_power
thermal_state
os_qos_policy
worker_counts
indexing_antivirus_backup_state
scan_profile
ui_connected
protocol_event_rate
```

Rules:

- public performance claims include profile and host-state metadata;
- benchmark harness supports cold-ish and warm-cache runs where practical;
- benchmark mode disables unrelated UI animation and records event stream cost separately;
- results separate scanner traversal time, read-model build time, metadata enrichment time, and first-useful-result time;
- mobile-laptop tests include plugged and battery modes;
- regression gates include responsiveness, not only total scan time.

Kill criteria:

- benchmark compares pdu CLI to product UI without read-model/protocol cost;
- single warm-cache SSD result becomes marketing claim;
- Fast mode benchmark runs while UI and protocol are disconnected;
- battery and thermal state are missing from benchmark artifact;
- regression gate allows faster total scan with worse cancel/query latency.

### Thirtieth-Pass Hardest Spikes

1. **Effective resource policy adapter spike**
   🎯 8 🛡️ 9 🧠 8, roughly 1400-3600 LOC/tests.
   Prove macOS QoS/thermal/low-power mapping, Windows EcoQoS/battery-saver mapping, Linux priority/cgroup capability mapping, unsupported fallback, and visible effective-policy reporting.

2. **Responsiveness budget and auto-downgrade spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC/tests.
   Prove command ACK latency, query latency, cancel visible-state latency, event-loop lag, event backpressure, cache-write chunking, and automatic downgrade under sustained pressure.

3. **Benchmark harness with host-state evidence spike**
   🎯 8 🛡️ 9 🧠 7, roughly 1000-2600 LOC/tests/docs.
   Prove benchmark metadata, cold/warm separation, UI-connected versus daemon-only cost, power/thermal/indexing/antivirus state capture, and no public claim without evidence.

## Thirty-First-Pass Observability, Support Bundle, Redaction, And Privacy Budget Layer

This layer treats diagnostics as a product feature with its own safety boundary. Clean Disk needs enough evidence to debug scanner, daemon, cleanup, protocol, permission, packaging, and platform failures. At the same time, the most useful evidence is also the most private: paths, app names, user names, mounted volumes, cloud roots, delete targets, search queries, and native error messages.

Core rule:

```text
observe operations, not private content
support evidence has schema and consent
telemetry is allowlisted before emission
redaction is typed, deterministic, and testable
logs fail safely under pressure
```

### Diagnostic Surfaces Are Separate Products

Runtime logs, metrics, traces, support bundles, crash reports, cleanup receipts, and user-visible diagnostics serve different users and need different data.

```text
DiagnosticSurface:
  local_runtime_log
  local_security_log
  local_performance_metric
  local_trace
  cleanup_receipt
  support_bundle
  crash_report
  telemetry_export
  user_visible_diagnostic
```

Rules:

- each surface has owner, audience, retention policy, privacy budget, size budget, and default on/off state;
- local runtime logs can be more detailed than telemetry export, but still cannot contain secrets or raw delete targets by default;
- support bundle is an explicit user action with preview, size estimate, privacy summary, and redaction manifest;
- cleanup receipt is user accountability, not general telemetry;
- crash reports do not automatically include scan tree, delete queue, raw paths, search text, or support bundle attachments;
- user-visible diagnostics explain recovery actions and support ids, not internal stack traces by default.

Kill criteria:

- one global logger feeds local logs, telemetry, crash reports, and support bundles without surface-specific filtering;
- support bundle is just a ZIP of logs and caches;
- crash report includes the last scanned path by default;
- cleanup receipt is uploaded as telemetry;
- user cannot inspect what will be exported.

### Field Privacy Classes Must Be Source-Level Types

Redaction should start before serialization. Regex cleanup after logging is a last line of defense, not the architecture.

```text
PrivacyClass:
  public
  operational
  user_sensitive
  secret
  destructive_target
  native_private_evidence
```

Examples:

```text
public:
  app_version
  protocol_version
  platform_family
  error_code

operational:
  operation_id
  operation_kind
  resource_profile
  aggregate_file_count_bucket
  scan_duration_bucket

user_sensitive:
  path_display_name
  volume_label
  search_query
  app_bundle_name

secret:
  daemon_token
  auth_header
  security_scoped_bookmark
  pairing_secret

destructive_target:
  delete_plan_item_ref
  trash_destination_ref
  receipt_item_identity

native_private_evidence:
  raw_hresult_message
  nserror_user_info
  errno_context_path
  shell_operation_message
```

Rules:

- every DTO field that can enter logs, telemetry, support bundles, or UI diagnostics has a privacy class;
- `secret` fields are non-serializable to logs by type, not by convention;
- `destructive_target` fields require stronger policy than ordinary user-sensitive path fields;
- raw native evidence is stored behind evidence ids and redaction policy;
- stable hashes of paths are disabled by default because low-entropy paths can be guessed;
- if correlation is needed, use per-install or per-bundle keyed identifiers with documented rotation and no cross-user sharing by default.

Kill criteria:

- path redaction depends on developers remembering to call `.redact()`;
- derived `Debug` dumps token-bearing structs;
- a field has no privacy class but appears in a support bundle;
- path hashes are treated as anonymized public data;
- redaction strips value but keeps enough hierarchy to identify the user anyway.

### Observability Schema Is Allowlist-First

OpenTelemetry is useful as a data model, not permission to emit everything. The product should define a small schema that can map to OTel logs, metrics, and traces later.

```text
ObservabilityEvent:
  event_name
  event_schema_version
  operation_id
  operation_epoch
  component
  severity
  error_code
  safety_impact
  resource_profile
  platform_family
  duration_bucket
  count_bucket
  privacy_class
```

Rules:

- metrics use low-cardinality labels only: platform family, operation type, resource profile, error code, safety impact, and coarse buckets;
- raw path, node id, session id, scan target, volume label, user id, and query text are never metric labels;
- high-cardinality details stay in local structured logs or support bundles with explicit redaction;
- attributes with security, privacy, cost, or high-cardinality risk are opt-in;
- event names are stable and versioned;
- schema tests reject unknown fields in telemetry export unless explicitly reviewed.

Kill criteria:

- metric label contains path, node id, operation id, session id, or search text;
- telemetry schema is inferred from arbitrary structured logs;
- adding a log field automatically adds telemetry;
- dashboards require raw user paths to answer operational questions;
- unsupported filesystems explode metric cardinality by raw mount name.

### Support Bundle Is A Manifested Evidence Package

Support bundle generation must be deterministic enough for tests and safe enough for users.

```text
SupportBundle:
  bundle_id
  generated_at_wall_time
  generated_at_monotonic_ref
  app_version
  daemon_version
  protocol_version
  taxonomy_version
  redaction_policy_version
  included_artifacts
  excluded_artifacts
  privacy_summary
  size_estimate
  redaction_report
  integrity_manifest
```

Artifact classes:

```text
SupportArtifact:
  operation_timeline
  redacted_runtime_log
  redacted_security_log
  error_taxonomy_snapshot
  capability_snapshot
  resource_budget_snapshot
  daemon_lifecycle_snapshot
  scan_session_summary
  delete_plan_summary_redacted
  cleanup_receipts_redacted
  protocol_compatibility_snapshot
  dependency_versions
  crash_summary
```

Rules:

- bundle creation has preview mode and explicit generate/export command;
- generated bundle includes a manifest of included, excluded, truncated, and redacted artifacts;
- logs are bounded by time window, operation id, and size cap;
- user can choose basic, diagnostics, or support-deep profile;
- support-deep profile can include more evidence only after explicit user consent;
- raw paths require a separate consent gate and should be unnecessary for most support;
- bundle writer handles low disk, partial artifact failure, and cancellation without corrupting the manifest.

Kill criteria:

- bundle silently skips failed artifacts;
- partial bundle has no manifest;
- bundle includes raw logs because redaction failed open;
- support-deep mode is default;
- export path itself leaks into later logs.

### Redaction Is A Pipeline With Failure Modes

Redaction can fail. The failure mode must be "omit or replace", not "export raw".

```text
RedactionDecision:
  keep
  bucketize
  truncate
  hash_with_local_salt
  replace_with_ref
  omit
  block_export
```

Rules:

- redaction policy is versioned and testable;
- source-level wrappers know how to produce public, support, and local-only forms;
- redaction reports count kept, bucketized, truncated, replaced, omitted, and blocked fields;
- unknown privacy class blocks export from telemetry and support bundle by default;
- native messages pass through CR/LF normalization and log-injection neutralization;
- support bundle preview shows privacy summary, not every private field;
- redaction tests include hostile Unicode names, CR/LF log injection, CSV formula strings, long paths, null-like bytes where platform allows, and native messages containing paths.

Kill criteria:

- redaction failure falls back to raw `Debug`;
- logs can contain multiline forged events from file names or OS messages;
- support bundle preview says "safe" without a redaction report;
- unknown fields are exported because serializer is permissive;
- tests cover only ASCII paths.

### Logging Failure Must Not Become Product Failure

Diagnostics must not take down scanning or cleanup.

Rules:

- log writers are bounded and backpressure-aware;
- low disk mode drops debug logs before operation journal, receipts, or recovery markers;
- telemetry export is best-effort and never blocks cleanup safety state;
- logging failures emit compact counters when possible;
- support bundle creation is read-only except for bundle output path and temp files;
- temp support bundle files are cleaned up or tracked for later cleanup;
- operation journal and cleanup receipt writes have higher priority than logs.

Kill criteria:

- scanner blocks because log collector is slow;
- daemon fills user's last free space with diagnostics;
- telemetry failure cancels scan or cleanup;
- support bundle creation modifies scan session state;
- logging error hides cleanup receipt failure.

### Incident Timeline Needs Correlation Without Private Content

When a user reports "I clicked Move to Trash and something weird happened", support needs a timeline.

```text
IncidentTimelineEvent:
  sequence
  operation_id
  operation_epoch
  command_id
  component
  state_before
  state_after
  error_code
  safety_impact
  native_evidence_ref
  receipt_ref
  wall_time
  monotonic_offset
```

Rules:

- timeline uses operation ids and evidence refs, not raw paths;
- destructive events link to redacted receipt refs;
- timeline keeps both wall time and monotonic offset;
- sequence gaps are explicit;
- client reconnect, daemon restart, quiesce, forced termination, recovery, and migration events appear in the same timeline;
- support bundle can be generated in recovery/read-only mode.

Kill criteria:

- support can see error but not the operation state transition that caused it;
- cleanup receipt cannot be correlated with error events;
- wall-clock change makes timeline impossible to read;
- forced termination loses final known state;
- recovery mode cannot generate diagnostics.

### Thirty-First-Pass Hardest Spikes

1. **Privacy-class type system and observability schema spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC/tests.
   Prove source-level privacy wrappers, telemetry allowlist, OTel-compatible event shape, low-cardinality metrics, no raw path labels, and compile/test gates for unclassified fields.

2. **Support bundle manifest and redaction pipeline spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1400-3600 LOC/tests.
   Prove preview, profiles, manifest, partial failure, redaction reports, unknown-field fail-closed behavior, hostile path/name fixtures, and low-disk partial bundle handling.

3. **Failure-safe logging and incident timeline spike**
   🎯 7 🛡️ 9 🧠 7, roughly 900-2400 LOC/tests.
   Prove bounded logging, drop policies, log injection neutralization, operation timeline correlation, receipt linking, forced termination evidence, and recovery-mode diagnostics.

## Thirty-Second-Pass Local Persistence, SQLite/Drift, Corruption Recovery, And Schema Drift Layer

This layer treats local persistence as a safety boundary, not just app storage. Clean Disk will persist session state, read-model indexes, operation journals, receipts, settings, permissions evidence, support metadata, and caches. Those records do not have equal value. A corrupt cache can be rebuilt. A corrupt cleanup journal can make destructive recovery unsafe.

Core rule:

```text
persistence is classified by safety value
SQLite files are a state bundle, not one db file
Drift schema is a contract, not a convenience
cache may be discarded
journal and receipt evidence must fail closed
database repair never invents destructive truth
```

### Persistence Classes Must Be Explicit

The database layout should reflect what can be rebuilt and what must survive.

```text
PersistenceClass:
  critical_operation_journal
  destructive_receipt
  authority_lease
  scan_snapshot_metadata
  read_model_index
  recommendation_cache
  telemetry_buffer
  support_bundle_manifest
  ephemeral_ui_state
```

Rules:

- each table belongs to one persistence class;
- critical journal, receipt, and authority lease tables have stricter write, migration, backup, and corruption policies;
- read-model indexes are rebuildable and can be dropped under corruption, migration, or low-disk pressure;
- recommendation caches carry rule version, scanner version, traversal policy, and target capability fingerprints;
- UI state never becomes the only copy of destructive intent or confirmation;
- table-level docs state whether data is source of truth, derived, cached, or disposable.

Kill criteria:

- scan cache and cleanup journal live in the same "delete and rebuild on error" bucket;
- UI restore relies on ephemeral state for delete confirmation;
- recommendation cache survives rule or scanner semantic change without invalidation;
- support bundle manifest is generated from best-effort logs instead of durable operation state;
- table purpose is known only from code comments.

### SQLite File Bundle Ownership

SQLite in WAL mode is not just `app.db`. WAL, shm, rollback journal, locks, and connection lifecycle are part of the state model.

```text
SqliteStateBundle:
  db_path
  wal_path
  shm_path
  rollback_journal_path
  sqlite_library_identity
  vfs_identity
  locking_protocol
  open_connection_owner
  schema_version
  application_id
  user_version
```

Rules:

- one daemon owns writes to the production database;
- Flutter clients do not open the daemon database directly;
- support/export tools use daemon APIs or SQLite Online Backup, not raw file copies of live DB files;
- WAL mode, checkpoint policy, busy timeout, synchronous level, and cache size are explicit config;
- database is opened through one canonical path, not sometimes symlink and sometimes real path;
- hardlinks/symlinks to DB files are rejected or normalized before opening;
- network filesystems for app data are unsupported unless a dedicated spike proves locking correctness.

Kill criteria:

- support bundle copies `app.db` while ignoring `app.db-wal`;
- second process opens same DB via different path;
- app links two different SQLite copies into the same process boundary without governance;
- update process renames or replaces DB while daemon has open connection;
- WAL mode is changed at runtime by a migration without exclusive ownership.

### Drift Schema Migrations Are Product Migrations

A SQL migration can succeed while product meaning becomes wrong. Drift gives useful tooling, but the architecture must still define compatibility policy.

```text
SchemaMigration:
  from_schema_version
  to_schema_version
  migration_id
  generated_schema_snapshot
  data_backfill_steps
  semantic_invalidation_steps
  compatibility_manifest
  destructive_feature_gate
  migration_receipt
```

Rules:

- every committed schema version has a saved schema snapshot;
- migrations are step-by-step and tested from every supported old version to current;
- generated schema verification runs in CI;
- semantic migrations explicitly invalidate affected caches and recommendations;
- destructive features stay disabled until migration, integrity check, and journal recovery pass;
- downgrade opens newer DB in read-only diagnostics mode unless an explicit tested downgrade path exists;
- migration receipts record schema version, app version, daemon version, and operation journal state.

Kill criteria:

- migration tests only start from previous version;
- generated Dart/Drift schema does not match actual runtime DB;
- failed migration leaves app half-upgraded but cleanup enabled;
- migration changes quantity semantics without invalidating cached sizes;
- older daemon writes into newer schema after rollback.

### Corruption Detection And Recovery Must Be Class-Aware

`SQLITE_CORRUPT` does not mean "wipe database and continue". Recovery depends on which persistence class is affected.

```text
PersistenceHealth:
  healthy
  busy_or_locked
  read_only
  low_space
  quick_check_failed
  integrity_check_failed
  cache_corrupt_rebuildable
  journal_corrupt_recovery_required
  receipt_corrupt_support_required
  unknown_requires_safe_mode
```

Rules:

- startup runs cheap health checks appropriate to DB size and last shutdown state;
- `quick_check` can be frequent, full `integrity_check` is scheduled or triggered by risk;
- cache corruption can quarantine and rebuild derived tables;
- journal or receipt corruption enters read-only recovery/support mode;
- recovery never fabricates missing item outcomes;
- corrupted DB artifacts are quarantined with manifest and privacy policy before replacement;
- support bundle can include redacted corruption evidence and schema metadata without raw DB export by default.

Kill criteria:

- app deletes DB on startup because open failed;
- journal corruption is treated like cache miss;
- repair code runs `VACUUM` or arbitrary rebuild over unresolved destructive journal;
- corruption state is hidden behind generic "database error";
- support asks user to send raw DB with private paths.

### Persistence Concurrency And Busy Handling

SQLite allows useful concurrency, but Clean Disk still needs one product-level writer model.

Rules:

- daemon owns all writes and exposes queries through protocol;
- long read queries are paginated and cancellable so they do not starve checkpointing or writes;
- busy/locked errors are typed and bounded, not infinite waits;
- checkpointing is scheduled away from critical receipt writes where possible;
- support backup/export runs incrementally and yields to journal writes;
- multi-window Flutter and web clients share daemon state instead of opening DB themselves;
- database access is split by purpose where useful: critical journal DB, cache DB, and optional telemetry buffer can have different durability policies.

Kill criteria:

- UI isolate opens SQLite directly for convenience;
- support export holds read lock long enough to grow WAL unbounded;
- batch cache write blocks cleanup receipt;
- busy timeout is so long that cancel and quiesce appear hung;
- one transaction mixes cache inserts and destructive receipt writes.

### Read-Model Cache Invalidation

The read model is derived. It needs strong invalidation because it feeds user decisions.

```text
CacheFingerprint:
  scanner_adapter_version
  traversal_policy_hash
  filesystem_accounting_policy
  metadata_enrichment_policy
  rule_pack_version
  privacy_schema_version
  target_identity
  volume_identity
  snapshot_epoch
```

Rules:

- cache rows include enough fingerprint data to decide whether they can be trusted;
- stale read-model data can be displayed only with stale/freshness state;
- DeletePlan never trusts cached identity without revalidation;
- cache eviction cannot remove evidence needed to explain a visible recommendation;
- query indexes can be rebuilt lazily but must not change operation journal truth;
- schema changes that affect path, size, identity, or rule semantics invalidate dependent caches.

Kill criteria:

- stale cached size drives cleanup estimate without warning;
- cache survives pdu adapter semantic change;
- cache key is only path string;
- cache eviction deletes warning evidence but leaves recommendation visible;
- old indexes silently answer new sort/filter semantics.

### Backup, Restore, And Support Export Are Different

Backup, restore, and support bundle export are often confused. They need separate commands and guarantees.

```text
PersistenceExportMode:
  online_backup_for_recovery
  redacted_support_bundle
  cache_snapshot_for_debug
  user_settings_export
  destructive_receipt_export
```

Rules:

- online backup uses SQLite Backup API, `VACUUM INTO`, or an equivalent safe DB-level mechanism;
- support bundle exports redacted artifacts, not raw DB by default;
- restore is disabled for destructive journal/receipt state unless a dedicated recovery workflow exists;
- cache snapshots are never imported as trusted source of truth;
- exported artifacts include schema version, SQLite version, Drift version, daemon version, and redaction policy version;
- raw DB export is developer/support-deep only and requires explicit consent plus warning about private paths.

Kill criteria:

- restore imports old cache and makes it fresh;
- support bundle raw-copies WAL DB;
- raw DB export is one click from normal settings;
- backup restore downgrades schema silently;
- exported receipt loses operation sequence or identity evidence.

### Persistence Fault Injection Matrix

Persistence tests must force the states normal dev machines rarely hit.

Fixtures:

```text
kill_during_schema_migration
kill_during_wal_checkpoint
kill_after_delete_intent_before_receipt
db_locked_by_old_process
wal_missing_from_backup
shm_unwritable_directory
network_filesystem_lock_failure
sqlite_busy_under_long_reader
integrity_check_failure_cache_table
integrity_check_failure_journal_table
older_schema_with_unresolved_cleanup
newer_schema_opened_by_old_daemon
low_disk_during_online_backup
```

Rules:

- tests distinguish rebuildable cache loss from destructive evidence loss;
- migration tests include data semantics, not only table shape;
- crash tests cover every destructive journal boundary;
- backup/export tests prove WAL-aware behavior;
- old/new daemon collision tests include schema and connection ownership;
- CI has fast persistence checks and slower destructive persistence chaos tests.

Kill criteria:

- persistence tests use only in-memory SQLite;
- migration test database has no realistic old data;
- no test simulates missing WAL after backup;
- support export never runs while DB has active writes;
- corruption recovery path is manual-only and untested.

### Thirty-Second-Pass Hardest Spikes

1. **SQLite/Drift persistence class and migration gate spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1400-3600 LOC/tests.
   Prove table persistence classes, Drift schema snapshots, step-by-step migrations from old versions, semantic cache invalidation, migration receipts, and destructive feature gates after migration.

2. **WAL-aware backup, support export, and corruption recovery spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC/tests.
   Prove SQLite Backup API or safe equivalent, no raw live DB copy, WAL/shm/journal handling, partial support export, cache quarantine, journal corruption safe mode, and redacted corruption diagnostics.

3. **Persistence concurrency and fault-injection spike**
   🎯 7 🛡️ 9 🧠 8, roughly 1100-3000 LOC/tests.
   Prove daemon-only writer ownership, busy handling, long-reader checkpoint pressure, UI/web multi-client behavior, kill during migration/checkpoint/journal write, and old/new daemon schema collision.

Focused split-out file for persistent operation journal and receipt durability
under low disk:
`critical-zones/persistent-operation-journal-receipt-durability-low-disk.md`.

## Thirty-Third-Pass Selection, Bulk Action, Confirmation, And Visible Intent Layer

This layer treats selection as a safety boundary. The app will have a virtualized treegrid, pagination, search, sort, filters, hidden rows, keyboard navigation, details panel, compact layout, and delete queue. In that environment, "the selected row" is not enough evidence for cleanup.

Core rule:

```text
focus is not selection
selection is not a DeletePlan
visible rows are not all affected rows
filter state is part of user intent
confirmation binds to a frozen plan, not to current UI state
```

### Focus, Selection, Queue, And Plan Are Different States

WAI-ARIA treegrid guidance separates focus from selection in multi-select grids. Our architecture should do the same.

```text
InteractionState:
  focused_cell_ref
  active_row_ref
  selected_node_refs
  visible_projection_ref
  queued_candidate_refs
  delete_plan_ref
  confirmed_plan_ref
```

Rules:

- focus movement never implies destructive selection;
- selected rows are snapshot-bound node refs, not row indexes or display paths;
- queued candidates are still not authorized for cleanup;
- DeletePlan is built server-side from selected refs, current snapshot evidence, warnings, and live revalidation policy;
- confirmation is bound to DeletePlan hash, not to selection state;
- changing selection, sort, filter, snapshot, authority, warning evidence, or resource scope invalidates confirmation.

Kill criteria:

- keyboard focus row becomes queued for deletion by accident;
- selected item identity is a visible row index;
- delete queue stores display path text as authority;
- confirmation remains valid after filter or selection changes;
- compact layout hides the distinction between selected, queued, and confirmed.

### Bulk Select Needs Explicit Scope

"Select all" is dangerous in a paginated, filtered, virtualized, hierarchical view. It can mean visible rows, current page, current filtered result, expanded subtree, entire scan target, or cleanup candidates only.

```text
SelectionScope:
  visible_rows_only
  current_page
  current_filtered_result
  current_expanded_subtree
  selected_subtree_recursive
  cleanup_candidates_matching_filter
```

Top 3 select-all policies:

1. **Visible rows only by default, explicit upgrade for filtered/all results**
   🎯 8 🛡️ 9 🧠 6, roughly 700-1800 LOC/tests.
   Best MVP safety. It is slower for power users but makes accidental bulk cleanup harder.

2. **Filtered result set by default with strong summary**
   🎯 6 🛡️ 7 🧠 7, roughly 1000-2600 LOC/tests.
   Efficient for cleanup workflows, but high risk when filters hide important context.

3. **Subtree recursive select by default**
   🎯 5 🛡️ 6 🧠 6, roughly 800-2200 LOC/tests.
   Familiar in file managers, but dangerous when collapsed children, skipped paths, and stale watchers exist.

Rules:

- every bulk selection has a `selection_scope`;
- UI text names the exact scope: visible rows, current page, filtered results, subtree, or candidates;
- hidden/skipped/stale descendants are counted separately before DeletePlan confirmation;
- recursive subtree selection requires subtree summary and warning aggregation;
- select-all across filtered results returns a server-side selection set id, not a list of all nodes in Flutter;
- selection set expires when snapshot/query/filter/sort/index version changes.

Kill criteria:

- `Ctrl+A` selects hidden filtered items without visible summary;
- selecting a collapsed folder silently selects skipped or unknown children;
- selection count ignores stale/invalidated descendants;
- Flutter materializes millions of selected node ids for "all results";
- user cannot tell whether action applies to visible rows or all filtered matches.

### Delete Queue Is Not A Visual Bookmark List

The delete queue is a staged intent surface. It must preserve why an item was queued, what evidence was visible, and what changed since queuing.

```text
QueuedCandidate:
  candidate_id
  source_selection_set_id
  node_ref
  display_summary_at_queue_time
  quantity_summary_at_queue_time
  warning_summary_at_queue_time
  recommendation_evidence_ref
  queued_at_snapshot_epoch
  current_validation_state
```

Rules:

- queue rows survive UI sort/filter changes without changing target identity;
- queue row summaries show stale, changed, missing, skipped, or requires-revalidation states;
- removing from queue is local intent removal, not filesystem undo;
- queue cannot auto-upgrade warnings after background refresh without invalidating confirmation;
- queue total distinguishes visible queued bytes, validated planned bytes, estimated reclaim, and unknown;
- details panel selection and queue selection are independent.

Kill criteria:

- queue order changes during confirmation because the table resorted;
- queue total uses stale visible size after watcher invalidation;
- deleting from queue is described as undoing filesystem action;
- background refresh silently changes queued candidate meaning;
- selected details panel controls mutate a different queued item.

### Confirmation Requires Visible Intent Proof

Microsoft confirmation guidance emphasizes enough information, safe defaults for risky actions, and extra thought for destructive actions. GNOME recommends confirmation or undo for destructive actions, with confirmation especially when undo is not available. For us, move-to-Trash is recoverable only by capability and receipt, not by generic promise.

```text
VisibleIntentProof:
  plan_hash
  selection_scope
  target_count
  top_parent_roots
  largest_items_summary
  hidden_or_collapsed_count
  skipped_or_unknown_count
  stale_or_revalidated_count
  warnings_summary
  reclaim_confidence_summary
  trash_capability_summary
```

Rules:

- confirmation surface shows what the action applies to, not only button text;
- destructive default action is disabled until visible proof is complete;
- risky or irreversible variants require stronger confirmation than move-to-Trash;
- "do not ask again" is forbidden for cleanup confirmation;
- confirmation token expires after plan change, watcher invalidation, daemon restart, auth/authority change, or timeout;
- screen reader confirmation includes count, scope, warnings, and safe default state;
- visible intent proof is recorded in receipt metadata without raw paths by default.

Kill criteria:

- confirmation says "Move selected items" without count/scope/warnings;
- safe default is the destructive button;
- compact confirmation hides skipped or unknown children;
- user can confirm while validation is still loading;
- receipt cannot prove which summary was shown at confirmation time.

### Filters And Recommendations Must Not Hide Risk

Search filters and recommendation rules can produce clean-looking lists that hide why an item is risky.

Rules:

- filtered views show active filter chips and result scope near destructive controls;
- cleanup candidate filters cannot remove critical warnings from confirmation;
- recommendation evidence follows candidate into queue and DeletePlan;
- if a filter hides children, confirmation still reports hidden affected descendants;
- sorting by reclaim estimate uses quantity kind and confidence label;
- stale search results cannot queue cleanup without revalidation.

Kill criteria:

- warning column hidden by filter means warning is absent from confirmation;
- "cleanup candidates" view queues app data without rule evidence;
- selected result from search points to old snapshot after subtree refresh;
- filter chip is off-screen in compact mode during destructive action;
- recommendation score appears as safety proof.

### Accessibility And Keyboard Semantics Are Safety Semantics

For this app, accessibility is not cosmetic. Keyboard and screen-reader users must understand the same target set and warnings as mouse users.

Rules:

- treegrid exposes selection state, expanded state, row count, row index, and sort state;
- focus indicator and selected state are visually distinct;
- multi-select state uses explicit accessible labels and counts;
- virtualized rows preserve stable semantics across scroll;
- destructive controls have accessible disabled reasons;
- keyboard shortcut behavior is documented in UI semantics tests, not only in help text;
- compact layout keeps queue, warning, and confirmation semantics reachable by keyboard.

Kill criteria:

- focus highlight and selection highlight are visually indistinguishable;
- screen reader hears row name but not selected/queued/warning state;
- hidden virtualized rows make row count wrong;
- keyboard shortcut queues item whose row is no longer focused;
- disabled destructive button gives no reason to assistive tech.

### Thirty-Third-Pass Hardest Spikes

1. **Selection set and DeletePlan binding spike**
   🎯 8 🛡️ 10 🧠 8, roughly 1200-3200 LOC/tests.
   Prove snapshot-bound selected refs, server-side selection set ids, queue candidate ids, DeletePlan hash, confirmation invalidation, and stale selection rejection after sort/filter/rescan.

2. **Bulk scope and hidden-descendant summary spike**
   🎯 8 🛡️ 9 🧠 7, roughly 900-2600 LOC/tests.
   Prove visible-only select-all, filtered-result upgrade, recursive subtree summary, hidden/skipped/stale counts, compact layout disclosure, and no full-id materialization in Flutter.

3. **Accessible treegrid destructive workflow spike**
   🎯 7 🛡️ 9 🧠 8, roughly 1000-2800 LOC/tests.
   Prove focus versus selection, `aria-multiselectable`, row count/index semantics under virtualization, screen-reader warning labels, keyboard shortcuts, disabled reasons, and confirmation summary parity.

## Thirty-Fourth-Pass Remote, Headless, Multi-User, And Network Trust Boundary Layer

This layer treats remote/headless mode as a separate product profile, not as a local daemon with a public bind address. The local desktop daemon can rely on loopback binding, local token, origin allowlist, and same-user filesystem authority. A remote server has different risks: many users, shared filesystems, network attackers, long-lived credentials, missing desktop Trash, no GUI permission prompts, server quotas, and API clients that can be scripted.

Core rule:

```text
remote mode is explicit
network location grants no trust
every object id needs authorization
read-only is the default remote capability
destructive remote cleanup needs a separate policy gate
server identity and user identity are not the same thing
```

### Deployment Profile Is A Security Boundary

Remote/headless mode must declare how it is exposed and who it serves.

```text
DeploymentProfile:
  local_loopback_desktop
  local_loopback_web_ui
  ssh_tunnel_single_user
  remote_single_user
  remote_multi_user
  ci_agent_read_only
  container_read_only
  enterprise_managed
```

Rules:

- remote mode is impossible to enable accidentally through config default;
- binding to `0.0.0.0`, public hostnames, or container-published ports requires explicit remote profile;
- each profile publishes capability state: scan, metadata, search, export, support bundle, delete-plan validate, move-to-trash, permanent delete;
- local loopback token model is not reused as remote authentication;
- remote profile chooses TLS termination, reverse proxy, direct TLS, or SSH tunnel explicitly;
- startup logs and UI show active profile and destructive capability state;
- unknown profile starts read-only or refuses to start.

Kill criteria:

- command-line flag changes bind address without changing auth policy;
- remote server accepts local daemon token format;
- container image exposes daemon port by default;
- remote mode inherits desktop Trash assumptions;
- support bundle cannot tell whether server was local, tunneled, or public.

### Authorization Must Be Object-Level And Capability-Level

Remote APIs expose session ids, node ids, cursor ids, selection set ids, delete plan ids, receipt ids, and support bundle ids. Every one is an authorization object.

```text
RemoteSubject:
  subject_id
  auth_method
  roles
  groups
  allowed_roots
  denied_roots
  capability_grants
  quota_policy
  session_policy
```

```text
ProtectedObject:
  scan_session
  scan_target
  node_ref
  cursor
  selection_set
  delete_plan
  cleanup_receipt
  support_bundle
  telemetry_buffer
```

Rules:

- every command/query checks subject, object, target root, operation kind, and capability;
- `NodeId` and `SessionId` opacity is not authorization;
- cursor belongs to subject, session, query shape, snapshot epoch, and expiry;
- delete plan validation requires stronger capability than scan/read;
- support bundle export is authorized separately because it can leak metadata;
- shared scan sessions are read-only by default unless collaboration policy is designed;
- authorization decisions are logged with redacted subject/object refs and denial reason.

Kill criteria:

- user changes session id in URL and reads another user's scan;
- delete plan id can be reused by another subject;
- support bundle endpoint checks only authentication;
- API trusts allowed root sent by client;
- admin role bypasses all object checks without audit.

### Remote Target Scope Must Be Explicit

On a server, "scan /" can mean system files, other users' homes, mounted secrets, containers, backups, NFS, cloud credentials, and application data.

```text
RemoteTargetScope:
  root_path
  scope_owner
  allowed_mount_policy
  denied_patterns
  max_depth
  max_nodes
  max_bytes_to_index
  metadata_policy
  symlink_policy
  cross_device_policy
  cleanup_policy
```

Rules:

- remote target roots are configured by operator or admin, not arbitrary client input by default;
- root scope has identity, owner, purpose, and allowed operations;
- cross-device, symlink, bind mount, container overlay, network mount, and secret mount policies are explicit;
- cleanup is disabled for shared or machine-global roots until a separate policy proves ownership and rollback semantics;
- per-root quota prevents one user scan from consuming daemon memory, IO, or event capacity;
- scan results display scope boundary and skipped/denied roots;
- scope changes invalidate sessions, selections, recommendations, and delete plans.

Kill criteria:

- remote user can scan any absolute path if OS permissions allow it;
- container `/` scan includes mounted Docker socket, secrets, or host path without policy;
- NFS/shared directories are treated as personal cache;
- scope config changes but old delete plan remains valid;
- denied paths are hidden instead of counted as denied/skipped capability state.

### Authentication And Transport Are Pluggable But Not Optional

The architecture can keep transport abstract, but remote transport needs real security.

```text
RemoteAuthMode:
  disabled
  ssh_tunnel_external_auth
  reverse_proxy_oidc
  bearer_token_static_admin_only
  mTLS_client_cert
  enterprise_identity_provider
```

Rules:

- direct remote HTTP without TLS is unsupported except explicitly documented dev mode;
- WSS uses the same authorization model as HTTP queries;
- WebSocket handshake authenticates, validates origin where applicable, and rechecks capability for each message class;
- tokens have expiry, rotation, revocation, audience, and scope semantics;
- static bearer token is acceptable only for tightly scoped single-user or dev deployments, not multi-user;
- reverse proxy auth headers are trusted only from configured loopback/proxy identities;
- auth mode is part of capability state and support bundle diagnostics.

Kill criteria:

- API key alone protects destructive multi-user server;
- WebSocket authenticates once and then skips message-level authorization;
- reverse proxy headers are trusted from any network client;
- token has no expiry or revocation path;
- CORS/origin is treated as authentication.

### Destructive Remote Operations Need Separate Policy

Remote cleanup is not just more dangerous. It can affect other users, production systems, backups, containers, cloud sync roots, and shared package stores.

```text
RemoteCleanupPolicy:
  disabled
  analyze_only
  move_to_trash_if_desktop_session
  quarantine_to_server_staging
  admin_approved_delete_plan
  tool_adapter_only
  permanent_delete_for_ephemeral_ci
```

Rules:

- remote MVP defaults to analyze-only;
- move-to-Trash is available only if platform/session capability proves a meaningful Trash/Recycle target;
- headless Linux does not assume desktop Trash;
- permanent delete requires explicit root policy, strong confirmation, audit reason, idempotency, and receipt;
- shared tool stores use official cleanup adapters or admin-approved policies, not raw folder deletion;
- remote delete plan includes subject, approver if any, root scope, policy id, and audit reason;
- UI must show remote host, target root, owner/scope, and cleanup policy before destructive confirmation.

Kill criteria:

- remote server offers the same Move to Trash button as desktop with no capability difference;
- cleanup runs under daemon service account over other users' data without subject mapping;
- permanent delete is enabled because Trash is unavailable;
- remote confirmation hides hostname or root scope;
- audit receipt cannot identify subject, policy, and target scope.

### Resource Isolation And Abuse Resistance

A remote scanner is an API service. It needs quotas, rate limits, and fairness.

```text
RemoteQuota:
  max_active_sessions_per_subject
  max_total_sessions
  max_roots_per_scan
  max_query_page_size
  max_event_replay_window
  max_support_bundle_size
  cpu_budget
  io_budget
  memory_budget
  export_rate_limit
```

Rules:

- remote API enforces per-subject and global limits;
- expensive queries, search, export, and support bundle generation have quotas;
- WebSocket event replay window is bounded by subject/session policy;
- unauthenticated requests have tiny limits and no filesystem action;
- cancellation and cleanup receipt writes are reserved even under quota exhaustion;
- audit records quota denials separately from auth denials;
- rate limits are part of protocol errors with safe retry hints.

Kill criteria:

- one user launches scans until daemon OOMs;
- support bundle export fills disk;
- event replay stores unbounded history per client;
- rate limit blocks cleanup receipt write;
- API returns generic 500 instead of typed quota error.

### Audit And Forensics Must Be Remote-Aware

Remote/headless mode needs an audit trail that is useful without leaking raw paths by default.

```text
RemoteAuditEvent:
  subject_ref
  auth_mode
  deployment_profile
  remote_addr_class
  command_id
  operation_id
  root_scope_ref
  capability
  decision
  reason_code
  policy_version
  receipt_ref
  support_evidence_ref
```

Rules:

- auth success/failure, authorization denial, target scope denial, quota denial, cleanup confirmation, cleanup dispatch, receipt creation, and support export are audit events;
- audit events use redacted refs and can be included in support bundle with privacy policy;
- remote audit retention is configurable and bounded;
- audit logs are append-oriented and protected from ordinary cache cleanup;
- operator can distinguish client bug, attacker probing, policy denial, and platform capability failure;
- remote support bundle includes auth/capability config fingerprint, not secret values.

Kill criteria:

- destructive remote command has no subject in receipt;
- audit log includes raw bearer token or raw path;
- auth failure flood fills critical app storage;
- remote support bundle omits policy version;
- operator cannot tell if cleanup was user-requested or API replay.

### Thirty-Fourth-Pass Hardest Spikes

1. **Remote profile and object authorization spike**
   🎯 8 🛡️ 10 🧠 9, roughly 1800-4800 LOC/tests.
   Prove explicit deployment profiles, no accidental public bind, subject/object/capability checks for session/node/cursor/selection/delete-plan/support-bundle ids, and old-client fail-closed behavior.

2. **Remote target scope and cleanup policy spike**
   🎯 7 🛡️ 10 🧠 9, roughly 1600-4200 LOC/tests.
   Prove configured roots, denied mounts/secrets, cross-device/symlink policy, analyze-only default, headless Trash capability, admin-approved destructive policy, receipts with subject/root/policy, and invalidation after scope change.

3. **Remote auth/transport/quota/audit spike**
   🎯 7 🛡️ 9 🧠 8, roughly 1400-3600 LOC/tests.
   Prove reverse-proxy/OIDC or mTLS adapter shape, WSS auth and message-level authorization, token expiry/revocation, per-subject quotas, event replay limits, typed quota errors, and redacted audit/support evidence.

Focused split-out file for remote/headless destructive cleanup authorization:
`critical-zones/remote-headless-destructive-cleanup-authorization.md`.

## Thirty-Fifth-Pass Async, Blocking, Worker-Pool, Panic, And Shutdown Boundary Layer

This layer handles the first deep Rust runtime risk: the daemon is async at the transport boundary, but scanning, metadata reads, indexing, platform Trash, and many filesystem APIs are blocking or CPU-heavy. If this boundary is sloppy, the UI can be architecturally correct and still feel broken: WebSocket heartbeats stall, cancellation lies, shutdown hangs, memory grows behind channels, or a dependency panic poisons a session.

Focused split-out file: `critical-zones/rust-runtime-execution.md`.

Core rule:

```text
Tokio owns network coordination
filesystem scanning owns dedicated bounded workers
blocking filesystem work never runs on async reactor threads
started blocking work is cancelled cooperatively
panic is a bug boundary, not a domain error
shutdown is a state machine, not a best-effort drop
```

### Runtime Lanes Are Explicit

Do not treat "Rust backend" as one execution pool. Each class of work has different latency and cancellation behavior.

```text
RuntimeLane:
  async_transport
  command_validation
  scanner_worker_pool
  metadata_enrichment_pool
  index_build_pool
  journal_writer
  platform_trash_thread
  event_fanout
  support_bundle_worker
```

Rules:

- `async_transport` handles HTTP, WebSocket, auth, heartbeats, and lightweight routing only;
- scanner traversal never blocks the async reactor thread;
- scanner and metadata pools have explicit budgets from `ScanResourceProfile`;
- event fanout cannot wait on slow clients while holding scanner locks;
- journal writes are separated from scan traversal so persistence latency does not freeze progress;
- platform adapters with thread-affinity requirements, especially Windows Shell/COM, get their own lane;
- every lane has queue size, timeout, cancellation, and shutdown semantics.

Kill criteria:

- `std::fs` traversal runs inside an async request handler;
- one large scan prevents WebSocket ping/pong or cancel command handling;
- pdu callback does JSON serialization or UI-event fanout inline;
- scanner, metadata, and indexing all use the same uncontrolled global pool;
- shutdown relies on dropping a handle and hoping workers stop.

### `spawn_blocking` Is A Bridge, Not The Scanner Runtime

Tokio `spawn_blocking` is useful for bounded blocking work that finishes on its own. It is a weak fit for long scans because started blocking tasks are not abortable, shutdown may wait for them, and the default blocking limit is intentionally large.

Top 3 runtime options:

1. **Dedicated scanner runtime lane plus async transport** - 🎯 9 🛡️ 10 🧠 8, roughly 1600-4200 LOC/tests.
   Best fit. Tokio stays responsive, scans get resource budgets, and cancellation/shutdown can be owned by scanner session state.

2. **Tokio `spawn_blocking` with strict semaphore and cooperative cancel** - 🎯 6 🛡️ 7 🧠 5, roughly 700-1800 LOC/tests.
   Acceptable as a small spike or fallback. Risk is that long started tasks still cannot be force-aborted and shutdown behavior is harder to make honest.

3. **Separate scanner child process per scan** - 🎯 5 🛡️ 8 🧠 9, roughly 2500-7000 LOC/tests.
   Strong isolation and kill semantics, but more IPC, packaging, crash recovery, auth, and Windows/macOS process-management cost. Not MVP unless in-process containment proves insufficient.

Rules:

- use `spawn_blocking` only for short, bounded adapters or as a measured prototype path;
- long scan sessions run in a named, bounded, owned executor/pool;
- pool size is profile-driven, not "number of cores everywhere";
- blocking tasks receive a cancellation token and check it at known safe points;
- shutdown timeout is explicit and reported as `shutdown_forced` or `scan_abandoned`, not hidden as clean success;
- started blocking work that cannot stop quickly is documented as a platform limitation.

Kill criteria:

- every scan is one `spawn_blocking` task with no internal cancel checkpoints;
- runtime shutdown waits indefinitely for scanner threads;
- Fast mode creates more total threads than CPU cores plus IO budget without a cap;
- tests assume `JoinHandle::abort` stops blocking filesystem work;
- a scan profile changes only UI labels, not actual worker budgets.

### pdu Adapter Must Not Own Global Concurrency Semantics

`parallel-disk-usage` is an adapter dependency. It may internally choose traversal and parallelism strategies. Our product still owns lifecycle, budgets, cancellation promises, and event pressure.

```text
ScannerAdapterExecution:
  adapter_owned_threads
  caller_owned_pool
  rayon_global_pool
  rayon_local_pool
  synchronous_inline
```

Rules:

- adapter capability reports whether thread count, hardlink policy, symlink policy, and progress cadence are configurable;
- if an adapter uses Rayon, prefer a local configured pool over process-global pool where feasible;
- do not initialize global Rayon from reusable library code unless the decision is explicit at app composition root;
- nested parallelism is measured and capped, especially pdu traversal plus metadata enrichment plus index build;
- pdu callbacks convert to internal scan events cheaply, then return;
- adapter panics are caught at the outer worker boundary only for containment, then treated as session failure.

Kill criteria:

- library crate sets global Rayon thread count as a side effect;
- two scan sessions each create "logical CPU count" worker pools with no global budget;
- pdu callback performs expensive metadata or DB writes;
- adapter thread count cannot be explained in support bundle diagnostics;
- adapter failure is reported as generic "scan failed" without capability/error classification.

### Cancellation Is Cooperative Across The Sync/Async Boundary

Cancellation is not one API call. It is a contract across traversal, metadata, indexing, journal, transport, UI state, and platform side effects.

```text
CancellationCheckpoint:
  before_enter_directory
  after_read_dir_batch
  before_metadata_enrichment_batch
  before_index_insert_batch
  before_event_publish_batch
  before_delete_plan_validation
  before_platform_side_effect
  before_receipt_commit
```

Rules:

- cancel request is accepted by async command path even under scan load;
- scanner observes cancellation through atomics/tokens, not by waiting on async runtime;
- cancellation latency is measured per profile and shown honestly if slow;
- terminal event distinguishes `cancelled`, `aborted_due_to_shutdown`, `failed`, and `completed`;
- delete side effects have a different cancellation model from scan because some OS calls may complete after cancellation;
- cancelled scan snapshots are marked partial and cannot feed cleanup recommendations unless explicitly allowed.

Kill criteria:

- cancel button disappears while daemon is busy;
- cancelled scan still produces a normal complete snapshot;
- delete cancellation uses same state as scan cancellation;
- UI says "cancelled" before worker has reached a safe checkpoint;
- reconnect after cancel can show stale `running` state.

### Backpressure Between Blocking Producers And Async Consumers

The scanner is a fast synchronous producer. WebSocket clients, JSON encoders, SQLite, and Flutter rendering are slower consumers. The bridge must classify event loss explicitly.

```text
EventPressureClass:
  lossless_terminal
  lossless_error
  lossless_receipt
  bounded_audit
  coalescable_progress
  coalescable_throughput
  pageable_tree_data
  discardable_debug
```

Rules:

- terminal events, receipts, and safety errors are lossless and journaled where needed;
- progress and throughput events are coalesced by latest value;
- tree rows are queryable read-model data, not streamed as one event per file;
- bounded channels have explicit overflow policy per event class;
- sync producer never allocates unbounded buffers to protect an async consumer;
- slow WebSocket clients are disconnected or downgraded to snapshot refresh;
- event sequence gaps force client resync, not silent interpolation.

Kill criteria:

- one WebSocket client can make scanner memory grow;
- progress event flood delays terminal event delivery;
- event queue overflow drops skip/error evidence;
- file nodes are streamed to Flutter as the primary tree data path;
- reconnect replays unbounded history from RAM.

### Panic Containment And Poisoned State

Rust panics are not domain errors. A panic means a bug or violated invariant. It can be caught only in unwind mode and only at safe boundaries. Catching it does not make partially mutated state trustworthy.

```text
PanicBoundary:
  scanner_worker_root
  metadata_worker_root
  index_builder_root
  platform_adapter_root
  support_bundle_worker_root
```

Rules:

- normal filesystem errors use `Result`, never `panic`;
- `catch_unwind` is not used as general error handling;
- panic containment happens at worker roots, not inside domain logic;
- after a worker panic, affected session/index/journal writer is marked poisoned or failed;
- poisoned mutable state is dropped or rebuilt from durable facts;
- panic payloads are redacted before logs/support bundles;
- panic strategy and containment expectations are part of release build config;
- no panic unwinds across FFI, FRB, C ABI, plugin, or platform callback boundaries.

Kill criteria:

- code catches panic and continues using the same partially updated index;
- adapter panic becomes user-facing "permission denied";
- panic payload containing a path is logged raw;
- FFI/bridge boundary assumes Rust unwind is safe;
- tests cover `Result` errors but not panic containment at worker roots.

### Shutdown Is A State Machine

Daemon shutdown can come from app quit, OS logout/shutdown, installer update, crash restart, watchdog, forced kill, or user stop. Each one has a different budget.

```text
ShutdownPhase:
  accepting_commands
  quiescing
  cancelling_scans
  flushing_journal
  final_receipts
  transport_close
  forced_stop
  recovery_on_next_start
```

Rules:

- shutdown stops accepting new scan/delete commands first;
- cancellation signal reaches workers before transport closes;
- journal and receipt flush have reserved IO budget;
- WebSocket clients receive a terminal lifecycle event when time allows;
- if time expires, next start sees `unclean_shutdown` and reconciles sessions;
- update/uninstall cannot remove daemon binary while destructive operation is mid-receipt;
- support diagnostics include previous shutdown reason and unfinished operations without raw paths.

Kill criteria:

- OS shutdown leaves operation journal in ambiguous state without recovery marker;
- update kills daemon during cleanup and hides unknown outcome;
- forced stop deletes temporary quarantine before receipt write;
- daemon closes WebSocket first, then tries to tell UI what happened;
- restart resumes destructive work without revalidation.

### Thirty-Fifth-Pass Hardest Spikes

1. **Dedicated scanner runtime lane spike**
   🎯 9 🛡️ 10 🧠 8, roughly 1600-4200 LOC/tests.
   Prove bounded scanner workers, Tokio responsiveness under scan load, cancel command latency, profile-controlled thread budgets, and no blocking filesystem work on async reactor threads.

2. **Cross-boundary backpressure and shutdown spike**
   🎯 8 🛡️ 10 🧠 9, roughly 1800-4600 LOC/tests.
   Prove event class overflow policy, lossless terminal/error/receipt delivery, slow WebSocket handling, snapshot resync after gaps, quiesce phases, forced-stop markers, and recovery on next start.

3. **Panic containment and poisoned-state spike**
   🎯 7 🛡️ 9 🧠 8, roughly 900-2600 LOC/tests.
   Prove worker-root panic boundaries, no raw-path panic logging, failed/poisoned session state, index rebuild/drop behavior, FFI/bridge no-unwind guarantee, and support-bundle evidence that does not leak private paths.

## Summary

The highest-risk mistake would be to treat this as "scanner + table + delete button". The real product is a chain of contracts:

```text
fast scanner
  -> compact snapshot
  -> bounded memory representation
  -> bounded metadata
  -> exact quantity and unit semantics
  -> snapshot-bound selection and visible intent proof
  -> explicit content-read boundary
  -> hostile-name display and export safety
  -> clock and causality semantics
  -> low-disk degraded mode
  -> SQLite/Drift persistence integrity and schema drift gates
  -> explicit traversal policy
  -> explicit state machines
  -> domain-specific cancellation and abortability
  -> typed error taxonomy and recovery actions
  -> power-aware and thermal-aware resource budgets
  -> privacy-budgeted observability and support evidence
  -> explicit remote/headless trust boundary
  -> async/blocking runtime lane isolation
  -> panic and poisoned-state containment
  -> recoverable protocol
  -> bounded protocol backpressure
  -> watcher freshness leases and stale-UI invalidation
  -> version-compatible protocol gates
  -> single-instance daemon lifecycle ownership
  -> graceful quiesce and forced-termination recovery
  -> hardened daemon
  -> least-privilege process identity
  -> explicit elevation boundary
  -> authority leases and confused-deputy defense
  -> host-interference and runtime trust gates
  -> threat-modeled trust boundaries
  -> evidence-backed UI claims
  -> per-target capability matrix
  -> volume topology and mount leases
  -> virtualized UI
  -> identity-checked DeletePlan
  -> blast-radius budgets
  -> staged cleanup with circuit breakers
  -> native Trash
  -> durable intent before side effects
  -> durable receipt
  -> contained failure domains
  -> trust recovery artifacts
  -> fault-injection harness
  -> path authority and namespace isolation
  -> assurance-case traceability
  -> policy-as-code release gates
  -> side-effect-free rule engine
  -> extension capability manifests
  -> misuse-resistant public library API
  -> human-factors destructive UX tests
  -> long-term compatibility and migration gates
  -> immutable receipts and replayable journals
  -> deterministic fixture truth levels
  -> fixture-backed release gate
```

Every link needs a pass/fail spike. If one link fails, the architecture should degrade by adapter/fallback, not by rewriting the whole app.
