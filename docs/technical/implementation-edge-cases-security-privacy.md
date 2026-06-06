# Implementation Edge Cases - Security, Privacy, And Threat Model

This file records security and privacy edge cases for Clean Disk.

The scanner can inspect private paths and the cleanup flow can move user files to Trash. That makes this project more security-sensitive than a normal dashboard. The main risk is not only external attackers. The risk is also a local browser tab, a stale web UI, a leaked daemon token, an over-permissive install, a support bundle with raw paths, or a remote mode that accidentally reuses local assumptions.

Related documents:

- [Implementation edge cases](implementation-edge-cases.md)
- [Implementation edge cases deep dive](implementation-edge-cases-deep-dive.md)
- [Implementation edge cases product workflows](implementation-edge-cases-product-workflows.md)
- [Implementation edge cases performance scale](implementation-edge-cases-performance-scale.md)
- [Rust architecture](rust-architecture.md)
- [Rust best practices research](rust-best-practices.md)

## Sources Reviewed

- OWASP, [CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html). Relevant points: custom headers can be used for browser APIs because they trigger same-origin/CORS controls, and CSRF must be handled server-side.
- OWASP, [WebSocket Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html). Relevant points: validate `Origin` on WebSocket handshake, use explicit allowlists, authenticate the connection, rate-limit, and avoid logging tokens/message contents.
- OWASP, [REST Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html). Relevant point: passwords, security tokens, and API keys should not appear in URLs because URLs are captured in logs.
- OWASP, [Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html). Relevant points: do not log access tokens, session IDs, secrets, sensitive personal data, and treat file paths as data that may need special handling.
- OWASP, [Input Validation Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html). Relevant points: use allowlist validation where appropriate, validate server-side, and canonicalization/normalization matter.
- OWASP, [Content Security Policy Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html). Relevant points: CSP can reduce XSS/clickjacking risk, avoid inline/eval, and restrict resources to trusted origins.
- OWASP, [Vulnerable Dependency Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Vulnerable_Dependency_Management_Cheat_Sheet.html). Relevant point: dependency vulnerability handling must be a planned process.
- Chrome Developers, [Private Network Access preflight](https://developer.chrome.com/blog/private-network-access-preflight). Relevant point: browsers are adding preflight behavior for private/local network requests.
- WICG, [Local Network Access](https://wicg.github.io/local-network-access/). Relevant point: browser permission checks are evolving because public websites can attack local network and localhost services.
- Microsoft Learn, [Local Network Access in Edge](https://learn.microsoft.com/en-us/deployedge/ms-edge-local-network-access). Relevant point: browser local-network restrictions affect websites that connect to localhost/local network servers.
- Microsoft Learn, [Named Pipe Security and Access Rights](https://learn.microsoft.com/en-us/windows/win32/ipc/named-pipe-security-and-access-rights). Relevant point: future Windows local IPC must have security descriptors/DACLs.
- Microsoft Learn, [STRIDE threat categorization](https://learn.microsoft.com/en-us/windows-hardware/drivers/driversecurity/threat-modeling-for-drivers). Relevant point: spoofing, tampering, repudiation, information disclosure, denial of service, and elevation of privilege are useful categories.
- Apple Developer Documentation, [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox). Relevant point: sandbox access to protected filesystem locations is constrained and can be extended through user-selected access/bookmarks.
- Apple Developer Documentation, [Security-scoped bookmark and URL access](https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access). Relevant point: persistent access needs explicit security-scoped bookmark handling.
- Apple Developer Documentation, [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). Relevant point: distribution needs signing/notarization and hardened runtime impacts app/helper behavior.
- Rust Reference, [Procedural macros](https://doc.rust-lang.org/reference/procedural-macros.html). Relevant point: procedural macros run during compilation and have the same security concerns as Cargo build scripts.
- Cargo Book, [Build scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html). Relevant point: build scripts are compiled and executed before building the package.
- RustSec, [Advisory Database](https://rustsec.org/). Relevant point: Rust dependency advisories can be checked with `cargo-audit`.
- Rust Secure Code Working Group, [Rust Supply Chain Security Guide](https://rust-secure-code.github.io/rust-supply-chain-security/). Relevant point: Rust supply chain includes sources, dependencies, toolchain, CI/CD, and binary distribution.

## Severity Scale

- `P0` - can allow unauthorized scan/delete, token theft, cross-origin daemon control, privilege escalation, remote data disclosure, or unrecoverable privacy leak.
- `P1` - can weaken isolation, create audit gaps, leak sensitive metadata, enable denial of service, or make secure operation hard to reason about.
- `P2` - important hardening, admin/deployment clarity, supportability, or defense-in-depth issue.

## Top 3 Security Decisions

1. Local daemon hardening by default - loopback-only bind, random port, per-session token, explicit Origin/Host validation, no wildcard CORS, no cookies, custom auth header - 🎯 10 🛡️ 10 🧠 6, roughly 300-900 LOC across HTTP/WS adapter, token discovery, middleware, and tests.
2. Delete-capable remote mode stays disabled/read-only until real authZ model exists - 🎯 10 🛡️ 10 🧠 5, roughly 200-700 LOC once remote mode exists.
3. Privacy-by-default logs, receipts, support bundles, and exports - 🎯 9 🛡️ 9 🧠 5, roughly 250-800 LOC across redaction, receipt/export models, and tests.

## Assets To Protect

Clean Disk assets:

- user files and folders;
- file and folder names;
- full paths;
- sizes, timestamps, permissions, and ownership metadata;
- scan history;
- delete plans;
- delete receipts;
- local daemon token;
- local daemon connection info;
- security-scoped bookmarks or permission grants;
- support bundles;
- app settings;
- installer/update channel;
- remote auth credentials if remote mode exists.

Important principle:

```text
Path metadata is private data.
```

A path can reveal client names, medical/legal/financial topics, project names, chat app usage, backups, source code layout, or personal media categories.

## Trust Boundaries

Primary trust boundaries:

- Flutter desktop UI -> Rust daemon;
- Flutter web UI -> browser -> Rust daemon;
- CLI/debug client -> Rust daemon;
- Rust daemon -> OS filesystem APIs;
- Rust daemon -> Trash/quarantine adapter;
- Rust daemon -> pdu scanner adapter;
- Rust daemon -> local state/cache/receipt storage;
- browser-delivered web UI bundle -> local daemon API;
- remote web UI -> remote daemon/server API;
- installer/updater -> app/helper/daemon binaries.

Boundary rule:

```text
Every boundary parses raw input into typed commands and rejects unsafe state before application services run.
```

The domain must never depend on "the UI probably did the right thing".

## STRIDE Snapshot

| STRIDE category | Clean Disk example | Main mitigation |
| --- | --- | --- |
| Spoofing | Malicious website pretends to be Clean Disk web UI and connects to localhost daemon | token, Origin/Host allowlist, no cookies, trusted UI origin |
| Tampering | Client edits DeletePlan payload to target a different path | server-side identity validation, plan hash, confirmation token binding |
| Repudiation | User cannot tell what was moved to Trash after partial failure | durable receipt, item outcomes, operation IDs |
| Information disclosure | Logs/support bundle leak raw private paths or tokens | redaction, data classification, no token logging |
| Denial of service | Web page opens many WebSockets or sends huge JSON | connection limits, body limits, rate limits, bounded queues |
| Elevation of privilege | App runs daemon as admin/root and exposes delete API | no privileged daemon by default, explicit admin mode, OS ACLs |

## Browser To Local Daemon

### Localhost Is Not Authentication - `P0`

A browser page can try to connect to local services. Browser policies are improving, but the daemon must defend itself.

Required behavior:

- bind local mode to `127.0.0.1` and `[::1]` only;
- use random port unless explicitly configured;
- require per-session local token for every command/query/event channel;
- reject missing/invalid token as auth failure;
- do not expose delete-capable API on `0.0.0.0` accidentally;
- remote listen address requires explicit remote profile.

### DNS Rebinding And Host Validation - `P0`

DNS rebinding can make an attacker-controlled origin point at local/private addresses after initial load. Do not rely only on CORS.

Required behavior:

- validate `Host` header against allowed loopback host/port values;
- reject unexpected DNS hostnames for local mode;
- reject `Origin` not in explicit allowlist;
- reject `Origin: null` for delete-capable endpoints;
- prefer serving the web UI from daemon origin in local mode;
- test DNS-rebinding-style requests with hostile `Host` and `Origin`.

### CORS Must Be Narrow - `P0`

Wildcard CORS is wrong for delete-capable local APIs.

Required behavior:

- explicit `Access-Control-Allow-Origin` for trusted local dev/UI origins only;
- no wildcard CORS for any token-bearing or delete-capable endpoint;
- no blind reflection of arbitrary `Origin`;
- allowed headers/methods are minimal;
- preflight failures return no sensitive details;
- CORS policy is tested as security behavior, not left as framework default.

### No Cookie Auth For Local Daemon - `P0`

Cookies make browser-based CSRF and cross-site WebSocket hijacking easier to get wrong.

Required behavior:

- local daemon auth uses explicit header or WebSocket subprotocol/token-bearing handshake;
- no ambient cookie auth for local daemon commands;
- custom header is required for mutating HTTP commands;
- commands still require confirmation and identity validation after auth;
- CORS/preflight is not a replacement for token validation.

### Token Must Not Be In URL - `P0`

URLs can land in browser history, logs, screenshots, proxies, crash reports, referrers, and support bundles.

Required behavior:

- daemon token never appears in query string;
- token never appears in path segment;
- token never appears in WebSocket URL query;
- use auth header or WebSocket protocol/handshake field;
- redact headers in logs;
- request DTOs and errors never serialize token values.

### WebSocket Security Is A Separate Check - `P0`

WebSocket upgrade starts as HTTP but then becomes a long-lived channel. Traditional HTTP logs and middleware can miss message-level behavior.

Required behavior:

- validate `Origin` during handshake;
- authenticate during handshake;
- bind connection to local session/client ID;
- enforce message size limits;
- enforce connection limits;
- validate every command message after decode;
- do not accept cleanup commands over WebSocket unless the same auth, idempotency, confirmation, and application validation are applied;
- log connection establishment/termination and security violations without message bodies or tokens.

### Private Network Access / Local Network Access Changes - `P1`

Chrome/Edge and standards work are changing how public sites access local/private network services.

Required behavior:

- test local web UI connection in Chrome, Edge, Safari, and Firefox;
- support PNA/LNA preflight behavior where required;
- show clear UI error when browser blocks local daemon;
- do not ask users to disable browser security features as normal setup;
- keep desktop app path working even if browser local access rules change.

### Serving Web UI Needs CSP - `P1`

If the daemon serves the web UI bundle, the web page becomes a sensitive control surface.

Required behavior:

- no remote scripts in production local web UI;
- no `eval`;
- avoid inline scripts/styles where practical;
- set CSP with `default-src 'none'` or strict equivalent that allows only required local assets/connect endpoints;
- `connect-src` only to the daemon origin;
- frame embedding is denied unless intentionally supported;
- development mode has separate relaxed policy and is never shipped as production default.

## Token And Secret Handling

### Token Discovery File Permissions - `P0`

Desktop app and web UI may need to find the local daemon port/token.

Required behavior:

- discovery file stored in OS runtime/state dir, not world-readable temp;
- restrictive permissions: user-only read/write;
- includes port/socket, daemon PID, protocol version, token identifier, and expiry metadata;
- token itself is protected or short-lived;
- stale discovery file is detected by PID/version/handshake;
- cleanup removes discovery file on normal shutdown.

### Secret Types - `P1`

Tokens should not be plain `String` values that accidentally derive `Debug` or serialize into logs.

Required behavior:

- use dedicated `LocalSessionToken` type;
- custom redacted `Debug`;
- no default `Serialize` for token-bearing internal types;
- equality check exists only where needed;
- token validation is transport/security adapter responsibility;
- application still performs authorization and delete safety validation.

### Token Rotation And Expiry - `P1`

Long-lived local tokens increase blast radius.

Required behavior:

- token generated per daemon session or app launch;
- token expires or rotates on explicit logout/pairing reset;
- web client handles token expiry by reconnecting through trusted discovery/pairing flow;
- old tokens invalidated on daemon restart;
- token rotation does not interrupt active delete operation without making state queryable.

## Command And Query Security

### Server-Side Authorization Only - `P0`

The UI may hide buttons, but server-side application services own authority.

Required behavior:

- every mutating command checks local/remote authorization server-side;
- cleanup command checks DeletePlan status and confirmation token;
- scan target must be allowed by current mode/profile;
- remote mode checks user/tenant permissions;
- app shell cannot bypass use cases to call filesystem or Trash adapters directly.

### Input Validation Happens At The Boundary - `P1`

Raw HTTP paths, JSON, query params, and WebSocket messages are untrusted.

Required behavior:

- body size limits;
- schema/version validation;
- allowlisted command names;
- bounded strings and arrays;
- typed path/request IDs;
- clear error codes;
- no generic "path from client -> filesystem operation" shortcut;
- reject unknown fields for destructive command payloads unless compatibility policy says otherwise.

### Path Validation Is Not Path Authority - `P0`

A syntactically valid path is not safe to delete.

Required behavior:

- scan target paths are parsed and permission-checked;
- cleanup actions use node identity snapshots from DeletePlan;
- before move-to-trash, revalidate identity, metadata, and risk class;
- display path never becomes execution authority;
- copied path text is not accepted as proof.

### Rate Limits Are Defense-In-Depth - `P1`

Rate limits help against accidental loops and malicious local pages, but they are not authentication.

Required behavior:

- per-client connection limit;
- per-token request rate limit;
- per-endpoint body limit;
- slow client eviction;
- scan session concurrency limit;
- delete operation cannot be rate-limit retried into duplicate execution.

### Error Messages Must Not Leak Too Much - `P1`

Security and filesystem errors can reveal private paths and permissions.

Required behavior:

- external protocol errors use stable codes and redacted context;
- full OS error details remain local debug logs only when safe;
- unauthorized errors do not reveal whether a path exists;
- remote mode avoids leaking cross-tenant path existence;
- support bundles show redaction preview.

## OS Permission And IPC Security

### Do Not Run As Root/Admin By Default - `P0`

Running elevated makes scan/delete more powerful and makes daemon exposure more dangerous.

Required behavior:

- normal app runs as current user;
- do not request admin/root just to scan more paths;
- privileged helper, if ever added, is a separate reviewed design;
- elevated mode has visible UI and separate confirmation;
- remote/server daemon should not run as root unless deployment explicitly requires and constrains it.

### macOS TCC And Security-Scoped Bookmarks - `P0`

macOS permissions are security controls, not annoying errors to bypass.

Required behavior:

- model permissions as capabilities;
- use user-selected folder access and security-scoped bookmarks where appropriate;
- never persist bookmarks without considering storage security and stale resolution;
- do not ask for Full Disk Access when a narrower grant is enough;
- signing identity changes can affect saved permissions/bookmarks;
- permission denied is a typed skipped state, not crash.

### Windows Named Pipe Future Transport - `P1`

If we later add named pipes, Windows pipe security must be explicit.

Required behavior:

- named pipe uses security descriptor/DACL limiting access to current user or intended group;
- no Everyone/write default for delete-capable API;
- first-instance behavior prevents spoofed daemon endpoints;
- client verifies server identity/version/capabilities after connect;
- named pipe transport shares protocol contract, not duplicate business logic.

### Unix Socket Future Transport - `P1`

If we later add Unix domain sockets, filesystem permissions become part of auth.

Required behavior:

- socket lives in user runtime dir;
- parent dir permissions are restrictive;
- stale socket cleanup checks owner/PID where possible;
- no socket in world-writable directory without safe creation pattern;
- token/origin-style auth may still be useful if browser bridge exists.

## Privacy And Data Minimization

### Logs Are Not Receipts - `P0`

Logs are diagnostics. Receipts are user-facing accountability. Mixing them leaks private data and weakens both.

Required behavior:

- production logs do not include raw scanned paths by default;
- logs never include tokens, request headers, auth material, or full WebSocket URLs;
- repeated path errors are counted/sampled;
- receipt export has redaction options;
- support bundle generator never dumps logs blindly.

### Support Bundle Must Be Safe By Default - `P0`

Support bundles can leak exactly the data this app inspects.

Required behavior:

- explicit user action to generate;
- preview before export;
- default redaction of home path and private path segments;
- token/header/auth fields excluded;
- receipts included only with explicit consent;
- remote/server bundles are scoped by tenant/user/session;
- generated bundle records redaction policy used.

### Scan History Is Sensitive - `P1`

Even without file contents, scan history can reveal user behavior.

Required behavior:

- detailed history disabled or limited by default;
- retention policy visible in settings;
- "clear scan history" does not delete receipts unless user explicitly chooses;
- local database/storage permissions are user-only;
- remote mode needs tenant/user retention policy before release.

### Screenshots And Crash Reports - `P1`

The UI is path-heavy, so screenshots and crash reports can leak private data.

Required behavior:

- crash reports, if ever added, do not include screenshots by default;
- user-shared diagnostics warn about visible paths;
- debug screenshots are opt-in;
- support UI can show redacted mode before capture/export.

### Telemetry Defaults To Off - `P1`

A disk cleanup app does not need network telemetry for MVP.

Required behavior:

- no telemetry in MVP unless explicitly approved later;
- if added, path-derived data is excluded by default;
- metrics use aggregates, not raw paths;
- remote mode observability has separate privacy policy.

## Remote / Server Mode

### Remote Mode Is Not Local Mode Over The Internet - `P0`

Local token/origin checks are not real remote authentication.

Required behavior:

- remote mode is explicit config;
- remote mode has real authentication;
- remote mode has authorization per user/target/action;
- TLS/reverse proxy decision is documented before enabling;
- delete-capable remote mode starts disabled/read-only until authorization and audit are designed;
- UI always shows target host/context.

### Multi-User Isolation - `P0`

Server scans can expose other users' paths.

Required behavior:

- scan sessions scoped to authenticated principal;
- event subscriptions check session ownership;
- DeletePlans scoped to principal;
- support bundles scoped and redacted per user/tenant;
- admin mode is separate, audited, and visibly different.

### Audit Without Over-Collecting - `P1`

Remote cleanup needs accountability, but audit logs can leak sensitive paths.

Required behavior:

- audit records operation ID, actor, target class, timestamps, outcome, and redacted path summary;
- full raw paths only stored if policy requires and access is restricted;
- delete receipt remains the detailed user-facing artifact;
- audit retention and deletion policy documented.

## Supply Chain And Release Security

### Dependencies Can Execute At Build Time - `P1`

Rust build scripts and procedural macros can run code during compilation.

Required behavior:

- dependency additions require maintainer/activity/license/security review;
- minimize proc-macro/build-script dependencies in production crates;
- run advisory checks such as `cargo audit` when Rust workspace exists;
- keep lockfiles for release reproducibility;
- do not pass signing keys, daemon tokens, or private paths into build environment unless release process requires it;
- CI/release environment is treated as sensitive.

### Web Bundle Supply Chain - `P1`

If the daemon serves the web UI, frontend dependencies affect a delete-capable control surface.

Required behavior:

- lockfile committed;
- dependency updates reviewed;
- no remote CDN scripts in production local web UI;
- CSP prevents unexpected script execution;
- web bundle version tied to daemon protocol compatibility.

### Signing, Notarization, And Helper Integrity - `P1`

Desktop users need to trust the binary that scans/deletes.

Required behavior:

- macOS release builds use Developer ID signing/notarization where distributed directly;
- helper/daemon binary is signed as part of app bundle/release;
- updater verifies signatures;
- protocol compatibility check prevents new UI from driving old daemon incorrectly;
- update is blocked or delayed during active delete operation.

## Testing Matrix

### Browser/Local Daemon Tests

- unauthorized `Origin` rejected;
- missing `Origin` policy is explicit;
- `Origin: null` rejected for delete-capable endpoints;
- hostile `Host` rejected;
- wildcard CORS absent from delete-capable endpoints;
- token in URL is not accepted;
- missing token rejected;
- invalid token rejected;
- custom header required for mutating HTTP commands;
- WebSocket unauthorized origin rejected;
- WebSocket missing token rejected;
- WebSocket oversized message rejected;
- PNA/LNA preflight behavior tested in Chrome/Edge;
- malicious page simulation cannot start scan or create DeletePlan.

### Token/Storage Tests

- discovery file permissions are user-only;
- stale discovery file does not connect to wrong daemon;
- tokens do not appear in logs;
- tokens do not appear in errors;
- tokens do not appear in support bundle;
- token-bearing types have redacted debug output.

### Command Security Tests

- client-side hidden button bypass does not authorize delete;
- unknown destructive command fields rejected or handled by compatibility policy;
- oversized command body rejected;
- scan path outside allowed profile rejected in remote mode;
- unauthorized user cannot query another user's session;
- unauthorized user cannot subscribe to another user's WebSocket events;
- unauthorized user cannot access another user's receipt.

### Privacy Tests

- logs redact home path by default;
- support bundle preview shows included data classes;
- support bundle excludes tokens/headers;
- receipt export redaction works;
- scan history clear works independently from receipts;
- crash report payload has no raw paths unless explicitly opted in.

### Supply Chain / Release Tests

- dependency audit command documented once Rust workspace exists;
- lockfile included in release builds;
- macOS app and helper signing checked;
- protocol version mismatch disables cleanup actions;
- updater does not restart daemon during active Trash operation.

## MVP Cut Line

MVP should include:

- loopback-only daemon bind;
- random port;
- local session token;
- no token in URL;
- Origin and Host validation;
- no wildcard CORS;
- WebSocket origin/token validation;
- HTTP body limits and WebSocket message limits;
- token redaction;
- support bundle redaction basics;
- no telemetry;
- remote cleanup disabled until authZ exists;
- no admin/root daemon by default.

MVP can defer:

- named pipe/Unix socket transport;
- remote multi-user cleanup;
- formal enterprise audit policy;
- telemetry;
- security-scoped bookmark sync across devices;
- privileged helper;
- advanced CSP nonce/hash tuning if local web UI is not served yet.

## Summary

Clean Disk's security model should stay simple:

```text
local by default, token-protected, origin-checked, least-privilege, privacy-redacted, remote-read-only until authZ exists
```

The dangerous mistake is treating "localhost" as trusted. The second dangerous mistake is treating paths as harmless strings.
