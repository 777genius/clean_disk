# Local Daemon Network Access Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN CORS guide: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS
- MDN preflight request: https://developer.mozilla.org/en-US/docs/Glossary/Preflight_request
- Chrome Private Network Access preflights: https://developer.chrome.com/blog/private-network-access-preflight/
- WICG Private Network Access: https://wicg.github.io/private-network-access/
- WICG Local Network Access: https://wicg.github.io/local-network-access/
- MDN secure contexts: https://developer.mozilla.org/en-US/docs/Web/Security/Secure_Contexts
- MDN WebSocket API: https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/

## Problem

Hosted web pages that talk to localhost, loopback daemons, or private network
devices cross a sensitive browser security boundary. Browsers continue to evolve
Private Network Access and Local Network Access protections because public sites
can otherwise attack routers, local services, and device admin panels. Clean
Disk explicitly considers daemon-served web UI, so this boundary must be
designed before product UI depends on it.

## Decision Options

1. Let any web UI connect to localhost daemon with CORS - 🎯 2   🛡️ 2
   🧠 2, about 80-160 LOC. Unsafe.
2. Prefer daemon-served loopback UI and treat hosted-to-local as a separate
   paired capability - 🎯 10   🛡️ 10   🧠 6, about 450-1000 LOC. Best fit.
3. Ban all web-to-daemon access - 🎯 6   🛡️ 9   🧠 2, about 0-80 LOC. Safe, but
   blocks remote/headless UI options.

Accepted: option 2.

## Accepted Contract

Headless exposes local service connection facts:

```dart
final class RLocalServiceConnection {
  final Uri serviceOrigin;
  final RLocalServiceTrustLevel trustLevel;
  final bool sameOriginServedByDaemon;
  final bool usesLoopback;
  final bool usesPrivateNetwork;
  final bool requiresPairingToken;
  final bool blockedByBrowserNetworkPolicy;
  final RConnectionCapability capability;
}
```

This is a UI capability contract. The daemon owns auth and transport.

## Rules

- Daemon-served UI is the default local web path.
- Hosted public UI cannot control local daemon without explicit pairing and
  origin allowlist.
- Local daemon accepts only allowed origins and current tokens.
- WebSocket and HTTP share the same authority model.
- Browser local network denial is shown as a distinct repair state.
- CORS success is not authentication.
- Private network or localhost access is never silently retried in loops.
- Tokens are never placed in URLs, routes, screenshots, or support bundles.

## Clean Disk Requirements

Clean Disk MVP should use:

- daemon-served loopback UI for web surface;
- random local port or stable broker with strict token;
- origin allowlist;
- no hosted website connecting to local daemon by default;
- clear disconnected, blocked, denied, and incompatible states.

Hosted pairing can be a future adapter with explicit threat model.

## State Model

```text
notConfigured:
  no daemon target selected

discovering:
  looking for local daemon without authority

pairingRequired:
  daemon found but no valid token

connected:
  token and origin accepted

browserBlocked:
  browser local/private network policy blocks connection

daemonDenied:
  daemon rejected origin, token, or capability

stale:
  connected session no longer matches daemon version or capability
```

## Testing Requirements

- Same-origin daemon-served UI succeeds.
- Hosted origin cannot connect without pairing.
- Token in URL fails test.
- WebSocket reconnect does not bypass auth.
- Browser-blocked state is distinguishable from daemon offline.
- Support bundle redacts origin token and port when configured as sensitive.

## Failure Catalog

- Public website can scan local disk through localhost daemon.
- CORS allow-all is used for development and ships.
- WebSocket reconnect reuses expired token.
- Browser local network prompt is shown with no explanation.
- Connection failure says "offline" when browser blocked local network access.
- Daemon token appears in route or logs.

## Release Gates

- Local daemon UI chooses same-origin loopback by default.
- Hosted-to-local mode requires separate security review.
- Every connection state has user-facing recovery copy.
- Destructive commands require capability and current authenticated session.

## Summary

Local daemon access is a browser security boundary. Headless should model it as
explicit connection capability, while Clean Disk defaults to daemon-served
loopback UI.
