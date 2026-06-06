# Implementation Edge Cases - Performance, Scale, And Benchmarking

This file records performance and scale edge cases for Clean Disk.

The goal is not to prematurely optimize. The goal is to avoid architecture choices that make a 500 GB disk, millions of files, or a slow browser tab impossible to handle later.

Related documents:

- [Implementation edge cases](implementation-edge-cases.md)
- [Implementation edge cases advanced scenarios](implementation-edge-cases-advanced-scenarios.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Rust best practices research](rust-best-practices.md)

## Sources Reviewed

- Flutter, [Performance best practices](https://docs.flutter.dev/perf/best-practices). Relevant points: large grids/lists should use lazy builder methods, expensive build/layout work causes problems, and intrinsic layout can be costly.
- Flutter, [Concurrency and isolates](https://docs.flutter.dev/perf/isolates). Relevant points: isolates are appropriate when large computations cause UI jank, message passing copies mutable data, long-lived isolates can reduce repeated spawn overhead, and Flutter web does not support isolates.
- Flutter API docs, [DataTable performance considerations](https://api.flutter.dev/flutter/material/DataTable-class.html). Relevant points: `DataTable` is expensive for large data because columns are measured twice, and `SingleChildScrollView` mounts/paints the entire child.
- Flutter, [Performance profiling](https://docs.flutter.dev/perf/ui-performance). Relevant points: 60 fps means roughly 16 ms per frame, and jank appears when frames take much longer.
- Tokio docs, [`spawn_blocking`](https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html). Relevant points: blocking work should not run inside normal async futures, the blocking thread upper limit is large, CPU-bound work needs explicit limiting or a specialized executor, and started blocking tasks cannot be aborted.
- Tokio docs, [`Semaphore`](https://docs.rs/tokio/latest/tokio/sync/struct.Semaphore.html). Relevant points: semaphores are useful for limiting access to shared resources, including open files and request rates.
- Rayon docs, [`ThreadPoolBuilder`](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html). Relevant points: Rayon thread pools can be built/configured explicitly and thread counts can be fixed.
- Rust Performance Book, [Profiling](https://nnethercote.github.io/perf-book/profiling.html). Relevant points: use platform profilers such as Instruments, VTune, `perf`, heaptrack, and domain-specific counters.
- Criterion.rs, [Documentation](https://bheisler.github.io/criterion.rs/book/index.html). Relevant points: Criterion is statistics-driven and can detect regressions across runs.
- `parallel-disk-usage`, [docs.rs crate docs](https://docs.rs/parallel-disk-usage/latest/parallel_disk_usage/). Relevant point: `pdu` exposes a library crate with tree-building APIs, so production integration can stay behind an adapter.
- `jwalk`, [docs.rs crate docs](https://docs.rs/jwalk/latest/jwalk/). Relevant points: `jwalk` is parallel using Rayon and can stream sorted entries, which matters if we fork/patch scanner behavior.
- Rust std docs, [`Vec::try_reserve`](https://doc.rust-lang.org/std/vec/struct.Vec.html#method.try_reserve). Relevant point: large allocations can return a typed error instead of failing mid-work.
- Rust std docs, [`HashMap`](https://doc.rust-lang.org/std/collections/struct.HashMap.html) and [`BTreeMap`](https://doc.rust-lang.org/std/collections/struct.BTreeMap.html). Relevant points: `HashMap` iteration order is arbitrary; `BTreeMap` iterates in key order.
- `bytes`, [docs.rs `Bytes`](https://docs.rs/bytes/latest/bytes/struct.Bytes.html). Relevant point: `Bytes` is cheaply cloneable and sliceable for transport-oriented buffers, but should not leak into domain models.
- Dart docs, [Concurrency on the web](https://dart.dev/language/concurrency#concurrency-on-the-web). Relevant points: Dart web does not support isolates and web workers copy data back and forth.

## Severity Scale

- `P0` - can make large scans unusable, freeze UI, exhaust memory, corrupt delete selection through stale data, or make performance claims false.
- `P1` - can cause latency spikes, excessive CPU/memory, non-deterministic behavior, or hard-to-debug regressions.
- `P2` - important polish, diagnostics, platform variation, or long-term maintainability issue.

## Top 3 Performance Decisions

1. Rust owns live scan tree/indexes and Flutter receives only pages - 🎯 10 🛡️ 10 🧠 5, roughly 500-1100 LOC across Rust indexes, protocol DTOs, Flutter stores, and tests.
2. Dedicated scan execution budget instead of unbounded Tokio/Rayon/thread stacking - 🎯 9 🛡️ 9 🧠 6, roughly 400-1000 LOC across scanner jobs, adapter config, cancellation, metrics, and benchmarks.
3. Macro benchmark suite before performance claims - 🎯 9 🛡️ 8 🧠 5, roughly 300-900 LOC across fixture generator, benchmark runner, reports, and CI profile.

## Core Rule

Performance must be measured by node count, directory shape, metadata calls, indexing cost, transfer size, UI frame stability, and delete revalidation cost.

Do not measure only by gigabytes.

A 500 GB disk with 30 huge video files is easy. A 40 GB developer directory with millions of tiny files can be much harder.

## Rust Scanner And Runtime

### Thread Budget Is A Product Decision - `P0`

Clean Disk can have several thread pools at once:

- Tokio async runtime for HTTP/WebSocket control plane;
- Tokio blocking pool if `spawn_blocking` is used;
- Rayon pool if `pdu`, `jwalk`, or our own indexing uses Rayon;
- OS/file provider/antivirus/background sync threads outside our process;
- Flutter engine/UI threads in desktop mode.

Risk:

- scanner starves HTTP status endpoint;
- WebSocket heartbeat stalls;
- CPU-bound indexing fights filesystem traversal;
- laptop fan and battery usage become unacceptable;
- too much parallel metadata IO makes network shares or external disks slower.

Required behavior:

- define a `ThreadBudget` config in Rust composition root;
- do not let scanner adapter pick uncontrolled global thread counts by accident;
- prefer a scanner-owned execution pool or explicitly configured Rayon pool when possible;
- use semaphores/permits for open-file and metadata concurrency;
- expose debug metrics: active scanner workers, queued scanner jobs, active blocking tasks, event queue length;
- benchmark `threads = 1, 2, 4, 8, auto` on real fixtures before choosing defaults.

### `spawn_blocking` Is Not A Scanner Architecture - `P1`

Tokio `spawn_blocking` is useful for bounded blocking work, but docs warn that CPU-bound work needs explicit limiting and that started blocking tasks cannot be aborted.

Required behavior:

- use `spawn_blocking` only for short, bounded blocking calls or adapter boundaries;
- long-running scan sessions should have cooperative cancellation, explicit worker ownership, and lifecycle tracking;
- shutdown must not rely on aborting already-started blocking tasks;
- if pdu scan is a blocking call, wrap it in a session worker with cancellation signal and terminal event handling;
- never run scan/index loops inside normal async route handlers.

### Scanner Parallelism Must Be Adaptive - `P1`

The fastest setting differs by storage:

- NVMe internal SSD;
- external USB SSD/HDD;
- APFS encrypted volume;
- NTFS volume;
- SMB/NFS network share;
- cloud-synced placeholder tree;
- antivirus-monitored Windows path.

Required behavior:

- default to conservative parallelism for unknown/network/removable targets;
- allow advanced override in debug settings;
- record device/target class when known;
- detect latency spikes and throttle progress/event pressure;
- avoid interpreting lower throughput as "scanner bug" without target classification.

### `pdu` Adapter Must Have A Performance Contract - `P0`

`parallel-disk-usage` is the selected scanner adapter, not the domain model. Its library APIs are useful, but the product still needs its own guarantees.

Adapter contract should expose:

- scan start/cancel lifecycle;
- progress snapshots;
- final tree build result;
- skipped/error entries;
- hardlink policy;
- thread/parallelism options if available;
- memory/node stats if available;
- adapter version and feature flags.

Required behavior:

- benchmark raw `pdu` separately from our indexing/protocol/UI;
- snapshot pdu option mapping so crate upgrades do not change behavior silently;
- if pdu cannot emit enough progress, add adapter-side progress or fork behind the same port;
- if pdu uses internal global parallelism that cannot be tuned, document the limitation and measure it under load.

### Hardlink Dedup Cost Is A Switch, Not A Hidden Default - `P1`

Hardlink deduplication needs identity tracking and can add memory/hash overhead.

Required behavior:

- expose hardlink policy in scan options and result metadata;
- benchmark with and without dedup on real trees;
- show confidence/semantic label in UI;
- do not pay global dedup cost unless policy requires it.

### Allocation Failure Must Become A Typed Scan Failure - `P0`

Millions of nodes can exhaust memory. Rust safety does not remove memory limits.

Required behavior:

- estimate memory per node before accepting unbounded scans;
- use `try_reserve` or equivalent fallible allocation at large growth points;
- return `resource_exhausted` with partial scan stats where possible;
- define max node budget per session and max concurrent sessions;
- expose peak memory in benchmark reports;
- avoid retaining both raw pdu tree and our full indexed tree longer than necessary.

### Path And String Storage Can Dominate Memory - `P1`

Naively storing full paths for every node can multiply memory usage.

Recommended model:

- node stores compact ID, parent ID, name segment, type, sizes, counts, timestamps, flags;
- full path is reconstructed lazily for details, receipt, and reveal actions;
- hot display names may use `Arc<str>` or string interning only after profiling;
- protocol pages send display path only where UI needs it;
- receipt stores original path independently from scan cache.

Avoid lifetime-heavy public APIs for theoretical wins. Measure first.

### Indexing Can Be Slower Than Traversal - `P1`

After traversal, the app still needs:

- child pages;
- largest folders;
- largest files;
- search;
- type/category breakdown;
- details panel;
- cleanup candidate lists.

Required behavior:

- build only indexes needed by visible product features;
- use bounded top-K structures for largest items;
- do not globally sort millions of nodes for each query;
- cache sorted child order by `(parent_id, sort_key, filter_hash, index_version)` only if measured useful;
- mark index build as a separate phase in status and metrics.

### Deterministic Ordering Is Required For Tests And UI - `P1`

Rust `HashMap` iteration is arbitrary. This can make pages, snapshots, and benchmark output unstable.

Required behavior:

- never derive UI order from raw `HashMap` iteration;
- use explicit sort keys and tie-breakers;
- use `BTreeMap` or sorted vectors where deterministic iteration is more important than raw insertion speed;
- benchmark map choice in hot indexes;
- protocol snapshots must be stable across runs.

### File Handles And Directory Iterators Need Permits - `P1`

Parallel traversal can exceed OS or provider limits.

Required behavior:

- global scan permit for open directories/files;
- separate network/removable target permit profile;
- release permits on cancellation and panic paths;
- test with low file-descriptor limits on Unix;
- map "too many open files" into typed error/warning.

## Protocol And Data Transfer

### JSON Is Fine Until It Is Not - `P1`

HTTP/WebSocket JSON is the first accepted transport format. It is easier to debug and version, but large payloads can create parse and allocation pressure.

Required behavior:

- keep JSON pages small and bounded;
- do not send the entire tree;
- measure response payload bytes and parse time;
- keep DTOs flat enough for fast encode/decode;
- add binary/protobuf/messagepack only after profiling shows JSON is a real bottleneck;
- protocol format is adapter detail, not domain model.

### Progress Events Must Be Coalesced - `P0`

Scanner can discover entries faster than UI can render or browser can receive.

Required behavior:

- latest progress is a replaceable state, not a durable event per file;
- semantic events are preserved: started, skipped, error, completed, cancelled, failed;
- progress batches have max frequency and max payload size;
- clients can request current summary after missed events;
- slow clients are isolated with bounded queues.

### Page Size Is A Tuning Knob - `P1`

Too small pages cause request overhead and visible loading. Too large pages cause parse jank and memory spikes.

Required behavior:

- default page size starts conservative, for example 100-300 rows;
- support client-requested page size with server max;
- record query p50/p95/p99 latency by page size;
- UI can prefetch one nearby page only when scrolling is stable;
- web client should use smaller defaults if parse/render jank appears.

### Compression Has A CPU Tradeoff - `P2`

Path-heavy JSON compresses well, but compression costs CPU and can increase latency on small pages.

Required behavior:

- disable compression for tiny responses;
- benchmark compression for large exports and report downloads;
- do not compress WebSocket progress by default without measuring;
- never make compression required for local protocol correctness.

### Transport Buffers Are Not Domain Models - `P1`

Crates like `bytes::Bytes` are useful for cheap sharing/slicing in transport code, but domain/application APIs should not expose them.

Required behavior:

- use transport buffer optimizations only in HTTP/WebSocket adapters;
- domain/application owns typed structs and IDs;
- avoid copying large response bodies more than necessary in interface layer;
- do not optimize buffer representation before page size and query boundaries are correct.

## Flutter UI Scale

### Do Not Use `DataTable` For The Main Tree - `P0`

Flutter docs say `DataTable` measures columns twice and `SingleChildScrollView` mounts/paints the entire child. That is incompatible with a million-node tree.

Required behavior:

- main tree/table uses virtualized/lazy rows;
- visible rows only are built;
- row height is stable;
- columns have fixed or bounded widths;
- horizontal and vertical scrolling are coordinated without mounting the whole grid;
- if Headless lacks this primitive, report it before building a workaround.

Candidate UI strategies:

1. Custom virtualized tree table over slivers - 🎯 9 🛡️ 8 🧠 7, roughly 900-1800 LOC.
2. `TableView` from `two_dimensional_scrollables` wrapped by design system - 🎯 8 🛡️ 8 🧠 5, roughly 400-1000 LOC, depends on API fit and styling.
3. Paginated list/table only - 🎯 6 🛡️ 7 🧠 3, roughly 250-600 LOC, simpler but worse for explorer-like navigation.

### 16 ms Frame Budget Is A Hard UI Constraint - `P0`

Flutter targets 60 fps with roughly 16 ms per frame. Clean Disk should not rebuild the whole screen on every progress event.

Required behavior:

- split scan progress, tree rows, details, queue, and metrics into separate stores/selectors;
- progress updates do not rebuild tree rows;
- row hover/selection does not rebuild summary cards;
- visible row widgets are cheap and mostly const/static where possible;
- expensive formatting is memoized or done before row build;
- use DevTools frame chart and rebuild profiler before accepting UI changes.

### JSON Parsing Can Jank Desktop And Web Differently - `P1`

Flutter isolates help on desktop/mobile for large parsing, but Flutter web does not support isolates. Dart web can use web workers, but they have different build and copy behavior.

Required behavior:

- keep normal page responses small enough to parse on main isolate;
- avoid relying on isolates for web correctness;
- for desktop-only large import/export parsing, consider long-lived isolates;
- for web, prefer smaller pages and progressive rendering before worker complexity;
- benchmark parse time separately from network time.

### Tree Expansion Must Not Rebuild The World - `P1`

Expanding a folder can insert hundreds or thousands of visible descendants.

Required behavior:

- view model stores flattened visible row IDs separately from full tree;
- expansion updates only affected range;
- large expansion can load first page and show "load more";
- collapse removes visible descendants without destroying cached Rust index;
- scroll anchor remains stable.

### Charts And Donuts Are Secondary Views - `P2`

The reference UI includes charts, but charts should not cost more than the table.

Required behavior:

- charts use summary data from Rust, not client aggregation over all nodes;
- redraw charts at lower frequency than raw progress events;
- avoid expensive blur/glow/opacity animation in the dense table area;
- charts are hidden/collapsed first on compact width if performance suffers.

### Text Layout Can Become A Hot Path - `P2`

Paths are long, localized, and can contain difficult characters.

Required behavior:

- use ellipsis and stable width constraints;
- avoid measuring all offscreen path text;
- cache formatted size/date strings for visible page DTOs;
- show full path in details/tooltip, not every row;
- use monospace only where alignment matters, not for all text.

## Cache And Persistence

### Live Tree Cache Is Not App History - `P1`

The live scan tree is a large in-memory read model. Persistent scan history is a different feature.

Required behavior:

- do not persist full live tree by default;
- persist summaries and receipts first;
- if detailed history is added, use versioned snapshots with retention limits;
- cache invalidation is explicit by scan session and index version;
- Drift/SQLite is not automatically the right store for live million-node mutation.

### Incremental Refresh Can Cost More Than Rescan - `P2`

Watchers and incremental updates sound attractive but can create complex correctness and performance costs.

Required behavior:

- MVP treats scan result as snapshot;
- watcher events are invalidation hints, not truth;
- if incremental refresh is added, benchmark update cost versus rescan;
- do not maintain live indexes for paths user is not viewing unless there is a clear product need.

### Search Index Must Be Scoped - `P1`

Full-text-ish search over millions of paths can use significant memory.

Required behavior:

- MVP can use substring search over indexed names with bounded result count;
- search queries are cancellable/debounced;
- search results are paginated;
- full path search is optional if memory cost is high;
- advanced token/trigram/fuzzy index is a measured upgrade, not default.

## Benchmarking Strategy

### Macro Benchmarks Are Mandatory - `P0`

Microbenchmarks do not answer whether the product feels fast. We need macro benchmarks for scanner + indexing + protocol + UI.

Required benchmark dimensions:

- OS: macOS, Windows, Linux;
- filesystem: APFS, NTFS, ext4, external volume, network share where possible;
- target shape: few huge files, many tiny files, deep tree, wide tree, mixed developer home;
- cache state: cold-ish and warm;
- scan options: hardlink dedup on/off, mount boundary on/off;
- client mode: desktop UI, browser web UI, CLI/status-only;
- power state: plugged in vs battery where practical.

### Benchmark Metrics Must Match Product Questions - `P0`

Record at least:

- time to first visible progress;
- time to first useful top folders;
- final scan time;
- index build time;
- peak RSS memory;
- node count;
- file count;
- directory count;
- skipped/error count;
- metadata errors by code;
- event batches sent/dropped/coalesced;
- WebSocket queue max depth;
- page query latency p50/p95/p99;
- search latency p50/p95/p99;
- Flutter frame jank during active scan;
- CPU usage and thread count.

Do not publish one "GB/s" number as if it explains the product.

### Regression Budget Needs Thresholds - `P1`

Performance tests without thresholds become vanity reports.

Required behavior:

- establish baseline on known fixture;
- fail CI only for stable synthetic benchmarks;
- track real-world benchmark reports manually or in nightly jobs;
- record hardware and OS details;
- mark noisy metrics as trend-only;
- store benchmark output in a structured format.

### Synthetic Fixtures Need Realistic Shape - `P1`

Random files in one folder do not represent a user disk.

Fixture set:

- `tiny_many`: hundreds of thousands of small files;
- `deep_tree`: thousands of nested directories;
- `wide_tree`: one directory with many children;
- `dev_home`: node_modules, Cargo target, build outputs, package caches;
- `media_large`: few huge files;
- `permissions_mixed`: denied/skipped paths;
- `unicode_paths`: long, bidi, emoji, normalization variants;
- `hardlinks`: duplicated hardlink entries;
- `sparse_compressed`: platform-specific allocated-size cases.

### Benchmarking Must Include UI - `P1`

Raw pdu speed is not enough. The product must stay responsive.

Required behavior:

- run UI benchmarks with active progress stream;
- measure frame jank while scrolling table during scan;
- measure details panel selection latency;
- measure search typing latency;
- measure add-to-queue latency from selected row;
- verify compact and wide layouts separately.

## Remote And Web Scale

### Remote Server Mode Changes Bottleneck - `P1`

Local desktop mode is disk/CPU/memory bound. Remote mode can be network and auth bound.

Required behavior:

- page responses remain small;
- avoid long-polling large payloads;
- WebSocket events are per authorized session;
- remote server can enforce per-user scan/session quotas;
- remote UI shows target host and scan source to avoid false local assumptions.

### Browser Memory Is A Product Limit - `P1`

Browser tabs have practical memory limits and can be background-throttled.

Required behavior:

- browser never holds full tree;
- reconnect/resync handles background tab throttling;
- page cache has max row/page count;
- large exports download as files/streams, not giant in-memory strings;
- web UI can degrade charts before table workflow.

## Observability

### Domain-Specific Counters Beat Guessing - `P1`

Profilers show hot code, but product counters explain why a scan is slow.

Counters to add:

- directories opened;
- metadata calls;
- metadata failures;
- symlink/reparse decisions;
- cloud placeholder count;
- hardlink table size;
- nodes allocated;
- index entries allocated;
- query cache hits/misses;
- progress coalescing ratio;
- slow client drops;
- current scanner permit usage.

### Logs Must Not Become A Performance Problem - `P2`

Logging every path or every node will destroy performance and leak privacy.

Required behavior:

- log session-level spans and aggregate counters;
- sample repeated errors;
- never log every scanned path in production;
- debug verbose path logging is opt-in and local;
- benchmark with normal logging enabled.

## Testing Checklist

### Rust Performance/Scale Tests

- million-node synthetic index can be built within memory budget;
- `try_reserve` failure maps to `resource_exhausted`;
- top-K query does not sort all nodes;
- `HashMap` iteration does not leak into protocol snapshot order;
- scanner cancellation releases permits;
- WebSocket slow client cannot grow unbounded queue;
- hardlink dedup memory cost is measured;
- pdu adapter benchmark reports raw scan time and post-index time separately.

### Flutter Performance Tests

- main tree renders only visible rows;
- progress update does not rebuild all rows;
- selecting a row does not rebuild summary cards;
- expanding/collapsing large folder keeps scroll anchor stable;
- large JSON page parse stays under budget on desktop and web;
- DataTable is not used for the central scan tree;
- wide and compact layouts stay below jank threshold while progress stream is active.

### End-To-End Benchmarks

- first visible progress under target threshold;
- first useful top folders under target threshold;
- active scan + scrolling remains responsive;
- search latency remains acceptable at 100k, 1m, and larger node fixtures;
- memory peak is recorded and does not grow unbounded after session dispose;
- repeated scans do not leak sessions, queues, event logs, or page cache.

## MVP Cut Line

MVP should include:

- raw pdu scan benchmark;
- Rust index benchmark;
- bounded progress event stream;
- paginated tree queries;
- no full-tree transfer to Flutter;
- virtualized/lazy tree UI;
- node and memory counters;
- page query latency metrics;
- manual benchmark script for Downloads/Library-like real folders;
- UI profiling pass for wide and compact references.

MVP can defer:

- binary protocol;
- compression tuning;
- advanced fuzzy search index;
- persistent detailed scan history;
- automatic adaptive thread tuning;
- browser web worker parsing;
- remote multi-user quotas.

## Summary

Clean Disk performance should be designed around a simple invariant:

```text
scan fast, index deliberately, transfer pages, render lazily, measure everything
```

The most dangerous performance bug is not "Rust scanner is a bit slower". The dangerous bug is accidentally moving the whole tree, whole sort, or whole render into Flutter.
