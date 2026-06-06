# Accessibility Supported Technology Policy Standard

## Status

Accepted as a Headless conformance policy standard. Not implemented yet.

## Source Standards

- WCAG 2.2 Conformance: https://www.w3.org/WAI/WCAG22/Understanding/conformance.html
- ARIA-AT: https://w3c.github.io/aria-at/
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- Flutter web accessibility: https://docs.flutter.dev/ui/accessibility/web-accessibility
- Platform Accessibility API Bridge Standard: platform-accessibility-api-bridge-standard.md

## Scope

This standard defines how Headless declares which technology stacks are relied
upon for accessibility support.

It applies to:

- web adapter claims;
- desktop adapter claims;
- native accessibility API mapping;
- screen reader test matrices;
- public docs;
- release gates.

It does not require every possible browser, OS, and assistive technology
combination to be supported. It requires honesty about what Headless relies on.

## Decision Options

Option A: Say "accessible" without stack policy - 🎯 2   🛡️ 2   🧠 1,
about 50-150 LOC.

- Easy marketing copy.
- Not acceptable for a community UI kit.

Option B: Maintain manual support notes - 🎯 6   🛡️ 6   🧠 4, about
300-700 LOC.

- Useful for docs.
- Hard to connect to release gates and adapter capabilities.

Option C: Versioned accessibility-supported technology policy - 🎯 9
🛡️ 9   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Converts conformance claims into explicit stack assumptions.
- Supports "not relied upon" and fallback paths.

## Accepted Direction

Headless should define `AccessibilitySupportedTechnologyPolicy`.

Policy fields:

- platform family;
- runtime version;
- adapter version;
- browser if applicable;
- screen reader or assistive technology;
- input mode;
- tested primitive set;
- relied-upon features;
- fallback features;
- unsupported features;
- test date;
- expiry date;
- claim level.

## Claim Levels

Claim levels:

- `reliedUpon`: used to satisfy accessibility behavior.
- `supportedWithFallback`: works through fallback semantics or commands.
- `notReliedUpon`: feature may exist, but conformance does not depend on it.
- `experimental`: useful but not a release claim.
- `unsupported`: known not to work.
- `unknown`: not tested.

`unknown` must fail closed for destructive or critical workflows.

## Reliance Rules

Rules:

- do not rely on unsupported ARIA role behavior;
- do not rely on exact screen reader phrase text;
- rely on user-observable task completion and semantic facts;
- specify versions when behavior is version-sensitive;
- prefer fallback commands over brittle role emulation;
- keep fallback labels concise and privacy-safe.

## Supported Stack Matrix

Minimum matrix for public Headless:

```text
Web
  Chrome + one major screen reader path
  Safari + VoiceOver path when claiming macOS web support
  Firefox + NVDA path before strong Windows web claim

Desktop
  macOS + VoiceOver path for macOS claim
  Windows + Narrator or NVDA path for Windows claim
  Linux + Orca path if Linux accessibility claim is made

Flutter
  Semantics tests for all primitives
  web semantics debug evidence for web adapter
```

The matrix is a claim boundary, not a universal testing promise.

## Non-Interference Rule

Even unsupported features must not interfere with supported access paths.

Examples:

- canvas chart may be unsupported as direct graphic navigation, but table
  summary must remain accessible;
- fancy drag may be not relied upon, but buttons must support the same action;
- shortcut layer may be experimental, but Tab navigation must still work;
- renderer animation may be disabled, but state must remain perceivable.

## Clean Disk Requirements

Clean Disk must declare support for:

- Flutter desktop macOS path before macOS release;
- daemon-served Flutter web path before web UI claim;
- Windows path before Windows release;
- read-only remote/headless path separately from local cleanup.

Cleanup gate:

- destructive confirmation cannot rely on an experimental accessibility path.

## API Shape Sketch

```text
AccessibilitySupportedTechnologyPolicy
  stackId
  platformFamily
  runtime
  assistiveTechnology
  adapterVersion
  reliedUponFacts
  fallbackFacts
  unsupportedFacts
  claimLevel
  evidenceRefs
  expiresAt
```

## Conformance Scenarios

Required scenarios:

- web TreeGrid claim lists browser and screen reader stack;
- desktop dialog claim lists platform screen reader path;
- unsupported chart direct navigation points to accessible table projection;
- adapter upgrade invalidates expired policy;
- `unknown` support disables public strong claim;
- fallback command path can complete same user task.

## Failure Catalog

Failures:

- "screen-reader compatible" without versioned stack;
- relying on ARIA role that target screen reader ignores;
- claiming web support based only on Flutter widget tests;
- treating one screen reader phrase as normative;
- unsupported feature blocks keyboard path;
- stale policy after browser or Flutter upgrade.

## Release Gates

Release gate:

- every public accessibility claim references a support policy;
- every support policy has evidence refs and expiry;
- unsupported relied-upon feature blocks release;
- fallback paths are documented in public primitive docs;
- Clean Disk release notes do not overclaim adapter coverage.

