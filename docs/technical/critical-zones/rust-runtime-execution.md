# Critical Zone - Rust Runtime Execution

Last updated: 2026-05-16.

This file is the next focused global critical-zone file after
`update-release-rollback-safety.md`. It splits out the execution model from
`../preimplementation-critical-zones-deep-dive.md`.

## Sources Reviewed

- Tokio `spawn_blocking` docs: blocking tasks use a separate pool, the default
  upper limit is large, CPU-bound usage should be limited by a semaphore or
  specialized executor, and started blocking tasks cannot be aborted.
  Source: https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html
- Tokio graceful shutdown topic: shutdown has three parts - deciding when to
  shut down, telling tasks to shut down, and waiting for them to finish.
  Source: https://tokio.rs/tokio/topics/shutdown
- Tokio `mpsc`, `broadcast`, and `watch` docs: bounded queues, backpressure,
  lag detection, and latest-value channels.
  Sources:
  https://docs.rs/tokio/latest/tokio/sync/mpsc/fn.channel.html,
  https://docs.rs/tokio/latest/tokio/sync/broadcast/,
  https://docs.rs/tokio/latest/tokio/sync/watch/
- `tokio-util` `CancellationToken` and `TaskTracker` docs: cooperative
  cancellation and task waiting primitives.
  Sources:
  https://docs.rs/tokio-util/latest/tokio_util/sync/struct.CancellationToken.html
  and https://docs.rs/tokio-util/latest/tokio_util/task/struct.TaskTracker.html
- Rayon `ThreadPoolBuilder` docs: custom local pools, configured thread counts,
  named threads, and global pool construction.
  Source: https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html
- Rayon `ThreadPool::install` docs: nested Rayon work such as `join`, `scope`,
  and parallel iterators runs inside the selected pool.
  Source: https://docs.rs/rayon/latest/rayon/struct.ThreadPool.html#method.install
- Rust `catch_unwind`, Rust Reference panic guidance, and Rustonomicon FFI
  guidance: catching unwind is not general error handling, aborting panics
  cannot be caught, and unwinding across wrong FFI boundaries is unsafe.
  Sources:
  https://doc.rust-lang.org/std/panic/fn.catch_unwind.html,
  https://doc.rust-lang.org/reference/panic.html,
  https://doc.rust-lang.org/nomicon/ffi.html

## Why This Is The Next Global Critical Zone

Clean Disk can have a fast scanner, clean protocol, strong UI, and good delete
contracts, but still fail if the daemon runtime model is implicit. The daemon
must scan huge trees, enrich metadata, build indexes, serve HTTP, stream
WebSocket events, persist journals, and eventually coordinate cleanup. These are
different workloads with different latency, memory, cancellation, and shutdown
semantics.

Top 3 next global risks after the update/release file:

1. **Rust runtime execution and worker-pool isolation** - 🎯 9  🛡️ 10  🧠 8, roughly 1600-4200 LOC/tests/docs.
   Selected now. If this fails, the product gets stalls, fake cancellation,
   memory growth, shutdown hangs, panic poisoning, and unreliable progress.
2. **Recommendation policy false-positive and rule-pack safety** - 🎯 7  🛡️ 9  🧠 8, roughly 1400-3600 LOC/tests/docs.
   Still important. It should become a separate file before recommendation cards
   or rule-pack updates become implementation work.
3. **Restore, quarantine, and undo semantics after cleanup** - 🎯 6  🛡️ 9  🧠 9, roughly 1800-5000 LOC/tests/docs.
   Still important before cleanup beta. Move-to-Trash, cloud sync, NAS, and
   tool-managed stores do not share one restore model.

## Core Rule

Do not let Tokio, pdu, Rayon, WebSocket, SQLite, and platform APIs accidentally
share one implicit runtime contract.

Accepted direction:

```text
Tokio coordinates network and async control flow.
Long filesystem scans run in dedicated bounded worker lanes.
pdu is an adapter inside a controlled execution boundary.
Internal pdu Rayon work runs inside our bounded execution lane.
Cancellation is cooperative and measured.
Tree data is queried by pages, not streamed file-by-file.
Shutdown is an explicit state machine.
Panic containment fails a session, not the whole product state.
```

## Runtime Lanes

The daemon needs explicit execution lanes. A lane is an ownership boundary with
queue policy, budget, cancellation, and shutdown behavior. It is not always one
OS thread.

```text
RuntimeLane
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

- `async_transport` owns HTTP routing, WebSocket handshakes, auth, heartbeats,
  and small command dispatch only.
- Filesystem traversal, metadata enrichment, index building, support bundle
  export, and platform cleanup never run directly on async reactor threads.
- Each lane has queue size, concurrency limit, timeout, cancellation policy, and
  shutdown phase.
- `clean-disk-server` owns global process budgets. Reusable `fs_usage_*` crates
  expose knobs and capability reports, but do not decide global policy.
- Platform adapters with thread-affinity constraints, especially Windows Shell
  and COM, get their own lane.
- Event fanout never holds scanner locks while waiting on JSON encoding,
  WebSocket clients, or SQLite.

Kill criteria:

- one scan blocks cancel, ping, or health endpoints;
- pdu progress callback serializes DTOs or touches WebSocket clients directly;
- metadata enrichment uses the same unbounded pool as traversal;
- platform Trash work runs in a generic worker and blocks unrelated scans;
- support diagnostics cannot explain which lane was overloaded.

## `spawn_blocking` Policy

`spawn_blocking` is a bridge for bounded blocking calls, not the primary scan
runtime. Tokio documents that started blocking tasks cannot be aborted and that
runtime shutdown can wait for them.

Use it for:

- short filesystem probes;
- small compatibility checks;
- bounded adapter calls with clear timeout;
- spike code that will not ship as the scan runtime.

Do not use it for:

- one long scan task with no internal cancellation checkpoints;
- hidden global concurrency;
- pdu callback fanout;
- force-stopping filesystem traversal;
- long cleanup side effects.

Implementation options:

1. **Dedicated scanner lane with bounded workers** - 🎯 9  🛡️ 10  🧠 8, roughly 1600-4200 LOC/tests.
   Best fit. Gives observable budgets, cooperative cancellation, pdu containment,
   and honest shutdown.
2. **`spawn_blocking` plus strict semaphore and cooperative cancel** - 🎯 6  🛡️ 7  🧠 5, roughly 700-1800 LOC/tests.
   Useful as a spike. Weak for long scans because started blocking work cannot
   be reliably aborted.
3. **Child process scanner worker** - 🎯 5  🛡️ 8  🧠 9, roughly 2500-7000 LOC/tests.
   Strong isolation, but expensive for IPC, packaging, permissions, crash
   recovery, support diagnostics, and app identity.

Accepted MVP direction: option 1. Option 2 is allowed only as throwaway spike
code.

## Worker Budget Model

```text
ScanResourceProfile
  background
  balanced
  fast
```

```text
WorkerBudget
  scanner_threads
  metadata_threads
  index_threads
  max_active_scans
  max_pending_jobs
  max_event_queue_items
  max_query_page_size
  max_support_bundle_bytes
  io_priority_hint
  cpu_priority_hint
```

Rules:

- `balanced` is the default profile.
- `fast` is opt-in and visible to the user.
- `background` reduces CPU/IO pressure and event frequency.
- thread counts are capped globally, not per scan session.
- nested parallelism is explicitly tested: pdu traversal plus metadata
  enrichment plus index build.
- budget changes create a runtime event and are visible in diagnostics.
- queues reject or defer work with typed `resource_exhausted` errors instead of
  growing unbounded.

Kill criteria:

- two simultaneous scans each create one full CPU-sized pool;
- pdu uses a global pool and metadata enrichment creates another full CPU-sized
  pool without cap;
- Fast mode is only a UI label;
- low-memory state does not reduce queue, page, or event limits;
- support bundle export competes with cleanup receipt writes.

## pdu Adapter Execution Boundary

`parallel-disk-usage` remains an adapter, not the owner of product runtime
semantics.

```text
PduExecutionContract
  traversal_policy_fingerprint
  hardlink_policy
  symlink_policy
  mount_policy
  progress_policy
  cancellation_capability
  thread_capability
  callback_cost_budget
  adapter_version
```

Rules:

- only the pdu adapter crate imports `parallel_disk_usage`;
- pdu callbacks do constant or near-constant work and return quickly;
- callbacks enqueue compact internal events, not Flutter DTOs;
- final tree is converted into our read model after adapter boundary checks;
- adapter capability reports thread, progress, and cancellation support;
- pdu version and semantic option fingerprint are stored with scan snapshot
  metadata;
- unsupported pdu policy becomes degraded capability, not hidden behavior.

Kill criteria:

- pdu callback performs DB writes or expensive metadata reads;
- pdu final tree is sent directly to Flutter;
- pdu global settings leak into other library consumers;
- pdu panic keeps partially built read model as valid;
- pdu option changes do not invalidate old snapshot comparison.

## Channel And Backpressure Policy

One queue policy cannot serve terminal events, progress ticks, audit events, and
pageable tree data.

```text
EventPressureClass
  lossless_terminal
  lossless_safety_error
  lossless_receipt
  bounded_audit
  coalescable_progress
  coalescable_throughput
  pageable_tree_data
  discardable_debug
```

Rules:

- terminal, safety error, and receipt events cannot be dropped silently;
- progress and throughput use latest-value or coalescing semantics;
- tree data is never streamed file-by-file to Flutter;
- slow WebSocket clients get sequence gaps and `resync_required`, or are
  disconnected;
- event queues have fixed capacity and visible overflow behavior;
- scanner workers do not allocate unbounded buffers for slow clients.

Kill criteria:

- progress flood delays terminal event delivery;
- one web client grows daemon memory;
- queue overflow drops skipped-path or permission evidence;
- reconnect attempts to replay unbounded RAM history;
- event loss is hidden from Flutter.

## Cancellation And Pause Semantics

Cancellation is cooperative because filesystem traversal and platform APIs
cannot always be force-stopped safely.

```text
CancellationCheckpoint
  before_enter_directory
  after_read_dir_batch
  before_metadata_batch
  before_index_batch
  before_event_batch
  before_delete_plan_validation
  before_platform_side_effect
  before_receipt_commit
```

Rules:

- cancel command must be accepted quickly even while scan is busy;
- scan workers observe cancellation through token or atomic state;
- UI receives `cancelling` before terminal `cancelled`;
- cancellation latency is measured in balanced and fast profiles;
- partial scan result is explicitly marked partial, stale, or discarded;
- pause is implemented only if worker state can be quiesced honestly;
- delete cancellation is separate from scan cancellation because side effects may
  already have occurred.

Kill criteria:

- UI says cancelled before worker reached safe checkpoint;
- cancelled scan becomes a normal complete snapshot;
- delete cancellation shares scan cancellation states;
- pause suspends event delivery but not resource use;
- reconnect after cancellation shows old running state.

## Panic And Poisoned-State Policy

Panics are not product errors. Product errors use `Result` and typed error
taxonomy. A panic is an invariant violation or bug.

```text
PanicBoundary
  scanner_worker_root
  metadata_worker_root
  index_builder_root
  platform_adapter_root
  support_bundle_worker_root
```

Rules:

- catch unwind only at worker roots where state can be safely discarded;
- after panic, affected session becomes `failed_internal` or `poisoned`;
- partially built indexes are dropped or rebuilt, never trusted;
- panic payloads are redacted before logs or support bundles;
- panic across FFI, FRB, C ABI, plugin, or platform callback boundaries is
  forbidden;
- panic strategy is documented for release builds;
- tests inject panic at worker roots and verify recovery state.

Kill criteria:

- `catch_unwind` wraps domain logic as if it were try/catch;
- session continues after panic with the same mutable index;
- panic payload logs raw path or token;
- adapter panic is mapped to permission denied;
- release panic strategy contradicts runtime containment design.

## Shutdown And Recovery State Machine

Shutdown is not a destructor. It is a protocol.

```text
ShutdownPhase
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

- stop accepting new scan/delete commands before cancelling active work;
- cancellation reaches workers before transport closes;
- journal and receipt writes have reserved IO budget;
- WebSocket lifecycle event is sent when time allows;
- forced stop writes or preserves enough state for next-start reconciliation;
- update/uninstall cannot remove active runtime evidence;
- restart never resumes destructive side effects without revalidation.

Kill criteria:

- update kills daemon during cleanup with no unknown-outcome marker;
- forced stop deletes quarantine/temp evidence before receipt;
- daemon closes socket first, then tries to notify UI;
- restart resumes delete from old plan without live identity revalidation;
- support bundle cannot tell whether previous stop was clean.

## Runtime Observability

Runtime diagnostics need to explain pressure without leaking raw paths.

```text
RuntimeHealthSnapshot
  active_profile
  active_scans
  lane_queue_depths
  lane_worker_counts
  dropped_event_counts_by_class
  coalesced_event_counts
  cancel_latency_ms_p50_p95
  shutdown_phase
  last_unclean_shutdown
  panic_boundary_failures_redacted
  current_resource_limits
```

Rules:

- queue depth and dropped event counts are low-cardinality metrics;
- raw paths and raw search text are not metric labels;
- support bundle includes lane pressure, not full queue contents;
- runtime health endpoint is authorized and safe for local UI;
- slow scan and slow event client are diagnosable as different states.

Kill criteria:

- diagnostics require dumping full scan tree;
- metrics include path segments or usernames;
- panic reports include raw target path;
- slow scan cannot be distinguished from slow client;
- support bundle hides resource budget decisions.

## Required Spikes Before Daemon MVP

1. **Tokio responsiveness under heavy scan**
   🎯 9  🛡️ 10  🧠 8, roughly 700-1800 LOC/tests.
   Start synthetic scanner load and prove HTTP health, cancel, and WebSocket
   heartbeat latency remain within budget.

2. **Bounded event pressure**
   🎯 8  🛡️ 10  🧠 8, roughly 900-2400 LOC/tests.
   Simulate slow WebSocket clients, progress flood, terminal events, and
   reconnect. Prove lossless classes survive and coalescable classes do not grow
   memory.

3. **Panic and forced-shutdown recovery**
   🎯 7  🛡️ 9  🧠 8, roughly 900-2600 LOC/tests.
   Inject worker panic, kill daemon mid-scan, force shutdown during journal
   flush, and verify recovery state is explicit and non-destructive.

## Minimal Acceptance Gates

Before product scan UI depends on the daemon:

- health endpoint and WebSocket heartbeat stay responsive during worst-case scan
  fixture;
- cancel command latency has measured budget in balanced and fast profiles;
- scanner lane concurrency is capped globally;
- pdu callback cost is bounded and tested;
- terminal events are lossless under slow-client pressure;
- tree data is served only by paginated query APIs;
- panic at worker root poisons only affected session;
- forced shutdown leaves next-start recovery marker;
- support bundle can explain runtime pressure without raw paths.

## Architecture Placement

```text
crates/
  fs_usage_engine/
    src/
      application/
        ports/
          scanner.rs
          runtime_budget.rs
          event_sink.rs
        services/
          scan_session_service.rs
          read_model_service.rs
      domain/
        scan_session.rs
        scan_profile.rs
        scan_event.rs
        runtime_health.rs

  fs_usage_pdu_adapter/
    src/
      adapter.rs
      execution_contract.rs
      pdu_event_mapper.rs

apps/
  clean_disk_server/
    src/
      runtime/
        lanes.rs
        budgets.rs
        shutdown.rs
        panic_boundary.rs
        health.rs
      transport/
        http/
        websocket/
      composition/
        app_state.rs
        adapters.rs
```

Layer rules:

- `fs_usage_engine` defines ports and product-neutral runtime contracts;
- `fs_usage_pdu_adapter` implements scanner adapter mechanics only;
- `clean_disk_server` owns Tokio runtime, worker lane construction, global
  budgets, shutdown, transport, and observability;
- Flutter never observes worker-pool internals directly. It sees protocol
  capability, progress, health, and typed errors.

## Summary

The next global critical zone is the Rust daemon execution model. It is the
foundation beneath scan speed, protocol correctness, cancellation truth, memory
safety, remote mode, and cleanup reliability.

The practical rule is simple:

```text
Make execution lanes explicit, bounded, observable, cancellable, and recoverable.
```
