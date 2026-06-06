# Multi Window And Session Scope Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN Page Visibility API: https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API
- MDN Web Storage API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Storage_API
- MDN History API: https://developer.mozilla.org/en-US/docs/Web/API/History_API
- MDN `beforeunload`: https://developer.mozilla.org/en-US/docs/Web/API/Window/beforeunload_event
- Flutter focus system: https://docs.flutter.dev/ui/interactivity/focus
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility

## Scope

This standard defines how Headless primitives classify and isolate state across
windows, tabs, sessions, routes, and app instances.

It applies to:

- desktop multiple windows;
- browser multiple tabs;
- daemon-backed local web UI;
- app restart;
- saved layout preferences;
- temporary selection;
- virtualized row cache;
- command history;
- overlay stacks;
- scanner session views;
- remote or headless read-only clients.

It does not define app persistence storage. It defines scope contracts that app
storage adapters must honor.

## Decision Options

Option A: Everything global app state - 🎯 3   🛡️ 3   🧠 2, about
100-250 LOC.

- Very simple.
- Multi-window bugs appear immediately.
- Unsafe for destructive workflows.

Option B: Everything window-local - 🎯 5   🛡️ 5   🧠 4, about 300-700 LOC.

- Safer for local UI.
- Preferences and shared scan sessions become inconsistent.
- Multi-client daemon events need reconciliation anyway.

Option C: Typed state scopes with explicit promotion rules - 🎯 9   🛡️ 9
🧠 7, about 900-1800 LOC.

- Accepted direction.
- Every state value declares scope and authority.
- Fits desktop, web, daemon, and remote/headless.

## Accepted Direction

Headless must classify component state by scope:

- `ephemeral`: current widget instance only.
- `focusScope`: current focus tree.
- `routeLocal`: current route instance.
- `windowLocal`: current desktop window or browser tab.
- `sessionLocal`: current app session.
- `userPreference`: persisted preference.
- `snapshotScoped`: tied to scan or data snapshot.
- `operationScoped`: tied to operation id.
- `sharedLive`: reconciled from daemon or shared source.
- `policyScoped`: controlled by app or security policy.

Promotion from one scope to another must be explicit.

## State Scope Examples

Ephemeral:

- hover;
- press;
- open animation progress;
- pointer capture;
- IME composition buffer.

Focus scope:

- roving focus index;
- active descendant;
- focus-visible modality.

Route local:

- local expanded sections;
- temporary filter input;
- open details tab.

Window local:

- split pane size;
- selected row in current window;
- current command palette query;
- undo stack.

Session local:

- active scan session view;
- reconnect state;
- transient diagnostics panel.

User preference:

- theme;
- density;
- column visibility preference;
- language;
- reduced motion override.

Snapshot scoped:

- expanded tree nodes;
- selected scan node;
- query result cursor;
- disk usage map projection.

Operation scoped:

- cleanup receipt view;
- progress log;
- cancellation state;
- operation result.

Shared live:

- daemon capability;
- scan session status;
- operation status;
- compatibility state.

Policy scoped:

- destructive action authorization;
- redaction policy;
- remote access policy;
- telemetry consent.

## Multi-Window Rules

Each window must have:

- window id;
- route state;
- focus state;
- selection state;
- overlay stack;
- undo stack;
- viewport anchors.

Shared state must be reconciled through application ports, not through direct
component references.

Headless components must not assume a singleton root.

## Browser Tab Rules

Browser tabs should be treated like window-local sessions unless app policy
declares shared state.

Rules:

- `localStorage` is not a safe command bus;
- `sessionStorage` maps better to tab-local state but still needs policy;
- BroadcastChannel or app-level event mechanisms are adapters, not Headless
  dependencies;
- history state must not contain secrets;
- visibility changes can pause non-essential updates.

## Daemon Session Rules

For Clean Disk local web UI:

- daemon session token is app infrastructure state, not Headless state;
- Headless may display disconnected or stale UI state;
- Headless must not persist token in ordinary component state;
- multiple windows can observe the same daemon scan session;
- destructive actions require current authority in the active window.

## Authority Rules

State scope is not authority.

Examples:

- selected row is not delete authority;
- queue item is not delete authority;
- restored route is not delete authority;
- historical snapshot is not delete authority;
- operation receipt is not undo unless restore capability exists.

Headless must label scopes clearly so app layers can enforce authority.

## Lifecycle Rules

On window open:

- create window-local scope;
- hydrate safe preferences;
- restore route if allowed;
- probe shared capabilities through app ports.

On window close:

- dispose focus and overlay state;
- persist allowed preferences;
- do not persist destructive confirmation;
- keep daemon operation state in daemon or app persistence, not Headless.

On visibility hidden:

- pause decorative motion;
- throttle non-essential UI updates;
- keep operation subscriptions as app policy decides;
- save recoverable view state.

## Clean Disk Requirements

Clean Disk must scope:

- selected node: window-local plus snapshot-scoped;
- expanded nodes: snapshot-scoped with optional window-local view;
- scan status: shared live;
- delete queue: window-local until app promotes it;
- delete plan: operation-scoped and validation-scoped;
- cleanup receipt: operation-scoped;
- theme: user preference;
- daemon compatibility: shared live;
- daemon token: infrastructure secret outside Headless.

## API Shape Sketch

```text
HeadlessScope
  id
  kind
  parent
  lifecycle
  dispose()

ScopedState<T>
  scopeKind
  ownerId
  value
  version
  authorityClass
  persistencePolicy

ScopeRegistry
  createScope(kind)
  promote(value, targetScope)
  invalidate(scopeId, reason)
```

## Conformance Scenarios

- two windows can focus different rows in the same scan;
- theme preference updates both windows;
- undo in one window does not undo another window's local command;
- daemon scan status updates all observing windows;
- delete confirmation does not survive window close;
- browser back restores route but not daemon token;
- visibility hidden pauses decorative animation;
- snapshot-scoped expanded nodes invalidate when snapshot changes.

## Failure Catalog

- singleton focus manager shared by all windows;
- localStorage used for destructive command state;
- selected row shared globally across windows;
- delete confirmation restored after restart;
- daemon token stored in route or component state;
- user preference treated as operation authority;
- stale snapshot state applied to new scan;
- overlay stack leaking between tabs;
- window close losing operation receipt;
- hidden tab consuming full UI update budget.

