# Implementation Edge Cases - Local State, Persistence, And Receipts

Last updated: 2026-05-13.

This file records edge cases for local state, app cache, SQLite/Drift, delete receipts, operation journals, migrations, retention, backups, corruption recovery, support bundles, and local secret storage.

The core split:

- scan tree caches are performance artifacts;
- delete receipts and destructive operation journals are user-trust artifacts;
- runtime daemon tokens are secrets;
- preferences and saved targets are user settings;
- logs and support bundles are diagnostics with privacy risk.

Those categories must not share one generic "app data" policy.

Related documents:

- [Implementation edge cases](implementation-edge-cases.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md)
- [Rust best practices research](rust-best-practices.md)

## Sources Reviewed

- SQLite, [Atomic Commit In SQLite](https://www.sqlite.org/atomiccommit.html). Relevant point: SQLite transactions are designed to appear atomic even across crashes/power loss, but durability depends on journal mode and sync assumptions.
- SQLite, [Write-Ahead Logging](https://www.sqlite.org/wal.html). Relevant points: WAL uses extra `-wal` and `-shm` files, checkpointing affects behavior, and WAL files are part of database state while connections are open.
- SQLite, [PRAGMA statements](https://www.sqlite.org/pragma.html). Relevant points: `application_id`, `user_version`, `integrity_check`, `quick_check`, journal/synchronous settings, and checkpoint-related behavior are operational tools, not decoration.
- SQLite, [Online Backup API](https://www.sqlite.org/backup.html). Relevant point: a live SQLite database should be backed up through SQLite's backup mechanism, not by casually copying one file while WAL state may exist.
- Drift, [Migrations](https://drift.simonbinder.eu/migrations/). Relevant points: Drift requires explicit schemaVersion changes and migration strategies; generated schema files and migration tests support safer evolution.
- Drift, [Testing migrations](https://drift.simonbinder.eu/migrations/tests/). Relevant point: migrations should be verified from older schema versions into the expected schema.
- Drift package page, [drift](https://pub.dev/packages/drift). Relevant point: Drift supports transactions, schema migrations, streams, and modular query organization.
- OWASP Cheat Sheet Series, [Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html). Relevant point: minimize storage of sensitive information before deciding to encrypt it.
- OWASP Cheat Sheet Series, [Logging](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html). Relevant points: logs can contain sensitive data, including file paths; logs must not be kept beyond retention windows and must exclude tokens/secrets.
- NIST, [Privacy Framework](https://www.nist.gov/privacy-framework). Relevant point: privacy risk management includes identifying and managing privacy risk, not only securing access.
- Apple Developer Documentation, [Using the file system effectively](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively?changes=l_3). Relevant points: Application Support stores support/configuration files needed by the app; Caches stores discardable files that improve performance.
- Apple Developer Documentation, [Application Support directory](https://developer.apple.com/documentation/foundation/filemanager/searchpathdirectory/applicationsupportdirectory). Relevant point: app support and cache directories have different intended semantics.
- Apple Developer Documentation, [Keychain Services](https://developer.apple.com/documentation/Security/keychain-services). Relevant point: Keychain is intended for small secrets such as passwords, keys, certificates, identities, and similar data.
- Apple Platform Security, [Keychain data protection](https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/1/web/1). Relevant point: keychain items encrypt metadata and secret values differently and are designed for small sensitive data.
- Microsoft Learn, [CryptProtectData](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata). Relevant point: DPAPI encrypts data tied to user or machine context, and machine scope changes who can decrypt.
- freedesktop.org, [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/?s=09). Relevant points: config, data, state, cache, and runtime files belong in different user-scoped locations; runtime files must not survive logout/reboot.
- freedesktop.org, [Secret Service API](https://specifications.freedesktop.org/secret-service/latest/). Relevant point: Linux desktops can provide a D-Bus secret service for storing secrets, but availability is environment-dependent.

## Severity Scale

- `P0` - can lose destructive operation receipts, leak tokens/private paths, corrupt confirmation state, make stale scan data drive deletion, or silently mis-migrate persisted safety data.
- `P1` - can cause support burden, broken update/downgrade, unusable history, excessive disk use, privacy surprises, or hard-to-debug corruption.
- `P2` - important polish, diagnostics, user controls, export/import quality, or future enterprise readiness.

## Top 3 Persistence Decisions

1. Separate storage classes for cache, state/history, receipts, secrets, logs, and runtime files - 🎯 10 🛡️ 10 🧠 5, roughly 400-1000 LOC across storage adapters, directories, schemas, and settings UI.
2. Durable operation journal only for destructive workflows - 🎯 9 🛡️ 10 🧠 7, roughly 700-1800 LOC across Rust application, SQLite/Drift, idempotency, crash recovery, and receipt UI.
3. Migration and corruption policy before first persisted beta - 🎯 9 🛡️ 9 🧠 6, roughly 500-1400 LOC across schema snapshots, Drift migration tests, integrity checks, recovery UX, and support bundle metadata.

The most important point: cache can be aggressively disposable. Receipt/journal data cannot be silently lost because it is how the user learns what happened to their files.

## Core Principle

Local data must have a durability class before implementation.

Recommended classes:

```text
runtime_secret:
  daemon token, socket path, process lock

rebuildable_cache:
  scan tree cache, page cache, search index, thumbnails if ever added

session_state:
  active scan id, recent target, current progress, stale/recoverable state

user_config:
  theme, density, saved roots, scan defaults, privacy preferences

durable_safety_state:
  delete plan confirmation state, idempotency records, operation journal

receipt:
  completed/interrupted delete operation outcomes

diagnostics:
  logs, traces, metrics snapshots, support bundle exports
```

Rules:

- each class gets a directory, retention policy, redaction policy, and backup/export policy;
- no one database table owns all classes by accident;
- UI must expose user controls for privacy-sensitive history;
- tests must assert cache deletion does not delete receipts;
- uninstall/update behavior depends on class, not file extension.

## Storage Taxonomy

### Runtime Secrets Are Not App Preferences - `P0`

Local daemon tokens, socket names, and auth handshakes protect scan/delete authority. They are not normal settings.

Required behavior:

- runtime tokens live in runtime/state directory with user-only permissions;
- tokens are short-lived and regenerated when daemon restarts if possible;
- tokens are never stored in Flutter preferences, Drift cache, logs, URLs, or support bundles;
- stale runtime token files are cleaned on startup;
- token discovery file has restrictive permissions and minimal content.

### Scan Tree Cache Is Disposable - `P0`

Scan tree cache can be rebuilt. It should not become a hidden source of delete authority.

Required behavior:

- deletion from old scan cache cannot execute without fresh DeletePlan revalidation;
- cache schema can be dropped on incompatibility;
- cache has size and age limits;
- cache stores snapshot/version IDs;
- cache clear action is safe and does not delete receipts or saved preferences.

### Session State Is Recoverable But Not Sacred - `P1`

If the app crashes during a scan, we can resume UI state or mark the scan interrupted. We do not need to persist every progress tick.

Required behavior:

- active scan session stores enough to show interrupted/unknown state on restart;
- progress events are not flushed one-by-one;
- terminal status is persisted for user clarity;
- stale session state expires;
- user can clear interrupted sessions.

### Preferences Need Stronger Stability Than Cache - `P1`

User preferences are small but trust-sensitive.

Examples:

- theme;
- density;
- language;
- saved scan targets;
- scan options;
- privacy/redaction settings;
- whether to show advanced warnings.

Required behavior:

- preferences persist across updates;
- preferences can be reset safely;
- saved targets that depend on bookmarks/permissions have capability state;
- privacy defaults are conservative after migration;
- preferences are not stored in cache directories.

### Receipts Are Product Artifacts - `P0`

Delete receipts are not logs. They are user-facing evidence of what was moved, skipped, failed, or interrupted.

Receipt must contain:

- receipt ID;
- operation ID;
- source scan session/snapshot reference;
- plan hash;
- started and completed/interrupted timestamps;
- item outcomes;
- adapter result such as Trash path when available;
- warnings at execution time;
- redaction mode for display/export;
- app/daemon version and protocol version.

Required behavior:

- receipt ID created before item moves start;
- receipt is updated incrementally or through a durable journal;
- interrupted receipt opens as `requires_review`;
- deleting scan history does not delete receipts unless user explicitly chooses;
- receipts can be exported with redaction.

## SQLite And Drift Policy

### One SQLite Database Is Not Automatically One Storage Policy - `P0`

SQLite can hold many tables, but that does not mean all tables should share retention, durability, or backup behavior.

Recommended options:

1. Separate SQLite databases by durability class - 🎯 8 🛡️ 9 🧠 7, roughly 400-1200 LOC. Strong isolation, more connection/migration complexity.
2. One database with strict table namespaces and class-specific services - 🎯 8 🛡️ 7 🧠 5, roughly 250-900 LOC. Good MVP if tests enforce retention boundaries.
3. One mixed database with ad hoc cleanup - 🎯 3 🛡️ 3 🧠 3, roughly 100-400 LOC. Easy now, expensive later, risky for privacy.

MVP bias:

- one app database is acceptable only if retention/deletion boundaries are explicit;
- runtime secrets should stay out of it;
- huge live scan tree cache may deserve separate disposable store later.

### WAL Files Are Part Of The Database - `P1`

SQLite WAL mode creates extra files and checkpoint behavior. Copying or deleting only the main database file can lose state or create confusing backups.

Required behavior:

- never delete `-wal` or `-shm` files as "junk";
- support bundle either uses SQLite backup API/export path or captures database metadata only;
- backup/export uses SQLite-supported mechanism, not raw file copy while open;
- checkpoint policy prevents unbounded WAL growth;
- tests open database, write, crash/close, restart, and verify state.

### Synchronous Policy Depends On Durability Class - `P0`

Rebuildable cache and delete receipts do not need the same fsync cost.

Recommended policy:

```text
rebuildable_cache:
  performance-oriented, disposable, can be dropped on corruption

preferences:
  moderate durability, atomic visibility, recover from backup/defaults

receipt/journal:
  stronger durability, slower acceptable, never silently discard
```

Required behavior:

- document SQLite `journal_mode` and `synchronous` policy;
- do not use the fastest settings for receipts just because they feel good in benchmarks;
- do not fsync every cache page update;
- benchmark with realistic scan write load;
- crash tests verify receipt/journal survival under expected policy.

### Integrity Checks Need A Startup/Support Policy - `P1`

SQLite provides `quick_check` and `integrity_check`, with different cost. Running heavy checks on every startup can slow the app.

Recommended behavior:

- run cheap metadata/schema checks at startup;
- run `quick_check` opportunistically after crash or support action;
- run full `integrity_check` only on user/support request or suspicious state;
- never block first paint on a large DB integrity scan unless safety state is unreadable;
- corrupted rebuildable cache can be deleted and rebuilt.

### Application ID And User Version Should Be Set - `P1`

SQLite `application_id` helps identify the file. `user_version` can hold schema version if using raw SQLite, while Drift uses its schemaVersion and migration tooling.

Required behavior:

- set application ID on app-owned SQLite databases;
- expose schema version in support diagnostics;
- schema version mismatch has typed recovery path;
- storage version is separate from protocol version;
- migration tests cover every supported prior schema.

### Drift Migrations Are Required Work, Not Optional Cleanup - `P0`

Drift requires schemaVersion changes and migration strategies when schema changes.

Required behavior:

- every schema change bumps `schemaVersion`;
- migration files/snapshots are committed;
- generated migration tests are run in CI;
- migration tests include sample data for receipts and preferences, not just empty tables;
- downgrade behavior is documented: block, read-only, or rebuild cache.

### Do Not Query New Schema Before Migration Completes - `P1`

Drift docs warn that generated queries expect the current schema. Migration callbacks must be careful when reading/writing old data.

Required behavior:

- migrations use raw/custom SQL only where needed;
- data migrations are staged and tested;
- no app store opens feature stores until DB migration finishes;
- migration failure keeps database in recoverable state;
- UI shows migration/recovery problem instead of crashing.

## Operation Journal And Idempotency

### Destructive Work Needs A Journal - `P0`

Moving many items to Trash is not atomic. A crash can happen after item 7 of 200.

Required behavior:

- journal operation starts before first item action;
- each item outcome is recorded as soon as practical;
- terminal state is written only after all outcomes are known;
- restart surfaces interrupted operation;
- retry requires user review and fresh revalidation.

### Idempotency Records Need Retention - `P1`

Duplicate commands can happen because of browser retry, app retry, reconnect, double-click, or timeout.

Required behavior:

- idempotency key scoped by user/client/session/action;
- stored payload hash prevents key reuse with different command;
- first result is reusable within retention window;
- retention window documented and enforced;
- idempotency records are privacy-sensitive if they contain path-derived payload hashes.

### Confirmation Tokens Are Safety State - `P0`

Delete confirmation token cannot be stored like normal form state.

Required behavior:

- token binds to plan hash and snapshot;
- token expires on plan edit, rescan, daemon restart policy, or timeout;
- token is single-use;
- token never appears in logs/support bundles;
- persisted token state contains only what is needed to reject stale execution.

## Retention And User Controls

### Retention Policy Must Exist Before History UI - `P1`

Scan history and receipts contain private paths.

Required behavior:

- default retention is conservative;
- user can clear scan history;
- user can clear receipts separately with explicit wording;
- user can clear logs;
- support bundle export has preview and redaction;
- remote mode later gets per-user/tenant retention.

### Clear History Is Not Clear Receipts - `P0`

Users may want to hide scan history without destroying the only record of a cleanup operation.

Required behavior:

- separate UI actions: clear scan history, clear logs, clear cache, delete receipts;
- destructive receipt deletion has confirmation;
- receipt deletion can be disabled during active delete operation;
- clearing cache does not remove saved targets/preferences;
- tests assert separation.

### App Uninstall Policy Must Be Explicit - `P1`

Uninstall can remove app binaries but leave user data. Different OSes/package formats behave differently.

Required behavior:

- uninstall stops daemon and removes runtime tokens;
- transient cache can be removed;
- receipts/preferences follow product policy and installer capabilities;
- support docs tell users where local data lives;
- reinstall handles old data schema safely.

### Support Bundles Are Controlled Exports - `P0`

Support bundles can leak paths, tokens, receipts, logs, and system details.

Required behavior:

- user initiates support bundle explicitly;
- preview lists included data classes;
- tokens and headers are excluded;
- path redaction defaults on;
- receipts included only with explicit consent;
- bundle records app version, OS, schema versions, and capability summary.

## Privacy And Encryption

### Minimize Before Encrypting - `P0`

OWASP cryptographic storage guidance emphasizes minimizing sensitive storage. Encryption is not a license to store everything.

Required behavior:

- do not persist full scan tree by default;
- do not persist every path visited;
- do not persist raw request/response bodies;
- store display paths only when needed for receipts/history;
- store path hashes or redacted paths for diagnostics where possible.

### Secrets Belong In Platform Secret Storage - `P0`

Small secrets should use platform secret storage where available:

- macOS Keychain;
- Windows DPAPI or Credential Manager-style store depending on adapter choice;
- Linux Secret Service when available, with fallback policy.

Required behavior:

- local daemon auth material is not stored in plain preferences;
- fallback to file storage is explicit, restrictive, and visible in capability diagnostics;
- machine-scope encryption is avoided unless needed because it expands who can decrypt;
- secret storage errors degrade safely;
- no secret values in `Debug`, logs, snapshots, or crash reports.

### Encrypting Receipts Is Not A Simple Default - `P1`

Receipts contain private paths, but they must remain usable for the current user and support/export.

Top 3 choices:

1. Plain local receipt DB with user-only filesystem permissions and redacted export - 🎯 8 🛡️ 7 🧠 4, roughly 250-700 LOC. Good MVP if local threat model is honest.
2. Encrypt receipt fields or database with platform-protected key - 🎯 7 🛡️ 8 🧠 8, roughly 900-2500 LOC. Stronger privacy, key recovery/migration/support complexity.
3. Do not persist receipts - 🎯 2 🛡️ 2 🧠 2, roughly 50-150 LOC. Not acceptable for cleanup-capable release.

MVP bias:

- start with user-only file permissions and minimization;
- design receipt schema so sensitive fields can be encrypted later;
- do not implement custom crypto casually.

### Logs Must Treat Paths As Sensitive - `P0`

OWASP logging guidance calls out file paths as data that may need special treatment.

Required behavior:

- logs use path redaction by default;
- debug mode can temporarily increase detail with visible setting;
- logs have size and age limits;
- log lines sanitize CR/LF/control characters;
- log export preserves redaction.

## Multi-Process And Concurrency

### Flutter And Rust Must Not Fight Over The Same SQLite File - `P0`

If the Rust daemon and Flutter app both open the same SQLite DB directly, locking, schema migration, and corruption recovery become harder.

Recommended ownership:

1. Rust daemon owns operational DB; Flutter queries via HTTP - 🎯 9 🛡️ 9 🧠 6, roughly 400-1200 LOC. Best for daemon-centered scan/delete state.
2. Flutter owns UI/preferences Drift DB; Rust owns operation journal DB - 🎯 8 🛡️ 8 🧠 7, roughly 700-1800 LOC. Good split if preferences stay in Flutter.
3. Both open one shared DB file directly - 🎯 3 🛡️ 4 🧠 5, roughly 300-900 LOC. Avoid unless there is a strong reason.

MVP bias:

- Rust owns scan/delete operation state;
- Flutter can own purely UI preferences if needed;
- shared durable safety state is accessed through daemon API.

### Migration Lock Is Required - `P1`

Only one process should migrate a DB.

Required behavior:

- app startup coordinates with daemon startup;
- migration lock exists;
- old daemon is stopped or denied DB access before new migration;
- UI waits for migration status;
- migration failure leaves clear recovery path.

### Background Support Bundle Must Not Race Writes - `P1`

Exporting DB/log state while daemon writes can produce inconsistent artifacts.

Required behavior:

- use SQLite backup API/export queries;
- support bundle uses snapshot or read transaction;
- receipts in progress are marked in progress;
- WAL state is handled correctly;
- bundle never copies runtime token files.

## Corruption And Recovery

### Corruption Policy Differs By Data Class - `P0`

If cache DB is corrupted, delete it and rebuild. If receipt DB is corrupted, do not silently discard.

Required behavior:

- cache corruption: show warning and rebuild;
- preferences corruption: offer reset with backup if possible;
- receipt/journal corruption: preserve damaged file, block destructive actions, guide support/export;
- runtime token corruption: regenerate token;
- logs corruption: rotate/drop with warning.

### Recovery Must Not Retry Destructive Actions Automatically - `P0`

After crash during delete, the app must show interrupted state. It must not continue moving items without user review.

Required behavior:

- startup scans operation journal;
- interrupted delete jobs become `requires_review`;
- already moved items are visible;
- remaining items require new confirmation/revalidation;
- idempotency result does not auto-execute unknown operations.

### Migration Failure Is Not Cache Failure - `P0`

If migration fails for receipt/journal DB, do not delete it as a convenience.

Required behavior:

- backup/copy old DB before destructive migration if feasible;
- migration failure blocks cleanup actions;
- user can export diagnostics;
- app can still run read-only scan mode if safe;
- rollback/downgrade behavior documented.

## Data Model Boundaries

### Persistence DTOs Are Not Protocol DTOs - `P1`

Wire protocol evolves differently from storage schema.

Required behavior:

- protocol DTOs include API compatibility fields;
- persistence rows include storage migration fields;
- domain entities map explicitly to both;
- no generated REST/WebSocket DTO is stored directly as durable row blob unless versioned;
- receipt export format has its own version.

### Store Stable Facts, Not UI Formatting - `P1`

Do not persist formatted sizes, localized dates, icon names, or translated warnings as authoritative data.

Required behavior:

- store bytes, timestamps, reason codes, warning codes;
- UI formats according to locale/theme;
- receipt export can include human text but keeps machine-readable codes;
- tests cover locale changes without data migration;
- support diagnostics use codes.

### Path Storage Needs Raw And Display Policy - `P0`

Paths can include Unicode, control characters, bidi marks, long path prefixes, and platform-specific syntax.

Required behavior:

- store raw path bytes/string representation according to platform adapter policy;
- display path is escaped/sanitized in UI/export;
- receipt path redaction can preserve enough identity for user review;
- path hashing uses stable normalized policy only for diagnostics, not identity;
- logs never output raw unescaped path blindly.

## Testing Matrix

### Storage Class Tests

Required:

- clear cache does not delete receipts;
- clear history does not delete receipts;
- clear receipts requires explicit confirmation;
- runtime token never appears in app DB;
- support bundle excludes tokens;
- uninstall/reinstall handles old data.

### SQLite/Drift Tests

Required:

- create current schema from scratch;
- migrate from every supported prior schema;
- migrate with sample receipt data;
- migration failure path;
- WAL restart recovery;
- checkpoint/large WAL behavior;
- `quick_check` or equivalent recovery trigger after simulated crash.

### Crash Recovery Tests

Required:

- crash during scan;
- crash after delete plan creation;
- crash after confirmation before first item;
- crash after several item outcomes;
- crash after final item before terminal receipt;
- restart shows requires-review state.

### Privacy Tests

Required:

- logs redact home paths;
- logs sanitize control characters;
- support bundle redaction preview;
- receipt export redacted mode;
- scan history retention cleanup;
- database files have user-only permissions where platform allows.

### Concurrency Tests

Required:

- two app windows start against one daemon;
- old daemon and new app protocol mismatch;
- migration lock prevents concurrent migration;
- support bundle export during active scan;
- support bundle export during active delete;
- DB busy/locked errors map to typed recoverable errors.

## MVP Cut Line

Before first cleanup-capable beta:

- storage classes are defined in code and docs;
- runtime tokens are separated from preferences/cache;
- scan cache is disposable and clearable;
- receipt/journal state persists destructive outcomes;
- Drift/SQLite migration tests exist for persisted safety data;
- support bundle has redaction preview;
- cache/history/receipt clearing are separate UI actions;
- app startup can detect interrupted delete operation;
- database corruption has typed recovery path;
- logs have retention and path-redaction policy.

Do not ship move-to-trash until receipt persistence and crash recovery are tested with simulated interruption.

## Summary

The safe stance:

```text
Cache is disposable.
Preferences are recoverable user state.
Receipts are durable user trust.
Runtime tokens are secrets.
Logs and support bundles are privacy liabilities.
Migrations are part of release safety.
```

The invariant:

```text
Clean Disk may rebuild scan data, but it must not silently lose, leak, or mis-migrate the record of destructive actions.
```

