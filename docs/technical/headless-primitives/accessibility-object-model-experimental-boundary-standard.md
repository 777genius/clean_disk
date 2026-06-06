# Accessibility Object Model Experimental Boundary Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- Accessibility Object Model explainer: https://wicg.github.io/aom/explainer.html
- WAI-ARIA: https://www.w3.org/TR/wai-aria/
- ARIA in HTML: https://www.w3.org/TR/html-aria/
- Using ARIA: https://www.w3.org/TR/using-aria/
- MDN ARIA reference: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference
- MDN browser compatibility data: https://github.com/mdn/browser-compat-data

## Problem

The Accessibility Object Model explores JavaScript APIs for accessibility
semantics beyond markup. It can be useful for future web adapters, custom
renderers, canvas-like surfaces, and virtualized components. But it is not a
stable public dependency for Headless primitives. If Headless bakes experimental
AOM assumptions into its core API, it risks browser lock-in and broken
accessibility.

## Decision Options

1. Ignore AOM until it becomes stable - 🎯 7   🛡️ 7   🧠 2, about 0-60 LOC.
   Safe but may block future renderer work.
2. Add an experimental adapter boundary - 🎯 9   🛡️ 9   🧠 5, about 250-650
   LOC. Best fit because it allows exploration without core dependency.
3. Build Headless web semantics on AOM first - 🎯 3   🛡️ 3   🧠 8, about
   900-1800 LOC. Too risky.

Accepted: option 2.

## Accepted Contract

Headless defines an experimental web semantic capability:

```dart
final class RAomAdapterCapability {
  final String browserFamily;
  final String browserVersionRange;
  final Set<RAomFeature> features;
  final bool enabledByDefault;
  final bool requiresFlag;
  final RStabilityLevel stabilityLevel;
  final Set<RFallbackPath> fallbackPaths;
}
```

The normal web adapter remains HTML and ARIA first.

## Boundary Rules

- Core primitives do not import or require AOM APIs.
- AOM adapters are optional and feature-gated.
- AOM use must have HTML/ARIA fallback unless the primitive is explicitly
  experimental.
- AOM capability is detected at runtime and recorded in evidence.
- Conformance cannot rely only on AOM when claiming broad web support.
- Browser-specific AOM behavior is documented as an adapter limitation.

## Clean Disk Requirements

Clean Disk does not need AOM for MVP.

Possible future uses:

- richer accessibility for canvas-like treemap renderers;
- virtualized accessibility projection experiments;
- custom web renderer research;
- diagnostics comparing intended semantics to browser-exposed semantics.

All of these stay behind renderer or adapter boundaries.

## Stability Levels

```text
stable:
  safe for production dependency

available:
  works in claimed browsers without user flags but remains adapter-scoped

experimental:
  requires flags, origin trials, or limited browser support

research:
  used only in tests, labs, or prototypes
```

Only stable and available can be considered for production adapters.

## Testing Requirements

- Feature detection tests per browser family.
- Fallback tests with AOM unavailable.
- Accessibility tree comparison between AOM and HTML/ARIA paths.
- Browser compatibility record attached to release evidence.
- No production test may require browser flags unless the adapter is marked
  experimental.

## Failure Catalog

- Component core requires AOM to expose a name.
- AOM path passes Chrome but fails Safari with no fallback.
- Browser flag is enabled in CI and hides production failure.
- AOM adapter creates semantics that do not match visible UI.
- Experimental feature leaks into stable package API.
- Docs describe research support as production support.

## Release Gates

- AOM remains adapter-only until standards and browser support justify
  promotion.
- Every AOM feature has a fallback or an explicit experimental limitation.
- Stable Headless docs mention AOM only as optional adapter technology.
- Compatibility matrix is updated before enabling any AOM path by default.

## Summary

AOM is promising, but it should be a controlled experiment for Headless. The
core stays HTML/ARIA and platform-semantics first, with AOM behind a feature
gated adapter boundary.
