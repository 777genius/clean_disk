# Degraded Offline And Partial Availability Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN online and offline events: https://developer.mozilla.org/en-US/docs/Web/API/Window/online_event
- MDN offline event: https://developer.mozilla.org/en-US/docs/Web/API/Window/offline_event
- MDN Page Visibility API: https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API
- MDN Progressive web apps offline operation: https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Offline_and_background_operation
- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

## Scope

This standard defines how Headless primitives represent disconnected, stale,
partial, degraded, offline, reconnecting, and incompatible states.

It applies to:

- daemon-backed UI;
- remote or local web app shell;
- async lists and virtualized grids;
- charts;
- command surfaces;
- forms;
- exports;
- cleanup workflows;
- support diagnostics.

It does not decide network policy. It defines UI state contracts when a data or
capability source is not fully available.

## Decision Options

Option A: Treat degraded as generic error - 🎯 4   🛡️ 4   🧠 2, about
100-250 LOC.

- Simple.
- Hides whether data is stale, partial, denied, disconnected, or retrying.

Option B: App-specific banners and disabled controls - 🎯 5   🛡️ 5   🧠 4,
about 300-800 LOC.

- Flexible.
- Headless components still need consistent stale and partial behavior.

Option C: Typed availability state across primitives - 🎯 9   🛡️ 9   🧠 7,
about 900-1700 LOC.

- Accepted direction.
- Availability state travels with data, command surfaces, and visible regions.
- Risky actions fail closed.

## Accepted Direction

Headless must model availability as a first-class state:

- `ready`;
- `loading`;
- `refreshing`;
- `stale`;
- `partial`;
- `degraded`;
- `offline`;
- `disconnected`;
- `reconnecting`;
- `incompatible`;
- `permissionLimited`;
- `unknown`;
- `failed`.

Each state must include:

- reason;
- data freshness;
- retry policy;
- user action availability;
- visible message policy;
- announcement policy;
- authority impact.

## Availability Is Not Error

Examples:

- stale scan snapshot can be viewed read-only;
- disconnected daemon can show cached rows but not delete;
- partial scan can show scanned subtrees with caveat;
- permission-limited scan can show accessible folders and repair action;
- incompatible daemon can block commands but show upgrade message;
- offline hosted UI cannot access local daemon unless paired and reachable.

## Data Freshness Rules

Data surfaces should carry:

- freshness state;
- source id;
- snapshot id;
- last updated time;
- query version;
- capability version;
- stale reason;
- safe actions.

Rules:

- stale data may be visible;
- stale data must not be cleanup authority;
- partial data must display what is missing when known;
- refresh failure must not silently preserve old state as current.

## Command Availability Rules

Commands must resolve against availability:

- read-only commands can remain active on stale data if safe;
- destructive commands disable on stale, unknown, disconnected, incompatible,
  or permission-limited authority;
- export can run on historical data if labeled;
- retry and repair commands should remain available;
- shortcuts must obey same availability as buttons.

## Reconnect Rules

When connection returns:

- do not auto-run destructive commands;
- refresh capability facts;
- reconcile visible state;
- mark stale views until refreshed;
- preserve user selection only if identity still matches;
- announce meaningful status change once.

## Offline Signal Rules

Browser online/offline signals are hints, not full truth.

Headless should treat:

- browser offline as strong degraded signal;
- browser online as not sufficient proof of daemon reachability;
- page hidden as reason to throttle non-essential updates;
- local daemon heartbeat as app adapter responsibility.

## Clean Disk Requirements

Clean Disk states:

- daemon disconnected;
- daemon restarting;
- protocol incompatible;
- scan partial due to permissions;
- scan cancelled;
- cached snapshot read-only;
- delete plan stale;
- Trash capability unavailable;
- remote mode read-only;
- web UI cannot reach local daemon.

Safety rule:

- if availability is unknown, destructive action is disabled.

## API Shape Sketch

```text
AvailabilityState
  kind
  reasonCode
  freshness
  sourceId
  snapshotId
  capabilityVersion
  safeActions
  authorityImpact

AvailabilityResolver
  resolveData(surface)
  resolveCommand(command, state)
  publishChange(state)
```

## Conformance Scenarios

- cached tree stays visible after daemon disconnect but delete is disabled;
- reconnect updates capability and marks stale data until refreshed;
- partial scan shows permission-limited state, not empty state;
- shortcut cannot execute disabled destructive command;
- offline browser state does not claim daemon is reachable;
- incompatible protocol blocks risky actions;
- export of historical snapshot is labeled historical;
- one reconnect announcement is emitted, not a loop.

## Failure Catalog

- stale data displayed as current;
- disconnected state hidden behind spinner forever;
- destructive action enabled on cached data;
- partial scan shown as complete;
- permission denial shown as empty folder;
- browser online treated as daemon available;
- reconnect reruns pending destructive action;
- shortcut bypasses availability gate;
- repeated reconnect announcements;
- no visible stale marker on cached view.

