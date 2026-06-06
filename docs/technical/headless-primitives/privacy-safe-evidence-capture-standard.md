# Privacy Safe Evidence Capture Standard

## Status

Accepted as a Headless quality-operations standard. Not implemented yet.

## Source Standards

- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/
- MDN Reporting API: https://developer.mozilla.org/en-US/docs/Web/API/Reporting_API
- MDN Content Security Policy: https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
- MDN Permissions Policy: https://developer.mozilla.org/en-US/docs/Web/HTTP/Permissions_Policy
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- Flutter error handling: https://docs.flutter.dev/testing/errors

## Scope

This standard defines how Headless captures screenshots, semantic snapshots,
logs, traces, reports, and diagnostic bundles without leaking sensitive user
data.

It applies to:

- conformance reports;
- support bundles;
- screenshot artifacts;
- semantic snapshots;
- command traces;
- render error diagnostics;
- crash summaries;
- privacy incident reports;
- Clean Disk support exports.

It does not define product telemetry. It defines evidence capture boundaries
for Headless and design-system usage.

## Decision Options

Option A: Capture everything on failure - 🎯 3   🛡️ 2   🧠 2, about
100-250 LOC.

- Useful for debugging.
- High privacy risk.

Option B: Capture only screenshots - 🎯 4   🛡️ 4   🧠 3, about
200-500 LOC.

- Familiar.
- Screenshots can leak more than structured redacted facts and miss semantics.

Option C: Evidence profiles with redaction and consent gates - 🎯 9
🛡️ 9   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Different evidence types have explicit privacy classes and export policies.

## Accepted Direction

Headless should define `EvidenceCaptureProfile`.

Profile includes:

- purpose;
- allowed artifacts;
- forbidden fields;
- redaction rules;
- consent requirement;
- retention hint;
- export destination class;
- encryption expectation if app supports it;
- user-visible summary.

## Evidence Types

Types:

- semantic snapshot;
- visual screenshot;
- command trace;
- focus trace;
- keyboard trace;
- announcement trace;
- render failure report;
- adapter manifest;
- localization stress result;
- support bundle item.

Each type declares sensitivity and redaction rules.

## Redaction Rules

Default redactions:

- raw path;
- filename;
- user name;
- daemon token;
- raw query;
- clipboard content;
- delete target path;
- support bundle secret;
- exact full tree.

Allowed by default:

- component type;
- command id;
- state code;
- count bucket;
- size bucket;
- adapter version;
- fixture id.

## Screenshot Rules

Screenshots are high risk.

Rules:

- prefer synthetic fixture screenshots for CI;
- support screenshots require user approval;
- blur or redact sensitive text where possible;
- pair screenshot with semantic snapshot;
- do not capture hidden windows or unrelated apps;
- do not include clipboard contents.

## Reporting Rules

Reports must include:

- profile id;
- capture reason;
- artifact list;
- redaction summary;
- user approval state;
- retention hint;
- known omissions.

Reporting API or platform crash reports are external mechanisms and must be
treated as unreliable and privacy-sensitive.

## Clean Disk Requirements

Clean Disk evidence capture:

- scan UI screenshot with synthetic data in CI;
- support bundle with redacted paths;
- command trace for cleanup disabled reason;
- semantic snapshot for TreeGrid issue;
- render failure report for chart adapter;
- receipt evidence without daemon token.

Rules:

- real user disk tree is not captured by default.
- raw delete target path requires explicit export profile.
- support bundle preview shows what will be included.

## API Shape Sketch

```text
EvidenceCaptureProfile
  id
  purpose
  allowedArtifacts
  forbiddenFields
  redactionRules
  consentPolicy
  retentionHint

EvidenceArtifact
  type
  privacyClass
  redactionReport
  contentRef
```

## Conformance Scenarios

- CI screenshot uses synthetic data;
- support bundle redacts raw paths by default;
- semantic snapshot excludes raw query;
- render failure report includes adapter id but no secret;
- screenshot capture requires consent in support mode;
- artifact manifest lists redactions;
- privacy incident can trace artifact source;
- report omits unavailable artifacts explicitly.

## Failure Catalog

- failure artifact captures real full disk tree;
- screenshot leaks username in path;
- command trace includes daemon token;
- support bundle hidden contents not previewed;
- Reporting API data treated as guaranteed delivered;
- semantic snapshot stores raw labels by default;
- redaction removes evidence without saying so;
- retention policy absent;
- unrelated app window captured;
- privacy incident has no artifact manifest.

