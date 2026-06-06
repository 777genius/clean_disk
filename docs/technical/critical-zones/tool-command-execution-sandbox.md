# Critical Zone - Tool Command Execution Sandbox And Side-Effect Control

Last updated: 2026-05-16.

This file records the next global critical zone after
`restore-quarantine-undo-safety.md`.

The core risk: official cleanup commands are often safer than raw folder
deletion, but running external tools creates a new execution boundary. If Clean
Disk can run `docker`, `npm`, `cargo`, `pip`, `gradle`, `xcodebuild`, or future
tool adapters, then command construction, executable lookup, environment,
working directory, process lifetime, stdout/stderr, cancellation, partial
outcomes, and receipts become part of cleanup safety.

## Sources Reviewed

- OWASP OS Command Injection Defense Cheat Sheet: recommends avoiding OS
  commands when possible, separating command arguments from shell syntax, and
  using allowlist validation when commands are unavoidable.
  Source:
  https://cheatsheetseries.owasp.org/cheatsheets/OS_Command_Injection_Defense_Cheat_Sheet.html
- CWE-78: command injection includes improper neutralization of special elements
  in OS commands; argument injection is related and has its own nuance.
  Source: https://cwe.mitre.org/data/definitions/78.html
- CISA Secure by Design Alert: CISA and FBI call OS command injection a
  preventable vulnerability class and urge manufacturers to eliminate it during
  design, not only patch individual cases.
  Source:
  https://www.cisa.gov/resources-tools/resources/secure-design-alert-eliminating-os-command-injection-vulnerabilities
- Rust `std::process::Command`: child processes inherit the parent environment
  by default; `env_clear` disables environment inheritance; `current_dir` sets
  the child working directory.
  Source: https://doc.rust-lang.org/std/process/struct.Command.html
- Tokio `process::Command`: arguments should be passed as separate items;
  relative program paths with `current_dir` are platform-specific and unstable;
  `kill_on_drop` changes whether dropping a child handle kills the spawned
  process.
  Source: https://docs.rs/tokio/latest/tokio/process/struct.Command.html
- Microsoft `CreateProcess`: when an application name is not fully specified,
  Windows searches several locations including the parent current directory and
  `PATH`.
  Source:
  https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessa
- Microsoft Job Objects: jobs can associate child processes, apply limits,
  collect accounting information, and terminate associated process trees.
  Source: https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects
- Linux `getrlimit`/`setrlimit`: child processes inherit resource limits, and
  limits are preserved across `execve`.
  Source: https://man7.org/linux/man-pages/man2/getrlimit.2.html
- Linux kernel seccomp filter docs: syscall filtering reduces kernel surface but
  is not a complete sandbox; policy and information flow need other controls.
  Source:
  https://www.kernel.org/doc/html/v6.3/userspace-api/seccomp_filter.html
- Docker prune docs: Docker provides official prune commands, but volumes are
  not removed by default because they can contain important data; filters and
  `--volumes` change blast radius.
  Source: https://docs.docker.com/reference/cli/docker/system/prune/
- npm cache docs: npm cache data is integrity-verified, and `npm cache clean`
  requires `--force` because cleaning is normally unnecessary except reclaiming
  disk space.
  Source: https://docs.npmjs.com/cli/v11/commands/npm-cache/
- Cargo clean docs: `cargo clean` supports `--dry-run`, profile/target filters,
  and target directory selection.
  Source: https://doc.rust-lang.org/cargo/commands/cargo-clean.html
- pip cache docs: `pip cache info`, `remove`, `purge`, and `list` distinguish
  inspection, selective removal, and full cache purge.
  Source: https://pip.pypa.io/en/stable/topics/caching/
- Gradle managed directories docs: Gradle automatically cleans user home caches
  and cache cleanup policy is configured through init scripts tied to Gradle User
  Home.
  Source: https://docs.gradle.org/current/userguide/directory_layout.html

## Why This Is The Next Global Critical Zone

Recommendation safety decides what we are willing to suggest. Restore safety
decides what we can honestly recover. The next boundary is what happens when the
selected cleanup action is not a filesystem Trash move, but an official tool
command.

Examples:

- Docker cleanup is best done through Docker's API or CLI because Docker knows
  containers, images, layers, volumes, labels, and build cache better than a raw
  folder delete;
- package managers know their own caches better than a disk analyzer;
- build tools often have dry-run or scoped cleanup modes;
- tool commands can affect global shared stores, running containers, open
  projects, SDK state, or other users' work;
- command execution introduces injection, PATH spoofing, environment leaks,
  process-tree leaks, timeout ambiguity, output privacy, and partial outcome
  ambiguity.

This is P0 because a trusted recommendation can become dangerous at execution
time even if the recommendation and restore semantics are correct.

## Current Global Ranking

1. Tool command execution sandbox and side-effect control - 🎯 8  🛡️ 10  🧠 8, roughly 1800-5000 LOC/tests/docs.
   Selected now. This controls how official cleanup adapters execute external
   tools without becoming arbitrary command execution or unbounded side effects.
2. Multi-user, enterprise, and remote cleanup authorization - 🎯 6  🛡️ 9  🧠 8, roughly 1500-4500 LOC/tests/docs.
   Remote/headless cleanup needs operator policy, audit, target scopes, user
   ownership, and read-only defaults before destructive workflows are credible
   outside local desktop mode.
3. Extension/plugin execution and third-party cleanup packs - 🎯 5  🛡️ 9  🧠 9, roughly 2500-7000 LOC/tests/docs.
   If external contributors can ship executable adapters or rules, signing,
   review, sandboxing, revocation, capability manifests, and telemetry-safe
   kill switches become mandatory.

## Core Rule

Clean Disk does not run commands. It executes typed, allowlisted cleanup actions
through adapter-owned command plans.

```text
cleanup recommendation
  -> user-approved DeletePlan
  -> adapter preflight
  -> typed CommandActionPlan
  -> command policy validation
  -> sandboxed execution
  -> stdout/stderr bounded capture
  -> adapter result parser
  -> receipt
  -> post-action rescan/reconcile
```

Rules:

- no user-supplied shell strings;
- no `sh -c`, `cmd.exe /c`, PowerShell, AppleScript, or batch files in MVP
  cleanup adapters unless the adapter has a dedicated exception record;
- executable path is resolved before execution and recorded in the receipt;
- commands are adapter-defined and schema-validated, not built from arbitrary UI
  text;
- arguments are passed as separate values, not joined strings;
- environment starts empty or minimal, then adds an allowlisted set;
- working directory is explicit and not used to resolve the executable;
- each command has timeout, output limits, cancellation semantics, and a
  side-effect boundary;
- every result is itemized enough to explain what changed and what remains
  unknown.

Kill criteria:

- any feature executes arbitrary user text as a command;
- path search is used for destructive adapters without recording the resolved
  executable identity;
- inherited environment can leak tokens, credentials, proxies, or user-specific
  tool config into a cleanup tool unexpectedly;
- cancellation drops a process handle but leaves children running;
- UI treats a killed command as rollback;
- command output with raw paths, secrets, tokens, or project names is sent to
  telemetry;
- official command stdout is parsed as a single truth source without rescan.

## Command Action Plan Model

Use a typed plan that can be inspected, stored, and tested before execution.

```text
CommandActionPlan
  action_id
  adapter_id
  adapter_version
  tool_kind
  risk_tier
  executable_policy
  executable_identity
  argv_schema_version
  argv[]
  working_directory_policy
  environment_policy
  stdin_policy
  stdout_policy
  stderr_policy
  timeout_policy
  cancellation_policy
  process_group_policy
  resource_policy
  expected_side_effects
  dry_run_plan
  parse_contract
  receipt_contract
```

`CommandActionPlan` is not public API for arbitrary automation. It is an
internal execution contract produced only by trusted cleanup adapters.

### Executable Policy

```text
ExecutablePolicy
  bundled_executable
    executable is shipped with Clean Disk and verified by app update trust

  system_known_path
    executable is expected at a platform-specific absolute path

  discovered_toolchain_path
    executable path is discovered by adapter-specific probe and user-approved

  user_configured_path
    user selected an executable path, stored with identity and warning level

  external_path_lookup
    not allowed for destructive actions in MVP
```

Rules:

- prefer official API/library before CLI when available and stable;
- prefer absolute executable paths;
- do not trust `PATH` for destructive commands by default;
- if discovery is needed, perform it in a read-only probe phase and record where
  the tool was found;
- revalidate executable identity before execution;
- record version output as evidence when the tool has a stable version command;
- block or warn if executable path changed between preflight and execution.

Why: Windows `CreateProcess` can search the application directory, current
directory, system directories, Windows directory, and `PATH` when the executable
name is not fully specified. Tokio also documents platform-specific ambiguity
for relative executable paths with `current_dir`.

Kill criteria:

- command plan has `program = "docker"` with no resolved absolute path;
- executable discovery runs in a user-controlled working directory;
- tool version is not included in receipt for tool adapters whose behavior
  changes across versions;
- app allows a project-local fake `docker`, `npm`, or `cargo` to satisfy a
  destructive adapter.

### Argument Policy

```text
ArgumentPolicy
  static_args
  enum_args
  path_args
  duration_args
  size_args
  label_filter_args
  forbidden_args
```

Rules:

- each argument is a separate `OsString`;
- never concatenate flags and values when the tool supports separate arguments;
- validate enums and option names against adapter schema;
- path arguments are canonicalized where possible and linked to approved target
  scopes;
- untrusted path text is never interpreted as extra flags;
- forbid dangerous broad flags unless the DeletePlan explicitly carries that
  risk tier.

Examples:

- `docker system prune --volumes` is a different action from `docker system
  prune`;
- `cargo clean --dry-run` is safe preview, while `cargo clean` is execution;
- `npm cache clean --force` is intentionally high-friction in npm docs and must
  be shown as such in our UI;
- `pip cache purge` is broad, while `pip cache remove <pattern>` is narrower.

Kill criteria:

- adapter accepts arbitrary extra args from UI;
- path beginning with `-` can become a flag;
- shell quoting is treated as a safety boundary;
- command preview shows one command but executor runs a broader command.

### Environment Policy

```text
EnvironmentPolicy
  env_clear: true
  allow:
    HOME
    USERPROFILE
    TMPDIR
    TEMP
    TMP
    LANG
    LC_ALL
    PATH
  deny:
    AWS_*
    GITHUB_*
    NPM_TOKEN
    NODE_AUTH_TOKEN
    CARGO_REGISTRIES_*_TOKEN
    PIP_INDEX_URL
    HTTP_PROXY
    HTTPS_PROXY
    ALL_PROXY
    SSH_AUTH_SOCK
```

The exact allowlist is adapter-specific. Some tools need `HOME` or
`USERPROFILE` to locate caches. Some need `PATH` only for subprocesses they
spawn. Some should receive no network/proxy credentials.

Rules:

- default to `env_clear`;
- add only adapter-required env variables;
- redact all env values in logs and receipts unless explicitly safe;
- avoid leaking package registry tokens to cleanup commands;
- set locale deterministically when output parsing depends on text;
- prefer machine-readable output to localized text where tools provide it.

Kill criteria:

- command inherits all daemon environment variables;
- command output parser depends on localized human text;
- proxy or registry credentials are exposed to a tool adapter that does not need
  network;
- support bundle includes env values.

## Shell Policy

The MVP policy is no shell for cleanup execution.

Allowed:

- direct executable invocation through Rust/Tokio `Command`;
- separate argv values;
- no stdin unless adapter explicitly needs it;
- no shell pipelines, redirects, glob expansion, command substitution, aliases,
  shell functions, or profile loading.

Not allowed in MVP:

- `sh -c`;
- `cmd.exe /c`;
- PowerShell one-liners;
- `.bat`/`.cmd` execution as cleanup adapters;
- AppleScript shell commands;
- user-supplied scripts;
- "copy this command from docs and run it" adapters.

Exception process:

```text
ShellException
  adapter_id
  reason
  no_api_alternative_evidence
  exact_script_template
  untrusted_fields
  quoting_strategy
  platform_scope
  test_fixtures
  security_review
  disabled_by_default
```

The exception process is not MVP. It exists so future decisions are explicit.

## Process Lifetime And Cancellation

Cancellation must stop future work and reconcile the current side-effect
boundary. It must not imply rollback.

```text
CommandExecutionState
  pending
  preflight_running
  running
  cancel_requested
  terminating
  exited_success
  exited_failure
  timed_out
  killed
  unknown
  reconciled
```

Rules:

- create a process group/job where the platform supports it;
- on Windows, use Job Objects for command families that can spawn children;
- on Unix-like systems, use process groups where available and safe;
- configure timeout per adapter and per action tier;
- output readers must keep draining stdout/stderr until process exit or kill;
- after timeout/kill, run adapter-specific reconciliation where possible;
- cancellation emits an event that says whether the side effect is known,
  partial, or unknown.

Why:

- Tokio's `kill_on_drop` is not a cleanup receipt strategy; it changes child
  process behavior when handles are dropped, but it does not explain the tool's
  side effects;
- Windows Job Objects can track children and terminate associated process trees,
  but jobs have breakaway and nested-job nuances;
- Linux resource limits and process groups help control spawned work, but they
  are not a full semantic sandbox.

Kill criteria:

- dropping a future is considered cancellation;
- timeout returns generic failure with no post-check;
- child process can continue after UI says cancelled;
- process is killed while stdout/stderr pipes deadlock;
- user can start another destructive command against the same target while the
  first is still reconciling.

## Output Capture And Privacy

Command output is both useful evidence and sensitive data.

```text
OutputPolicy
  max_stdout_bytes
  max_stderr_bytes
  max_line_bytes
  capture_mode
  redaction_profile
  parser_mode
  user_visible_summary
  support_bundle_summary
```

Rules:

- bound stdout and stderr;
- truncate by bytes and mark truncation explicitly;
- never stream raw command output directly into telemetry;
- parse machine-readable formats where possible;
- redact raw paths, tokens, user names, project names, registry URLs, and cloud
  URLs in support bundles;
- keep full local receipt only if needed for user-visible recovery and protected
  by local privacy policy;
- treat parser failure as `unknown`, not success.

Kill criteria:

- unlimited output can fill memory or disk;
- stderr containing tokens is shown in support bundle by default;
- localized command output breaks success detection;
- tool warning text is ignored because exit code is zero.

## Official Cleanup Adapter Semantics

Official tool commands are not interchangeable. Each adapter needs its own risk
model and receipt parser.

### Docker

Docker has separate prune scopes: images, containers, networks, volumes, build
cache, and `system`. Docker docs explicitly keep volumes out of default system
prune because volumes can contain important data.

Rules:

- MVP may recommend Docker cleanup, but execution should start with low-risk
  scopes such as build cache or dangling images before volumes;
- `--volumes` is a separate high-risk action;
- `-a` is broader than default and needs explicit UI copy;
- use filters where possible;
- collect `docker system df` or API facts before and after if available;
- treat Docker daemon context as part of target identity.

Kill criteria:

- one generic "Clean Docker" button runs `docker system prune -af --volumes`;
- Docker Desktop context or remote Docker host is ignored;
- volume cleanup is treated as normal cache cleanup.

### npm

npm documents that cache integrity is verified and cleaning should not normally
be necessary except reclaiming disk space; cache clean needs `--force`.

Rules:

- classify npm cache cleanup as reclaim-space action, not corruption repair by
  default;
- show that npm can redownload cache content;
- do not remove npm project `node_modules` as npm cache;
- tokens and registry env must not leak to command logs.

Kill criteria:

- adapter deletes `~/.npm` raw without npm semantics;
- `node_modules` is classified as cache without project evidence;
- `NPM_TOKEN` or `NODE_AUTH_TOKEN` appears in logs.

### pnpm

pnpm store is shared and content-addressed. `pnpm store prune` is narrower than
deleting the store, but it can affect future installs and active workflows.

Rules:

- prefer official store prune command over deleting the store;
- detect store path through pnpm where possible;
- warn that packages may be redownloaded;
- never treat project `node_modules` symlink/hardlink layout as ordinary
  disposable files.

Kill criteria:

- raw delete of pnpm store in MVP;
- follows links from project `node_modules` into shared store as if local.

### Cargo

Cargo supports `cargo clean --dry-run` and scoped target/profile options. It
cleans generated artifacts, not global source crates by default.

Rules:

- prefer project-scoped `cargo clean --dry-run` preview;
- distinguish workspace `target` from `CARGO_TARGET_DIR`;
- do not delete Cargo registry/git cache without separate user-visible policy;
- parser should not assume English text if relying on output.

Kill criteria:

- global `~/.cargo` deletion presented as Rust cache cleanup;
- target dir is inferred only from folder name.

### pip

pip exposes `pip cache info`, `list`, `remove`, and `purge`.

Rules:

- prefer `pip cache info` for preview;
- distinguish wheel cache, HTTP cache, virtualenvs, and project environments;
- `purge` is broad and should be higher-friction than selective remove;
- do not delete virtual environments as pip cache.

Kill criteria:

- `.venv`, `venv`, or Conda envs are cleaned by pip cache adapter;
- adapter ignores custom pip cache directories.

### Gradle

Gradle has automatic user-home cleanup policy and cache retention can be
configured through init scripts. Some caches are shared across Gradle versions.

Rules:

- avoid raw deletion of Gradle User Home in MVP;
- prefer explaining existing Gradle cleanup and showing safe repair guidance;
- if execution is added, use Gradle-supported cleanup configuration or a
  carefully scoped adapter;
- distinguish project `.gradle`, build outputs, wrapper distributions, and user
  home caches.

Kill criteria:

- deletes entire `~/.gradle` as cache;
- deletes wrapper distributions needed by projects without warning;
- fights Gradle daemon locks without reconciliation.

## Architecture Decision

Add a reusable command action subsystem under the Rust side, but keep it as a
port/adapter boundary.

Recommended crate ownership:

```text
fs_usage_actions
  domain/
    action_plan.rs
    command_policy.rs
    action_result.rs
    receipt.rs
    risk.rs
  application/
    ports/
      command_executor.rs
      executable_resolver.rs
      action_receipt_store.rs
      output_redactor.rs
      reconciliation_probe.rs
    services/
      validate_command_action.rs
      execute_command_action.rs
      reconcile_command_action.rs
  infrastructure/
    process/
      tokio_command_executor.rs
      process_group_unix.rs
      job_object_windows.rs
      output_limiter.rs
    tools/
      docker_adapter.rs
      npm_adapter.rs
      pnpm_adapter.rs
      cargo_adapter.rs
      pip_adapter.rs
      gradle_adapter.rs
```

Clean Disk host ownership:

```text
apps/clean_disk_server
  owns transport DTO mapping
  owns local token/origin policy
  owns command execution feature flags
  owns installed adapter registry
  owns observability redaction config
```

Flutter ownership:

```text
features/scan or future features/cleanup
  presentation shows action preview
  application owns cleanup use cases and ports
  data maps protocol DTOs into feature read models
  UI never builds shell commands
```

Decision:

- MVP scanner does not need command execution;
- cleanup MVP can ship with command preview cards before execution;
- first executable cleanup adapter should be behind a feature flag and a fixture
  test lab;
- official tool adapters are separate from raw path delete and OS Trash adapters;
- no plugin-provided command adapters until extension security is designed.

## Command Runner API Shape

The application service should depend on a small port, not on Tokio directly.

```text
CommandExecutor
  validate(plan) -> ValidatedCommandAction
  start(validated_plan) -> CommandRunHandle
  request_cancel(run_id) -> CancelAccepted
  stream_events(run_id) -> CommandRunEvent
  await_result(run_id) -> CommandRunResult
```

Events:

```text
CommandRunEvent
  started
  stdout_chunk_summary
  stderr_chunk_summary
  progress_hint
  timeout_warning
  cancel_requested
  terminating
  exited
  killed
  output_truncated
  parser_warning
  reconciliation_started
  reconciled
```

Do not expose raw command strings as the API.

## Receipts And Reconciliation

Every external command is a side-effect boundary.

```text
CommandActionReceipt
  action_id
  adapter_id
  executable_path
  executable_identity
  executable_version
  argv_fingerprint
  environment_fingerprint
  working_directory
  started_at
  finished_at
  exit_status
  termination_reason
  stdout_summary
  stderr_summary
  parsed_result
  output_truncated
  post_probe_result
  observed_space_delta
  recovery_capability
  unknowns[]
```

Rules:

- store receipt before execution begins;
- update receipt after each major state transition;
- parse command output, then verify with a post-probe where possible;
- use rescan/reconcile as final product truth;
- receipt stores fingerprints for command shape, not necessarily all raw args in
  telemetry;
- unknown state blocks automatic next destructive action on overlapping targets.

Kill criteria:

- command result is only `exit_code = 0`;
- cleanup summary relies only on tool-reported reclaimed bytes;
- no receipt exists when daemon crashes mid-command;
- command output is truncated without marking parser confidence lower.

## Permission And Authority Boundaries

The command runs with the daemon user's authority. That is not the same as the
Flutter UI user's visual intent.

Rules:

- command target scopes must be derived from approved DeletePlan;
- remote/headless mode defaults to read-only command previews until authorization
  is designed;
- privileged commands are not MVP;
- `sudo`, UAC elevation, admin shells, and password prompts are out of MVP;
- command adapter reports whether it talks to local service, remote daemon, or
  remote tool context.

Examples:

- Docker CLI may talk to Docker Desktop, a remote Docker context, or a rootful
  daemon;
- package managers may use global stores shared across projects;
- Gradle daemons may hold locks;
- enterprise endpoint policy may block process execution or inspect it.

Kill criteria:

- command adapter silently follows a remote Docker context;
- command prompts for password in hidden stdin;
- command starts a long-running daemon as a cleanup side effect;
- headless API allows destructive commands without explicit policy scope.

## Testing Strategy

Required fixture classes:

```text
command_injection_fixtures
  path_with_spaces
  path_with_quotes
  path_starting_with_dash
  path_with_shell_metacharacters
  unicode_and_bidi_path
  very_long_path

executable_resolution_fixtures
  fake_tool_in_cwd
  fake_tool_in_project_bin
  changed_tool_after_preflight
  missing_tool
  wrong_version

environment_fixtures
  secret_env_vars
  locale_variants
  proxy_vars
  missing_home

process_lifecycle_fixtures
  ignores_sigterm
  spawns_child
  writes_unbounded_stdout
  writes_unbounded_stderr
  hangs
  partial_side_effect_then_failure

adapter_fixtures
  docker_without_volumes
  docker_with_volumes
  npm_force_required
  cargo_dry_run
  pip_purge
  gradle_locked_cache
```

Required tests:

- no shell invocation in MVP adapters;
- no inherited env by default;
- resolved executable path is absolute;
- fake executable in working directory is rejected;
- output cap and truncation are tested;
- cancellation handles child process and receipt state;
- parser failure produces unknown or failed state, not success;
- post-action rescan/reconcile is required before final reclaimed-space claim;
- telemetry snapshots are redacted.

## MVP Cut Line

In MVP:

- support command preview architecture and receipts;
- no arbitrary command execution;
- no plugin command adapters;
- no shell adapters;
- no privileged cleanup commands;
- no one-click Docker volume prune;
- no raw deletion of tool-managed stores when official cleanup exists;
- first executable adapter must be feature-flagged and covered by fixture tests.

Allowed MVP actions:

- show official cleanup recommendation with clear risk and manual command
  guidance;
- execute OS Trash moves through platform adapter;
- execute pdu/scan-only work through scanner adapters;
- prototype one low-risk command adapter only after the command runner contract
  exists.

## Open Questions

1. Which first command adapter is worth implementing?
   - Cargo project `target` cleanup with `--dry-run` is the safest first
     candidate - 🎯 8  🛡️ 8  🧠 5, roughly 500-1100 LOC/tests.
   - pip cache preview and purge is simple but can affect global developer
     workflows - 🎯 7  🛡️ 7  🧠 5, roughly 500-1200 LOC/tests.
   - Docker build cache cleanup is valuable but context/volume risk is higher -
     🎯 6  🛡️ 7  🧠 7, roughly 900-2200 LOC/tests.
2. Should command execution live in the reusable `fs_usage_actions` crate from
   day one?
   My recommendation: yes for contracts and generic process executor, no for
   Clean Disk product policy and UI wording.
3. Do we need OS-level sandboxing for every command?
   MVP answer: not for every command, but every command needs allowlist, env
   clearing, output limits, timeout, process-group/job control, and receipts.
   OS-level sandbox profiles can be added for high-risk adapters later.

## Final Decision

Treat official cleanup commands as a separate destructive adapter class.

They are not safer merely because they are official. They are safer only when
Clean Disk constrains them through typed plans, allowlisted executable identity,
argument schema validation, minimal environment, bounded output, lifecycle
control, durable receipts, and post-action reconciliation.

The architecture should make unsafe command execution hard to express.
