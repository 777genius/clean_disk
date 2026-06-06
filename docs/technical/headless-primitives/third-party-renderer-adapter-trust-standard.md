# Third Party Renderer Adapter Trust Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN Web Components: https://developer.mozilla.org/en-US/docs/Web/API/Web_components
- MDN Using custom elements: https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_custom_elements
- MDN Using shadow DOM: https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_shadow_DOM
- MDN `ElementInternals`: https://developer.mozilla.org/en-US/docs/Web/API/ElementInternals
- MDN Content Security Policy: https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/

## Scope

This standard defines how Headless accepts third-party renderers, adapters,
themes, and extension packages without losing accessibility, security,
privacy, or command authority.

It applies to:

- Material renderer adapters;
- Cupertino renderer adapters;
- web DOM adapters;
- Web Component adapters;
- chart adapters;
- disk usage map adapters;
- test adapters;
- community extension packages.

It does not define package publishing. It defines trust and capability
contracts.

## Decision Options

Option A: Trust any renderer that implements methods - 🎯 3   🛡️ 3
🧠 2, about 100-250 LOC.

- Easy for ecosystem growth.
- Lets renderers bypass focus, semantics, privacy, and command rules.

Option B: Only official renderers - 🎯 6   🛡️ 8   🧠 4, about 250-600 LOC.

- Safer.
- Limits community value and blocks project-specific renderers.

Option C: Capability-declared adapters with conformance gates - 🎯 9
🛡️ 9   🧠 8, about 1000-2400 LOC.

- Accepted direction.
- Third-party renderers can exist, but must declare capability and pass tests.
- Critical behavior stays in Headless, not renderer.

## Accepted Direction

Headless must treat renderers as adapters with declared trust level.

Trust levels:

- `official`;
- `verifiedCommunity`;
- `experimental`;
- `localApp`;
- `testOnly`;
- `untrusted`.

Capability is separate from trust.

## Renderer Must Not Own

Renderer must not own:

- command dispatch authority;
- destructive action policy;
- focus state machine;
- selection state;
- keyboard navigation model;
- accessibility role contract;
- privacy redaction;
- stable ids;
- persisted state migration;
- telemetry export.

Renderer can own:

- visual layout inside contract;
- paint;
- animation details within motion policy;
- hit target visuals within target-size policy;
- platform projection;
- theme mapping.

## Capability Declaration

Renderer declares:

- primitive support;
- role support;
- keyboard support level;
- focus ring support;
- reduced motion support;
- high contrast support;
- text scaling support;
- RTL support;
- virtualization support;
- live announcement support;
- test coverage level;
- known degraded behaviors.

Missing critical capability must fail closed or downgrade feature.

## Web Component And Shadow DOM Rules

If adapter uses Web Components:

- accessibility semantics must cross shadow boundary correctly;
- labels and descriptions must work;
- focus delegation must be explicit;
- internal ids must not leak product data;
- slots must not bypass content trust policy;
- ElementInternals can expose semantics where supported;
- fallback must exist where ElementInternals is missing.

Shadow DOM is encapsulation, not automatic safety.

## Security Rules

Renderer package must not:

- execute untrusted markup;
- install global event listeners without scope;
- intercept shortcuts outside registered scope;
- send telemetry by default;
- read clipboard without app command;
- expose raw paths through DOM attributes;
- bypass CSP or Trusted Types policies.

App may impose stricter policy for community adapters.

## Clean Disk Requirements

Clean Disk will use:

- app design system wrapper;
- Headless primitives;
- optional chart or disk map renderer adapters;
- possibly custom TreeGrid renderer later.

Rules:

- Syncfusion or any chart adapter stays behind `DiskUsageMapView`;
- third-party renderer cannot become cleanup authority;
- renderer capability gaps must be visible in diagnostics;
- unverified renderer cannot enable destructive shortcut paths.

## API Shape Sketch

```text
RendererAdapterManifest
  packageId
  trustLevel
  supportedPrimitives
  capabilities
  conformanceReport
  knownDegradations
  privacyPolicy

RendererGate
  validate(manifest)
  requireCapability(capability)
  downgrade(reason)
```

## Conformance Scenarios

- renderer without high contrast support is marked degraded;
- renderer cannot dispatch command without router;
- web component label works across shadow boundary or fails conformance;
- chart adapter exposes data table fallback;
- untrusted renderer cannot emit telemetry by default;
- missing reduced-motion support disables animation adapter;
- conformance report lists screen reader scenarios;
- raw path never appears in renderer DOM attributes.

## Failure Catalog

- renderer owns keyboard navigation;
- renderer bypasses command router;
- community adapter claims support without conformance evidence;
- Shadow DOM breaks label relationship;
- renderer leaks raw path into attribute;
- chart adapter has no accessible fallback;
- global shortcut listener installed by renderer;
- telemetry sent from adapter without app consent;
- missing capability treated as supported;
- official renderer and community renderer expose different semantics.

