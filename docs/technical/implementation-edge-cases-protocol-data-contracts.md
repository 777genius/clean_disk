# Implementation Edge Cases - Protocol Data Contracts

Last updated: 2026-05-13.

This file records edge cases for data contracts between the Rust daemon/server and Flutter clients.

Related documents:

- [Rust architecture](rust-architecture.md)
- [Rust best practices research](rust-best-practices.md)
- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Implementation edge cases web UI and local daemon runtime](implementation-edge-cases-web-ui-daemon-runtime.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)
- [Implementation edge cases local state persistence](implementation-edge-cases-local-state-persistence.md)

This document focuses on the wire/data boundary:

- Rust DTOs versus domain models;
- JSON number precision across Flutter desktop and Flutter web;
- path and filename encoding;
- timestamps and durations;
- enum evolution;
- unknown fields;
- OpenAPI/JSON Schema drift;
- error DTOs;
- pagination cursors;
- snapshot tests and compatibility fixtures.

## Sources Reviewed

- Dart, [Numbers in Dart](https://dart.dev/resources/language/number-representation). Relevant points: native Dart commonly uses 64-bit signed integers, but Dart compiled to JavaScript uses 64-bit double-precision floating point for both `int` and `double`.
- Dart API, [`int` class](https://api.dart.dev/dart-core/int-class.html). Relevant points: Dart integers compiled to JavaScript are restricted to values exactly representable by double-precision floating point, and behavior can differ between VM and web.
- Dart diagnostics, [`avoid_js_rounded_ints`](https://dart.dev/tools/diagnostics/avoid_js_rounded_ints). Relevant points: integer values outside `-(2^53 - 1)` to `2^53 - 1` may be rounded silently on web.
- RFC 8259, [JSON](https://www.rfc-editor.org/rfc/rfc8259). Relevant points: JSON number precision/range can be implementation-limited; exact interoperability for integers is only guaranteed in the `[-(2^53)+1, (2^53)-1]` range; object member names should be unique.
- MDN, [Number.MAX_SAFE_INTEGER](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER). Relevant points: JavaScript safe integer maximum is `2^53 - 1`; integer-level precision fails above that.
- MDN, [BigInt](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt). Relevant points: JSON can contain long number literals, but JavaScript cannot parse them to full precision as `Number`; BigInt coercion from Number is intentionally restricted to avoid precision loss.
- Rust Standard Library, [`std::path::Path`](https://doc.rust-lang.org/std/path/struct.Path.html). Relevant points: `Path::to_str()` returns `None` for non-Unicode paths, and `to_string_lossy()` replaces invalid sequences with `U+FFFD`.
- Serde, [enum representations](https://serde.rs/enum-representations.html). Relevant points: internally/adjacently tagged enums provide explicit tags, while untagged enums pick the first variant that deserializes successfully.
- Serde, [struct flattening](https://serde.rs/attr-flatten.html). Relevant point: `flatten` is not supported with `deny_unknown_fields`, which matters for compatibility strategy.
- OpenAPI Specification, [v3.1.0](https://spec.openapis.org/oas/v3.1.0). Relevant points: OpenAPI 3.1 schemas are based on JSON Schema 2020-12 and define `integer` formats such as `int32` and `int64`.
- Google Discovery API docs, [Type and format](https://docs.cloud.google.com/docs/discovery/type-format). Relevant point: Google represents 64-bit integers as JSON strings with `format: int64` because JavaScript/JSON integer interoperability is limited.
- RFC 3339, [Date and Time on the Internet](https://www.rfc-editor.org/rfc/rfc3339). Relevant point: RFC 3339 defines an unambiguous internet timestamp profile.
- Dart API, [`DateTime.parse`](https://api.flutter.dev/flutter/dart-core/DateTime/parse.html). Relevant point: Dart parses a subset of ISO 8601 including the subset accepted by RFC 3339.
- RFC 9457, [Problem Details for HTTP APIs](https://www.ietf.org/rfc/rfc9457.html). Relevant points: machine-readable problem details avoid inventing ad hoc error formats; `detail` is human-readable and clients should not parse it for logic.
- JSON Schema, [Draft 2020-12 Core](https://json-schema.org/draft/2020-12/json-schema-core). Relevant points: schemas are platform-independent validation/documentation artifacts; `unevaluatedProperties` and annotations make strict schema behavior subtle.

## Severity Scale

- `P0` - can corrupt byte counts, delete the wrong target, make web and desktop disagree, break compatibility, or turn private path data into unsafe exported/logged data.
- `P1` - can cause stale UI, impossible migrations, confusing errors, broken generated clients, or hard-to-debug protocol drift.
- `P2` - important developer experience, diagnostics, documentation, or future tooling concern.

## Top 3 Data Contract Decisions

1. Dedicated `shared/protocol` contract with mapping at boundaries - 🎯 10 🛡️ 10 🧠 6, roughly 500-1400 LOC across Rust DTOs, Dart DTOs, mappers, schema snapshots, and tests.
2. String-encoded exact integers for byte counts, large counters, IDs, cursors, and sequence values - 🎯 10 🛡️ 10 🧠 5, roughly 250-900 LOC across value objects, serde helpers, Dart parsing/formatting, and fixtures.
3. Explicitly tagged DTO variants with unknown-tolerant client decoding - 🎯 9 🛡️ 9 🧠 5, roughly 300-900 LOC across event enums, error reason codes, Flutter fallbacks, and compatibility tests.

Rejected as defaults:

- raw Rust domain structs serialized directly to Flutter;
- OpenAPI-generated DTOs used as domain models;
- JSON numeric `u64` for exact byte sizes in web-facing DTOs;
- untagged public protocol enums;
- path strings as command authority.

## Core Principle

The wire protocol is a compatibility boundary, not the domain model.

Required shape:

```text
Rust domain/application types
  -> protocol mapper
  -> shared/protocol DTO
  -> JSON/OpenAPI/AsyncAPI examples
  -> Flutter transport DTO
  -> feature application/view state
```

Do not skip the mapping layer just because a field set looks identical today.

Why:

- domain evolves around rules and invariants;
- protocol evolves around compatibility;
- persistence evolves around migrations;
- UI state evolves around rendering and interaction;
- generated API types are convenient but should not own product language.

## Numeric Precision

### JSON `u64` Is Unsafe For Flutter Web - `P0`

Dart web and JavaScript cannot represent every 64-bit integer exactly. Disk sizes, inode counts, event sequences, timestamps in nanoseconds, and opaque numeric IDs can exceed the safe integer boundary in realistic or future remote/server use.

Important threshold:

```text
2^53 - 1 = 9,007,199,254,740,991
```

That is about 8 PiB if interpreted as bytes. A 500 GB laptop is safe, but Clean Disk should not bake laptop-scale assumptions into the protocol.

Required behavior:

- exact unsigned/signed 64-bit values cross JSON as decimal strings;
- Flutter parses them into a value object, not a raw `int` in web-facing code;
- display formatting can use server-provided formatted values or safe approximate doubles;
- sorting/filtering by exact size happens in Rust;
- arithmetic needed for UI progress uses bounded safe values or server-provided ratios;
- OpenAPI schema marks exact integer strings explicitly.

Recommended DTO pattern:

```json
{
  "logicalBytes": "41570752512",
  "allocatedBytes": "38700000000",
  "reclaimBytesEstimate": "28600000000",
  "percentOfParentBasisPoints": 3980
}
```

`percentOfParentBasisPoints` can be a JSON number because it is bounded. Exact byte values stay strings.

### Use Value Objects For Exact Quantities - `P0`

Do not spread decimal strings through UI code.

Rust:

```text
ByteCountDto
  raw: u128/u64 internally
  JSON: decimal string
```

Dart:

```text
ByteCount
  decimal: String
  safeInt: int?       # present only when exactly safe on current target
  approxDouble: double
  display: String?    # optional server/client formatted label
```

Rules:

- UI rows do not do exact ordering with `approxDouble`;
- delete plan totals come from Rust;
- display labels do not become command input;
- tests include `2^53 - 1`, `2^53`, `2^53 + 1`, and max supported values.

### Counts Can Also Exceed Safe Integers - `P1`

File count, directory count, skipped count, warning count, and event sequence count can grow in remote/server mode.

Recommended policy:

- small bounded values: JSON number;
- user-visible unbounded counters: decimal string plus optional display label;
- event sequence IDs: opaque string or decimal string, not JSON number;
- page sizes and limits: JSON number with max validation;
- percentages/ratios: integer basis points or decimal string, never binary float for authority.

Examples:

```json
{
  "filesScanned": "1284221",
  "directoriesScanned": "42193",
  "skippedCount": 17,
  "eventSeq": "scan_01HX_seq_0000000000001234"
}
```

### Float Percentages Are Display Hints Only - `P1`

Floating-point values are acceptable for charts and animation hints, but not for safety rules.

Allowed:

- donut chart percentages;
- progress smoothing;
- throughput estimate;
- approximate display ratios.

Forbidden:

- using `double` to compute delete totals;
- using `double` to determine whether an item is above a cleanup threshold;
- using floating comparison for stable pagination;
- using client-calculated percentage as authority for details panel.

Preferred:

```json
{
  "shareBasisPoints": 5700,
  "shareDisplay": "57.0%"
}
```

### BigInt Is Not A Wire Format - `P1`

JavaScript BigInt exists, but JSON does not natively serialize BigInt as a separate type. Relying on BigInt in browser code also complicates generated clients and cross-runtime behavior.

Policy:

- wire uses decimal strings;
- Rust maps strings to exact integer types;
- Dart maps strings to value objects;
- BigInt may be used inside Dart value object implementation if useful;
- no public JSON field expects a JavaScript BigInt literal.

## Path And Name Encoding

### JSON Strings Are UTF-8, OS Paths Are Not Always UTF-8 - `P0`

Rust `Path` and `OsStr` exist because paths are platform-native values. Unix paths can contain arbitrary bytes except NUL and slash. `Path::to_string_lossy()` can replace invalid bytes, which is fine for display but fatal for authority.

Required DTO split:

```json
{
  "nodeId": "node_...",
  "displayName": "fo�.txt",
  "displayPath": "/tmp/fo�.txt",
  "pathEncoding": "lossy",
  "pathAuthority": "node_id_only"
}
```

Rules:

- destructive commands never accept display path as authority;
- path display can be lossy and must be labeled internally;
- identity snapshot remains server-side or encoded in an opaque token;
- exports can include a redacted/safe display path by default;
- technical support bundles may include encoded path bytes only with explicit consent.

### Display Path And Command Path Are Different Fields - `P0`

For scanned nodes:

- UI displays `displayPath`;
- UI selects `nodeId`;
- delete plan stores `nodeId` plus identity snapshot;
- Rust revalidates current filesystem metadata;
- Rust adapter performs operation using OS-native path.

Forbidden:

```json
{
  "path": "/Users/belief/Library/Caches"
}
```

as the only command input for cleanup.

Acceptable command:

```json
{
  "deletePlanId": "dplan_...",
  "confirmationToken": "confirm_...",
  "idempotencyKey": "idem_..."
}
```

### Path Normalization Is Not Protocol Normalization - `P0`

Unicode normalization, case sensitivity, drive letters, UNC paths, volume mount points, and symlink/reparse behavior are platform facts. The protocol should not pretend that a path string can be normalized once and used everywhere.

Required fields where relevant:

```text
node_id
scan_session_id
index_version
volume_id?
provider_kind?
path_display
path_encoding
name_display
case_sensitivity_hint?
normalization_hint?
```

Rules:

- search normalization is separate from filesystem identity;
- path comparison happens in Rust/platform adapters;
- UI path matching is display-only;
- protocol never lowercases paths as identity;
- path equality is not inferred from display text.

### Bidi And Control Characters Need Safe Display Metadata - `P1`

Paths can contain characters that visually reorder text or hide suffixes.

Required behavior:

- protocol may include `hasBidiControls`, `hasControlChars`, or display safety flags;
- UI escapes or visually marks suspicious names in details/export contexts;
- copy-to-clipboard and export follow safe escaping policy;
- delete confirmation shows full safe path context, not only base name.

## Timestamps And Durations

### Wall-Clock Timestamps Use RFC 3339 Strings - `P1`

JSON has no native timestamp type. Use strings.

Recommended:

```json
{
  "startedAt": "2026-05-13T10:25:42.123Z",
  "completedAt": null
}
```

Rules:

- timestamps use UTC with explicit offset, normally `Z`;
- fractional seconds precision is documented;
- parsing failure is a protocol error;
- timestamps are optional when OS metadata is unavailable;
- display formatting is UI/localization work;
- timestamps are supporting evidence, not identity authority.

### Durations Are Not Timestamps - `P1`

Elapsed scan time, retry delay, token expiry duration, and throughput windows are not wall-clock instants.

Recommended:

```json
{
  "elapsedMillis": "168000",
  "retryAfterMillis": 2500
}
```

Policy:

- long/unbounded durations as decimal strings;
- small bounded delays can be JSON numbers;
- timeout decisions happen on server;
- client displays timers as hints;
- sleep/wake gaps are explicit status facts.

### Do Not Use Timestamps For Ordering Or Idempotency - `P0`

Wall clock can jump, clocks can differ, and file timestamps can have weak precision.

Use:

- server sequence for event order;
- operation ID for operation identity;
- idempotency key for retry dedupe;
- index version for snapshot identity;
- file identity snapshot for cleanup revalidation.

Do not use:

- `modifiedAt` as unique identity;
- `DateTime.now()` as request ID;
- client timestamp as ordering authority.

## Enums, Variants, And Compatibility

### Public Protocol Variants Need Explicit Tags - `P0`

Use explicit tags for commands, events, status variants, and polymorphic payloads.

Good:

```json
{
  "type": "scan.progress",
  "payload": {
    "sessionId": "scan_...",
    "filesScanned": "872341"
  }
}
```

Risky:

```json
{
  "sessionId": "scan_...",
  "filesScanned": 872341
}
```

with type inferred from shape.

Rules:

- no untagged enums for public command/event protocols;
- every event has `type`;
- every command has an endpoint plus explicit body shape;
- every public enum has unknown fallback in Flutter;
- Rust protocol mapping rejects unknown command variants unless explicitly allowed.

### Unknown Enum Values Are A Normal Compatibility Event - `P1`

Old Flutter clients can see new server variants.

Required behavior:

- Flutter transport DTOs decode unknown enum strings into `unknown(rawValue)`;
- UI renders safe fallback labels;
- destructive actions are disabled when risk/status variant is unknown;
- logs include raw unknown value safely;
- snapshot tests include future unknown variant fixtures.

Example:

```json
{
  "riskTier": "provider_managed_database"
}
```

Old client behavior:

- can display "Unknown risk";
- cannot execute cleanup based on it;
- can still render row safely.

### Boolean Flags Are Bad For Growing State - `P1`

Flags like `isRunning`, `isFailed`, `isPaused`, `canDelete`, `isStale` drift into impossible combinations.

Prefer:

```json
{
  "status": "running",
  "staleness": "current",
  "cleanupCapability": "disabled_revalidation_required"
}
```

Use booleans only when truly independent and stable:

- `hasMore`;
- `selected`;
- `expanded`;
- `isDirectory` if file kind is not expected to grow.

Even `isDirectory` may become too small if the protocol needs symlink, package, volume, cloud placeholder, or special file distinctions.

## Null, Missing Fields, And Defaults

### Null And Missing Must Have Different Meanings Or One Must Be Forbidden - `P1`

Ambiguous optionality creates subtle compatibility bugs.

Recommended policy:

- field missing: older protocol or optional field not sent;
- field `null`: known but unavailable/not applicable;
- field value: known value.

Example:

```json
{
  "modifiedAt": null,
  "modifiedAtState": "not_available"
}
```

For high-risk fields, explicit state is better than relying on `null`.

### Additive Fields Need Defaults In Both Directions - `P1`

When server adds a field:

- old clients ignore it;
- new clients have a default when talking to old server;
- compatibility tests cover missing field;
- OpenAPI/schema examples include old and new shapes.

Rust serde policy:

- use `#[serde(default)]` for newly added optional fields where old payloads must decode;
- avoid `deny_unknown_fields` on forward-compatible DTOs;
- do not combine `flatten` and strict unknown-field assumptions.

Flutter policy:

- generated/manual `fromJson` must tolerate extra fields;
- optional fields map to explicit domain/view defaults;
- missing safety-critical field disables destructive controls.

### Duplicate JSON Object Keys Are Invalid For Our Commands - `P1`

RFC 8259 says object names should be unique and behavior is unpredictable when they are not.

For public command/query inputs:

- reject duplicate keys where parser/tooling allows;
- if the JSON parser cannot detect duplicates, keep command bodies simple and schema-validated;
- never rely on "last key wins" for security-relevant fields;
- add malicious duplicate-key fixtures for auth, target, confirmation token, and delete plan IDs.

## IDs, Cursors, And Opaque Tokens

### IDs Are Strings, Not Numbers - `P0`

Node IDs, scan session IDs, delete plan IDs, receipt IDs, operation IDs, request IDs, and event stream IDs are opaque strings.

Required behavior:

- clients never parse IDs;
- IDs include enough server-side scope internally if useful, but that format is private;
- no vector indexes, memory addresses, or database row IDs are exposed as stable public IDs;
- ID prefixes are for debugging only, not client branching.

Good:

```json
{
  "nodeId": "node_01hx9v5x0z...",
  "scanSessionId": "scan_01hx9v..."
}
```

Bad:

```json
{
  "nodeId": 183994
}
```

### Pagination Cursors Are Opaque Strings - `P0`

Cursors carry snapshot/index/sort/filter/page boundary information, but the client should not know the structure.

Required behavior:

- cursor is a string;
- server validates cursor belongs to current session and query shape;
- cursor expires on incompatible index version;
- cursor includes or references protocol version;
- cursor is not logged with private filters unless redacted;
- cursor tampering returns structured problem.

Example:

```json
{
  "items": [],
  "nextCursor": "cur_01hx...",
  "hasMore": true
}
```

## Error Contracts

### Use Problem Details, But Keep Domain Error Codes Stable - `P1`

HTTP status alone is not enough. Human-readable `detail` is not a machine contract.

Required error shape:

```json
{
  "type": "https://cleandisk.local/problems/stale-snapshot",
  "title": "Snapshot is stale",
  "status": 409,
  "detail": "The selected item changed since the scan.",
  "instance": "err_01hx...",
  "errorCode": "stale_snapshot",
  "correlationId": "req_...",
  "retryable": false
}
```

Rules:

- clients branch on `errorCode` or typed fields, not `detail`;
- `detail` is safe, localized/user-facing if needed;
- no stack traces;
- no raw private paths by default;
- validation errors include JSON pointer or field path;
- destructive errors include operation ID and receipt/job reference when relevant.

### Error Code Additions Are Compatibility Events - `P1`

Unknown error code behavior:

- safe generic message;
- no automatic retry unless server marks known retry policy;
- destructive action disabled if error affects safety;
- diagnostics preserve raw code for support.

## Schema, OpenAPI, And Code Generation

### OpenAPI `integer int64` Can Mislead Web Clients - `P0`

OpenAPI supports `type: integer`, `format: int64`, but JavaScript/Dart web precision still matters. Some generators may map `int64` to a numeric type and lose precision.

Policy for exact large integers:

```yaml
type: string
format: int64
pattern: "^[0-9]+$"
x-clean-disk-exact-integer: true
```

For signed values:

```yaml
type: string
format: int64
pattern: "^-?[0-9]+$"
```

Rules:

- if the client must preserve exactness, use string;
- if a field is bounded below `2^53`, JSON number is acceptable with documented max;
- generated code must map exact integer strings to value objects, not raw `String` spread everywhere;
- schema snapshots include generated examples.

### JSON Schema Is A Contract Test Tool, Not The Domain - `P1`

JSON Schema/OpenAPI helps validate and document DTOs. It should not define domain rules by accident.

Allowed:

- validate command/query shape;
- validate protocol examples;
- generate docs;
- catch missing/renamed fields;
- support contract tests.

Forbidden:

- importing schema-generated types into domain;
- putting cleanup safety only in schema;
- treating schema validation as authorization;
- storing schema DTOs directly in persistence as durable rows without version wrapper.

### Codegen Must Be Owned By A Boundary Package - `P1`

If we generate Dart clients:

- generated files live under a protocol/data adapter package;
- feature application state maps from generated DTOs to local value objects;
- generated API changes require snapshot review;
- generated code is not manually edited;
- generated code does not import Flutter widgets or design system.

If we generate Rust OpenAPI:

- generation comes from `shared/protocol` DTOs or adapter annotations;
- domain/application crates do not depend on OpenAPI crates;
- snapshots of generated OpenAPI are reviewed in PRs.

## DTO Shape For Performance

### Large Tree Rows Need Flat, Compact DTOs - `P1`

Nested rich DTOs increase JSON size and decode work.

Recommended row DTO:

```json
{
  "nodeId": "node_...",
  "parentNodeId": "node_...",
  "depth": 4,
  "kind": "directory",
  "displayName": "Caches",
  "displayPath": "/Users/belief/Library/Caches",
  "logicalBytes": "41570752512",
  "allocatedBytes": "38700000000",
  "itemCount": "24981",
  "modifiedAt": "2026-05-06T14:18:00Z",
  "warnings": ["some_items_may_be_in_use"]
}
```

Avoid per-row:

- full ancestor object arrays;
- repeated full volume metadata;
- nested permission objects unless details panel requests them;
- localized display text for every possible action;
- huge warning/detail arrays.

Details panel can query richer data lazily.

### DTOs Should Separate Raw Facts From Display Strings - `P1`

Raw facts:

- exact bytes;
- count;
- timestamp;
- enum reason code;
- node ID.

Display strings:

- `38.7 GB`;
- `May 6, 2026`;
- `Some items may be in use`;
- localized status labels.

Policy:

- server may provide optional display hints for consistency;
- client can format local UI from raw facts;
- snapshots should not break only because a localized display label changed unless that label is part of protocol;
- sorting/filtering use raw facts, not display strings.

## Privacy And Redaction In DTOs

### Protocol DTOs Need Sensitivity Classification - `P0`

Every DTO field should be classified before logging/exporting.

Suggested classes:

```text
public_safe:
  protocol version, feature flags, bounded counters

user_sensitive:
  paths, file names, scan targets, timestamps, app names

secret:
  daemon tokens, confirmation tokens, pairing codes

destructive_authority:
  confirmation token, delete plan execution proof

support_sensitive:
  operation IDs, host/user summary, capability details
```

Rules:

- `secret` fields never appear in logs, reports, URLs, screenshots, or support bundles;
- `user_sensitive` fields are redacted by default in support bundles;
- `destructive_authority` fields are single-use and never persisted in browser storage;
- protocol snapshots use fake paths and fake tokens.

### Redaction Must Preserve Debuggability - `P1`

Bad redaction:

```text
/Users/[redacted]/[redacted]/[redacted]
```

Better:

```text
/Users/<user>/Library/Caches/<name>
path_hash: hmac_sha256(...)
path_depth: 5
basename_class: cache_dir
```

This lets support correlate entries without collecting raw private names.

## Compatibility Policy

### Protocol Version Is Not App Version - `P1`

App version, daemon version, protocol version, DTO schema version, and database schema version are different.

Handshake should return:

```json
{
  "daemonVersion": "0.1.0",
  "protocolVersion": "1.0",
  "minClientProtocolVersion": "1.0",
  "uiBundleVersion": "0.1.0+abc123",
  "features": {
    "scan": true,
    "moveToTrash": false
  }
}
```

Rules:

- patch app releases do not require protocol bumps unless wire behavior changes;
- additive fields can be minor version changes;
- removed/renamed/retyped fields require major version change;
- delete-capable UI requires compatible protocol;
- incompatible clients can still show diagnostics if safe.

### Compatibility Direction Must Be Explicit - `P1`

For local daemon-served UI:

- daemon and UI bundle normally ship together;
- still handle stale browser cache and old tab.

For hosted UI:

- new UI can meet old daemon;
- old UI can meet new daemon;
- remote deployments can lag;
- compatibility tests become mandatory.

MVP policy:

- daemon-served UI first;
- hosted UI only after compatibility matrix exists.

## Testing Matrix

### Numeric Fixtures

Required:

- `0`;
- `1`;
- `2^31 - 1`;
- `2^32`;
- `2^53 - 1`;
- `2^53`;
- `2^53 + 1`;
- `u64::MAX` if accepted by field semantics;
- negative value rejected for unsigned field;
- decimal string with leading zero rejected unless explicitly allowed;
- decimal string with exponent rejected for exact integer fields;
- huge value rejected with structured problem if above product max.

### Path Fixtures

Required where platform supports:

- valid UTF-8 path;
- invalid UTF-8 Unix path;
- lossy display path;
- bidi/control characters;
- decomposed/composed Unicode names;
- Windows drive path;
- UNC path;
- long path;
- path with trailing dot/space on Windows semantics;
- symlink/reparse display versus target identity.

### DTO Evolution Fixtures

Required:

- missing newly added optional field;
- unknown enum value;
- unknown event type;
- extra object field;
- duplicate key malicious payload where tooling supports detection;
- old client fixture against new server example;
- new client fixture against old server example;
- renamed field caught by snapshot diff;
- reordered fields do not break semantic test;
- generated OpenAPI snapshot diff reviewed.

### Error Fixtures

Required:

- RFC 9457 problem with known error code;
- unknown error code;
- validation error with JSON pointer;
- stale cursor;
- stale snapshot;
- unsupported protocol version;
- payload too large;
- invalid exact integer string;
- invalid timestamp;
- path display redacted in problem detail.

## MVP Cut Line

MVP protocol contract requires:

- `shared/protocol` DTO boundary exists in Rust;
- Flutter DTOs map into feature state/value objects;
- byte sizes and unbounded counts cross JSON as decimal strings;
- IDs and cursors are opaque strings;
- path display is not command authority;
- RFC 3339 timestamps for wall-clock instants;
- explicit event/variant tags;
- unknown enum fallback in Flutter;
- no untagged public protocol enums;
- no `deny_unknown_fields` on forward-compatible public DTOs;
- problem details or equivalent structured error DTO;
- schema/snapshot tests for representative command/query/event/error examples;
- numeric precision fixtures around `2^53`.

MVP can defer:

- full OpenAPI generation;
- AsyncAPI generation;
- binary transport;
- protobuf/FlatBuffers/MessagePack;
- external SDK guarantees;
- strict duplicate-key parser if command bodies stay simple and schema-tested;
- localized server-side display strings.

## Summary

Clean Disk's protocol must be boring and explicit:

```text
exact numbers as strings
opaque IDs as strings
paths as display text only
commands by IDs/tokens
explicit variant tags
unknown-tolerant clients
schema snapshots as review gates
domain models behind mappers
```

📌 The most dangerous protocol bug is not a crash. It is silent disagreement: Rust knows the exact file, Flutter web rounds the number or trusts a display path, and the UI looks correct while the command is wrong.
