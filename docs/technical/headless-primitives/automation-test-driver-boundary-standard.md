# Automation Test Driver Boundary Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- W3C WebDriver: https://www.w3.org/TR/webdriver2/
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- ARIA-AT: https://w3c.github.io/aria-at/
- Flutter testing accessibility: https://docs.flutter.dev/ui/accessibility/accessibility-testing
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- MDN User activation: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/User_activation

## Scope

This standard defines how Headless primitives expose deterministic automation
and test hooks without weakening accessibility, privacy, user intent, or public
API stability.

It applies to:

- widget tests;
- integration tests;
- browser automation;
- conformance harnesses;
- screen reader labs;
- app-specific test IDs;
- simulated keyboard and pointer events;
- destructive-flow test fixtures.

It does not make test hooks product APIs. It defines safe boundaries.

## Decision Options

Option A: Test by visible text and internal widget structure - 🎯 4   🛡️ 4
🧠 2, about 50-200 LOC.

- Easy at first.
- Breaks localization, redesigns, and accessibility refactors.

Option B: Add arbitrary test ids everywhere - 🎯 5   🛡️ 5   🧠 3, about
150-500 LOC.

- Stable for tests.
- Can leak product data or become unofficial API.

Option C: Headless automation contract with semantic test handles - 🎯 9
🛡️ 9   🧠 7, about 800-1500 LOC.

- Accepted direction.
- Test handles are stable, typed, privacy-safe, and tied to primitive roles.
- Automation does not bypass command policy unless explicitly in test mode.

## Accepted Direction

Headless should expose `AutomationHandle` metadata for primitives.

Handle includes:

- primitive type;
- stable component id;
- role;
- state facts;
- command ids;
- privacy class;
- test-only fields;
- conformance scenario tags;
- automation scope.

It must not include raw user content by default.

## Test Selector Rules

Selectors should be:

- stable;
- semantic;
- low-cardinality;
- independent from localized text;
- independent from raw paths;
- independent from visual renderer class names;
- versioned when public.

Bad selectors:

- raw filename;
- raw path;
- localized label;
- CSS class from theme;
- row index in virtualized list;
- generated widget hash.

Good selectors:

- primitive role plus stable row id hash;
- command id;
- column id;
- conformance scenario id;
- safe fixture id.

## Automation And User Intent

Automation can simulate input. It is not automatically real user intent.

Rules:

- automation dispatch must carry automation provenance;
- sensitive commands require test policy to simulate fresh intent;
- production code must not accept test-only bypass flags;
- conformance runner may use controlled fixtures;
- destructive operations use safe fixtures or dry-run adapters.

## Accessibility Test Rules

Conformance tests must check:

- role;
- accessible name presence;
- keyboard path;
- focus order;
- target size where available;
- contrast where available;
- live announcement trace;
- disabled reason;
- error recovery path.

Tests should not pass only because a test id exists.

## Virtualized Surface Rules

Automation for virtualized grids must not assume visible widget index equals
data identity.

Test driver should request:

- row by stable id;
- column by stable id;
- command by id;
- viewport reveal action;
- focus cell action;
- assertion over semantic state.

## Clean Disk Requirements

Clean Disk automation needs:

- select scan target;
- start scan fixture;
- reveal row by node id;
- sort and filter;
- add to queue;
- validate delete plan in dry-run;
- confirm move-to-trash only in safe fixture environment;
- assert stale plan blocks action;
- assert path redaction.

Rules:

- no raw user path as test selector;
- no real cleanup through ordinary UI test;
- automation cannot bypass daemon capability unless fixture adapter declares it.

## API Shape Sketch

```text
AutomationHandle
  primitiveType
  componentId
  role
  state
  commandIds
  stableTestKey
  privacyClass
  scenarioTags

AutomationPolicy
  mode
  allowSensitiveSimulation
  fixtureScope
  prohibitRawContentSelectors
```

## Conformance Scenarios

- localized UI still passes tests using command id;
- virtualized row test reveals by stable row id;
- disabled destructive command cannot be clicked through test hook;
- screen reader role is tested separately from selector;
- raw path is not emitted as test id;
- automation provenance is visible in command trace;
- dry-run cleanup fixture can confirm safe path;
- renderer class rename does not break semantic test.

## Failure Catalog

- tests select by English label;
- raw path used as data-testid;
- automation bypasses disabled state;
- virtualized row selected by visible index;
- conformance test only checks widget exists;
- production accepts test-only bypass flag;
- destructive test runs against real filesystem;
- localized accessible name used as command id;
- CSS class names become public API;
- test hook leaks sensitive content in screenshots or logs.

