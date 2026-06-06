# Implementation Edge Cases - Dependency And Supply Chain Governance

Last updated: 2026-05-13.

This file records edge cases for dependency selection, license policy, vulnerability gates, supply-chain trust, build scripts, procedural macros, release artifacts, SBOMs, update automation, vendoring/forks, and dependency drift.

Clean Disk is not a normal dashboard. It scans private files and can move data to Trash. A dependency that is acceptable in a simple UI may be too risky in a delete-capable daemon, installer, or scanner adapter.

Related documents:

- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Implementation edge cases testing quality gates](implementation-edge-cases-testing-quality-gates.md)
- [Implementation edge cases platform permissions packaging](implementation-edge-cases-platform-permissions-packaging.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Rust best practices research](rust-best-practices.md)
- [Rust architecture](rust-architecture.md)

## Sources Reviewed

- RustSec, [Advisory Database](https://rustsec.org/). Relevant points: `cargo-audit` audits `Cargo.lock`; `cargo-deny` can check advisories, licenses, bans, sources, and duplicate versions; `cargo-auditable` can embed dependency information into binaries.
- `cargo-deny`, [checks documentation](https://android.googlesource.com/toolchain/cargo-deny/+/HEAD/docs/src/checks/README.md). Relevant points: supported check classes include licenses, bans, advisories, and sources.
- Cargo Vet, [How it Works](https://mozilla.github.io/cargo-vet/how-it-works.html). Relevant points: `cargo vet` helps projects track third-party audits, supports exemptions for existing dependencies, and can import audits from trusted organizations.
- Dart, [Security advisories](https://dart.dev/tools/pub/security-advisories). Relevant points: `pub` surfaces GitHub Advisory Database advisories during dependency resolution, and root packages can explicitly ignore advisories.
- Dart, [`dart pub outdated`](https://dart.dev/tools/pub/cmd/pub-outdated). Relevant points: `pub outdated` identifies direct and transitive outdated packages, recommends update paths, and dependency updates must be tested.
- GitHub Docs, [Dependency review](https://docs.github.com/en/code-security/concepts/supply-chain-security/about-dependency-review). Relevant points: dependency review shows dependency diffs, release dates, usage, license, and vulnerability data in pull requests.
- GitHub Docs, [Dependabot version updates](https://docs.github.com/en/code-security/concepts/supply-chain-security/about-dependabot-version-updates). Relevant points: Dependabot can raise version and security update PRs for manifests, lockfiles, vendored dependencies, and GitHub Actions.
- Cargo Book, [Build scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html). Relevant points: `build.rs` is compiled and executed before package build; build scripts can link native libraries, generate code, inspect environment, and use build dependencies.
- Rust Reference, [Procedural macros](https://doc.rust-lang.org/reference/procedural-macros.html). Relevant points: procedural macros run during compilation, can access files and stdio, can panic or loop, and have the same security concerns as Cargo build scripts.
- Cargo Book, [Workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html). Relevant points: `workspace.dependencies` centralizes dependency versions, features are additive, and `workspace.lints` can propagate lint policy.
- SPDX, [License List](https://spdx.org/licenses/). Relevant points: SPDX provides standardized license identifiers and license expressions.
- CycloneDX, [SBOM](https://cyclonedx.org/capabilities/sbom/). Relevant points: SBOMs inventory first-party and third-party components, dependencies, and relationships to support vulnerability, licensing, and compliance workflows.
- SLSA, [Get started](https://slsa.dev/how-to/get-started). Relevant points: provenance documents build process and should be made available; GitHub Actions can support stronger provenance flows.
- Sigstore, [Cosign signing overview](https://docs.sigstore.dev/cosign/signing/overview/). Relevant points: keyless signing binds short-lived certificates to OIDC identity and records signing events in a transparency log.

## Severity Scale

- `P0` - dependency can execute privileged code, weaken delete safety, bypass architecture boundaries, introduce incompatible license obligations, compromise released binaries, or hide a vulnerable transitive dependency in a delete-capable component.
- `P1` - dependency can cause release friction, unsupported platforms, stale security posture, large binary/runtime bloat, update skew, non-reproducible builds, or noisy false confidence.
- `P2` - improves maintainability, auditability, dependency hygiene, release documentation, or future enterprise acceptance.

## Top 3 Governance Decisions

1. Dependency gate before every new production dependency - 🎯 10 🛡️ 10 🧠 4, roughly 150-500 LOC across docs, checklist, CI config, and review templates once Rust CI exists.
2. `cargo-deny` plus `pub` advisory/outdated checks as baseline, `cargo-vet` and SBOM/provenance later for release hardening - 🎯 9 🛡️ 9 🧠 6, roughly 400-1200 LOC/config across Rust, Flutter, CI, and release scripts.
3. Fully vendored dependency tree and strict offline reproducible builds from day one - 🎯 5 🛡️ 8 🧠 9, roughly 1500-5000 LOC/config plus operational burden. Useful later if distribution/security requirements demand it, too heavy before the dependency graph stabilizes.

My recommendation: start with a strict dependency review checklist and automated advisory/license/source checks. Add SBOM, artifact signing, provenance, and cargo-vet before public binary releases, not after a dependency incident.

## Core Principle

Dependencies are part of the product boundary.

Minimum dependency record:

```text
DependencyDecision
  package_name
  ecosystem
  version_requirement
  owner
  purpose
  used_by_crates_or_packages[]
  runtime_surface
  privilege_surface
  license
  advisory_status
  maintenance_status
  build_script_or_proc_macro
  native_code_or_ffi
  feature_flags
  alternatives_considered[]
  accepted_risks[]
  review_date
```

Rules:

- no production dependency without a purpose and owner;
- no scanner, Trash, filesystem, networking, serialization, crypto, process, installer, or update dependency without explicit review;
- no dependency type leaks from domain/application public APIs unless intentionally part of the contract;
- no `build.rs`, procedural macro, FFI, native library, or git dependency without a higher-friction review;
- no ignored advisory without documented applicability analysis and expiry/revisit date.

## Bounded Context

### Dependency Governance Is Not General Security - `P1`

Security documents describe threats and controls. Dependency governance decides what code is allowed to enter the product and release pipeline.

Required behavior:

- security/privacy owns threat model and runtime controls;
- dependency governance owns selection, license, advisories, source trust, feature flags, and release artifact transparency;
- testing quality gates execute the policy in CI;
- architecture docs keep dependency direction stable.

Avoid:

- treating `cargo audit` as the entire policy;
- treating pub.dev likes/popularity as enough package review;
- adding convenience crates to inner layers because they save a small amount of code;
- deferring license checks until release packaging.

### Runtime Surface Matters More Than Package Count - `P0`

A small dependency in the delete path is riskier than a large dev dependency used only in tests.

Required dependency classes:

- `domain_only` - no IO, no async runtime, no platform APIs, no unsafe by default;
- `application_policy` - use cases, ports, validation, no concrete adapters;
- `protocol_boundary` - serde/DTO/schema dependencies, stable and carefully versioned;
- `filesystem_adapter` - scanner, Trash, identity, metadata, watcher, xattr, platform APIs;
- `transport_adapter` - HTTP, WebSocket, TLS, CORS, auth middleware;
- `ui_runtime` - Flutter packages, web UI dependencies, icons, design system dependencies;
- `build_release_tooling` - signing, packaging, codegen, CI tools;
- `dev_test_only` - test fixtures, property tests, benchmarks, mocks.

The review burden scales with runtime surface, not only with direct/transitive count.

## Rust Dependency Edge Cases

### `build.rs` Is Compile-Time Code Execution - `P0`

Cargo build scripts are compiled and executed during builds. They can inspect environment, link native libraries, generate files, and affect compilation.

Required behavior:

- flag every new `build.rs` dependency in review;
- prefer crates without build scripts for inner and protocol crates;
- build scripts are acceptable only in adapter/release crates when the value is real;
- build script output and native link behavior must be stable in CI;
- cross-compilation paths are tested before release packaging depends on them.

Avoid:

- adding native `-sys` crates casually;
- trusting a crate because the Rust API looks small while its build script is complex;
- allowing build scripts in domain/application crates without an explicit exception.

### Procedural Macros Have Build-Script-Level Risk - `P0`

Rust procedural macros run during compilation with compiler resources and file access.

Required behavior:

- review proc macro dependencies separately from runtime dependencies;
- keep proc macros out of domain/application if hand-written code is reasonable;
- allow common mature macros only with explicit benefit: `serde`, `thiserror`, test tools, codegen boundaries;
- keep generated code out of sensitive invariants unless tests cover generated behavior;
- pin and review macro-heavy dependencies before release builds.

Avoid:

- using macro frameworks that hide business rules;
- using derive macros to avoid writing important validation;
- adding codegen that makes architecture boundaries invisible.

### Cargo Feature Unification Can Change Behavior - `P1`

Cargo features are additive across the dependency graph. A feature enabled by one crate can affect another crate that uses the same dependency.

Required behavior:

- centralize shared versions in `workspace.dependencies`;
- keep feature sets narrow;
- prefer `default-features = false` where practical and documented;
- snapshot effective dependency features before releases;
- review broad features for Tokio, serde, HTTP/OpenAPI, platform APIs, compression, TLS, and tracing.

Avoid:

- enabling "full" feature sets by default;
- letting a dev/test dependency pull runtime features into production by accident;
- assuming crate-local feature declarations are isolated.

### Public Dependencies Can Leak Into Architecture - `P1`

If domain/application public APIs expose external crate types, we inherit that crate's SemVer, maintenance, and conceptual model.

Required behavior:

- `pdu`, `axum`, `tokio`, `trash`, platform APIs, and WebSocket crates remain adapter details;
- protocol DTOs expose our own types, not pdu trees or HTTP library types;
- stable inner crates avoid public dependency types unless explicitly accepted;
- API review checks public function signatures and re-exports.

Avoid:

- returning `pdu` nodes from scan application services;
- accepting framework request/response types in use cases;
- letting Flutter DTOs become Rust domain types.

## `pdu`, Scanner, And Filesystem Adapter Governance

### `pdu` Is A Strategic Dependency, Not A Utility - `P0`

`parallel-disk-usage` is the current selected scanner plan as a Rust library adapter. That makes it a high-impact dependency.

Required behavior before production integration:

- record crate version, license, repository activity, maintainer status, release cadence, and transitive dependency graph;
- map every pdu option we rely on into our own adapter config;
- snapshot pdu output behavior on canonical fixtures;
- test hardlinks, symlinks, permission denied, mount boundaries, hidden/system files, empty dirs, huge trees, cancellation, and changing files;
- keep pdu types inside `scan/infrastructure/pdu`;
- define a fallback/replace strategy if pdu API or behavior changes.

Avoid:

- making pdu's tree model our domain model;
- relying on pdu CLI output in production;
- upgrading pdu without fixture diffs;
- treating faster benchmarks as enough acceptance.

### Trash/File Operation Crates Need Destructive-Path Review - `P0`

Any crate that moves or deletes files is more sensitive than ordinary IO.

Required behavior:

- keep Trash behind `TrashAdapter`;
- require per-platform fixture tests before enabling cleanup beta;
- review platform support, maintenance, unsafe/FFI, mount behavior, and error mapping;
- map crate errors into typed outcomes;
- do not expose crate-specific error strings to UI as policy decisions.

Avoid:

- direct UI calls to Trash crates;
- direct permanent delete fallback without separate user confirmation;
- accepting Linux desktop assumptions as universal Linux behavior.

## Flutter/Dart Dependency Edge Cases

### Pub Advisories Are Resolver-Time Signals, Not Full Review - `P1`

Dart `pub` surfaces security advisories during resolution, but it does not replace package health, license, and platform review.

Required behavior:

- run `fvm dart pub outdated` or workspace equivalent as a regular maintenance check;
- treat `pub get` advisory output as a review blocker unless explicitly triaged;
- ignored advisories require reason, owner, and expiry;
- review transitive changes when lockfiles change;
- check desktop/web platform support before adding Flutter packages.

Avoid:

- suppressing advisories permanently in `pubspec.yaml`;
- updating Flutter packages without running desktop and web smoke tests;
- adding UI convenience packages when the design system can cover the primitive cleanly.

### Flutter Web UI Dependencies Are Part Of The Local Daemon Attack Surface - `P0`

If the web UI can command a local daemon, frontend dependencies are not harmless visual code.

Required behavior:

- keep web dependencies minimal;
- no package that injects remote scripts, eval-heavy code, or uncontrolled HTML into daemon control surfaces;
- lockfile changes involving web UI dependencies require dependency review;
- CSP and local daemon auth remain server-side controls, not package trust assumptions;
- generated web bundle provenance matters for releases.

Avoid:

- assuming local daemon token protects against all frontend compromise;
- allowing rich markdown/HTML renderers in privileged flows unless sanitized and justified;
- pulling analytics/tracking libraries into local cleanup UI.

## License And Compliance Edge Cases

### License Compatibility Must Be Checked Before Adoption - `P0`

Clean Disk may ship binaries, desktop installers, web UI assets, and possibly server images. License obligations differ across these modes.

Required behavior:

- use SPDX identifiers where possible;
- define allowed, review-required, and denied license classes;
- review copyleft, network-copyleft, unknown, custom, dual, and missing license cases manually;
- record license choices for vendored packages and generated assets;
- keep license notices generation as part of release packaging.

Practical initial policy:

```text
Allowed by default:
  MIT
  Apache-2.0
  BSD-2-Clause
  BSD-3-Clause
  ISC
  Zlib
  Unicode-3.0

Review required:
  MPL-2.0
  LGPL*
  GPL*
  AGPL*
  custom LicenseRef
  missing license
  non-code asset licenses

Denied until explicitly accepted:
  unknown runtime dependency license
  license that conflicts with intended distribution
```

Avoid:

- assuming transitive dependency licenses are irrelevant;
- assuming assets/icons/fonts have the same license as code;
- treating GitHub repo license as enough when published package metadata differs.

### Dual Licenses Need An Explicit Choice - `P1`

Many Rust crates use `MIT OR Apache-2.0`. Some packages use more complex expressions.

Required behavior:

- record which branch of a dual license we rely on if it matters for notices;
- parse license expressions with tooling, not string contains;
- document manual decisions for ambiguous expressions;
- do not normalize away `WITH` exceptions.

## Vulnerability And Update Edge Cases

### Advisory Checks Need Triage, Not Blind Auto-Fail Forever - `P1`

Some advisories affect unused features or platforms. Some vulnerable transitive dependencies have no immediate update path.

Required behavior:

- CI fails for critical/high reachable advisories in production dependencies;
- low/unreachable advisories can be temporarily ignored only with owner, reason, and expiry;
- ignore entries live in config with comments, not hidden in CI;
- stale ignores fail after expiry;
- release notes include known dependency risks when relevant.

Avoid:

- ignoring advisories because "it is only transitive";
- accepting a vulnerable dependency because no exploit is known locally;
- merging a lockfile update without reviewing advisory delta.

### Automated Updates Can Create False Safety - `P1`

Dependabot helps with update discovery, but a passing PR is not a product-level dependency review.

Required behavior:

- group low-risk updates to reduce noise;
- separate scanner/Trash/security/transport dependencies from routine UI/dev updates;
- require fixture diffs for scanner-related updates;
- require smoke tests for Flutter web/desktop package updates;
- update GitHub Actions themselves, not only code packages.

Avoid:

- auto-merging dependency updates that touch delete path, scanner path, transport auth, installer, or update tooling;
- letting Dependabot go silent because too many stale PRs are open;
- treating green CI as proof that new dependency behavior is safe.

## Release Artifact Governance

### Lockfiles Prove The Build Inputs Only If The Release Uses Them - `P0`

The release binary must be built from the reviewed lockfiles and workflow, not from an untracked local environment.

Required behavior:

- commit `Cargo.lock` for Rust application binaries;
- commit Flutter/Dart lockfiles for app packages where applicable;
- release builds run from clean CI;
- release process records toolchain versions: Flutter/FVM, Dart, Rust, target triples, linker/signing tool versions;
- release artifacts store build metadata and source revision.

Avoid:

- building public installers from a developer laptop;
- changing lockfiles during release build;
- shipping binaries without knowing exact dependency graph.

### SBOM Is Inventory, Not A Security Guarantee - `P1`

SBOMs help users and future us understand what shipped, but they do not prove the artifact is safe.

Required behavior:

- generate SBOM for public releases once release pipeline exists;
- include Rust crates, Flutter/Dart packages, native libraries, and bundled web assets where practical;
- store SBOM next to release artifacts;
- keep SBOM generation deterministic enough for review;
- do not include private local paths in SBOM metadata.

Avoid:

- treating SBOM generation as vulnerability remediation;
- publishing incomplete SBOM as if it covers installer scripts and native helpers;
- mixing dev/test-only dependencies into runtime SBOM without labeling.

### Signing And Provenance Need User-Facing Verification Story - `P1`

Artifact signing and provenance are only useful if we know what users or support can verify.

Required behavior:

- macOS/Windows platform signing follows platform requirements from packaging docs;
- optional Sigstore/cosign style signing can be added for release assets when the release pipeline is stable;
- provenance is published with enough instructions to interpret it;
- signing identity and CI workflow are protected;
- release notes point to checksums/signatures once available.

Avoid:

- adding signatures that no one verifies;
- signing artifacts after manual mutation;
- storing long-lived signing secrets in broad CI contexts.

## Forking, Vendoring, And Patching Edge Cases

### Forks Are Product Dependencies - `P1`

Forking `pdu`, a Trash crate, or a platform crate may be justified, but it creates maintenance ownership.

Required behavior:

- fork decision has owner, upstream sync policy, patch list, and exit criteria;
- forked crate version is clearly distinguishable;
- security advisories for upstream still get monitored;
- local patches are small and reviewed;
- fork does not leak into domain/application APIs.

Avoid:

- silently pinning to a git fork forever;
- carrying patches without tests;
- assuming Dependabot/RustSec covers private forks automatically.

### Vendoring Is A Tradeoff, Not Free Security - `P2`

Vendoring can improve availability and audit control, but increases repository size and update burden.

Required behavior before vendoring:

- define why registry access is insufficient;
- decide whether vendored code is reviewed or only mirrored;
- run license/advisory checks against vendored state;
- document update cadence;
- keep vendored dependencies out of ordinary app code paths unless release requirements demand it.

Avoid:

- vendoring to avoid dependency review;
- editing vendored code without patch tracking;
- committing huge vendor trees before release process needs them.

## Native, FFI, And Platform Dependency Edge Cases

### Native Dependencies Expand The Support Matrix - `P1`

Rust and Flutter plugins may pull native libraries, SDKs, or platform permissions.

Required behavior:

- review every native dependency for macOS, Windows, Linux, web support;
- document minimum OS versions and packaging needs;
- test cross-compilation and notarization/signing impact;
- track whether dependency requires system-installed libraries;
- avoid native dependencies in shared/domain/application crates.

Avoid:

- accepting a macOS-only package in a universal UI layer;
- shipping a dependency that works in dev but fails in signed/notarized builds;
- hiding native library failures behind generic startup errors.

### GitHub Actions Are Also Dependencies - `P1`

CI actions can affect releases, signing, SBOMs, and uploaded artifacts.

Required behavior:

- update actions through Dependabot;
- pin high-risk release/signing actions deliberately;
- separate PR validation workflows from release workflows;
- restrict release workflow permissions;
- review action changes like dependency changes.

Avoid:

- using unpinned third-party actions in release workflows;
- letting PRs from forks access signing secrets;
- assuming package dependency review covers CI action dependencies.

## Architecture Enforcement

### Dependency Policy Must Match Clean Architecture Boundaries - `P0`

Allowed defaults:

```text
domain:
  no IO, no async runtime, no serde unless DTO-only reason exists, no pdu, no Flutter, no platform APIs

application:
  ports/use cases, typed errors, no HTTP/WS/framework/pdu/Trash/platform implementation

infrastructure:
  external crates allowed through adapters, reviewed by surface

interfaces:
  transport/protocol frameworks allowed, no domain rules

apps:
  composition roots may depend on concrete adapters
```

Required behavior:

- boundary checks fail if inner crates import forbidden external crates;
- dependency additions include target layer and allowed import scope;
- generated bridge/protocol code stays outside domain;
- architecture fitness functions run before cleanup-capable beta.

Avoid:

- solving a domain issue with an infrastructure crate;
- adding a dependency to a shared crate because two adapters happen to need it;
- creating `utils` crates that collect unrelated dependency needs.

## Operational Policy

### Dependency Review Checklist

Before adding a production dependency:

- what problem does it solve?
- why is local code not enough?
- what layer owns it?
- does it touch filesystem, delete, networking, auth, serialization, process, native APIs, installer, update, or build pipeline?
- does it have `build.rs`, proc macros, FFI, native libraries, or platform-specific behavior?
- what licenses apply?
- what advisories exist?
- is it maintained?
- what features are enabled?
- how large is the transitive graph?
- what tests protect our accepted behavior?
- what is the replacement/fork/rollback plan?

### Dependency Classes That Need Higher Friction

Higher review required:

- scanner/traversal crates;
- Trash/delete/file operation crates;
- HTTP/WebSocket/TLS/auth middleware;
- serialization/protocol schema generators;
- platform permission/native integration packages;
- installer/updater/signing packages;
- proc macro/codegen frameworks;
- crates with `build.rs`;
- crates with unsafe-heavy internals where used in critical paths;
- unmaintained/yanked/archived packages;
- git/path dependencies outside local workspace;
- packages with unknown/custom/copyleft/network-copyleft licenses.

## Testing And CI Gates

### Baseline Gates Before Rust Scanner Integration

Required before production Rust dependency integration:

- `cargo deny check` or equivalent policy planned;
- dependency review checklist exists;
- `pdu` adapter behavior fixtures exist before pdu upgrade acceptance;
- Rust application `Cargo.lock` committed once Rust app exists;
- Flutter lockfile policy documented;
- no dependency can enter scanner/delete/transport path without review.

### Baseline Gates Before Cleanup Beta

Required before cleanup-capable beta:

- Rust advisory/license/source checks in CI;
- Dart/pub advisory and outdated checks in maintenance workflow;
- GitHub dependency review enabled where repo hosting supports it;
- release workflow dependency/action review;
- SBOM plan accepted;
- ignored advisories have expiry;
- license notices generated or manually reviewed.

### Baseline Gates Before Public Binary Release

Required before public release:

- clean release from CI;
- exact source revision and lockfiles recorded;
- release artifact checksums;
- platform signing/notarization as needed;
- SBOM generated or explicit decision to postpone;
- dependency policy report archived;
- high-risk dependency changes blocked close to release unless explicitly approved.

## MVP Cut Line

Before first scanner prototype:

- dependency review checklist exists;
- `pdu` remains adapter-only;
- no pdu types in domain/application;
- no dependency policy required for throwaway CLI experiments, but prototype dependencies do not become production by accident.

Before first Rust daemon branch:

- workspace dependency policy is documented;
- `Cargo.lock` commitment rule is documented;
- build scripts/proc macros are review triggers;
- initial license allow/review/deny list exists;
- CI has a placeholder or issue for advisory/license/source checks.

Before first cleanup-capable beta:

- scanner, Trash, transport, and Flutter daemon-control dependencies are reviewed;
- advisory/license gates run in CI;
- ignored advisories have owner/reason/expiry;
- release artifacts are built from clean lockfiles;
- architecture boundary checks prevent dependency leaks inward.

## Summary

The safe stance:

```text
Dependency count is not the main risk.
Runtime authority is the main risk.
Build-time code execution is supply-chain risk.
Licenses are release blockers, not paperwork.
SBOM is inventory, not proof of safety.
Automation finds changes, humans accept risk.
Adapter dependencies must never become domain language.
```

The invariant:

```text
Clean Disk must not ship scan, delete, transport, installer, or update behavior through an unreviewed dependency path.
```
