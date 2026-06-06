# Public Fixture Pack And Interoperability Standard

## Status

Accepted as a Headless community testing standard. Not implemented yet.

## Source Standards

- WAI ACT Overview: https://www.w3.org/WAI/standards-guidelines/act/
- ACT Rules Format 1.1: https://www.w3.org/TR/act-rules-format/
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- Flutter accessibility testing: https://docs.flutter.dev/ui/accessibility/accessibility-testing
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/
- Semantic Versioning: https://semver.org/

## Scope

This standard defines shared public fixture packs for Headless primitives so
community renderers and adapters can prove interoperable behavior.

It applies to:

- examples;
- conformance fixtures;
- benchmark fixtures;
- adapter compatibility packages;
- third-party renderer submissions;
- Clean Disk synthetic UI fixtures.

It does not use real user data. It defines synthetic but realistic scenarios.

## Decision Options

Option A: Each adapter writes its own fixtures - 🎯 4   🛡️ 4   🧠 3,
about 300-900 LOC per adapter.

- Fast for one adapter.
- Cross-adapter regressions are hard to compare.

Option B: Keep fixtures only inside main repo tests - 🎯 6   🛡️ 6
🧠 4, about 600-1200 LOC.

- Good for maintainers.
- Community renderers cannot easily self-certify.

Option C: Versioned public fixture packs with scenario metadata - 🎯 9
🛡️ 9   🧠 8, about 1200-2800 LOC.

- Accepted direction.
- Examples, tests, docs, and third-party adapters share the same scenarios.
- Fixture versions become compatibility contracts.

## Accepted Direction

Headless should define `FixturePack`.

Pack fields:

- pack id;
- primitive ids;
- fixture version;
- scenario list;
- data privacy class;
- expected behavior traces;
- expected semantic facts;
- optional visual baselines;
- scale profile;
- adapter requirements;
- known limitations.

## Fixture Types

Types:

- minimal behavior fixture;
- keyboard interaction fixture;
- screen reader transcript fixture;
- high contrast fixture;
- localization and bidi fixture;
- virtualization scale fixture;
- error and recovery fixture;
- destructive safety fixture;
- performance budget fixture;
- host-boundary fixture.

Each fixture declares whether it is normative, optional, or exploratory.

## Data Rules

Rules:

- no real filesystem paths;
- no real user names;
- no customer content;
- no tokens or endpoints;
- synthetic data must still include long names, bidi text, duplicates, and
  sensitive-looking placeholders;
- fixture privacy class is explicit.

Clean Disk synthetic fixtures can include path-like strings only when generated
and clearly fake.

## Interoperability Claims

Claims:

- `passesCorePack`: supports normative behavior.
- `passesAdapterPack`: supports platform adapter requirements.
- `passesScalePack`: supports large-data behavior.
- `passesA11yPack`: supports accessibility scenarios for declared stack.
- `passesProductPack`: supports product-specific scenarios.

Community renderers must not claim full Headless compatibility from visual
fixtures only.

## Clean Disk Requirements

Clean Disk needs fixture packs for:

- 50k-row TreeTable;
- compact layout;
- high contrast dark and light;
- long localized file names;
- permission degraded scan;
- stale delete plan;
- partial cleanup failure;
- disk usage map with accessible table fallback.

The fixture pack should be reusable by external apps that need a disk-like
tree without importing Clean Disk domain models.

## API Shape Sketch

```text
FixturePack
  id
  version
  primitives
  scenarios
  syntheticDataProfile
  expectedBehavior
  expectedSemantics
  budgets
  privacyClass
  compatibilityClaim
```

## Conformance Scenarios

Required scenarios:

- renderer passes same keyboard fixture as Material adapter;
- fixture pack upgrade marks breaking expected behavior;
- third-party adapter publishes evidence refs;
- synthetic Clean Disk tree includes no real path;
- visual fixture is paired with semantic fixture;
- scale fixture has explicit hardware and runtime notes.

## Failure Catalog

Failures:

- public fixture contains real user path;
- adapter claims compatibility from screenshot only;
- fixture expected behavior changes without version bump;
- scale fixture hides performance budget;
- destructive fixture can touch real filesystem;
- product fixture imports product-only DTOs into Headless core.

## Release Gates

Release gate:

- every public primitive has core fixture pack;
- every adapter has compatibility fixture pack;
- fixture pack changes follow semantic versioning;
- privacy scan runs before publishing fixtures;
- Clean Disk UI changes update product fixture evidence.

