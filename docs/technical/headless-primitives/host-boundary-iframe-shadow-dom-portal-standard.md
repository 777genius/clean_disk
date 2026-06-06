# Host Boundary Iframe Shadow DOM And Portal Standard

## Status

Accepted as a Headless web embedding and host integration standard. Not
implemented yet.

## Source Standards

- MDN iframe: https://developer.mozilla.org/docs/Web/HTML/Reference/Elements/iframe
- MDN Permissions Policy: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Permissions_Policy
- MDN Using shadow DOM: https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_shadow_DOM
- MDN ElementInternals: https://developer.mozilla.org/en-US/docs/Web/API/ElementInternals
- MDN postMessage: https://developer.mozilla.org/en-US/docs/Web/API/Window/postMessage
- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/

## Scope

This standard defines how Headless behaves when primitives are hosted inside
iframes, shadow roots, custom elements, portals, micro-frontends, or app shell
embedding boundaries.

It applies to:

- web DOM adapter;
- web ARIA bridge;
- overlay portals;
- dialogs and popovers;
- tooltip and status regions;
- context menus;
- Clean Disk daemon-served web UI if embedded later.

It does not require MVP Clean Disk to support third-party embedding. It defines
the boundary before the API makes embedding impossible.

## Decision Options

Option A: Assume app owns whole document - 🎯 5   🛡️ 4   🧠 2, about
100-250 LOC.

- Good enough for simple apps.
- Breaks public component adoption in docs sites, admin shells, iframes, and
  custom elements.

Option B: Document embedding as unsupported - 🎯 6   🛡️ 6   🧠 2, about
100-300 LOC.

- Honest.
- Too limiting for a community Headless library.

Option C: Explicit host boundary contract with capability probes - 🎯 9
🛡️ 8   🧠 8, about 1200-2600 LOC.

- Accepted direction.
- Components know what root, focus scope, portal host, and policy boundary they
  live in.
- Unsafe cross-boundary behavior fails closed.

## Accepted Direction

Headless should define `HostBoundaryContext`.

Context fields:

- document root;
- composed tree root;
- shadow root if any;
- iframe boundary if any;
- same-origin access;
- permissions policy facts;
- portal host;
- focus boundary;
- inert boundary;
- live region host;
- geometry root;
- security class.

## Boundary Types

Types:

- `documentRoot`;
- `shadowRoot`;
- `sameOriginIframe`;
- `crossOriginIframe`;
- `customElementHost`;
- `portalRoot`;
- `nativeWindow`;
- `unknownHost`.

Each type has different rules for focus, labels, live regions, portals,
geometry, and messaging.

## Focus Rules

Rules:

- do not assume `document.activeElement` is enough inside shadow roots;
- preserve logical focus inside component state;
- cross-iframe focus transfer requires explicit host integration;
- dialog focus trap is scoped to host boundary;
- Escape handling must not leak through unrelated host layers;
- focus return target must survive portal movement.

## Label And Relationship Rules

Rules:

- ARIA relationship ids may not cross document boundaries;
- shadow DOM labels need explicit strategy or ElementInternals support;
- portal content must preserve accessible name and description;
- tooltip ownership across roots is adapter-specific;
- `aria-controls` is not a substitute for unreachable relationship.

## Overlay Rules

Overlay primitives must resolve:

- placement root;
- clipping container;
- z-order policy;
- inert siblings;
- outside-click boundary;
- Escape priority;
- scroll lock authority;
- focus restoration.

For cross-origin iframes, Headless must not attempt to control parent document
inertness directly.

## Clean Disk Requirements

MVP Clean Disk:

- daemon-served web UI may assume document-root ownership.

Future embedded Clean Disk:

- remote read-only dashboard may be iframe-hosted;
- destructive cleanup must require same-origin or trusted host integration;
- support bundle screenshots must record host boundary class;
- local daemon token must never be exposed through cross-origin messages.

## API Shape Sketch

```text
HostBoundaryContext
  boundaryType
  rootRef
  portalHost
  focusBoundary
  inertAuthority
  liveRegionHost
  geometryRoot
  sameOrigin
  permissionsPolicy
```

## Conformance Scenarios

Required scenarios:

- dialog opens inside shadow root and returns focus to trigger;
- tooltip label strategy works with custom element host;
- same-origin iframe can host status region;
- cross-origin iframe blocks destructive command integration;
- portal menu does not escape inert boundary;
- Escape closes innermost overlay only.

## Failure Catalog

Failures:

- overlay portal goes to top document and breaks embedded app;
- `aria-labelledby` references element outside reachable root;
- focus return fails because trigger was in shadow root;
- cross-origin iframe receives raw daemon token;
- parent page shortcuts close child dialog;
- status region mounted outside screen reader reachable host.

## Release Gates

Release gate:

- each web adapter declares supported host boundaries;
- unsupported boundaries expose degraded capability;
- destructive flows require trusted boundary;
- public examples include shadow-root and iframe notes;
- host boundary facts appear in conformance evidence.

