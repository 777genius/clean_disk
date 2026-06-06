# Implementation Edge Cases - Resource Governance

Last updated: 2026-05-13.

This document records resource-governance edge cases for Clean Disk. The goal is to keep the scanner fast without making the computer feel broken while scanning 500 GB, multi-million entry trees, developer caches, network mounts, or remote servers.

Resource governance is not a nice-to-have optimization. It is product behavior. A disk cleanup tool can win a benchmark and still lose user trust if it burns battery, makes the mouse stutter, causes fans to spike, blocks builds, or makes Windows Defender and Spotlight fight with it.

## Sources Reviewed

- Tokio docs, [`spawn_blocking`](https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html). Relevant points: blocking work must not run inside ordinary async futures; the blocking pool can grow to a large limit; CPU-bound work needs explicit limiting; started blocking tasks cannot be aborted; long-lived blocking workloads should prefer dedicated threads.
- Rayon docs, [`ThreadPoolBuilder`](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html). Relevant points: Rayon pools can be configured, the global pool initializes once, and thread counts should be explicit when we need deterministic budgets.
- Apple Energy Efficiency Guide, [Quality of Service classes](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/PrioritizeWorkWithQoS.html). Relevant points: finite resources need priority classification; QoS affects scheduling, CPU and IO throughput, and timer latency; utility/background work is the natural class for long-running scans.
- Apple Developer, [Responding to power notifications](https://developer.apple.com/documentation/xcode/responding-to-power-notifications). Relevant points: apps should observe power and thermal changes, reduce optional work in Low Power Mode, defer work in elevated thermal states, and reduce or stop work in critical thermal states.
- Microsoft Learn, [`SetPriorityClass`](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setpriorityclass). Relevant points: background processing mode lowers resource scheduling priority; CPU priority alone is not enough for file IO, network IO, or data processing; realtime priority can make input and disk caches unresponsive.
- Microsoft Learn, [`SetProcessInformation` with ProcessPowerThrottling](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setprocessinformation). Relevant points: EcoQoS is for work that does not contribute to foreground UX and can improve battery life, heat, and fan noise; it must not be used for foreground critical work.
- Microsoft Learn, [`GetSystemPowerStatus`](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-getsystempowerstatus). Relevant points: Windows exposes AC/DC, charge, battery remaining, and battery-saver status.
- Linux kernel docs, [Block IO priorities](https://www.kernel.org/doc/html/next/block/ioprio.html). Relevant points: IO priority support is scheduler-dependent; realtime IO can starve the system; idle IO runs only when no one else needs the disk.
- Flutter docs, [Performance best practices](https://docs.flutter.dev/perf/best-practices). Relevant points: large lists should be lazy, intrinsic layout passes are expensive, and smooth UI targets roughly 16 ms per frame on 60 Hz displays.
- Chrome for Developers, [Background tabs](https://developer.chrome.com/blog/background_tabs/). Relevant points: background tabs are timer-throttled, `requestAnimationFrame` is paused in background, and long background tasks can be throttled heavily.
- Microsoft Defender docs, [Performance analyzer](https://learn.microsoft.com/en-us/defender-endpoint/tune-performance-defender-antivirus). Relevant points: Defender can analyze top paths, files, processes, and extensions that affect scan performance.
- Microsoft Support, [Search indexing in Windows](https://support.microsoft.com/en-us/windows/search-indexing-in-windows-da061c83-af6b-095c-0f7a-4dfecda4d15a). Relevant points: Windows Search constantly tracks changed files, Enhanced mode indexes more of the PC, and lots of small files or code can increase index size.

## Severity Scale

- `P0` - can freeze the UI, make deletion unsafe, hang daemon control plane, or make the machine unusable.
- `P1` - can cause severe latency, fan/battery spikes, runaway memory, misleading progress, or bad defaults.
- `P2` - can reduce scan speed, waste energy, or create confusing but recoverable behavior.
- `P3` - polish, diagnostics, or tuning gaps.

## Core Principle

Default mode must preserve system responsiveness. Fast mode is opt-in.

Clean Disk is not a benchmark-only program. The default user experience should feel like:

- the UI remains interactive;
- scan can be paused or cancelled quickly;
- the laptop remains usable;
- other developer tools can keep working;
- file deletion is never rushed because a scan found a large folder;
- resource use is visible and adjustable.

If a user explicitly chooses "Fast scan", we can use more CPU and IO, but the UI must say that this may increase fan noise, battery use, and system load.

## Top 3 Decisions

1. Explicit resource profiles: Balanced, Fast, Background - 🎯 10 🛡️ 9 🧠 6, roughly 700-1800 LOC across Rust policy, platform adapters, UI controls, config, tests, and telemetry.

   This is the best default. It is understandable to users, maps cleanly to platform knobs, and keeps future tuning controlled.

2. Separate control plane, scan workers, index workers, and event fanout budgets - 🎯 9 🛡️ 9 🧠 7, roughly 1000-2600 LOC across supervisors, queues, metrics, cancellation, and tests.

   This prevents pdu, indexing, sort/search, and WebSocket fanout from fighting on the same thread pool. It also keeps the daemon responsive when scanning is hot.

3. Platform resource policy adapter behind a port - 🎯 8 🛡️ 8 🧠 8, roughly 900-2400 LOC across macOS QoS, Windows background/EcoQoS, Linux nice/ionice/cgroups where available, capability reporting, and fallback behavior.

   This gives us real OS integration without leaking platform APIs into domain/application. The cost is higher because platform behavior differs and some knobs are process-wide, not session-local.

## Resource Profile Model

### Problem - `P1`

One "max speed" algorithm cannot be the only product behavior. The right scan behavior depends on:

- plugged in vs battery;
- foreground app vs background tab;
- local SSD vs HDD vs network mount;
- active developer build vs idle machine;
- quick folder scan vs full disk scan;
- desktop UI vs remote headless server;
- user expecting speed vs user expecting quiet background work.

### Decision

Define `ResourceProfile` in application contracts:

```text
ResourceProfile
  balanced
  fast
  background
  custom
```

Suggested MVP semantics:

```text
balanced:
  default
  bounded scanner parallelism
  normal or utility OS priority
  throttled progress events
  preserves UI responsiveness

fast:
  opt-in
  higher scanner parallelism
  no background/EcoQoS throttling by default
  still bounded
  visible warning for battery/thermal/fan impact

background:
  lower scanner parallelism
  background OS priority when available
  lower event frequency
  optional auto-pause on battery saver or serious thermal state

custom:
  developer/advanced settings
  explicit max threads, event rate, IO policy
  hidden behind advanced UI until needed
```

### Mitigation

- Persist selected default profile per device, not per scan result.
- Record effective resource profile inside each scan metadata snapshot.
- Show current profile in scan status.
- Allow changing profile during scan if the scanner adapter can apply it safely.
- If dynamic changes are not possible, apply to next scan and say so.

### Architecture Placement

```text
domain:
  ResourceProfile value object if pure business meaning is needed

application:
  ResourcePolicy port
  ScanBudget use-case input
  ScanSession effective policy snapshot

infrastructure:
  pdu thread config
  Tokio/Rayon worker pools
  OS priority adapters
  power/thermal sensors

interface:
  HTTP/WebSocket DTOs
  CLI flags

presentation:
  mode selector
  visible warnings
  diagnostics
```

Domain must not call OS APIs, read battery state, configure Rayon, or know pdu.

## CPU And Thread Budget

### Problem - `P0`

Clean Disk can accidentally stack several thread systems:

- Tokio runtime worker threads;
- Tokio blocking pool;
- pdu/Rayon traversal threads;
- sort/search/index workers;
- compression or serialization workers;
- Flutter UI and render threads;
- OS indexing, antivirus, cloud sync, backup tools.

If every layer uses "available parallelism" independently, an 8-core machine can behave like a 40-thread machine under load.

### Failure Modes

- control API becomes slow because async runtime threads are busy;
- scan speed drops because thread contention beats disk parallelism;
- fan and battery usage spike;
- cancellation waits too long;
- sort/search blocks event fanout;
- remote clients timeout even though scan is still progressing.

### Required Mitigation

- Treat `available_parallelism()` as an upper bound, not a target.
- Reserve capacity for UI, daemon control plane, and OS.
- Keep Tokio control-plane runtime separate from blocking scan work.
- Use bounded channels between scanner, indexer, event aggregator, and transport.
- Do not use Tokio `spawn_blocking` as a general CPU pool.
- Do not use unbounded `spawn_blocking` for pdu or long scan loops.
- If pdu uses Rayon internally, avoid adding a second full Rayon pool around it.
- If we need a custom Rayon pool, build it explicitly with `ThreadPoolBuilder`.

### Starting Defaults

These are hypotheses, not final benchmark facts:

```text
balanced local SSD:
  scanner threads: min(4, max(1, cores - 2))
  index threads: 1-2
  event aggregation: 1
  control plane: normal Tokio runtime

fast local SSD:
  scanner threads: min(cores, 8) initially
  index threads: 2-4
  event aggregation: 1

background:
  scanner threads: 1-2
  index threads: 1
  event aggregation: lower frequency
```

For HDD, external drive, SMB/NAS, FUSE/rclone, and cloud placeholders, high thread count can reduce throughput. The scanner should adapt down when latency rises.

### Metrics

Record per scan:

- configured scanner thread count;
- effective scanner thread count;
- active Tokio tasks by class where practical;
- channel depths and dropped/coalesced event counts;
- CPU percent;
- thread count;
- page latency;
- cancellation latency;
- query latency while scan is active.

## `spawn_blocking` And Dedicated Threads

### Problem - `P1`

Tokio `spawn_blocking` is appropriate for bounded blocking calls. A full disk scan can be long-lived, IO-heavy, and not abortable once the closure starts.

### Rule

Use `spawn_blocking` for short bounded bridge operations. Use dedicated supervised scan workers for long-running scanner sessions.

### Mitigation

- Scan worker owns cancellation token and progress reporter.
- Scanner loop must check cancellation at boundaries.
- If pdu cannot stop immediately, expose cancellation state as `cancelling` until the adapter returns.
- Runtime shutdown must not wait forever on non-abortable blocking tasks.
- Use `shutdown_timeout` only as a last resort and document possible orphaned work if any.

## Disk IO Budget

### Problem - `P0`

Disk usage scanning is mostly metadata IO, but metadata IO can still make the machine feel stuck. This gets worse on:

- HDDs;
- external USB disks;
- network shares;
- FUSE mounts;
- cloud-provider virtual filesystems;
- encrypted volumes;
- very large directories with millions of entries;
- many small files in `node_modules`, package stores, build caches, or mail/browser stores.

### Failure Modes

- Finder/File Explorer becomes slow;
- builds slow down because source tree metadata is hot;
- antivirus re-scans touched files;
- backup/indexer fights with traversal;
- external drives disconnect or stall;
- network shares trigger auth prompts or rate limiting.

### Required Mitigation

- Use bounded directory traversal concurrency.
- Detect mount type where practical and apply profile-specific defaults.
- Avoid scanning multiple roots on the same physical disk at full speed.
- Expose "scan slower in background" setting.
- Add adaptive downshift when directory read/stat latency rises.
- Separate progress estimation from raw throughput because high speed can be bursty from OS cache.
- Never treat benchmark fixture speed as default production speed.

### Adaptive IO Signals

Useful signals:

- average directory read latency;
- metadata error rate;
- skipped permission count spike;
- current throughput vs recent throughput;
- OS power state;
- user changed profile;
- app went background;
- WebSocket slow clients;
- target path under network/cloud/removable mount.

Suggested behavior:

```text
if target_is_network_or_fuse:
  start with lower concurrency

if stat_latency_p95 rises sharply:
  reduce scanner parallelism one step

if user selects fast:
  allow higher cap but keep cancellation responsive

if battery_saver or serious thermal:
  shift to background profile or prompt
```

## OS Priority And QoS

### Problem - `P1`

Thread count alone does not express work importance. OS schedulers have their own CPU, IO, timer, memory, and power policies.

### macOS

Apple QoS classes map well to our profiles:

```text
UI/control:
  userInteractive or userInitiated only for immediate UI/control actions

foreground scan with visible progress:
  utility

background scan:
  background
```

Important caveats:

- QoS can be inferred or promoted through dependencies.
- Priority inversions can happen when high-priority UI waits on low-priority scan locks.
- Rust threads may need pthread QoS setup if we want native scheduling behavior.
- Do not make all scanner work `userInitiated` because that steals resources from real UI.

### Windows

Windows offers multiple relevant knobs:

- `PROCESS_MODE_BACKGROUND_BEGIN` lowers resource scheduling priority for background process work.
- `SetProcessInformation(ProcessPowerThrottling)` can opt into EcoQoS for non-foreground work.
- `GetSystemPowerStatus` exposes AC/DC, charging, remaining battery, and battery saver.

Important caveats:

- `PROCESS_MODE_BACKGROUND_BEGIN` is process-wide if applied through `SetPriorityClass`.
- Our daemon may also serve UI/control API, so process-wide background mode can hurt responsiveness.
- Prefer thread-specific or worker-process isolation if we need aggressive background policy.
- Do not use realtime/high priority for scanner.
- EcoQoS should be tied to Background profile, not foreground Fast scan.

### Linux

Linux offers:

- `nice`/`setpriority` for CPU scheduling hints;
- `ionice`/`ioprio_set` for IO priority where supported by the scheduler;
- cgroups in server deployments for CPU, memory, and IO quotas;
- systemd slices/scopes when running as a service.

Important caveats:

- IO priority support is scheduler-dependent.
- Realtime IO can starve the system.
- Idle IO may be too slow for foreground user expectations.
- Desktop app permissions may not allow all tuning knobs.
- Server/headless mode should prefer cgroup/systemd budgets over ad hoc process tuning.

### Cross-Platform Port

Define an infrastructure port:

```text
ResourceGovernor
  capabilities() -> ResourceCapabilities
  apply_session_policy(session_id, EffectiveResourcePolicy)
  observe_power_state() -> PowerState
  observe_thermal_state() -> ThermalState
  reset_session_policy(session_id)
```

Capabilities should say what is actually supported:

```text
supports_thread_qos
supports_process_background_mode
supports_power_state
supports_thermal_state
supports_io_priority
supports_cgroup_limits
policy_scope: process | thread | worker_process | unsupported
```

If a platform cannot apply a policy, UI should show "Limited OS resource controls" only in diagnostics, not as a scary warning during normal usage.

## Battery, Thermal, And Power State

### Problem - `P1`

A full disk scan can run for minutes. On laptops, thermal and battery state can change during scan.

### Required Behavior

- Capture power state at scan start.
- Observe power/thermal changes where available.
- In Balanced mode, warn or downshift if battery saver or serious thermal state appears.
- In Background mode, auto-downshift or pause optional indexing when thermal state is serious.
- In Fast mode, keep running but show a clear status if system is battery-constrained.
- Record sleep/wake gaps separately from slow throughput.

### macOS Policy

Suggested mapping:

```text
thermal nominal:
  normal profile behavior

thermal fair:
  keep balanced scan, reduce nonessential indexing

thermal serious:
  reduce scanner concurrency, reduce event rate, pause optional analysis

thermal critical:
  pause scan by default unless user explicitly resumes
```

Low Power Mode:

- Background profile should honor it automatically.
- Balanced should prompt or downshift.
- Fast should require explicit user choice if started while Low Power Mode is active.

### Windows Policy

Use `GetSystemPowerStatus` to detect:

- AC vs battery;
- battery saver;
- battery percentage;
- charging state.

Suggested behavior:

```text
on battery saver:
  balanced -> background-like budget
  background -> pause optional indexing
  fast -> visible warning

on low battery threshold:
  pause long scan by default if background
  ask in foreground
```

### Linux Policy

For desktop Linux:

- read UPower if available;
- fallback to `/sys/class/power_supply`;
- do not require root;
- document missing power/thermal detection as a capability gap.

For server Linux:

- battery is usually irrelevant;
- CPU/memory/IO quotas matter more;
- expose resource budget through CLI/config.

## UI Responsiveness Budget

### Problem - `P0`

The Rust side can be healthy while Flutter becomes janky because it parses too much JSON, rebuilds too much tree UI, or receives progress updates too often.

### Required Mitigation

- Flutter never receives the whole tree.
- Rust returns pages with stable cursors.
- Sort/search/top-K happen in Rust.
- UI uses lazy list/table primitives.
- Do not use intrinsic layout for large tree rows.
- Progress events are coalesced to a frame-friendly rate.
- Large payload parsing must not happen repeatedly on the web main thread.
- Details panel and charts update at lower rate than scan status.

### Suggested Frontend Budget

```text
row page size:
  100-500 visible/near-visible rows, tune by benchmark

progress update rate:
  4-10 updates/sec while active
  lower if tab is background

chart update rate:
  1-2 updates/sec while scanning
  final update on scan complete

search result page:
  50-200 rows
```

Do not let a progress event mutate thousands of row objects in Flutter state.

## Web UI Background Behavior

### Problem - `P1`

The web UI is a display/control surface, but browsers throttle background tabs. A tab can miss timer ticks, delay UI work, or reconnect after sleep.

### Required Mitigation

- Server state is authoritative.
- UI timers are hints only.
- Progress display should recompute elapsed time from server timestamps after resume.
- WebSocket events are optional notifications, not the source of truth.
- On visibility change to foreground, query current session snapshot.
- Do not depend on `requestAnimationFrame` for protocol health.
- Avoid client-side long tasks in background tabs.

## Backpressure Across The Whole Pipeline

### Problem - `P0`

Backpressure is not only WebSocket backpressure. We need budgets at every boundary:

```text
scanner -> aggregator
aggregator -> tree/index builder
tree/index -> query service
session -> event stream
event stream -> each client
cleanup adapters -> operation journal
```

### Failure Modes

- scanner blocks because a browser tab is slow;
- events pile up in memory;
- query service blocks behind scan aggregation;
- indexer eats CPU while scan should be cancellable;
- cleanup receipts lag behind file operations;
- one remote client degrades all clients.

### Required Mitigation

- Use bounded queues.
- Coalesce progress events.
- Keep terminal events durable and never silently dropped.
- Slow clients receive lag notice and must resync by querying snapshot.
- Query APIs should read immutable snapshots or short-lived locks.
- Do not hold global locks while doing file IO, sorting, serialization, or WebSocket sends.

## Memory Budget

### Problem - `P1`

Resource governance includes memory. A scan tree for millions of entries can get large even if the UI receives pages.

### Required Mitigation

- Rust owns full tree and indexes with measured memory budget.
- Store compact IDs and intern repeated strings where useful.
- Do not keep every historical event.
- Keep scan snapshots bounded by retention policy.
- Use spill-to-disk only after designing persistence and privacy semantics.
- Query pages should allocate predictably.
- Large search indexes should be optional or built incrementally.

### Metrics

- peak RSS;
- tree node count;
- average bytes per node;
- path interning hit ratio if implemented;
- index memory;
- event buffer memory;
- per-client buffer memory.

## Scanner And Indexer Scheduling

### Problem - `P1`

Scanning, aggregating, sorting, search indexing, recommendation classification, and tool-specific analysis are different workloads.

### Rule

Scanner gets first priority during active scan. Optional analysis is opportunistic.

Suggested pipeline:

```text
scan:
  required for result

aggregate sizes:
  required for result

top-K indexes:
  required for first useful UI

search index:
  deferred or incremental

recommendation rules:
  deferred, prioritized by largest/risk-known folders

tool cleanup adapters:
  on demand or after scan complete
```

### Mitigation

- Build minimal tree/table result first.
- Defer expensive classification until user opens details or scan completes.
- Pause optional work when scan cancellation is requested.
- Pause optional work under battery saver, thermal serious, or background profile.
- Keep recommendation engine from scanning file contents by default.

## Deletion And Resource Budget

### Problem - `P1`

Move-to-trash or cleanup commands can also be expensive. Deleting `node_modules`, Docker layers, or build caches can create heavy metadata IO and trigger security scanners.

### Required Mitigation

- Cleanup operation has its own resource policy.
- Default cleanup should run with conservative IO budget.
- UI must remain interactive while delete is active.
- Delete journal writes must have higher reliability priority than progress events.
- Do not run full scan and heavy delete at full speed on the same target at the same time.
- If delete starts during scan, either pause the overlapping subtree scan or mark it stale.

### Extra Safety

- Before delete, revalidate identity as documented in cleanup safety docs.
- During delete, do not chase symlinks/reparse points unexpectedly.
- After delete, schedule targeted refresh with low priority unless user requests immediate rescan.

## Interference With OS Services

### Problem - `P2`

Clean Disk runs on machines that already have file observers:

- Microsoft Defender;
- Windows Search;
- Spotlight;
- Time Machine;
- cloud sync clients;
- IDE indexers;
- build systems;
- backup tools;
- Docker Desktop or container runtimes.

### Required Mitigation

- Benchmarks must record whether Defender/Spotlight/indexers are active.
- Do not recommend disabling security tools.
- Detect obvious index/cache folders and label them correctly.
- If a scan gets unexpectedly slow, diagnostics should mention possible external scanners.
- Avoid file content reads unless a feature explicitly needs content.
- Prefer metadata traversal over opening files.

### Windows Specific

Windows Search Enhanced mode can index the entire PC and use more resources. Microsoft documents that Windows Search tracks file changes and updates the index in the background. Defender can report top paths/files/processes that affect antivirus scan performance.

Clean Disk should treat Defender/Search interaction as an environmental factor:

- record Windows Defender enabled in benchmark notes if discoverable;
- record indexing mode if accessible safely;
- avoid causing writes during scan;
- avoid content hashing by default.

## Remote And Headless Resource Quotas

### Problem - `P1`

If Clean Disk runs on a remote server, "fast" can hurt production workloads.

### Required Mitigation

- Headless server default profile is `background` or explicit configured budget, not `fast`.
- Require CLI/config for max threads, max memory, max sessions, max roots, and max event clients.
- Support cgroups/systemd integration where practical.
- Expose current resource budget in `/health` or diagnostics endpoint.
- Multi-user remote mode needs per-user/session quotas.
- Admin can disable Fast mode.

### Server Defaults

```text
max_concurrent_scans:
  1 by default

max_scan_threads:
  min(4, cores / 2) by default

max_clients_per_session:
  bounded

event_buffer:
  bounded per client

query_page_size:
  bounded
```

## OS Sleep, Wake, And App Lifecycle

### Problem - `P1`

Sleep/wake is both operational reliability and resource governance. A scan can appear frozen or wildly slow after a laptop sleeps.

### Required Mitigation

- Detect monotonic-time gaps.
- Mark gap as `sleep_or_suspend_gap` in session events.
- Do not count sleep time as scanner throughput failure.
- On wake, refresh target health.
- If removable/network mount disappeared, transition scan to recoverable partial state.
- Reapply OS resource policy after wake if required.
- Re-check power/thermal state after wake.

## Benchmarks Must Measure Responsiveness

### Problem - `P1`

If benchmarks only measure "time to scan", we will choose bad defaults.

### Required Benchmark Dimensions

For each target:

- elapsed scan time;
- files/sec and directories/sec;
- bytes/sec where meaningful;
- CPU percent;
- peak RSS;
- thread count;
- UI frame time or jank count;
- query latency while scan is active;
- event lag and dropped/coalesced count;
- cancellation latency;
- battery state;
- thermal state where available;
- disk type and filesystem;
- Defender/indexer/cloud sync state where practical;
- power profile and plugged-in status.

### Benchmark Matrix

Minimum:

```text
macOS:
  APFS internal SSD
  ~/Library
  developer project with node_modules
  Xcode DerivedData
  battery vs plugged if laptop available

Windows:
  NTFS internal SSD
  user profile
  node_modules/project cache
  Defender enabled
  Windows Search Classic or Enhanced noted

Linux:
  ext4/btrfs internal SSD
  home directory
  cargo/npm/gradle caches
  nice/ionice support noted

External/network:
  USB disk
  SMB/NAS if available
  FUSE/rclone if available
```

## Product UI Requirements

### Required UI

Expose a simple mode selector:

```text
Balanced
Fast
Background
```

Optional advanced diagnostics:

```text
threads
event rate
current power state
thermal state
effective OS policy
scan queue pressure
slow client count
```

### Copy Rules

Do not over-explain internals in the main UI.

Good:

```text
Balanced
Fast
Background
```

Diagnostics:

```text
Background mode reduces CPU and disk priority where the OS allows it.
```

Avoid:

```text
Rayon thread pool using x workers with OS scheduler utility QoS and coalesced event pipeline
```

### Status Examples

```text
Scanning in Balanced mode
Scanning in Background mode because Battery Saver is on
Fast mode may increase fan noise and battery use
Paused due to critical thermal state
Reduced scan speed while target is on a network volume
```

## Configuration Shape

Suggested Rust-side config:

```toml
[resource.default]
profile = "balanced"

[resource.profiles.balanced]
max_scan_threads = "auto"
max_index_threads = 2
progress_events_per_second = 8
prefer_os_utility_qos = true

[resource.profiles.fast]
max_scan_threads = "auto_fast"
max_index_threads = 4
progress_events_per_second = 10
allow_high_io_pressure = true

[resource.profiles.background]
max_scan_threads = 2
max_index_threads = 1
progress_events_per_second = 2
prefer_os_background_qos = true
pause_on_critical_thermal = true
```

Do not make this public stable config until we test real machines.

## Protocol Shape

Events:

```text
resource_policy_applied
resource_policy_changed
power_state_changed
thermal_state_changed
scan_budget_changed
scan_throttled
slow_client_detected
sleep_gap_detected
```

Snapshot fields:

```text
effective_resource_profile
effective_scan_threads
effective_index_threads
progress_event_rate
os_resource_policy
power_state
thermal_state
throttle_reason
queue_pressure
```

These fields are diagnostic and product-visible selectively. They should not be required for old clients to function.

## Clean Architecture Rules

### Domain

Allowed:

- pure `ResourceProfile` value if needed;
- pure policy names and risk labels;
- no OS specifics.

Forbidden:

- Tokio;
- Rayon;
- pdu;
- `windows` crate;
- libc/pthread calls;
- battery APIs;
- WebSocket state;
- Flutter DTOs.

### Application

Allowed:

- `ResourceGovernor` port;
- `PowerStateProvider` port;
- scan budget use cases;
- resource policy decisions based on ports;
- session state transitions.

Forbidden:

- direct platform API calls;
- direct process priority changes;
- direct pdu config if that leaks adapter details.

### Infrastructure

Allowed:

- pdu adapter thread config;
- worker pools;
- OS priority adapters;
- power/thermal detection;
- cgroups/systemd integrations;
- metrics collectors.

### Interface

Allowed:

- HTTP/WS DTOs;
- CLI flags;
- admin config;
- capability endpoint.

### Presentation

Allowed:

- mode selector;
- concise warnings;
- diagnostics panel;
- responsive UI behavior.

## Testing Requirements

### Unit Tests

- resource profile maps to expected budget;
- battery saver maps Balanced to reduced budget;
- thermal critical pauses Background profile;
- Fast mode does not auto-disable from battery without explicit policy;
- unsupported platform capabilities degrade safely;
- old clients ignore new resource event fields.

### Integration Tests

- start scan in Balanced, switch to Background, verify event and effective policy;
- slow WebSocket client does not block scanner;
- query latency remains under budget during scan fixture;
- cancellation remains responsive while optional indexing is active;
- scan wake/resume rechecks target and policy;
- deleting while scanning same subtree marks scan data stale.

### Platform Tests

- macOS: QoS adapter applies only to worker threads where possible;
- Windows: background/EcoQoS policy does not slow control API;
- Linux: ionice/nice fallback reports unsupported clearly;
- remote/headless: config caps max sessions and threads.

### Manual Tests

- full user-home scan while moving mouse, opening Finder/File Explorer, and searching UI;
- scan on battery;
- scan while plugged in;
- scan while a build is running;
- scan while Docker Desktop is active;
- scan while browser tab is backgrounded;
- scan external disk and unplug in a test fixture;
- Windows scan with Defender enabled.

## MVP Cut Line

For the first serious implementation:

Must have:

- Balanced/Fast/Background profiles;
- explicit scanner thread cap;
- bounded event queues;
- throttled progress;
- Rust-owned tree with paginated queries;
- cancellation state;
- UI mode selector;
- benchmark notes for CPU, memory, thread count, and query latency.

Should have:

- Windows power status detection;
- macOS power/thermal detection;
- basic Linux power fallback;
- background profile OS priority on at least one platform;
- diagnostics panel.

Can wait:

- cgroups/systemd integration;
- fully adaptive IO control;
- per-volume auto-tuning;
- advanced custom profile editor;
- fan/noise telemetry;
- enterprise admin policy.

## Open Questions

- Can pdu expose enough control over Rayon/thread pool per scan, or do we need a fork/adapter layer with explicit pool ownership?
- Should desktop app run scanner inside same process or a worker child process for stronger OS priority isolation?
- Should local web daemon default to Background profile when no foreground desktop window is attached?
- What is the exact default thread formula after real benchmarks on macOS, Windows, and Linux?
- How much resource diagnostic UI belongs in the main app vs support bundle only?

## Summary

📌 Clean Disk should ship with resource budgets from the start. The best architecture is not "scan as fast as possible"; it is "scan as fast as the current profile allows while preserving control-plane, UI, and OS responsiveness." Resource policy belongs behind ports, platform knobs belong in infrastructure, and every benchmark must measure responsiveness, not only elapsed scan time.
