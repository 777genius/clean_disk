# Critical Zone - Persistent Operation Journal And Receipt Durability Under Low Disk

Last updated: 2026-05-16.

This file is the next focused global critical-zone file after
`remote-headless-destructive-cleanup-authorization.md`. It covers the durable
safety record behind destructive workflows: operation journal, receipt skeleton,
per-item outcomes, crash recovery, low-disk behavior, SQLite policy, support
export, migration, and corruption handling.

## Sources Reviewed

- SQLite Atomic Commit: SQLite transactions are designed to appear atomic across
  crashes and power loss, but durability depends on journal mode, sync settings,
  filesystem behavior, and avoiding unsafe modes.
  Source: https://www.sqlite.org/atomiccommit.html
- SQLite Write-Ahead Logging: WAL has extra `-wal` and `-shm` files, checkpoint
  behavior, durability differences between `synchronous=FULL` and
  `synchronous=NORMAL`, and a requirement that WAL state stays with the DB.
  Source: https://www.sqlite.org/wal.html
- SQLite PRAGMA `synchronous`: WAL with `FULL` is ACID, while WAL with `NORMAL`
  can lose durability after power loss or system crash.
  Source: https://www.sqlite.org/pragma.html#pragma_synchronous
- SQLite result codes: `SQLITE_FULL` means a write could not complete because
  the disk is full, and it can happen while writing main database or temporary
  files.
  Source: https://www.sqlite.org/rescode.html
- SQLite testing docs: SQLite explicitly tests OOM, disk I/O errors, power-loss
  recovery, and compound failure cases through fault injection.
  Source: https://www.sqlite.org/testing.html
- SQLite Online Backup API: live DB backup should use SQLite backup mechanisms
  instead of casual file copying, especially when WAL state may exist.
  Source: https://sqlite.org/backup.html
- SQLite corruption guidance: SQLite depends on filesystem locking correctness;
  network filesystems and direct file access while SQLite owns the DB can create
  corruption risk.
  Source: https://www.sqlite.org/howtocorrupt.html
- SQLite VACUUM: `VACUUM` can need up to twice the original DB size in free
  space, and `VACUUM INTO` can create a consistent snapshot but an interrupted
  output database may be incomplete.
  Source: https://www.sqlite.org/lang_vacuum.html
- Linux `fsync(2)` man page: `fsync` on a file does not necessarily persist the
  containing directory entry; `ENOSPC` can happen while synchronizing.
  Source: https://www.kernel.org/pub/linux/docs/man-pages/book/man-pages-6.06.pdf
- Microsoft `FlushFileBuffers`: Windows buffers file writes and the API flushes
  buffered file data to the device; it can be expensive and must be used
  intentionally for critical data.
  Source:
  https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-flushfilebuffers

## Why This Is The Next Global Critical Zone

Clean Disk is a cleanup tool. The most dangerous failure mode is not only
"deleted the wrong thing". It is also:

```text
we performed a destructive side effect but cannot prove what happened
```

This can happen exactly when users need the tool most: when the disk is almost
full. Low disk can break DB writes, temp files, checkpoints, support export,
logs, cache writes, and receipts. If the journal or receipt cannot be written,
cleanup safety collapses:

- user cannot see what was moved, skipped, failed, or unknown;
- restore/undo UI has incomplete evidence;
- crash recovery cannot know whether an item was dispatched to Trash;
- duplicate command retry can repeat side effects;
- remote audit can lose the actor or policy decision;
- support cannot distinguish app bug, OS failure, or user cancellation;
- release/update can migrate away safety evidence.

This is P0 before any cleanup beta. It also affects remote/headless cleanup,
tool-command cleanup, restore/quarantine, update quiesce, support bundles, and
operational reliability.

## Current Global Ranking

1. **Persistent operation journal and receipt durability under low disk** - 🎯 8  🛡️ 10  🧠 9, roughly 1800-5200 LOC/tests/docs.
   Selected now. It is the last line of truth after crash, OS shutdown,
   partial Trash execution, low disk, update, migration, and support export.

2. **Support bundle, diagnostics export, and privacy-preserving evidence** - 🎯 8  🛡️ 10  🧠 8, roughly 1600-4600 LOC/tests/docs.
   Next candidate because diagnostics must be useful without exporting raw
   paths, receipts, command output, tokens, scan trees, crash memory, or remote
   audit data.

3. **Remote deployment and pairing lifecycle** - 🎯 6  🛡️ 8  🧠 9, roughly 1800-5200 LOC/tests/docs.
   Important if web/headless/server usage becomes productized beyond local
   daemon-served UI.

## Core Rule

No destructive side effect can start unless the durable safety record is ready.

```text
delete plan confirmed
  -> durable operation intent written
  -> durable receipt skeleton written
  -> preflight identity and policy recorded
  -> per-item dispatch marker written
  -> side effect called
  -> per-item outcome written
  -> terminal operation status written
  -> receipt finalized
```

Rules:

- intent is written before filesystem side effects;
- receipt ID exists before execution starts;
- every item has an `in_flight` marker before native Trash/delete/tool command
  dispatch;
- final receipt is complete only after all item outcomes are known;
- crash between dispatch and outcome becomes `unknown_requires_review`;
- interrupted operations never auto-resume destructive side effects;
- receipt write failure stops starting new item side effects;
- cache, logs, scan indexes, and telemetry are lower priority than journal and
  receipt writes.

Kill criteria:

- cleanup can start with receipt only in memory.
- outcome is written only after the full batch.
- crash recovery retries incomplete delete automatically.
- receipt write failure is logged but cleanup continues.
- cache transaction and receipt transaction share one mixed batch.

## Storage Classes

Different data needs different durability.

```text
StorageClass
  rebuildable_cache
  user_preferences
  scan_history
  critical_operation_journal
  destructive_receipt
  audit_record
  local_secret
  debug_log
  support_export
```

Rules:

- critical journal and destructive receipts have stricter settings than cache;
- critical safety data is Rust-daemon-owned through an application port;
- Flutter does not directly open the safety DB;
- cache clearing never deletes receipts or active journals;
- support bundle generation never raw-copies a live safety DB;
- DB ownership is one product writer, even if SQLite can technically handle
  multiple connections.

Accepted storage split:

1. **Dedicated Rust-owned safety SQLite DB** - 🎯 8  🛡️ 10  🧠 8, roughly 900-2600 LOC/tests.
   Best fit. Clean boundary, mature transactions, queryable receipts, and
   strong crash behavior if settings and tests are serious.

2. **Append-only custom journal plus SQLite read model** - 🎯 5  🛡️ 7  🧠 9, roughly 1800-5200 LOC/tests.
   Attractive on paper, but writing a crash-safe log correctly is its own
   storage engine. Not MVP.

3. **Reuse Flutter/Drift app DB for safety records** - 🎯 4  🛡️ 5  🧠 5, roughly 500-1600 LOC/tests.
   Convenient, but it mixes UI lifecycle, migrations, cache pressure, and
   destructive safety. Not accepted.

Decision: use option 1.

## SQLite Policy

SQLite is a strong candidate, but only if we configure it as critical storage.

Safety DB policy:

```text
journal_mode = WAL
synchronous = FULL
temp_store = MEMORY where safe for small critical statements
busy_timeout = explicit
wal_autocheckpoint = explicit and monitored
foreign_keys = ON
application_id = Clean Disk safety DB id
user_version = schema version
```

Rules:

- `synchronous=NORMAL` is not acceptable for safety DB because power-loss
  durability can be lost in WAL mode.
- `synchronous=OFF`, `journal_mode=MEMORY`, and similar fast settings are
  forbidden for safety DB.
- WAL, SHM, and DB files are treated as a state bundle.
- WAL checkpointing is scheduled away from critical receipt writes when possible.
- checkpoint failure is typed and visible to diagnostics.
- safety DB never lives on network filesystem by default.
- support export uses SQLite Online Backup API, safe query export, or equivalent
  DB-level mechanism.
- `VACUUM` is forbidden during low disk and active cleanup because it can need a
  large free-space budget.

Open spike:

```text
WAL + FULL
  vs
rollback journal + EXTRA
```

WAL + FULL is the accepted default because it gives strong durability and better
reader behavior. Rollback + EXTRA remains a fallback candidate for very small
serial safety DBs if WAL bundle handling or checkpointing becomes too costly.

Kill criteria:

- safety DB runs with same settings as rebuildable cache.
- code deletes `*.db-wal` or `*.db-shm` as cleanup.
- support export copies only `safety.db`.
- long reader causes WAL growth while cleanup receipts are writing.
- safety DB is placed in a user-selected scan target or network share.

## Low-Disk Strategy

Low disk is normal product weather for Clean Disk.

```text
LowDiskSafetyMode
  normal
  warning
  critical
  emergency_reserve_released
  destructive_actions_blocked
  recovery_only
```

Rules:

- keep a small critical reserve file in the safety data directory;
- release the reserve only to finalize receipts, write recovery markers, or
  enter recovery mode;
- recreate the reserve after low-disk mode exits;
- before cleanup starts, estimate journal and receipt write budget;
- if budget is unavailable and reserve cannot be created, block cleanup;
- stop starting new item side effects when critical writes fail;
- logs, debug traces, caches, previews, and support bundle writes are shed first;
- query/index work yields to receipt writer under pressure;
- `SQLITE_FULL`, `ENOSPC`, quota errors, and temp-file full errors are typed
  safety errors, not generic failures.

Reserve sizing should be configurable by profile:

```text
local_desktop: 16-64 MB
remote_server: policy-defined
ci_disposable: smaller but explicit
enterprise_managed: admin-defined
```

Rules:

- reserve is on the same volume as the safety DB;
- reserve does not promise to save arbitrary DB growth;
- reserve is not used to continue scanning;
- reserve release is audited and surfaced in diagnostics.

Kill criteria:

- low disk mode drops operation journal entries.
- cleanup continues after `SQLITE_FULL` on receipt write.
- support bundle generation consumes the last free space.
- reserve file is on a different volume from safety DB.
- UI says cleanup succeeded when receipt finalization failed.

## Operation State Machine

The operation journal is a state machine, not a log dump.

```text
CleanupOperationState
  draft
  planned
  confirmed
  intent_recorded
  preflight_recorded
  executing
  stopping
  interrupted_requires_review
  completed
  completed_with_failures
  completed_with_unknowns
  cancelled_before_side_effects
  blocked_safety_record_unavailable
```

Item state:

```text
CleanupItemState
  pending
  preflight_passed
  dispatch_recorded
  in_flight_unknown
  moved_to_trash
  deleted_by_tool
  skipped_policy
  skipped_stale_identity
  failed_adapter
  failed_safety_record
  unknown_requires_review
```

Rules:

- `dispatch_recorded` is committed before adapter call;
- `in_flight_unknown` is the startup recovery state after crash at unsafe
  boundary;
- terminal item outcome writes are lossless events;
- operation terminal status is derived from item states;
- receipt finalization is a separate state so crash after all items but before
  final receipt is recoverable.

Kill criteria:

- one boolean `is_deleted` stores item truth.
- receipt cannot represent unknown outcomes.
- cancel during adapter call marks item as cancelled.
- crash recovery cannot distinguish before-dispatch from after-dispatch.

## Idempotency And Duplicate Commands

Cleanup commands can be repeated by UI retry, WebSocket reconnect, HTTP retry,
daemon restart, or remote client confusion.

```text
IdempotencyKey
  principal_ref
  operation_id
  delete_plan_hash
  confirmation_token_ref
  target_scope_version
  command_kind
```

Rules:

- duplicate start command returns existing operation state;
- stale delete plan hash is denied;
- repeated terminal command returns terminal receipt;
- duplicate per-item adapter retry is not automatic;
- unknown outcome requires manual review or explicit new plan.

Kill criteria:

- retry creates a second cleanup operation for the same confirmation.
- idempotency key excludes target scope or plan hash.
- reconnect starts execution again after receipt was already terminal.

## Crash Recovery

Every crash boundary must be tested.

Crash points:

```text
after intent write
after receipt skeleton
after preflight write
after dispatch marker before adapter call
during adapter call
after adapter success before outcome write
after outcome write before event delivery
after final item before terminal status
after terminal status before receipt finalization
during migration
during checkpoint
during support export
```

Recovery rules:

- startup opens safety DB before accepting cleanup commands;
- interrupted operations are surfaced in a recovery inbox;
- no destructive adapter call is resumed automatically;
- unknown outcomes are visible, typed, and exportable;
- recovery can finalize purely informational receipt gaps only when journal
  facts prove no side effect was dispatched;
- crash recovery itself must handle `SQLITE_FULL`, `SQLITE_BUSY`, corruption,
  and migration failure.

Kill criteria:

- recovery silently deletes interrupted operation rows.
- app hides old interrupted receipts to reduce user worry.
- recovery finalizes unknown outcomes as success.
- startup accepts new cleanup while safety DB is unhealthy.

## Migration And Compatibility

Safety schema migration is a release gate.

Rules:

- migration has a preflight budget and a rollback/recovery plan;
- migration writes migration receipt metadata;
- destructive cleanup is blocked while migration is incomplete;
- old receipts remain readable or exportable after upgrade;
- downgrade/rollback cannot silently discard new receipts;
- protocol DTO version and safety DB schema version are separate;
- cache migrations and safety DB migrations do not share one risk class.

Kill criteria:

- failed migration deletes safety DB and starts fresh.
- app update runs cleanup while safety schema is mid-migration.
- release rollback cannot display receipts created by newer version.
- migration uses only empty database tests.

## Corruption Recovery

Corrupt safety DB is a product incident, not cache invalidation.

Rules:

- cache DB corruption can quarantine and rebuild;
- safety DB corruption enters read-only recovery/support mode;
- damaged files are preserved before repair attempts;
- `quick_check` can be used after crash or suspected corruption;
- `integrity_check` is support/recovery path, not every startup;
- export uses a safe mechanism and redaction policy;
- destructive actions stay blocked until safety state is healthy.

Kill criteria:

- corrupt safety DB is deleted automatically.
- destructive cleanup is enabled after failed integrity check.
- support export raw-copies live WAL files.
- corruption diagnostics include raw paths by default.

## Backup, Export, And Support Bundles

Receipts and journals may contain private paths. They also contain safety truth.

Rules:

- support bundles exclude receipts by default unless user explicitly includes
  them;
- receipt export supports redaction;
- export keeps operation sequence, item outcome codes, policy version, app
  version, daemon version, and schema version;
- live safety DB backup uses SQLite Online Backup API or safe query export;
- `VACUUM INTO` can be considered only when free-space budget is known;
- support bundle writer must be bounded and low-disk aware.

Kill criteria:

- support export fills disk while user is trying to recover space.
- export loses sequence numbers or unknown outcomes.
- export copies `safety.db` but misses `safety.db-wal`.
- receipt export leaks tokens, auth headers, or raw remote audit subjects.

## Architecture Placement

```text
crates/
  fs_usage_engine/
    src/
      domain/
        cleanup/
          cleanup_operation.rs
          cleanup_item_outcome.rs
          receipt.rs
          receipt_id.rs
      application/
        ports/
          operation_journal.rs
          safety_store_health.rs
          clock.rs
          idempotency_store.rs
        services/
          record_cleanup_intent.rs
          record_cleanup_item_dispatch.rs
          record_cleanup_item_outcome.rs
          recover_interrupted_cleanup.rs

apps/
  clean_disk_server/
    src/
      persistence/
        safety_db/
          connection.rs
          migrations.rs
          sqlite_operation_journal.rs
          sqlite_receipt_store.rs
          low_disk_reserve.rs
          backup_export.rs
          corruption_recovery.rs
      cleanup/
        execution_state_machine.rs
        cleanup_recovery_boot.rs
```

Layer rules:

- domain models operation and receipt facts, not SQLite;
- application owns journal ports and recovery use cases;
- server infrastructure owns SQLite, filesystem sync, backup, and low-disk
  reserve;
- Flutter queries receipts through protocol, not direct DB access;
- transport events are derived from durable state for safety-critical outcomes.

## Required Spikes Before Cleanup Beta

1. **Low-disk and reserve-file spike**
   🎯 8  🛡️ 10  🧠 8, roughly 900-2400 LOC/tests.
   Prove `SQLITE_FULL`, `ENOSPC`, temp-file exhaustion, quota exhaustion,
   reserve release, receipt finalization, cache/log shedding, and fail-closed
   behavior.

2. **Crash matrix and item-boundary recovery spike**
   🎯 9  🛡️ 10  🧠 9, roughly 1200-3400 LOC/tests.
   Prove forced kill at every operation and item state, no auto-retry, unknown
   outcomes, terminal receipt recovery, duplicate command idempotency, and event
   replay after restart.

3. **SQLite policy, migration, backup, and corruption spike**
   🎯 8  🛡️ 10  🧠 8, roughly 1000-3000 LOC/tests.
   Prove WAL + FULL settings, WAL-aware backup/export, migration receipt,
   rollback/downgrade behavior, quick_check recovery, checkpoint behavior, and
   corrupt DB fail-closed mode.

## Minimal Acceptance Gates

Before cleanup beta:

- safety DB is separate from rebuildable cache;
- Rust daemon is the only writer to operation journal and receipts;
- SQLite safety settings are explicit and tested;
- low-disk reserve exists or cleanup is blocked;
- receipt skeleton is durable before side effects;
- per-item dispatch marker is durable before adapter call;
- interrupted/unknown states are represented and surfaced;
- duplicate start command is idempotent;
- safety DB corruption blocks destructive actions;
- support export is WAL-aware and bounded;
- crash tests cover every destructive state boundary;
- migration tests include real receipt/journal fixtures;
- cleanup never continues after critical journal write failure.

## Decision

The next global critical zone is persistent operation journal and receipt
durability under low disk.

Implementation should use a dedicated Rust-owned safety SQLite DB through
application ports, with explicit durability policy, low-disk reserve, per-item
journal boundaries, idempotency, recovery inbox, WAL-aware export, and
fail-closed corruption handling.

Practical rule:

```text
If we cannot durably record the cleanup truth,
we are not allowed to perform the cleanup side effect.
```
