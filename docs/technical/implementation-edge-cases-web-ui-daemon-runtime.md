# Implementation Edge Cases - Web UI And Local Daemon Runtime

Last updated: 2026-05-13.

This file records browser-runtime edge cases for Clean Disk when the Flutter web UI talks to the Rust daemon through HTTP and WebSocket.

Related documents:

- [Implementation edge cases transport protocol streaming](implementation-edge-cases-transport-protocol-streaming.md)
- [Implementation edge cases security privacy](implementation-edge-cases-security-privacy.md)
- [Implementation edge cases remote and headless mode](implementation-edge-cases-remote-headless-mode.md)
- [Implementation edge cases operational reliability](implementation-edge-cases-operational-reliability.md)
- [Implementation edge cases Flutter large tree UI](implementation-edge-cases-flutter-large-tree-ui.md)

This document is narrower than the transport document. It focuses on the browser as an execution environment:

- CORS and origin rules;
- Private Network Access and Local Network Access browser policy;
- localhost daemon discovery and pairing;
- service worker cache/version skew;
- WebSocket behavior in tabs, bfcache, sleep, and browser lifecycle;
- Flutter web renderer constraints;
- hosted web UI versus daemon-served web UI;
- browser storage and support bundle privacy;
- web-specific testing.

## Sources Reviewed

- MDN, [Cross-Origin Resource Sharing](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS). Relevant points: CORS is header-based, preflight exists for non-simple or side-effect-capable requests, wildcard origins are incompatible with credentialed requests, and browser JavaScript receives limited failure detail.
- Chrome for Developers, [Private Network Access: introducing preflights](https://developer.chrome.com/blog/private-network-access-preflight). Relevant points: requests from public/private contexts to more private networks, including localhost, are subject to Private Network Access rules; PNA introduces `Access-Control-Request-Private-Network` and `Access-Control-Allow-Private-Network`.
- Chrome for Developers, [New permission prompt for Local Network Access](https://developer.chrome.com/blog/local-network-access). Relevant points: local network protections are evolving, loopback/local/private destinations have special rules, and permission prompts can affect local daemon access.
- MDN, [Secure contexts](https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts). Relevant point: localhost, 127.0.0.1, `*.localhost`, and file URLs are generally treated as potentially trustworthy local origins.
- MDN, [Mixed content](https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/Mixed_content). Relevant points: active HTTP requests from secure contexts can be blocked; local loopback resources have special treatment, but mixed-content policy still matters for hosted UI and downloads.
- OWASP Cheat Sheet Series, [WebSocket Security](https://cheatsheetseries.owasp.org/cheatsheets/WebSocket_Security_Cheat_Sheet.html). Relevant points: validate `Origin`, authenticate handshakes, authorize messages, enforce size/rate limits, and treat WebSocket compression carefully.
- MDN, [Writing WebSocket client applications](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_client_applications). Relevant points: open WebSockets can interact with bfcache; close on `pagehide` and reconnect on `pageshow`.
- MDN, [Using Service Workers](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers). Relevant points: service workers act like a proxy/cache layer, require HTTPS except local development, and have install/activate/version lifecycle.
- Flutter, [Build and release a web app](https://docs.flutter.dev/deployment/web). Relevant points: `flutter build web` produces static files in `build/web`, and release builds should be validated through a web server.
- Flutter, [Web renderers](https://docs.flutter.dev/platform-integration/web/renderers). Relevant points: default web build uses CanvasKit; `--wasm` makes Skwasm available with fallback; Skwasm threading needs SharedArrayBuffer security requirements.
- Flutter, [Web app initialization](https://docs.flutter.dev/platform-integration/web/initialization). Relevant points: web bootstrap and service worker versioning can be customized at build time.
- MDN, [Cross-Origin-Opener-Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Cross-Origin-Opener-Policy). Relevant points: SharedArrayBuffer and unthrottled timers require cross-origin isolation through COOP/COEP headers.

## Severity Scale

- `P0` - can expose local filesystem control to the wrong website, enable destructive commands from an untrusted origin, strand users on a stale daemon/client version, or make the web UI unusable in normal browsers.
- `P1` - can cause confusing connection failures, stale UI, browser-specific bugs, performance cliffs, support burden, or broken remote/local mode semantics.
- `P2` - polish, diagnostics, packaging, or future-mode concerns that should not block the first prototype but must be known.

## Top 3 Web Runtime Decisions

1. Daemon-served local web UI as the default local web path - 🎯 10 🛡️ 9 🧠 5, roughly 450-1200 LOC across static asset serving, capability handshake, cache headers, web bootstrap, and tests.
2. Hosted web UI as an explicit advanced mode with pairing and browser-policy handling - 🎯 7 🛡️ 7 🧠 8, roughly 900-2600 LOC across origin allowlists, PNA/LNA handling, pairing UX, token flow, support diagnostics, and compatibility tests.
3. Browser-only scanner through Web APIs or WASM - 🎯 2 🛡️ 3 🧠 7, roughly 1200-3500 LOC for a weaker product. It cannot be the full disk scanner because browser filesystem APIs are sandboxed and user-mediated.

Recommended product posture:

- local desktop app can embed or launch the same UI;
- local web UI should normally be served by the Rust daemon on loopback;
- externally hosted web UI is useful for remote/headless/server mode, but it is a different capability tier;
- browser-only disk scanning is a demo/import helper, not the product scanner.

## Core Principle

The web UI is a control plane, not the scanner.

The browser must never become the authority for:

- scan target permissions;
- filesystem identity;
- delete authority;
- stale scan revalidation;
- cleanup receipts;
- daemon token validation;
- durable operation state.

Those stay in Rust application/domain/runtime services. Flutter web owns only presentation state, UI intent, and small client-side caches.

## Delivery Modes

### Daemon-Served Web UI Should Be The Local Default - `P0`

Serving the Flutter web bundle from the local daemon gives one strong advantage: the UI and daemon can be same-origin by default.

Expected shape:

```text
http://127.0.0.1:{random_port}/
  serves Flutter web assets

http://127.0.0.1:{random_port}/api/...
  serves HTTP commands and queries

ws://127.0.0.1:{random_port}/events
  serves WebSocket events
```

Benefits:

- no CORS for the normal local flow;
- daemon can serve a matching UI bundle;
- capability/version handshake is same-origin;
- no hosted website needs direct access to localhost;
- fewer browser permission surprises;
- simpler support story.

Required behavior:

- bind only loopback;
- randomize port;
- keep token or session proof even with same-origin;
- serve static assets with explicit cache policy;
- expose `/health`, `/version`, and `/capabilities`;
- disable destructive UI if daemon capability handshake fails;
- never serve private filesystem data as static assets.

Do not assume same-origin means trusted. Same-origin reduces browser policy friction, but malicious local processes, browser extensions, stale tabs, and compromised UI assets still matter.

### Hosted Web UI Is A Separate Mode - `P0`

Hosted web UI means a public or LAN-served origin connects to a local daemon:

```text
https://app.cleandisk.example
  -> http://127.0.0.1:{random_port}/api
  -> ws://127.0.0.1:{random_port}/events
```

This is possible, but it touches more browser policy:

- CORS;
- Private Network Access;
- mixed content rules;
- Local Network Access prompts;
- corporate browser policy;
- old tabs and cached app versions;
- user confusion about which machine is being scanned.

Required behavior:

- hosted UI mode is opt-in;
- daemon has an explicit origin allowlist;
- pairing proves user intent;
- destructive commands stay disabled until pairing and capability checks pass;
- UI clearly shows target daemon host, user, and mode;
- support docs explain browser prompts and local daemon discovery.

Hosted UI must not silently fall back to unsafe broad CORS just to make setup easier.

### Browser-Only Filesystem Access Is Not The Product Scanner - `P0`

Browser file access APIs are user-mediated and sandboxed. They are useful for:

- importing a report file;
- exporting support bundles;
- opening a user-selected folder in a limited future experiment;
- web demo data.

They are not enough for:

- scanning the whole disk;
- scanning protected folders;
- detecting OS Trash semantics;
- reliable filesystem identity snapshots;
- move-to-trash adapters;
- remote/headless server scanning.

Rule:

- any browser filesystem integration is an import/export adapter;
- scanner contracts still point to Rust daemon/server ports;
- no UI copy should imply that the browser can scan the full disk by itself.

## CORS, PNA, And Local Network Policy

### CORS Is Not Authentication - `P0`

CORS controls what browser JavaScript can read. It does not prove that the caller is a trusted app, and it does not protect against non-browser clients.

Required behavior:

- authenticate every HTTP and WebSocket request;
- authorize every command and object;
- validate `Origin` and `Host`;
- never use `Access-Control-Allow-Origin: *` for local daemon APIs;
- do not rely on cookies for local daemon auth;
- avoid credentialed CORS unless there is a specific future reason;
- fail closed on missing or unexpected Origin for browser-facing routes.

Hosted web UI CORS policy:

```text
Allowed:
  Origin: https://app.cleandisk.example
  Access-Control-Allow-Origin: https://app.cleandisk.example

Forbidden:
  Access-Control-Allow-Origin: *
  reflected arbitrary Origin
  broad suffix matching like *.example.com without exact host policy
```

### PNA/LNA Can Break Hosted UI Suddenly - `P1`

Private Network Access and Local Network Access policies exist because public websites talking to private/local endpoints can be abused. Clean Disk is exactly in that risk zone when a hosted UI connects to a local daemon.

Required behavior:

- daemon handles `OPTIONS` preflight cleanly;
- daemon can return `Access-Control-Allow-Private-Network: true` only for explicitly allowed origins;
- hosted UI has a connection doctor that distinguishes CORS, PNA, auth, daemon offline, and version mismatch;
- local-mode docs prefer daemon-served UI to avoid most hosted-to-local policy churn;
- tests cover Chrome policy changes at least manually before public releases.

Do not treat browser PNA failures as generic "daemon offline". Users need a specific recovery action.

### Localhost, 127.0.0.1, ::1, And *.localhost Are Not Identical In Practice - `P1`

Browsers, DNS, proxies, VPNs, and enterprise policy can treat these differently.

Required behavior:

- bind IPv4 loopback and IPv6 loopback intentionally, or report which is active;
- generate UI URLs with the bound address;
- do not rely on `localhost` resolving correctly in every environment;
- Host allowlist includes only exact accepted loopback hosts;
- DNS rebinding checks reject unexpected hostnames;
- discovery records address family and port.

Test cases:

- `127.0.0.1`;
- `localhost`;
- `::1`;
- stale browser tab pointing to old port;
- corporate proxy/PAC interfering with localhost;
- VPN running while daemon starts.

### Mixed Content Rules Affect Hosted UI - `P1`

An HTTPS hosted page opening `http://127.0.0.1` or `ws://127.0.0.1` can hit mixed-content and browser-specific policy. Loopback has special treatment in modern browsers, but this is not a product contract we should stretch.

Required behavior:

- local default avoids hosted-to-local mixed-content by serving UI from daemon;
- hosted UI has explicit compatibility testing for HTTP and WebSocket local daemon connections;
- do not put daemon tokens or report downloads in insecure remote URLs;
- if remote mode is internet-facing, require HTTPS/WSS rather than relying on local exceptions;
- keep support text precise: local loopback is special, remote HTTP is not.

## Pairing And Token Flow

### Browser Cannot Read The Daemon Discovery File - `P0`

The desktop launcher or CLI can read a per-user discovery file. A hosted browser page cannot.

Recommended pairing options:

1. Daemon-served UI needs no external discovery because the URL already points to the daemon - 🎯 10 🛡️ 9 🧠 4, roughly 200-600 LOC.
2. Hosted UI asks user to paste a short pairing code shown by the desktop app/daemon - 🎯 8 🛡️ 8 🧠 6, roughly 500-1300 LOC.
3. Hosted UI receives daemon endpoint from a custom URL scheme launcher - 🎯 7 🛡️ 7 🧠 8, roughly 900-2500 LOC across installers, protocol handlers, OS prompts, and browser flows.

MVP recommendation:

- use daemon-served local UI first;
- add pairing code only when hosted UI becomes product scope;
- delay custom URL scheme until installer strategy is stable.

### Tokens Must Not Be Long-Lived Browser Secrets - `P0`

Browser storage is exposed to XSS, extensions, profile sync edge cases, support screenshots, and local users.

Required behavior:

- access token is short-lived and bound to daemon instance;
- token is never placed in query parameters;
- token is not stored in `localStorage`;
- if browser storage is needed, prefer session-only storage and rotate on daemon restart;
- logs, reports, receipts, and support bundles redact tokens;
- server accepts token only with allowed Origin and Host for browser routes;
- destructive operations still require confirmation token tied to plan hash.

Acceptable local-mode model:

```text
daemon session token:
  proves UI is connected to this daemon instance

delete confirmation token:
  proves user reviewed this exact DeletePlan

idempotency key:
  dedupes retry of one command
```

These are different secrets with different lifetimes.

### URL Fragments Are Still Sensitive - `P1`

A URL fragment is not sent to the server in HTTP, but it can still appear in browser history, screenshots, analytics bugs, copied URLs, and debugging sessions.

If a pairing flow ever uses a fragment:

- make it single-use;
- expire it quickly;
- clear it with `history.replaceState` immediately after bootstrap;
- never put delete-capable confirmation tokens in a fragment;
- do not use fragments for normal daemon auth if daemon-served UI can avoid it.

## Service Worker And Cache Versioning

### Service Worker Can Serve The Wrong UI For The Right Daemon - `P0`

Service workers are powerful because they proxy and cache. That also means a stale service worker can keep serving an old Flutter app against a newer daemon.

MVP rule:

- do not enable offline-first/PWA service worker behavior for daemon-served UI until update semantics are designed.

If service worker is enabled:

- every startup performs protocol/capability handshake;
- UI build version is visible to the daemon;
- daemon exposes minimum compatible UI build/protocol version;
- old UI disables destructive commands when compatibility fails;
- update flow can force reload safely;
- support bundle records service worker version and cache status without leaking paths.

### Cache Headers Need A Product Policy - `P1`

Recommended local daemon static cache policy:

```text
index.html:
  Cache-Control: no-store or no-cache

flutter_bootstrap.js:
  Cache-Control: no-store or no-cache

hashed assets:
  Cache-Control: public, max-age=31536000, immutable

API responses:
  Cache-Control: no-store
```

Reasons:

- `index.html` and bootstrap choose the running app version;
- hashed assets are safe to cache aggressively;
- API responses contain sensitive local state and must not be browser-cached by default.

### Offline UI Must Not Promise Offline Scanning - `P0`

An offline-capable web shell can render, but it cannot scan without the daemon.

Required behavior:

- if daemon is unreachable, show reconnect/diagnostic state;
- do not show stale scan tree as current filesystem truth;
- stale cached data is labeled as history if history is supported;
- destructive controls are disabled while daemon authority is unavailable;
- offline support bundle generation is limited to already-local non-sensitive diagnostics.

## Browser Tab Lifecycle And WebSocket Behavior

### WebSocket Disconnect Is Normal - `P1`

Tabs sleep, laptops suspend, browsers throttle background JS, network changes, and bfcache can pause or close connections.

Required behavior:

- client treats socket close as `connection_unknown`, not scan failure;
- on reconnect, client queries HTTP state before trusting events;
- `pagehide` closes the WebSocket cleanly where possible;
- `pageshow` triggers capability/session query and reconnect;
- background tab progress can be stale by design;
- UI shows stale timestamp for last progress update.

### Browser WebSocket Handshake Needs The Same Security As HTTP - `P0`

OWASP calls out Cross-Site WebSocket Hijacking risk. Browser cookies and ambient credentials make this worse, so Clean Disk should avoid cookie auth for the local daemon.

Required behavior:

- validate Origin on WebSocket handshake;
- require bearer/session token or equivalent explicit auth;
- verify subscription authorization for every session ID;
- limit message size;
- rate-limit client messages;
- disable per-message compression until measured and threat-reviewed;
- close unauthorized or malformed connections with explicit protocol close reason where safe.

### WebSocket Is Not A Command Bus - `P1`

For browser reliability, keep commands and queries on HTTP.

Allowed WebSocket client messages:

- subscribe;
- unsubscribe;
- heartbeat/ack if needed;
- client capability/debug metadata if needed.

Forbidden in MVP:

- `delete_path`;
- `execute_delete_plan`;
- raw tree query results;
- large report export;
- arbitrary debug filesystem command.

## Flutter Web Runtime

### CanvasKit Is The Compatibility Baseline - `P1`

Flutter web default build uses CanvasKit. It is compatible with modern browsers and adds a Wasm/asset payload. That is acceptable for a dense local productivity app, but it affects first load.

Required behavior:

- measure first load for daemon-served UI;
- keep landing shell minimal;
- do not block daemon connection doctor behind heavy optional assets;
- preload only what the first screen needs;
- avoid giant bundled example data.

### Skwasm Is A Future Performance Option, Not A Contract - `P1`

Flutter `--wasm` can use Skwasm with CanvasKit fallback. Threaded Skwasm depends on SharedArrayBuffer and cross-origin isolation headers.

Required behavior:

- baseline release works without `--wasm`;
- if using `--wasm`, daemon static server must emit required COOP/COEP headers when safe;
- check `crossOriginIsolated` in diagnostics if threaded rendering is expected;
- do not make product correctness depend on SharedArrayBuffer;
- test with browsers that do and do not support WasmGC/Skwasm.

### Browser Memory Is A Hard Product Limit - `P0`

The browser tab has a weaker memory budget than native desktop. CanvasKit/Wasm, decoded JSON, virtualized rows, charts, and cached pages all compete.

Required behavior:

- Flutter web keeps only viewport pages and bounded caches;
- large exports stream/download through daemon endpoints instead of building giant in-memory blobs;
- charts use aggregated summaries, not full-tree client arrays;
- page cache has a memory budget;
- hidden tabs stop expensive animations and polling;
- web benchmarks include memory snapshots.

## Data Export And Browser Downloads

### Export Downloads Are Not UI State - `P1`

A support bundle or report can be too large to assemble in Flutter web memory.

Required behavior:

- daemon creates export job;
- UI polls/query job status;
- download endpoint streams file;
- export has size limit and retention;
- browser download name is sanitized;
- CSV/HTML/Markdown escaping policy from product workflow document still applies;
- daemon token is not embedded in downloaded URLs.

### Browser Download UX Differs By Platform - `P2`

Chrome, Safari, Firefox, desktop browsers, and managed enterprise browsers handle downloads differently.

Required behavior:

- completion UI says "export created" rather than assuming file saved;
- support bundle path is not guessed by the app;
- if a browser blocks a download, show retry/copy diagnostic action;
- remote mode labels which host generated the export.

## Web Storage And Privacy

### LocalStorage Is Too Durable For Secrets - `P0`

`localStorage` survives restarts and can be read by any script on the same origin.

Required behavior:

- do not store daemon tokens in `localStorage`;
- store only non-secret UI preferences if needed;
- clear session storage on incompatible daemon/session change;
- endpoint hints are non-authoritative and must be revalidated;
- user can clear web UI local state;
- support bundle reports presence of stored preferences without dumping sensitive values.

### IndexedDB Is Not A Scan Cache By Default - `P1`

The daemon owns scan tree and indexes. Duplicating them into browser IndexedDB increases privacy risk and version complexity.

Allowed:

- small preference cache;
- UI layout preferences;
- non-sensitive recent target labels if product policy allows;
- offline docs/help assets if service worker mode is accepted later.

Forbidden in MVP:

- full raw scan tree in IndexedDB;
- delete plan authority in browser storage;
- receipts stored only in browser;
- daemon tokens in IndexedDB.

## Remote And Hosted Mode Boundaries

### Local UI And Remote UI Need Visible Target Context - `P0`

A browser tab can connect to:

- local daemon on this machine;
- remote daemon on a server;
- daemon inside a container;
- daemon on a shared workstation;
- stale daemon from a previous launch.

Required UI facts:

- target host/mode;
- effective user where safe;
- read-only versus cleanup-capable;
- daemon version/protocol;
- scan root origin;
- remote delete policy;
- last successful handshake time.

Destructive confirmations must include the target context, not only the folder name.

### Hosted UI Must Not Broaden Local Daemon Attack Surface - `P0`

If hosted UI is allowed, only that exact origin should work. Adding `localhost` CORS to support "any hosted frontend" is unsafe for a cleanup tool.

Required behavior:

- local daemon has a configured origin allowlist;
- pairings are scoped to origin;
- origin allowlist is visible in diagnostics;
- dev mode broad origins require an explicit environment flag and warning;
- production never reflects arbitrary Origin.

## Clean Architecture Fit

### Web Runtime Is Infrastructure - `P0`

The web delivery model must not leak into domain.

Layer placement:

```text
domain:
  scan, cleanup, session, receipt entities and value objects

application:
  ports for scan/query/session/delete/export/capabilities

infrastructure:
  HTTP adapter
  WebSocket adapter
  static web bundle server
  CORS/PNA policy
  daemon discovery
  token store

presentation:
  Flutter pages, stores, connection doctor, route state
```

Forbidden dependencies:

- domain imports Axum, CORS, WebSocket, Flutter, browser, service worker, or token DTOs;
- use cases inspect browser headers directly;
- widgets perform filesystem or daemon discovery;
- web storage becomes source of truth for scan/delete authority.

### Connection Doctor Is A Product Adapter - `P1`

Users will see failures caused by CORS, PNA, daemon offline, stale service worker, browser policy, token expiry, and version mismatch. A generic network error is not enough.

Required diagnostic categories:

```text
daemon_unreachable
daemon_version_unsupported
ui_version_unsupported
auth_required
auth_expired
origin_not_allowed
private_network_blocked
local_network_permission_denied
service_worker_stale
websocket_blocked
websocket_closed
protocol_mismatch
browser_unsupported
```

Each category should map to a clear user-facing action and a structured support field.

## Testing Matrix

### Browser Policy Tests

Required before hosted UI beta:

- hosted HTTPS UI to local daemon;
- daemon-served HTTP loopback UI;
- `127.0.0.1`, `localhost`, and `::1`;
- unexpected Origin rejected;
- reflected Origin rejected;
- wildcard CORS absent;
- PNA preflight accepted only for allowed origin;
- PNA preflight rejected for unpaired origin;
- CORS failure categorized as origin/policy, not daemon offline;
- WebSocket Origin validation rejects untrusted origin.

### Cache And Version Tests

Required before public local web release:

- old UI bundle against new daemon;
- new UI bundle against old daemon;
- stale service worker if service worker exists;
- hard refresh;
- daemon port change after restart;
- browser tab from yesterday;
- asset cache headers verified;
- API responses not cached.

### Browser Lifecycle Tests

Required before public local web release:

- tab backgrounded during scan;
- laptop sleep/wake during scan;
- browser back/forward navigation with active WebSocket;
- `pagehide` closes socket;
- `pageshow` reconnects and queries state;
- daemon restart while tab is open;
- WebSocket reconnect after token expiry.

### Flutter Web Performance Tests

Required before large-tree beta:

- first load time for daemon-served UI;
- tree viewport memory at 10k, 100k, and 1M node scan snapshots through paginated query;
- CanvasKit memory while scrolling;
- large path names with bidi characters;
- hidden tab behavior;
- export job download without giant in-memory blob;
- service worker disabled/enabled variants if applicable.

### Security Tests

Required before any delete-capable web UI:

- malicious origin cannot query health beyond safe public fields;
- malicious origin cannot open WebSocket;
- missing token rejected;
- wrong token rejected;
- token in URL not accepted;
- token redacted from logs/support bundle;
- delete command rejected without plan confirmation token;
- plan confirmation token cannot be reused;
- same browser origin cannot access another daemon session without pairing.

## MVP Cut Line

MVP web runtime accepts:

- daemon-served local Flutter web UI;
- loopback-only random port;
- exact Host and Origin checks;
- no wildcard CORS;
- no production hosted UI unless pairing is implemented;
- no browser-only scanner;
- no offline-first service worker for daemon UI;
- HTTP queries and commands;
- WebSocket events with reconnect/resync;
- capability/version handshake before enabling destructive controls;
- browser storage limited to non-secret preferences;
- connection doctor with typed failure categories;
- CanvasKit baseline;
- paginated data only.

MVP defers:

- hosted public web UI;
- custom URL scheme launcher;
- service worker offline mode;
- Skwasm as required runtime;
- browser File System Access scanning;
- cross-origin isolated threaded rendering requirement;
- PWA install flow;
- enterprise browser policy automation.

## Summary

The safest local web architecture is:

```text
Rust daemon serves the web UI on loopback
  -> same-origin HTTP commands and queries
  -> same-origin WebSocket events
  -> explicit token/session proof
  -> capability/version handshake
  -> no browser-owned scan authority
```

Hosted web UI is useful later, especially for remote/headless mode, but it must be treated as a separate mode with pairing, origin policy, PNA/LNA support, and clearer target context.

📌 The browser is a hostile, cached, policy-changing UI runtime. Clean Disk should use it for interface portability, not for filesystem authority.
