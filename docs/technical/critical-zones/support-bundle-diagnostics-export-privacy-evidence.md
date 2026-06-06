# Critical Zone - Support Bundle, Diagnostics Export, And Privacy-Preserving Evidence

Last updated: 2026-05-16.

This file records the next focused global critical zone after
`persistent-operation-journal-receipt-durability-low-disk.md`.

The core risk: diagnostics are necessary for a product that scans millions of
private filesystem entries, but diagnostics are dangerous by default. A support
bundle can accidentally become an export of the user's home directory structure,
project names, cloud folders, deleted items, daemon tokens, raw command output,
search text, receipt details, and crash memory.

Clean Disk must make support possible without turning support into data
exfiltration.

## Sources Reviewed

- OWASP Logging Cheat Sheet: application logs provide context that
  infrastructure logs cannot, but audit/security/transaction logs serve
  different purposes and must not log too much or too little.
  Source:
  https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
- OWASP Poor Logging Practice: logs can expose stack traces, configuration
  values, file paths, and user data when implemented poorly.
  Source: https://owasp.org/www-community/vulnerabilities/Poor_Logging_Practice
- OWASP MASWE-0001: application logs can expose sensitive user and system data,
  including tokens and PII.
  Source: https://mas.owasp.org/MASWE/MASVS-STORAGE/MASWE-0001/
- OpenTelemetry Logs Data Model: logs should have a clear data model with typed
  top-level fields and attributes so records can be stored, transferred, and
  interpreted consistently.
  Source: https://opentelemetry.io/docs/specs/otel/logs/data-model/
- OpenTelemetry Semantic Conventions: shared attribute names help standardize
  traces, metrics, logs, profiles, and resources across codebases.
  Source: https://opentelemetry.io/docs/concepts/semantic-conventions/
- CNIL data minimization guidance: collect only what is necessary, minimize log
  data too, avoid storing sensitive or critical data in logs, and associate
  retention periods with each data category.
  Source: https://www.cnil.fr/en/sheet-ndeg7-minimize-data-collection
- ICO storage limitation guidance: personal data should not be kept longer than
  needed, retention must be justified, and anonymization should be used when
  identifying individuals is no longer required.
  Source:
  https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-protection-principles/a-guide-to-the-data-protection-principles/storage-limitation/
- Microsoft Azure Monitor personal data docs: prefer filtering, obfuscating, or
  anonymizing collected data; purge/delete is costly and should be used
  carefully.
  Source:
  https://learn.microsoft.com/en-us/azure/azure-monitor/logs/personal-data-mgmt
- Google Sensitive Data Protection redaction docs: redaction and de-identifying
  sensitive text are explicit transformation steps and can replace sensitive
  values with placeholders.
  Source:
  https://docs.cloud.google.com/sensitive-data-protection/docs/redacting-sensitive-data
- Sentry sensitive data docs: scrub data before sending when possible so
  sensitive data never leaves the local environment.
  Source:
  https://docs.sentry.dev/platforms/javascript/guides/nextjs/data-management/sensitive-data/

## Why This Is The Next Global Critical Zone

Previous critical zones protect destructive execution and durable proof. The
next question is:

```text
Can we debug the product without exporting the user's private filesystem?
```

Clean Disk diagnostics can contain unusually sensitive data:

- raw paths reveal user names, project names, customer names, medical/legal
  topics, repositories, browser profiles, cloud folders, and secrets embedded in
  filenames;
- receipts reveal what the user deleted or tried to delete;
- scan trees can reveal almost every file and folder the user owns;
- command output can contain registry URLs, tokens, project names, or tool
  configuration;
- crash dumps can include daemon tokens, scan tree memory, search text, and
  selected cleanup targets;
- WebSocket and HTTP logs can expose local tokens, request headers, origins, and
  object ids;
- remote/headless audit data can identify actors, hosts, tenants, and target
  scopes.

This is P0 before public beta support. Without a safe support bundle, every real
bug report becomes either useless or too private to share.

## Current Global Ranking

1. Support bundle, diagnostics export, and privacy-preserving evidence - 🎯 8  🛡️ 10  🧠 8, roughly 1600-4600 LOC/tests/docs.
   Selected now. It decides what evidence can leave the machine and how support
   remains useful without raw private data.
2. Extension/plugin execution and third-party cleanup packs - 🎯 5  🛡️ 9  🧠 9, roughly 2500-7000 LOC/tests/docs.
   Important later if external contributors can add executable cleanup behavior,
   rules, or adapters.
3. Hosted pairing, relay, and remote UI exposure lifecycle - 🎯 6  🛡️ 9  🧠 9, roughly 2000-6500 LOC/tests/docs.
   Important if a hosted web UI, cloud relay, Tailscale-like flow, or shared
   remote support workflow becomes product scope.

## Core Rule

No diagnostic export is raw by default.

```text
diagnostic source
  -> typed data classification
  -> surface-specific allowlist
  -> redaction transform
  -> manifest and redaction report
  -> user preview or admin policy
  -> bounded export
```

Rules:

- every field that can enter logs, metrics, traces, crash reports, support
  bundles, receipts, or telemetry has a privacy class;
- unknown privacy class fails closed;
- redaction is schema-aware and typed, not only regex afterthought;
- support bundles include a manifest and redaction report;
- default support bundle excludes raw paths, full scan tree, tokens, raw search
  text, raw command output, and raw receipts;
- raw-path export requires a separate explicit profile and consent/policy gate;
- crash reports do not automatically attach support bundles;
- telemetry is absent in MVP unless explicitly revisited.

Kill criteria:

- support bundle is a zip of logs, caches, and SQLite files;
- adding a DTO field automatically makes it exportable;
- `Debug` output of domain/protocol structs appears in production logs;
- redaction failure falls back to raw output;
- path or search text becomes metric label;
- support bundle preview says "safe" without a manifest and redaction counts;
- crash dump uploads without local scrubbing.

## Diagnostic Data Classes

Use explicit data classes so every surface can decide what is allowed.

```text
DiagnosticDataClass
  public_product
    app version, OS family, architecture, feature flags

  operational_aggregate
    counts, durations, queue depth, error class, size bucket

  local_fingerprint
    stable hash/fingerprint for correlation, not reversible by support

  private_path_segment
    filename, folder name, user name, project name, cloud folder segment

  raw_path
    absolute or relative path string

  raw_search_text
    user query text from search/filter

  secret
    daemon token, auth header, bearer token, API key, registry token

  receipt_private
    cleanup selection, delete outcome, restore destination, user-approved plan

  audit_private
    actor, tenant, host, policy id, target scope, auth denial evidence

  command_output_private
    stdout/stderr from external tools before parser and redaction

  crash_memory_private
    minidump, panic payload, raw stack locals, heap fragments

  full_scan_tree_private
    node names, paths, sizes, metadata, and hierarchy
```

Rules:

- `secret` is never exportable;
- `raw_path`, `raw_search_text`, `receipt_private`, `audit_private`,
  `command_output_private`, `crash_memory_private`, and
  `full_scan_tree_private` are blocked from standard support bundles;
- `local_fingerprint` must use keyed or scoped hashing when correlation could
  enable dictionary attacks against common paths;
- `operational_aggregate` must avoid high cardinality labels;
- UI copy must name the export profile honestly.

## Diagnostic Surfaces

Different surfaces need different policies.

```text
DiagnosticSurface
  production_log
  local_debug_log
  security_audit_log
  cleanup_receipt
  support_bundle_standard
  support_bundle_sensitive
  crash_report_metadata
  crash_report_minidump
  telemetry_event
  metric
  trace_span
  web_console_log
  support_export_endpoint
```

Rules:

- production logs carry event codes, operation ids, and redacted summaries;
- local debug logs may be more detailed but still exclude secrets by type;
- security audit logs use actor/action/outcome with redacted refs by default;
- cleanup receipts are not telemetry;
- support bundle standard profile is redacted and bounded;
- sensitive support profile is opt-in and should be rare;
- crash minidumps are local-only until a separate crash pipeline is designed;
- metrics never use raw path, node name, search text, tenant id, or receipt id as
  high-cardinality labels;
- web console follows production redaction because users paste console logs into
  bug reports.

Kill criteria:

- one logger feeds all surfaces with the same payload;
- crash reporter auto-attaches logs or scan snapshots;
- metric labels include folder names;
- web UI logs local daemon token or URL query string;
- support endpoint checks authentication but not object authorization.

## Support Bundle Profiles

Support bundle generation is a product workflow with profiles.

```text
SupportBundleProfile
  standard_redacted
    default, safe for most bug reports

  operation_focused
    includes one selected operation id and redacted receipt summary

  runtime_pressure
    includes worker lanes, queue pressure, resource budgets, shutdown reason

  protocol_debug
    includes route/event names, schema versions, connection state, no bodies

  remote_admin_redacted
    includes policy fingerprints, auth mode, target scope summaries, audit refs

  sensitive_with_raw_paths
    explicit user/admin consent, local-only unless manually shared

  crash_local_forensics
    local minidump or detailed panic data, never uploaded automatically
```

Rules:

- standard profile is the default;
- every profile has a manifest;
- every profile has size cap, time window, and included data classes;
- raw path profile requires separate confirmation and shows why support needs it;
- remote profile requires separate authorization because it can leak tenant/host
  metadata;
- support bundle creation is read-only except for output/temp files.

## Bundle Manifest And Redaction Report

Every exported bundle must explain itself.

```text
SupportBundleManifest
  bundle_id
  created_at_utc
  app_version
  daemon_version
  protocol_version
  schema_versions
  platform_profile
  deployment_profile
  export_profile
  redaction_policy_version
  retention_note
  included_artifacts[]
  excluded_artifacts[]
  size_bytes
  warnings[]
```

```text
RedactionReport
  fields_kept
  fields_redacted
  fields_omitted
  fields_bucketized
  fields_hashed
  fields_truncated
  fields_blocked_unknown_class
  secret_matches_blocked
  raw_path_matches_blocked
  redaction_failures
```

Rules:

- manifest is included inside the bundle and shown in preview;
- redaction report counts are enough to prove policy ran;
- unknown fields block export or are omitted with explicit warning;
- redaction failure blocks standard export;
- manifest includes no secrets;
- exported bundle name avoids raw path or user search text.

Kill criteria:

- support bundle has no manifest;
- preview and actual bundle can diverge;
- redaction report cannot tell if raw paths were found;
- export file path is later logged raw.

## Evidence References Instead Of Raw Evidence

Support should work with evidence ids rather than raw private data.

```text
EvidenceRef
  evidence_id
  evidence_kind
  source_operation_id
  redacted_label
  local_fingerprint
  privacy_class
  available_locally
  exportable_profile
```

Examples:

- `path_fingerprint` instead of `/Users/name/ClientProject/legal_case/file`;
- `rule_id` plus evidence counts instead of raw folder names;
- `error_class = permission_denied_tcc` instead of full OS message with path;
- `receipt_summary_id` instead of raw delete target list;
- `tool_adapter_output_hash` instead of raw stdout/stderr.

Rules:

- raw evidence stays local unless user chooses a sensitive profile;
- fingerprints are scoped to bundle or installation where possible;
- evidence ids should let support ask targeted follow-up questions without
  seeing private paths first.

## Logs, Metrics, And Traces

Use OTel-compatible shape as a model, not as permission to export everything.

```text
CleanDiskEvent
  event_name
  severity
  timestamp_utc
  operation_id
  component
  error_code
  recovery_action
  privacy_class
  attributes
```

Rules:

- event names are stable and documented;
- attributes are allowlisted by event schema;
- high-cardinality values stay out of metrics;
- traces carry operation flow, not scan tree contents;
- logs record error classes and evidence refs, not raw native messages by
  default;
- telemetry export, if added later, has a smaller schema than local logs.

Kill criteria:

- telemetry schema is inferred from arbitrary logs;
- adding a log attribute automatically exports it;
- raw path appears in span attribute;
- support bundle needs full logs to diagnose normal issues.

## Secret And Token Redaction

Secrets must be impossible to log by normal APIs.

Rules:

- daemon tokens, auth headers, pairing secrets, registry tokens, environment
  secrets, and API keys use wrapper types that do not implement raw diagnostic
  formatting;
- secret redaction happens before text enters logs, not only before upload;
- support bundle scanner performs final secret-pattern pass as a backstop;
- secret scanners are not the primary safety model because they can miss custom
  formats;
- if a secret match is found in a generated bundle, standard export blocks.

Kill criteria:

- local daemon token appears in URL, log, panic, screenshot, support bundle, or
  telemetry;
- command runner logs inherited env values;
- panic payload includes token string;
- secret redaction relies only on regex at export time.

## Crash Reports

Crash data is high-risk evidence.

Rules:

- MVP uses local crash metadata, not automatic remote crash upload;
- crash metadata includes app/daemon version, OS, thread name, panic type,
  operation id, component, and redacted error class;
- crash minidumps and raw stack locals are excluded from standard support bundle;
- panic payloads are sanitized before logging;
- crash report can reference unfinished operation id so receipt/journal recovery
  remains the truth source.

Kill criteria:

- crash reporter auto-uploads minidumps;
- crash report includes full scan tree or selected delete queue;
- panic payload from native code is logged raw;
- crash metadata replaces operation journal recovery.

## Support Bundle Size And Low Disk

Diagnostics must not make the disk problem worse.

Rules:

- bundle generation has size cap, temp space preflight, and cancellation;
- export is paged/streamed where practical;
- support bundle creation never competes with operation journal/receipt writes;
- low-disk mode can generate minimal diagnostics only;
- temp bundle files are tracked and cleaned;
- support bundles have retention and deletion policy.

Kill criteria:

- support export fills the disk;
- generating support bundle blocks daemon control plane;
- partial bundle has no manifest explaining missing artifacts;
- low-disk mode drops receipts before debug logs.

## Remote And Headless Authorization

Support export is its own object-level authorization surface.

Rules:

- remote support bundle export is authorized separately from scan/query;
- support export endpoint checks actor, host, tenant, target scope, profile, and
  audit policy;
- remote standard bundle uses redacted refs by default;
- raw path export can be disabled by admin policy;
- support export itself creates an audit event;
- exported bundle never includes bearer tokens, local session tokens, or raw
  headers.

Kill criteria:

- authenticated remote user can export another user's support bundle;
- support bundle endpoint accepts arbitrary file path;
- admin role bypasses redaction without audit;
- remote support bundle includes policy secrets.

## Architecture Decision

Add a dedicated diagnostics and evidence boundary. Do not let each component
invent its own logging/export rules.

Recommended ownership:

```text
fs_usage_diagnostics
  domain/
    diagnostic_data_class.rs
    diagnostic_surface.rs
    support_bundle_profile.rs
    evidence_ref.rs
    redaction_manifest.rs
    diagnostic_event.rs
  application/
    ports/
      diagnostic_sink.rs
      redactor.rs
      support_bundle_store.rs
      bundle_artifact_source.rs
      secret_detector.rs
      retention_policy.rs
    services/
      classify_diagnostic_field.rs
      create_support_bundle.rs
      redact_artifact.rs
      build_redaction_report.rs
      enforce_retention.rs
  infrastructure/
    logging/
      structured_log_sink.rs
      console_sink.rs
      file_sink.rs
    bundle/
      zip_bundle_writer.rs
      sqlite_safe_export.rs
      manifest_writer.rs
    redaction/
      path_redactor.rs
      token_redactor.rs
      command_output_redactor.rs
```

Clean Disk host ownership:

```text
apps/clean_disk_server
  owns diagnostic config
  owns support export endpoints
  owns local support bundle output path
  owns remote authorization for export
  owns telemetry disabled-by-default policy
```

Flutter ownership:

```text
features/settings or features/diagnostics
  shows support bundle preview
  shows redaction profile
  shows size estimate and warnings
  never displays raw diagnostic text by default
```

Decision:

- diagnostics are a reusable subsystem, not ad hoc logs;
- telemetry is not MVP;
- support bundle is explicit user action;
- standard bundle is redacted and bounded;
- raw-path bundle is exceptional and consent-gated.

## Testing Strategy

Required fixture classes:

```text
redaction_fixtures
  home_path
  cloud_sync_path
  customer_project_path
  unicode_bidi_path
  newline_log_injection_path
  csv_formula_filename
  path_with_token_like_segment
  raw_search_text

secret_fixtures
  daemon_token
  bearer_header
  npm_token
  github_token_like_value
  aws_key_like_value
  registry_url_with_credentials
  proxy_env_with_password

bundle_fixtures
  large_logs
  huge_scan_summary
  crash_metadata
  interrupted_operation_receipt
  remote_audit_summary
  redaction_failure
  unknown_privacy_class
  low_disk_partial_bundle
```

Required tests:

- every diagnostic DTO field has privacy class;
- unknown privacy class blocks standard export;
- `secret` fields cannot be formatted through normal diagnostic APIs;
- standard bundle contains no raw paths, tokens, raw search text, full scan tree,
  raw receipts, or raw command output;
- redaction preview matches actual exported bundle;
- manifest and redaction report are included;
- size caps and cancellation work;
- support export can run in read-only recovery mode;
- remote support export requires separate authorization;
- hostile filenames cannot forge log lines or CSV formulas;
- support bundle creation does not modify scan or cleanup state.

## MVP Cut Line

For MVP:

- no external telemetry;
- local structured logs with data classification;
- standard redacted support bundle;
- manifest and redaction report;
- support bundle preview;
- no raw crash minidump upload;
- no raw full scan tree export;
- no automatic support upload.

Out of MVP:

- hosted crash reporting provider;
- automatic telemetry pipeline;
- enterprise SIEM integration;
- cryptographic bundle sealing;
- raw-path remote support profile;
- external DLP service dependency.

## Final Decision

Treat diagnostics as evidence, not leftovers.

The product needs enough evidence to debug scanner bugs, protocol failures,
cleanup failures, update issues, and runtime pressure. But evidence must be
typed, classified, redacted, bounded, and consented before it leaves the user's
machine.

Support bundle generation is therefore a first-class workflow with its own
manifest, redaction report, authorization, retention, and tests.
