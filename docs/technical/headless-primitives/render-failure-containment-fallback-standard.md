# Render Failure Containment And Fallback Standard

## Status

Accepted as a Headless quality-operations standard. Not implemented yet.

## Source Standards

- MDN CSS error handling: https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Syntax/Error_handling
- MDN Web Components: https://developer.mozilla.org/en-US/docs/Web/API/Web_components
- MDN Using custom elements: https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_custom_elements
- MDN Reporting API: https://developer.mozilla.org/en-US/docs/Web/API/Reporting_API
- Flutter error handling: https://docs.flutter.dev/testing/errors
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html

## Scope

This standard defines how Headless and renderer adapters contain rendering
failures without breaking the full app or lying about user state.

It applies to:

- third-party renderers;
- chart adapters;
- virtualized rows;
- custom cell renderers;
- overlays;
- dialogs;
- theming failures;
- token resolution failures;
- web component failures;
- Flutter widget build failures.

It does not hide product errors. It makes failures bounded, observable, and
safe.

## Decision Options

Option A: Let renderer exception crash surface - 🎯 4   🛡️ 4   🧠 2, about
100-250 LOC.

- Honest.
- Poor user experience and hard to recover in large apps.

Option B: Catch and show generic fallback - 🎯 6   🛡️ 6   🧠 4, about
300-800 LOC.

- Better.
- Can hide semantic state and lose command safety.

Option C: Structured render boundary with semantic fallback - 🎯 9   🛡️ 9
🧠 7, about 900-1800 LOC.

- Accepted direction.
- Fallback preserves safe semantics and disables risky commands.
- Diagnostics are redacted and actionable.

## Accepted Direction

Headless should define render boundaries for adapter-owned visuals.

Boundary captures:

- primitive ref;
- adapter id;
- renderer part;
- failure class;
- fallback state;
- safe commands;
- semantic fallback;
- diagnostic code;
- privacy-safe context.

## Failure Classes

Classes:

- `rendererBuildError`;
- `tokenResolutionError`;
- `layoutConstraintError`;
- `semanticProjectionError`;
- `chartRendererError`;
- `slotContractViolation`;
- `webComponentUpgradeError`;
- `adapterCapabilityMissing`;
- `unknown`.

Each class maps to fallback behavior.

## Fallback Rules

Fallback must:

- preserve accessible name where possible;
- expose error state;
- keep focus recoverable;
- disable unsafe commands;
- show retry or report action where appropriate;
- avoid raw error detail in production;
- not trap keyboard focus.

If fallback cannot preserve essential semantics, component is degraded or
blocked.

## Diagnostics Rules

Diagnostics include:

- stable error code;
- primitive type;
- adapter id;
- renderer part;
- safe stack hash if allowed;
- version;
- scenario id if from test.

Diagnostics exclude:

- raw paths;
- raw queries;
- secrets;
- clipboard contents;
- full user labels by default.

## Clean Disk Requirements

Clean Disk render fallback:

- disk map renderer failure falls back to table summary;
- TreeGrid cell renderer failure shows safe text cell;
- details chart failure does not disable delete safety model;
- cleanup confirmation renderer failure blocks destructive command;
- progress footer failure shows plain status.

Rules:

- renderer error cannot bypass command router.
- fallback does not claim cleanup is safe.
- support bundle redacts render diagnostics.

## API Shape Sketch

```text
RenderBoundary
  ownerRef
  adapterId
  part
  onError(error)
  fallback(policy)

RenderFailure
  code
  class
  primitive
  adapter
  severity
  privacySafeContext
```

## Conformance Scenarios

- chart adapter failure shows accessible table fallback;
- custom cell renderer failure preserves row selection state;
- cleanup confirmation renderer failure blocks move-to-trash;
- token error reports stable code and uses safe default;
- focus moves to safe fallback target;
- raw path absent from render error diagnostics;
- third-party renderer failure does not crash whole app;
- fallback state appears in semantic snapshot.

## Failure Catalog

- renderer exception crashes full route;
- fallback is visual-only with no semantics;
- destructive button remains enabled after renderer error;
- raw error detail leaks user path;
- focus trapped in failed overlay;
- chart failure removes all data access;
- token failure creates invisible text;
- web component upgrade failure goes silent;
- support cannot map error to renderer version;
- fallback hides adapter capability gap.

