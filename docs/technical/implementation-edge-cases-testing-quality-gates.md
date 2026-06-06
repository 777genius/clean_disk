# Implementation Edge Cases - Testing Strategy And Quality Gates

Last updated: 2026-05-13.

This file records testing, fixture, CI, benchmark, contract, and release-gate edge cases for Clean Disk.

Testing cannot be treated as "run unit tests". Clean Disk has a dangerous mix of cross-platform filesystem behavior, local daemon transport, large trees, desktop/web UI, caches, receipts, and cleanup actions. The test strategy must prove boundaries and destructive workflows, not only increase coverage numbers.

Related documents:

- [Implementation edge cases](implementation-edge-cases.md)
- [Implementation edge cases cleanup delete safety](implementation-edge-cases-cleanup-delete-safety.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md)
- [Rust best practices research](rust-best-practices.md)

## Sources Reviewed

- Flutter Documentation, [Testing Flutter apps](https://docs.flutter.dev/testing/overview). Relevant point: Flutter distinguishes unit, widget, and integration tests, and the Flutter SDK includes `integration_test`.
- Flutter Documentation, [Integration testing](https://docs.flutter.dev/testing/integration-tests). Relevant point: integration tests use `flutter_test` style APIs but require an app to test.
- Flutter API, [matchesGoldenFile](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html). Relevant points: golden tests compare against master images, `flutter test --update-goldens` updates them, and custom fonts/platforms can change rendering.
- Flutter API, [goldenFileComparator](https://api.flutter.dev/flutter/flutter_test/goldenFileComparator.html). Relevant point: default golden comparison is exact pixel comparison with a local file comparator under `flutter test`.
- Dart Documentation, [dart analyze](https://dart.dev/tools/dart-analyze). Relevant point: command-line analysis mirrors IDE analysis and can fail on warnings or infos depending on flags.
- Dart package page, [test](https://pub.dev/packages/test). Relevant points: Dart tests support VM/browser platforms, sharding, concurrency, timeouts, tags, and `dart_test.yaml`.
- Melos Documentation, [bootstrap](https://melos.invertase.dev/commands/bootstrap). Relevant points: bootstrapping installs dependencies, links local packages, and can enforce lockfiles.
- Melos Documentation, [exec](https://melos.invertase.dev/commands/exec). Relevant points: commands can run across packages with concurrency and fail-fast behavior.
- Cargo Book, [Tests](https://doc.rust-lang.org/cargo/guide/tests.html). Relevant point: `cargo test` runs unit tests, integration-style tests under `tests/`, examples, and documentation tests.
- Cargo Book, [cargo test](https://doc.rust-lang.org/nightly/cargo/commands/cargo-test.html). Relevant point: `cargo test` compiles and executes unit, integration, and documentation tests.
- cargo-nextest Documentation, [Repository configuration](https://nexte.st/docs/configuration/). Relevant points: repository config is checked in and supports profiles, retries, timeouts, test groups, and per-test behavior.
- Proptest Documentation, [Failure persistence](https://proptest-rs.github.io/proptest/proptest/failure-persistence.html). Relevant point: failing generated cases are persisted under `proptest-regressions` by default.
- Rust Fuzz Book, [cargo-fuzz guide](https://rust-fuzz.github.io/book/cargo-fuzz/guide.html). Relevant points: fuzz targets run through `cargo fuzz`, support feature configuration, and compile with `cfg(fuzzing)`.
- Miri repository, [Miri](https://github.com/rust-lang/miri). Relevant point: Miri detects many undefined-behavior classes in Rust tests, especially around unsafe code.
- Loom crate docs, [loom](https://docs.rs/loom/latest/loom/). Relevant point: loom explores possible thread interleavings for deterministic concurrent tests.
- Criterion.rs Documentation, [User guide](https://bheisler.github.io/criterion.rs/book/user_guide/user_guide.html). Relevant point: Criterion is useful for statistics-driven microbenchmarks and comparison of functions.
- RustSec, [RustSec Advisory Database](https://rustsec.org/). Relevant points: `cargo-audit` checks `Cargo.lock` for vulnerable crates; `cargo-deny` can also check licenses, bans, sources, and duplicate versions.
- cargo-deny Documentation, [licenses check](https://embarkstudios.github.io/cargo-deny/checks/licenses/index.html). Relevant point: cargo-deny can verify license requirements against configured policy, but it does not exhaustively scan every source file.

## Severity Scale

- `P0` - missing gate can allow wrong-file delete, unsafe cleanup release, protocol incompatibility, hidden dependency/security issue, or tests touching real user data.
- `P1` - missing gate can allow platform regressions, flaky CI, bad performance claims, broken installer/update, or UI regressions in the main workflow.
- `P2` - useful hardening, diagnostics, developer ergonomics, and long-term maintainability.

## Top 3 Quality Decisions

1. Layered quality gates, not one mega test command - 🎯 10 🛡️ 10 🧠 5, roughly 300-900 LOC across scripts, Melos commands, CI workflow, and Rust profiles.
2. Disposable filesystem fixture lab with real and fake adapters - 🎯 10 🛡️ 10 🧠 7, roughly 800-2200 LOC across fixture builder, platform probes, cleanup contracts, and CI artifacts.
3. Contract/property/snapshot tests for domain, protocol, and cleanup invariants - 🎯 9 🛡️ 9 🧠 7, roughly 700-1800 LOC across Rust tests, Dart tests, DTO snapshots, proptest regressions, and import-boundary checks.

The main rule: fast tests protect developer flow, slow tests protect platform truth, and release gates protect user files.

## Gate Levels

### Local Fast Gate - `P0`

This is what developers should run constantly.

Required checks:

- `fvm flutter analyze` or workspace equivalent;
- Dart package tests for pure packages;
- Flutter widget tests for changed UI packages;
- Rust `cargo fmt --check`;
- Rust `cargo clippy` once Rust crates exist;
- Rust `cargo test --workspace` for fast unit tests;
- import boundary tests for Clean Architecture rules;
- protocol snapshot tests if public DTOs changed.

Rules:

- local fast gate must avoid real Trash/Recycle Bin;
- local fast gate must not scan real user folders;
- local fast gate must finish quickly enough that developers actually run it;
- no network dependency unless explicitly testing network adapters with controlled fakes.

### Pull Request Gate - `P0`

PR CI should prove the codebase is internally coherent.

Required checks:

- FVM Flutter version is respected;
- Dart workspace dependencies resolve from lockfile;
- Melos workspace commands run with controlled concurrency;
- `dart analyze`/`flutter analyze` fail on errors and warnings according to repo policy;
- package unit/widget tests;
- Rust fmt, clippy, unit/integration tests;
- generated files are up to date;
- architecture boundary tests;
- dependency/advisory/license checks once Rust crates exist;
- no golden updates unless explicitly reviewed.

Avoid:

- retrying every flaky test and calling CI healthy;
- making PR CI depend on a user's local OS permissions;
- hiding package-level failures inside one huge script with unreadable output.

### Nightly Platform Gate - `P1`

Nightly tests should catch the cross-platform reality that PR CI cannot afford every time.

Required checks:

- macOS, Windows, Linux matrix;
- real disposable filesystem fixtures;
- real local daemon startup and shutdown;
- HTTP/WebSocket protocol compatibility tests;
- scan of high-entry-count fixtures;
- real Trash smoke test on disposable files where supported;
- package-mode smoke tests for direct desktop builds;
- macro benchmark trends with cold/warm state notes;
- fuzz/property/stress jobs for selected targets.

Rules:

- nightly failures create issues or block release depending on severity;
- flaky tests are quarantined with owner and expiry, not silently retried forever;
- artifacts are sanitized before upload.

### Release Candidate Gate - `P0`

RC gates are stricter than PR gates because installers, permissions, and cleanup affect real machines.

Required checks:

- signed/notarized installer smoke test where applicable;
- update from previous version;
- uninstall policy test;
- app and daemon version compatibility;
- permission doctor behavior;
- support bundle redaction;
- crash recovery for scan and cleanup;
- move-to-trash on disposable fixture for every supported OS;
- receipt persistence and migration;
- dependency/security/license report;
- benchmark summary with environment details.

Hard rule:

```text
Cleanup-capable release is blocked if stale identity, partial receipt, duplicate command, or crash recovery tests fail.
```

## Test Types

### Domain Unit Tests - `P0`

Domain tests should be pure and fast.

Required coverage:

- size model calculations;
- node identity comparison;
- hardlink accounting policy;
- DeletePlan normalization;
- cleanup risk classification;
- confirmation token rules;
- receipt state transitions;
- error code mapping without transport details.

Rules:

- no filesystem access;
- no Flutter imports;
- no HTTP/WebSocket imports;
- no platform APIs;
- no pdu or Trash crate imports.

### Application Use Case Tests - `P0`

Application layer tests validate ports and orchestration.

Required coverage:

- scan session lifecycle;
- paginated query behavior;
- cursor/snapshot consistency;
- cancellation;
- slow-client backpressure policy;
- create/validate/confirm/execute DeletePlan;
- operation journal and receipt writer interactions;
- retry/idempotency behavior.

Rules:

- use fake adapters with realistic failure modes;
- fakes must model permission denied, path stale, identity mismatch, unsupported Trash, and partial success;
- tests assert port calls and outcomes, not private implementation details.

### Adapter Contract Tests - `P0`

Every adapter behind a port needs shared contract tests.

Required adapters:

- scanner adapter;
- filesystem identity probe;
- Trash adapter;
- receipt storage;
- protocol client/server;
- cache storage;
- platform capabilities.

Rules:

- fake adapter and real adapter run the same core contract suite where possible;
- real adapter tests use disposable temp roots;
- destructive tests are opt-in on developer machines and required in controlled CI;
- every platform adapter maps native errors into typed app errors.

### Protocol Snapshot Tests - `P0`

The Flutter UI and web UI depend on stable HTTP/WebSocket contracts.

Required snapshots:

- command request examples;
- query response examples;
- event envelope examples;
- problem/error payloads;
- capabilities payload;
- receipt payload;
- cursor and pagination examples.

Rules:

- snapshots must be deterministic;
- no unordered `HashMap` output;
- no timestamps unless fixed;
- no raw local paths or tokens;
- snapshot massive scan trees only as focused examples, never full production-like trees.

### Property-Based Tests - `P1`

Property tests are valuable for tree, cursor, sorting, and delete-plan invariants.

Good targets:

- parent/child selection normalization is idempotent;
- sorting plus pagination returns every item exactly once;
- cursor rejects mismatched snapshot/sort/filter;
- hardlink accounting never exceeds apparent bytes;
- receipt totals equal item outcomes;
- path display never changes identity;
- duplicate execute commands return stable result.

Rules:

- persist regressions under `proptest-regressions`;
- convert important generated failures into named regression tests;
- limit generated cases for local runs;
- use nightly/scheduled runs for heavier properties.

### Fuzz Tests - `P2`

Fuzzing should target parsers and boundary code, not the whole daemon at first.

Good targets:

- protocol JSON decode;
- cursor decode;
- path display/sanitization;
- search query parser if added;
- receipt import/export if added;
- settings/config parser;
- platform metadata DTO decoding.

Rules:

- cargo-fuzz is a later hardening gate;
- found crashes become normal regression tests;
- fuzz artifacts are not committed unless curated;
- fuzz jobs run on schedule or before risky releases, not every PR.

### Golden And Widget Tests - `P1`

The design references matter, but golden tests can become brittle across fonts, OS, GPU, and Flutter versions.

Required coverage:

- central tree/table row states;
- selected row;
- compact layout;
- delete queue;
- permission/skipped/stale warnings;
- progress/status bar;
- details panel;
- empty/loading/error states.

Rules:

- load deterministic fonts in golden tests;
- keep golden surface small and component-focused;
- avoid full-app giant goldens as the only UI proof;
- review golden updates as design changes;
- run visual checks on the same Flutter version pinned by FVM;
- use widget tests for behavior and golden tests for visual regressions.

### Integration And End-To-End Tests - `P1`

Integration tests are expensive but necessary for app/daemon behavior.

Required flows:

- web UI connects to fake/local daemon;
- desktop UI connects to local daemon;
- start scan, receive progress, query pages;
- cancel scan;
- search/sort/filter tree;
- create DeletePlan;
- stale item requires revalidation;
- move disposable file to Trash on supported platform;
- daemon crash/restart recovery;
- incompatible daemon version disables cleanup.

Rules:

- integration tests use test keys and stable selectors;
- tests do not rely on animation timing;
- fake daemon covers deterministic UI flows;
- real daemon smoke tests cover platform edges.

## Fixture Lab

### Never Test Against Real User Folders - `P0`

Tests must not scan or cleanup `~/Downloads`, `~/Library`, project roots, or user-selected folders.

Required behavior:

- all tests create temp fixture roots;
- fixture roots are marked with a sentinel file;
- destructive tests refuse to run without sentinel;
- cleanup adapters reject paths outside fixture root in tests;
- test receipts use synthetic paths or redacted paths.

### Core Filesystem Fixtures - `P0`

Fixture builder must support:

- many small files;
- deep directory tree;
- wide directory with thousands of entries;
- empty directories;
- sparse file where supported;
- hardlinks where supported;
- symlink loop where supported;
- symlink to outside root;
- broken symlink;
- read-only file;
- permission-denied directory;
- path with spaces;
- path with non-ASCII text;
- path with invalid/non-UTF-8 bytes where supported;
- path with newline/tab/control/bidi characters;
- very long path;
- file changed during scan;
- file replaced between scan and cleanup.

### Platform-Specific Fixtures - `P1`

macOS:

- APFS clone/sparse/snapshot behavior where practical;
- CloudStorage/iCloud mocked or disposable provider fixture;
- TCC-denied folder behavior;
- app bundle/package directory;
- resulting Trash URL.

Windows:

- long path over 260 chars;
- Recycle Bin through Shell API;
- read-only attribute;
- ACL denied;
- junction/reparse point;
- file locked by another process;
- memory-mapped file;
- path case-sensitivity setting where available.

Linux:

- FreeDesktop Trash support;
- no desktop Trash support;
- external-volume Trash;
- immutable/append-only attribute where available;
- sticky directory;
- read-only mount if CI can provide it;
- headless/container scan-only mode.

## CI And Tooling Policy

### Toolchain Pinning - `P0`

Clean Disk already pins Flutter through FVM.

Required behavior:

- CI uses FVM Flutter `3.41.9`;
- CI fails if local Flutter version drifts from `.fvmrc`;
- Rust toolchain is pinned once Rust crates exist;
- dependency lockfiles are committed and enforced for app builds;
- generated outputs are reproducible or checked.

### Melos/Dart Workspace Gate - `P1`

Melos should orchestrate workspace checks without hiding package failures.

Required behavior:

- `melos bootstrap` or `dart pub get` policy is explicit;
- `melos exec` concurrency is controlled;
- package filters are used for local speed, full workspace for CI;
- commands fail fast only when that improves feedback;
- CI prints package names clearly.

### Rust Test Runner Policy - `P1`

Start simple, upgrade when test volume demands it.

Recommended path:

1. `cargo test --workspace` first - 🎯 10 🛡️ 8 🧠 2, roughly 20-80 LOC scripts/CI.
2. Add `cargo-nextest` when Rust tests are numerous or slow - 🎯 8 🛡️ 8 🧠 4, roughly 80-220 LOC config.
3. Split profiles into local, CI, nightly, and destructive-platform - 🎯 8 🛡️ 9 🧠 5, roughly 150-400 LOC config/scripts.

Rules:

- nextest config is checked into repo;
- CI profile should report multiple failures instead of stopping at first one;
- retries are allowed only with owner and reason;
- slow filesystem tests get explicit timeouts.

### Dependency And License Gate - `P0`

The project will eventually ship native binaries. Dependencies are part of the product.

Required checks:

- RustSec advisory check for Rust crates;
- cargo-deny or equivalent for licenses, advisories, duplicate versions, bans, and sources;
- Dart/Flutter dependency freshness check before adding new dependencies;
- review of crates with `build.rs`, proc macros, unsafe, FFI, or native code;
- explicit exception file for accepted advisories/licenses with expiry and reason.

Rules:

- do not add dependency just for test convenience if a small fixture helper is enough;
- new dependency must have owner, purpose, and latest stable version checked;
- license policy must be compatible with desktop app distribution.

## Performance And Regression Gates

### Benchmarks Are Not Tests - `P1`

Benchmarks prove trends, not correctness.

Required benchmark classes:

- microbenchmarks for tree index insert/query, sort, search, pagination, path formatting;
- macro benchmarks for end-to-end scan throughput;
- UI benchmarks for large tree paging and row rendering;
- protocol benchmarks for query latency and WebSocket event pressure.

Rules:

- Criterion-style microbenchmarks are useful for hot algorithms;
- macro benchmarks record OS, filesystem, disk type, file count, byte count, thread count, cache state, and scanner options;
- CI timing gates must use generous thresholds or trend reporting because shared runners are noisy;
- never choose scanner architecture from tiny synthetic fixtures alone.

### Performance Budgets Need Product Meaning - `P1`

Useful budgets:

- time to first progress;
- time to first page of tree;
- memory per million nodes;
- max UI frame time during active scan;
- query latency for children/top/search;
- WebSocket queue memory under slow client;
- cancellation latency;
- cleanup receipt write latency.

Avoid:

- "scan 500 GB in X seconds" as the only metric;
- comparing cold macOS scan to warm Linux scan;
- ignoring skipped/protected paths in benchmark reports.

## Flakiness And Quarantine

### Flaky Tests Are Product Signals - `P1`

Filesystem and UI tests will be naturally harder than pure tests. Still, retries can hide real races.

Required behavior:

- every flaky test has owner and issue;
- quarantine has expiry;
- retry count is visible in CI output;
- flaky cleanup tests block cleanup release even if retried passing;
- repeated platform-specific flakes become adapter bugs.

### Determinism Rules - `P0`

Tests must control:

- clock;
- timezone;
- locale;
- random seed;
- file ordering;
- path separator display;
- hash map ordering;
- temp root;
- port allocation;
- daemon token;
- animation timing.

Without this, snapshots and protocol tests will fail for uninteresting reasons.

## Safety Rules For Destructive Tests

### Destructive Tests Are Opt-In Locally - `P0`

Required behavior:

- destructive tests require explicit env var;
- destructive tests require sentinel fixture root;
- destructive tests log target root before execution;
- cleanup adapter refuses non-fixture paths in test mode;
- no test ever empties system Trash/Recycle Bin;
- tests move only disposable files to Trash;
- receipts are written and then verified.

### Test Cleanup Must Not Destroy Evidence - `P0`

When a destructive test fails, evidence is useful.

Required behavior:

- failed fixture root is preserved or archived if safe;
- logs are sanitized;
- receipt remains available;
- CI artifact excludes secrets and raw user paths;
- test cleanup does not mask partial outcome bugs.

## Boundary And Architecture Tests

### Import Boundary Tests Are Required - `P0`

Clean Architecture rules should be mechanically enforced.

Required checks:

- domain does not import Flutter, Dio, Drift, GetIt, Modularity, pdu, Trash, HTTP, WebSocket, or platform APIs;
- application does not import Flutter UI or infrastructure implementations;
- feature packages do not import other feature packages directly;
- generated bridge/protocol DTOs do not leak into domain;
- adapters do not leak into domain tests.

### Contract Tests Beat Mock-Driven Architecture - `P1`

Mocks can make a bad abstraction look good.

Required behavior:

- fakes model behavior, not only expected calls;
- contract tests apply to fake and real adapters;
- adapter errors are typed and tested;
- domain tests validate invariants without mocking internals;
- integration tests validate composition roots.

## MVP Cut Line

Before first scanner beta:

- local fast gate exists;
- PR gate runs Dart/Flutter/Rust checks for existing code;
- fixture builder supports basic file trees;
- scan domain/application tests exist;
- protocol snapshot tests exist once protocol exists;
- import boundary tests exist.

Before first cleanup-capable beta:

- cleanup DeletePlan property tests exist;
- stale identity/replaced path tests exist;
- real Trash smoke tests pass on every supported OS;
- receipt crash recovery tests exist;
- destructive tests are opt-in locally and mandatory in controlled CI;
- dependency/advisory/license gate exists;
- golden/widget tests cover the delete queue and warnings;
- release gate blocks if cleanup safety tests fail.

Before public release:

- installer/update/uninstall smoke tests;
- permission doctor tests;
- support bundle redaction tests;
- macro benchmark baseline;
- compatibility test between UI and daemon versions;
- dependency and license report attached to release artifacts.

## Summary

The safe stance:

```text
Coverage is not the goal.
Invariants are the goal.
Fast gates protect development.
Slow gates protect platform reality.
Release gates protect user files.
Destructive tests never touch real user data.
Protocol and cleanup contracts must be snapshot/property tested.
```

The invariant:

```text
Clean Disk is not allowed to ship cleanup behavior that has not been proven against disposable fixtures, stale identities, partial outcomes, crash recovery, and platform Trash capability on every supported OS.
```
