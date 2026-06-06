# Critical Zone - Update, Release, Rollback, And App Identity Safety

Last updated: 2026-05-16.

This file starts the focused critical-zone phase after
`../preimplementation-critical-zones-deep-dive.md`. New global risks should live
in separate files when they deserve their own failure model, state machine,
release gates, and test fixtures.

## Sources Reviewed

- The Update Framework specification: signed metadata, versioned metadata,
  expiration, snapshot/targets/timestamp roles, and resistance to rollback,
  freeze, and mix-and-match update attacks.
  Source: https://theupdateframework.github.io/specification/latest/
- NIST SP 800-218 SSDF: protect all software components from tampering and
  unauthorized access, produce secure releases, and respond to vulnerabilities.
  Source: https://csrc.nist.gov/pubs/sp/800/218/final
- SLSA specification and provenance model: provenance describes where, when, and
  how artifacts were built so consumers can verify expected build behavior.
  Sources: https://slsa.dev/spec/ and https://slsa.dev/spec/v1.1/provenance
- Apple Developer ID and notarization: direct macOS distribution relies on
  Developer ID, Gatekeeper, and notarization tickets for user trust.
  Source: https://developer.apple.com/developer-id/
- Microsoft MSIX signing and Windows code-signing docs: Windows install trust
  depends on signed packages, trusted certificates, timestamping, package
  integrity, and SmartScreen reputation behavior.
  Sources:
  https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide
  and https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options
- Microsoft MSIX persistent identity: certificate changes can break update
  continuity unless explicit identity bridging artifacts are used.
  Source: https://learn.microsoft.com/lb-lu/windows/msix/package/persistent-identity
- Tauri updater docs as a practical desktop reference: signed updater artifacts,
  updater public keys, HTTPS in production, platform-targeted update payloads.
  Source: https://tauri.app/plugin/updater/

## Why This Is The Next Global Critical Zone

The scanner can be wrong in one subsystem. A bad update can invalidate nearly
every subsystem at the same time:

- app binary, daemon binary, helper binary, scanner adapter, rule packs, protocol
  DTOs, Drift schema, operation journal, cleanup receipts, and settings can all
  move to different versions;
- macOS app identity and helper signing changes can affect Gatekeeper,
  notarization, Full Disk Access, TCC behavior, and user trust prompts;
- Windows signing identity, package publisher, timestamping, SmartScreen
  reputation, and MSIX identity continuity can affect installation and update
  behavior;
- cleanup can be in-flight when an updater wants to replace binaries;
- rollback can launch older code against newer database, journal, rule-pack, or
  protocol state;
- remote/headless deployments may have operator policies and uptime expectations
  that are different from local desktop installs.

This is a P0 design area because update safety sits above scanner correctness,
delete safety, persistence integrity, protocol compatibility, and platform
permission continuity.

## Top 3 Next Separate Critical Zones

1. Update, release, rollback, and app identity safety - 🎯 8  🛡️ 10  🧠 8, roughly 1600-4200 LOC/tests/docs.
   Selected now. This is the highest global blast-radius zone because it can
   break multiple safety boundaries in one release.
2. Recommendation policy false-positive and rule-pack safety - 🎯 7  🛡️ 9  🧠 8, roughly 1400-3600 LOC/tests/docs.
   Needs a later focused file. The risk is not scan accuracy, but unsafe
   interpretation: calling persistent app data "cache", recommending deletion
   from shared package stores, or applying old rules to new tool layouts.
3. Restore, quarantine, and undo semantics after cleanup - 🎯 6  🛡️ 9  🧠 9, roughly 1800-5000 LOC/tests/docs.
   Needs a later focused file. Move-to-trash, quarantine, restore, cloud sync,
   NAS deletes, package-manager cleanup, and admin policy do not share one
   universal undo model.

## Core Rule

Treat updates as safety-critical state transitions, not as file replacement.

An update is allowed only when these contracts hold:

- release artifacts are authenticated and traceable to a trusted build;
- app, daemon, helper, protocol, schema, rule pack, and journal versions are
  compatible;
- active destructive operations are quiesced or durably recoverable;
- rollback is compatibility-checked before old code touches new state;
- app identity changes are treated as permission-impacting migrations;
- feature flags fail closed for unknown or incompatible versions.

## Release Artifact Trust Model

Release artifacts must be described by a manifest that is signed or covered by
signed update metadata.

```text
ReleaseArtifactSet
  app_bundle
  daemon_binary
  helper_binary
  protocol_schema
  drift_schema
  rule_pack
  migration_bundle
  updater_metadata
  signature_bundle
  sbom
  provenance
```

Required metadata per artifact:

- stable artifact id;
- semantic version;
- target OS and architecture;
- build profile and channel;
- cryptographic digest;
- signature or metadata inclusion proof;
- provenance reference;
- minimum and maximum compatible protocol versions;
- minimum and maximum compatible state schema versions;
- destructive-feature capability flags.

Practical direction:

- Use TUF-like concepts for update metadata even if the MVP does not adopt a TUF
  library immediately: signed metadata, target hashes, metadata version numbers,
  expiration, and separation of update roles.
- Use SLSA-style provenance as the model for release auditability: every app,
  daemon, helper, and rule-pack artifact should be traceable to a source commit,
  build definition, builder identity, and CI run.
- Use NIST SSDF as the baseline policy: protect code and release artifacts from
  tampering and unauthorized access, and keep evidence for release integrity.
- Do not let cleanup rule packs update through a weaker channel than binaries.
  A malicious or broken rule pack can cause more damage than a scanner bug.

Kill criteria:

- update metadata is unsigned or authenticated only by HTTPS;
- app, daemon, helper, or rule pack can be replaced outside one compatibility
  manifest;
- build artifact cannot be traced to source commit and build run;
- the release process cannot prove which rule pack shipped with a binary;
- the app accepts older update metadata without anti-rollback checks;
- update metadata has no expiry, so freeze attacks are invisible.

## Operation Quiesce Gate

Updater decisions must flow through daemon/app state, not process-kill behavior.

```text
UpdateGateState
  idle_safe
  active_scan_can_drain
  active_cleanup_blocks_update
  journal_recovery_required
  migration_required
  update_downloaded_pending_restart
  update_aborted_safe
```

Rules:

- Cleanup execution blocks install, restart, daemon replacement, helper
  replacement, and schema migration until the cleanup journal and receipt state
  are durable.
- Active scans may be drained or cancelled, but the result snapshot must be
  explicitly marked stale after update.
- The updater must not steal the daemon single-instance lock.
- If the OS installer replaces files anyway, startup enters recovery mode before
  accepting scan/delete commands.
- If recovery is required, the UI must show a repair state and disable destructive
  commands until reconciliation finishes.
- Quiesce state must be observable by the app, daemon, updater, and support
  diagnostics without exposing private paths.

Kill criteria:

- auto-update kills the daemon while a trash/delete operation is in progress;
- migration runs before unresolved cleanup journal entries are reconciled;
- old and new daemons can both accept commands;
- updater cannot tell whether cleanup is active;
- failed update leaves the UI connected to a daemon with unknown binary version.

## Compatibility Manifest

Clean Disk needs a first-class compatibility document per release.

```text
CompatibilityManifest
  app_version
  daemon_version
  helper_version
  protocol_version_range
  db_schema_from_to
  journal_schema_from_to
  rule_pack_version
  fs_usage_engine_version
  pdu_adapter_version
  min_client_version
  rollback_allowed_to
  destructive_features_enabled
```

Rules:

- New app against old daemon and old app against new daemon are explicit cases,
  not accidental HTTP errors.
- Unknown daemon versions disable destructive commands.
- Unknown client versions are rejected for destructive commands.
- DB migration and protocol migration are separate decisions.
- Rollback is allowed only if database, journal, receipt, rule-pack, and protocol
  state are compatible with the previous binary.
- Rule-pack changes invalidate recommendation caches when classification
  semantics change.
- Feature flags are constrained by compatibility state. A remote flag must not
  enable a destructive feature on an incompatible daemon.

Kill criteria:

- `404`, `500`, or JSON parse failure is the compatibility strategy;
- old UI can send delete commands to newer daemon semantics;
- rollback launches old code against a migrated journal;
- migration changes reclaim accounting without invalidating cached estimates;
- protocol schema changes without generated DTO and fixture updates.

## App Identity Continuity

App identity is a permission boundary, not cosmetic packaging metadata.

macOS rules:

- Developer ID signing and notarization are part of direct distribution trust.
- Bundle id, Team ID, helper identity, hardened runtime, entitlements, and app
  installation path can affect permission continuity and user prompts.
- Full Disk Access and TCC behavior must be re-probed after update from the real
  scanner/helper process, not assumed from previous app state.

Windows rules:

- Public distribution requires a trusted signing path, not self-signed packages.
- MSIX publisher identity and certificate continuity matter for updates.
- Timestamping matters because packages without timestamping can fail after
  certificate expiry.
- SmartScreen reputation can affect user trust even when code is signed.
- If we ship MSIX later, persistent identity and certificate change flows need a
  specific release plan.

Linux rules:

- AppImage, deb, rpm, Flatpak, Snap, and distro package flows have different
  update trust and sandbox models.
- If packaged through a store or distro, update authority may belong to the
  platform, not to Clean Disk.

Rules:

- Signing identity changes are permission-impacting migrations.
- Helper identity changes require a capability re-probe and a repair UX.
- The app must show scan-quality degradation if an update loses access.
- Support bundles may include identity fingerprints and signing status, but not
  secrets, tokens, or raw private paths.
- Update docs must separate development signing from production signing.

Kill criteria:

- changing signing cert, bundle id, publisher id, or helper identity is treated
  as a normal patch release;
- update breaks Full Disk Access but UI still claims a complete scan;
- helper and app are signed with incompatible identities;
- installer path assumptions break after app translocation or package relocation;
- Windows package publisher change breaks update chain without a bridge plan.

## Rollback And Partial Update Model

Rollback is not "run the old binary". It is a compatibility transition.

Partial update states:

```text
PartialUpdateState
  app_new_daemon_old
  app_old_daemon_new
  helper_mismatch
  schema_migrated_binary_old
  rule_pack_mismatch
  updater_metadata_new_artifacts_old
  downloaded_artifact_unverified
```

Rules:

- Every startup validates app, daemon, helper, DB schema, journal schema, rule
  pack, and protocol version.
- Any mismatch enters a defined mode: normal, read-only, repair-required, or
  hard-fail.
- Read-only mode may allow viewing previous scan results but not cleanup.
- Migration must be monotonic and receipt-backed. Destructive state must never be
  overwritten by rollback.
- A rollback that cannot safely handle current state must stop before opening
  write-mode persistence.
- Rule-pack rollback invalidates recommendation caches.

Kill criteria:

- app rollback after migration can still execute cleanup;
- helper binary remains old after daemon requires new helper semantics;
- failed download leaves metadata accepted as current release;
- rollback does not invalidate stale recommendations;
- old daemon accepts commands from a newer UI without negotiated capabilities.

## Update Channels And Staged Rollout

Channels must be isolated by policy and metadata.

```text
UpdateChannel
  development
  staging
  production
  enterprise_pinned
  offline_manual
```

Rules:

- Development, staging, and production use separate update metadata roots or
  equivalent trust boundaries.
- Production app must never accept development update metadata.
- Enterprise-pinned and remote/headless deployments can disable auto-install and
  require operator approval.
- Staged rollout can disable destructive features if crash, migration, cleanup,
  or support signals cross a threshold.
- Kill switches must be signed/configured so they can disable unsafe behavior,
  but cannot enable destructive behavior that compatibility gates rejected.
- Manual offline update must still validate signatures and compatibility.

Kill criteria:

- staging and production share mutable update JSON without channel separation;
- hotfix bypasses provenance, signing, or compatibility gates;
- remote/headless daemon auto-updates without operator policy;
- kill switch can enable cleanup despite failed compatibility checks.

## Data And Privacy In Update Telemetry

Update diagnostics are useful, but they can easily leak private state.

Allowed by default:

- app/daemon/helper version;
- OS version and architecture;
- update channel;
- update result enum;
- compatibility state enum;
- schema migration result enum;
- signed artifact digest prefix;
- coarse error category.

Disallowed by default:

- raw paths;
- delete targets;
- raw search strings;
- full scan tree;
- auth tokens;
- signed update URLs with credentials;
- local usernames in labels;
- high-cardinality path-like metrics.

Rules:

- Update failures should have stable error codes that map to support docs.
- Support bundles may include redacted update manifests and compatibility reports.
- Telemetry must not be required for update safety.

## Testing And Release Gates

Required fixture names:

```text
kill_during_cleanup_update
old_client_new_daemon_delete
new_client_old_daemon_delete
db_migrated_then_rollback
permission_regression_after_update
helper_binary_mismatch
rule_pack_mismatch
update_metadata_rollback
update_metadata_freeze
partial_artifact_replacement
unsigned_rule_pack_rejected
staging_metadata_rejected_by_prod
```

Required gates:

- upgrade tests from the oldest supported version to current;
- rollback tests from current to each supported rollback target;
- compatibility matrix tests for app/daemon/helper/protocol combinations;
- signed metadata verification test;
- expired metadata rejection test;
- anti-rollback metadata test;
- partial update recovery test;
- cleanup-in-flight update block test;
- schema migration backup/recovery test;
- rule-pack cache invalidation test;
- macOS signing/notarization validation in release CI;
- Windows signing/timestamp/package identity validation in release CI.

## MVP Cut Line

MVP can avoid a full automatic updater if the safety model is not ready.

Acceptable MVP:

- manual install/update only;
- update availability check is allowed;
- update download is allowed only after signature/metadata verification is
  designed;
- install/restart only when daemon is idle or safely quiesced;
- destructive commands are disabled during update/recovery/migration;
- rule packs are bundled with app/daemon release artifacts;
- no out-of-band rule-pack updates;
- no permanent delete feature;
- no auto-update in remote/headless mode.

Not acceptable MVP:

- auto-install while cleanup can be active;
- unsigned or HTTPS-only update trust;
- separate daemon/helper replacement without compatibility manifest;
- app claims scan completeness after permission regression;
- rollback without DB/journal compatibility handling.

## Architecture Impact

Rust host:

- `clean-disk-server` owns update compatibility reporting because it owns daemon
  lifecycle, protocol mapping, config, persistence access, observability, and
  concrete adapter wiring.
- Reusable `fs_usage_*` crates must not know app release channels or updater
  policy. They may expose library version and capability metadata.
- Cleanup use cases must expose quiesce state and recovery requirements to the
  host through application ports.

Flutter app:

- Flutter queries update/compatibility state through product protocol adapters.
- UI disables cleanup commands when compatibility state is not fully safe.
- UI shows permission regression as scan-quality degradation, not as a generic
  update error.

Protocol:

- Include `daemonVersion`, `protocolVersion`, `compatibilityState`,
  `destructiveCommandsEnabled`, and `requiredClientAction` in capability DTOs.
- Treat update, migration, and recovery states as first-class enums.
- Unknown enum values must fail closed for cleanup.

Persistence:

- Migrations need backups or durable receipts.
- Cleanup journals must be reconciled before schema writes that old code cannot
  understand.
- Cache records must include producer versions for scanner, rule pack,
  accounting model, and protocol.

## Decision

The next separate critical-zone document is update, release, rollback, and app
identity safety.

We should not implement automatic updates, out-of-band rule packs, helper binary
replacement, or production release channels until this file's quiesce,
compatibility, artifact trust, and rollback gates have at least a minimal spike
and test harness.
