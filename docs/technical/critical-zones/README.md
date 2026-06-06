# Critical Zones

This folder stores focused global critical-zone research created after
`../preimplementation-critical-zones-deep-dive.md` became too broad.

Use this folder for cross-cutting risks that can invalidate multiple guarantees
at once: scanner correctness, cleanup safety, daemon lifecycle, protocol
compatibility, release integrity, local permissions, and user trust.

Read this folder as release gates. If a feature touches one of these areas, the
feature is not ready until the relevant critical-zone invariants, kill criteria,
and acceptance gates are represented in design, tests, and runtime behavior.

Relation to implementation phases:

- runtime and scanner work must check Rust runtime execution;
- recommendations must check rule-pack safety;
- cleanup must check restore/undo, command sandbox, receipt durability, and
  reclaim-accounting docs;
- remote/headless cleanup must check remote authorization before destructive
  mode exists;
- release, updater, installer, helper, or protocol compatibility work must
  check update/release/rollback safety;
- support, diagnostics, logging, telemetry, or crash reporting work must check
  support bundle privacy evidence.

## Current Global Ranking

1. [Update, release, rollback, and app identity safety](update-release-rollback-safety.md) - 🎯 8  🛡️ 10  🧠 8, roughly 1600-4200 LOC/tests/docs.
   Selected first because one bad update can cross binary trust, daemon/runtime state,
   protocol compatibility, database migrations, cleanup journals, helper identity,
   package signing, and platform permissions.
2. [Rust runtime execution and worker-pool isolation](rust-runtime-execution.md) - 🎯 9  🛡️ 10  🧠 8, roughly 1600-4200 LOC/tests/docs.
   Selected next because the daemon execution model sits under scan speed,
   protocol responsiveness, cancellation truth, memory pressure, shutdown,
   panic containment, and future cleanup reliability.
3. [Recommendation policy, rule-pack safety, and false-positive control](recommendation-policy-rule-pack-safety.md) - 🎯 8  🛡️ 10  🧠 8, roughly 1500-4200 LOC/tests/docs.
   Important because bad cleanup advice can cause user harm even when the scanner is correct.
4. [Restore, quarantine, undo, and cleanup receipt safety](restore-quarantine-undo-safety.md) - 🎯 8  🛡️ 10  🧠 9, roughly 1800-5200 LOC/tests/docs.
   Important because "Move to Trash" is not a full restore guarantee across platforms,
   cloud providers, network shares, snapshots, and tool-managed storage.
5. [Tool command execution sandbox and side-effect control](tool-command-execution-sandbox.md) - 🎯 8  🛡️ 10  🧠 8, roughly 1800-5000 LOC/tests/docs.
   Important because official cleanup adapters are safer than raw deletion, but
   command execution brings PATH spoofing, scripts, environment, locks,
   credentials, output parsing, timeout, and cancellation risks.
6. [Remote/headless destructive cleanup authorization](remote-headless-destructive-cleanup-authorization.md) - 🎯 8  🛡️ 10  🧠 10, roughly 2600-7600 LOC/tests/docs.
   Important before remote cleanup because tenant/host authority, target scopes,
   audit, and operator policy wrap the same side-effect model.
7. [Persistent operation journal and receipt durability under low disk](persistent-operation-journal-receipt-durability-low-disk.md) - 🎯 8  🛡️ 10  🧠 9, roughly 1800-5200 LOC/tests/docs.
   Important because cleanup safety collapses if intent, item outcomes, receipts,
   and recovery markers cannot be durably written while the app is trying to free
   disk space.
8. [Support bundle, diagnostics export, and privacy-preserving evidence](support-bundle-diagnostics-export-privacy-evidence.md) - 🎯 8  🛡️ 10  🧠 8, roughly 1600-4600 LOC/tests/docs.
   Important because support/debug evidence can leak raw paths, tokens, receipts,
   scan trees, command output, crash memory, and remote audit data unless export
   is typed, redacted, bounded, and consented.

## Current Files

- [Update, release, rollback, and app identity safety](update-release-rollback-safety.md)
- [Rust runtime execution and worker-pool isolation](rust-runtime-execution.md)
- [Recommendation policy, rule-pack safety, and false-positive control](recommendation-policy-rule-pack-safety.md)
- [Restore, quarantine, undo, and cleanup receipt safety](restore-quarantine-undo-safety.md)
- [Tool command execution sandbox and side-effect control](tool-command-execution-sandbox.md)
- [Remote/headless destructive cleanup authorization](remote-headless-destructive-cleanup-authorization.md)
- [Persistent operation journal and receipt durability under low disk](persistent-operation-journal-receipt-durability-low-disk.md)
- [Support bundle, diagnostics export, and privacy-preserving evidence](support-bundle-diagnostics-export-privacy-evidence.md)

## Rule For New Files

Create a separate file when the topic has its own failure model, invariants,
state machine, release gates, and test fixtures. Do not append more broad passes
to `../preimplementation-critical-zones-deep-dive.md` unless the topic is only a
minor extension of an existing pass.
