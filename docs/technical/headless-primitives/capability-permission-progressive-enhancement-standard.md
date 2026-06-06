# Capability Permission And Progressive Enhancement Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN Permissions API: https://developer.mozilla.org/en-US/docs/Web/API/Permissions_API
- MDN Permissions Policy: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Permissions_Policy
- MDN File API: https://developer.mozilla.org/en-US/docs/Web/API/File_API
- MDN Clipboard API: https://developer.mozilla.org/docs/Web/API/Clipboard_API
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

## Scope

This standard defines how Headless primitives represent platform capabilities,
permissions, unavailable features, repair actions, and progressive enhancement.

It applies to:

- clipboard;
- file picker and dropzone;
- drag and drop;
- native reveal actions;
- print and export;
- notifications;
- screen reader semantics capability;
- web, desktop, mobile, and embedded renderers;
- daemon-backed features in Clean Disk.

It does not own real permissions. It owns user-facing capability state and
component behavior when features are absent.

## Decision Options

Option A: Feature flags as booleans - 🎯 4   🛡️ 4   🧠 2, about
100-250 LOC.

- Easy.
- Loses reasons, repair actions, policy state, and platform distinction.

Option B: App handles all missing capability UI - 🎯 5   🛡️ 5   🧠 4,
about 300-700 LOC.

- Flexible.
- Public Headless components still need consistent disabled, hidden, and
  degraded behavior.

Option C: Typed capability facts and progressive enhancement states - 🎯 9
🛡️ 9   🧠 7, about 900-1700 LOC.

- Accepted direction.
- Headless knows whether a primitive action is supported, denied, restricted,
  policy-blocked, or unknown.
- App adapters provide real platform probes and repair commands.

## Accepted Direction

Headless must expose a capability model:

- capability id;
- support status;
- permission status;
- policy status;
- user repair path;
- fallback behavior;
- privacy class;
- test capability.

Primitives consume capability facts. They do not probe browser, OS, daemon, or
plugin APIs directly.

## Capability Status

Statuses:

- `supported`: available and ready.
- `unsupported`: platform does not provide this capability.
- `unknown`: adapter has not probed or result expired.
- `denied`: user or platform denied access.
- `promptable`: user can be asked.
- `policyBlocked`: app, enterprise, browser policy, or sandbox blocks access.
- `temporarilyUnavailable`: transient failure.
- `degraded`: available but incomplete or lower fidelity.
- `requiresNativeHost`: web UI needs local daemon or host bridge.
- `requiresTrust`: action needs signed host, pairing, or stronger authority.

## Permission Versus Capability

Capability is not permission.

Examples:

- browser may support Clipboard API but permission is denied;
- file picker may exist but app policy disallows raw path display;
- native reveal may exist on desktop but not web;
- Clean Disk daemon may support scan but not cleanup in remote mode;
- screen reader semantics may be enabled but a renderer cannot expose a
  specific ARIA pattern.

The model must keep these facts separate.

## Progressive Enhancement Rules

When capability is missing:

- hide only if the feature is optional and not central;
- disable with reason if user can benefit from knowing it exists;
- show repair action if user can fix it;
- show degraded path if an alternative exists;
- fail closed for destructive actions;
- avoid fake controls that look available.

Headless primitive must expose:

- action availability;
- disabled reason;
- repair command descriptor;
- fallback command descriptor;
- learn-more link key where app chooses to provide it.

## Prompt Rules

Headless must not trigger sensitive permission prompts on render.

Prompt may happen only:

- in response to clear user intent;
- through app adapter;
- with visible context;
- with recovery path for denial;
- with no hidden repeated prompt loop.

Clean Disk examples:

- choosing "Custom Folder" may open a picker;
- repair Full Disk Access is a platform workflow, not a Headless prompt;
- copy path can ask for clipboard if platform needs it;
- remote cleanup cannot prompt browser into having filesystem authority.

## Capability Invalidation

Capability facts expire when:

- app resumes;
- daemon reconnects;
- renderer changes;
- platform permission changes;
- user switches browser tab or window;
- enterprise policy changes;
- extension adapter changes;
- app updates.

Headless must support capability change events and re-render affected actions
without losing focus.

## Clean Disk Requirements

Clean Disk capability facts:

- scan target available;
- Full Disk Access quality;
- metadata enrichment available;
- Trash adapter available;
- native reveal available;
- export available;
- daemon reachable;
- cleanup allowed in current mode;
- remote read-only or destructive policy;
- disk map renderer capability.

Safety rule:

- unknown capability disables risky actions.
- cleanup requires current capability and current validated plan.

## API Shape Sketch

```text
CapabilityFact
  id
  support
  permission
  policy
  quality
  reasonCode
  repairAction
  fallbackAction
  privacyClass
  expiresAt

CapabilityRegistry
  get(id)
  watch(scope)
  invalidate(id, reason)
```

## Conformance Scenarios

- unavailable clipboard shows disabled reason or fallback;
- denied file access does not render as empty state;
- promptable capability prompts only after user action;
- capability change preserves keyboard focus;
- unknown cleanup capability disables move-to-trash;
- web UI marks scan as requiring daemon host;
- policy-blocked action cannot be triggered by shortcut;
- degraded renderer publishes capability level.

## Failure Catalog

- boolean feature flag hiding real denial reason;
- prompting on page load;
- shortcut bypassing disabled UI;
- unsupported feature silently doing nothing;
- unknown capability treated as supported;
- permission denial shown as "No data";
- repair action controlled by renderer instead of app adapter;
- stale capability after daemon reconnect;
- destructive action enabled in degraded authority state;
- capability state stored in localized labels.

