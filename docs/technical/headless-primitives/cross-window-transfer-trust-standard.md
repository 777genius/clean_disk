# Cross Window Transfer And Trust Standard

## Status

Accepted as a Headless runtime interoperability standard. Not implemented yet.

## Source Standards

- MDN Broadcast Channel API: https://developer.mozilla.org/en-US/docs/Web/API/Broadcast_Channel_API
- MDN MessageChannel: https://developer.mozilla.org/en-US/docs/Web/API/MessageChannel
- MDN Window `postMessage`: https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage
- MDN Web Storage API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Storage_API
- MDN Clipboard API: https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API
- WCAG 3.2.3 Consistent Navigation: https://www.w3.org/WAI/WCAG22/Understanding/consistent-navigation.html
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/

## Scope

This standard defines how Headless treats state and data moving between
windows, tabs, iframes, and app instances.

It applies to:

- multi-window desktop apps;
- browser tabs;
- daemon-served web UI;
- clipboard transfer;
- drag between windows;
- broadcast state updates;
- route state sharing;
- command synchronization.

It does not define the transport. It defines trust downgrade and authority
boundaries.

## Decision Options

Option A: Share state globally - 🎯 3   🛡️ 3   🧠 2, about 100-300 LOC.

- Simple.
- Selection, focus, and destructive state leak between windows.

Option B: Window-local only - 🎯 6   🛡️ 6   🧠 4, about 300-800 LOC.

- Safer.
- Misses useful shared status and multi-window scan observation.

Option C: Cross-window trust envelopes - 🎯 9   🛡️ 9   🧠 7, about
900-1800 LOC.

- Accepted direction.
- Shared facts carry source, target, trust, expiry, and authority class.

## Accepted Direction

Headless should represent cross-window data as `CrossWindowEnvelope`.

Envelope includes:

- source window id;
- target scope;
- message kind;
- payload ref;
- trust level;
- authority class;
- privacy class;
- version;
- expiry;
- correlation id.

## Trust Rules

Cross-window transfer downgrades authority by default.

Examples:

- selected row in window A can be displayed in window B only if app permits;
- delete queue in one window is not automatically confirmed in another;
- clipboard data from another window is external unless signed by app envelope;
- route state is read-only until validated;
- daemon status can be shared as live fact.

## Transport Rules

Transport choices:

- BroadcastChannel;
- postMessage;
- MessageChannel;
- native desktop channel;
- daemon event stream;
- storage event;
- clipboard.

Headless does not depend on any one transport. Adapter maps transport to
trusted envelope facts.

## Focus And Selection Rules

Focus is window-local.

Selection can be:

- window-local;
- shared read-only;
- shared collaborative;
- operation-scoped.

Destructive selection must not silently become operation authority in another
window.

## Clean Disk Requirements

Clean Disk multi-window facts:

- scan session status can be shared;
- daemon compatibility can be shared;
- selected row is window-local;
- delete queue is window-local unless app explicitly promotes it;
- delete plan validation is operation-scoped;
- receipt can be viewed in another window by operation id.

Rules:

- cross-window cleanup requires current validation in active window.
- daemon token is never in Headless envelope.
- raw paths are redacted unless policy allows.

## API Shape Sketch

```text
CrossWindowEnvelope
  sourceWindow
  targetScope
  kind
  payloadRef
  trustLevel
  authorityClass
  privacyClass
  version
  expiresAt

CrossWindowPolicy
  canReceive(envelope)
  downgrade(envelope)
  validate(envelope, context)
```

## Conformance Scenarios

- two windows can focus different rows;
- shared scan status updates both windows;
- delete confirmation does not transfer;
- clipboard row ref loses cleanup authority;
- stale envelope is rejected;
- postMessage origin or equivalent source is checked by adapter;
- receipt ref can open read-only receipt;
- raw path is not included by default.

## Failure Catalog

- global selected row changes in every window;
- delete queue copied as confirmed delete plan;
- cross-tab message accepted without source validation;
- clipboard internal payload treated as trusted forever;
- daemon token in shared state;
- focus state broadcast to another window;
- stale route state treated as current authority;
- no version on envelope;
- storage event used as command bus;
- support snapshot leaks raw path across windows.

