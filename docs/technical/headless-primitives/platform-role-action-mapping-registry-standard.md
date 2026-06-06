# Platform Role Action Mapping Registry Standard

## Status

Accepted as a Headless platform adapter standard. Not implemented yet.

## Source Standards

- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- MDN ARIA reference: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles
- Apple accessibility roles: https://developer.apple.com/documentation/applicationservices/carbon_accessibility/roles
- Microsoft UI Automation control patterns: https://learn.microsoft.com/en-us/windows/apps/design/accessibility/control-patterns-and-interfaces
- GNOME AT-SPI Accessible API: https://gnome.pages.gitlab.gnome.org/at-spi2-core/devel-docs/doc-org.a11y.atspi.Accessible.html
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility

## Scope

This standard defines a registry for mapping Headless semantic roles, states,
values, actions, and relationships to platform accessibility systems.

It applies to:

- web DOM ARIA adapter;
- Flutter native adapters;
- Material/Cupertino preset packages;
- testing harnesses;
- platform capability matrices.

It does not put platform APIs into Headless core. It records mapping facts at
adapter boundaries.

## Decision Options

Option A: Let every adapter map roles independently - 🎯 4   🛡️ 4
🧠 3, about 200-600 LOC per adapter.

- Flexible.
- Divergence and accessibility regressions are likely.

Option B: One universal role enum only - 🎯 6   🛡️ 5   🧠 4, about
400-900 LOC.

- Simple API.
- Hides state/action differences across ARIA, UIA, AX, AT-SPI, and Flutter.

Option C: Registry of role, state, relationship, and action mappings - 🎯 9
🛡️ 9   🧠 8, about 1200-2600 LOC.

- Accepted direction.
- Makes adapter differences explicit.
- Supports fallback and evidence generation.

## Accepted Direction

Headless should define `PlatformSemanticMappingRegistry`.

Registry entry includes:

- Headless semantic role;
- platform family;
- platform role;
- supported states;
- supported properties;
- supported actions;
- relationships;
- value model;
- focus model;
- unsupported facts;
- fallback strategy;
- evidence refs.

## Mapping Dimensions

Dimensions:

- role: what object is;
- name: accessible name source;
- description: supplemental explanation;
- value: current value or range;
- state: selected, expanded, checked, disabled, busy, readonly;
- action: invoke, increment, decrement, expand, collapse, dismiss;
- relation: labelled-by, described-by, controls, owns;
- collection: row count, column count, index, level, position;
- focus: platform focus and accessibility focus behavior.

Do not reduce these to one role enum.

## Fallback Rules

Fallbacks:

- if role cannot map, preserve name, state, and action;
- if relationship cannot map, use concise description fallback;
- if collection metadata is weak, preserve keyboard navigation and row labels;
- if action cannot map, expose command alternative;
- if value cannot map, expose value text.

Fallbacks must be documented as `approximate` or `fallbackLabel`, not `exact`.

## Clean Disk Requirements

Clean Disk requires strong mappings for:

- TreeTable row, cell, column header, and disclosure;
- checkbox selection and cleanup queue item;
- primary scan, pause, cancel, and reveal commands;
- destructive confirmation dialog;
- progress and status;
- disk usage map alternative table.

Weak mapping blocks only the affected claim, not the whole product, unless it
breaks cleanup safety.

## API Shape Sketch

```text
PlatformSemanticMappingRegistry
  lookup(headlessRole, platformFamily)
  listUnsupported(platformFamily)
  fallbackFor(fact, platformFamily)
  evidenceFor(mappingId)

SemanticMappingEntry
  headlessRole
  platformRole
  states
  properties
  actions
  relationships
  fidelity
```

## Conformance Scenarios

Required scenarios:

- ARIA TreeGrid mapping includes row and column metadata where supported;
- UIA mapping records patterns needed for value and selection;
- macOS mapping records approximate roles when exact role is missing;
- AT-SPI mapping records role, state, action, and localized role behavior;
- fallback label does not include sensitive path;
- unsupported mapping appears in public limitation report.

## Failure Catalog

Failures:

- renderer invents platform roles;
- role maps but action is missing;
- selected state is visual only;
- collection index exists in core but not adapter evidence;
- unknown platform mapping treated as exact;
- fallback text leaks product data.

## Release Gates

Release gate:

- every public primitive has mapping entries for supported adapters;
- every critical action has mapped or fallback activation;
- mapping fidelity is recorded in conformance evidence;
- adapter changes update registry version;
- exact claims require platform evidence.

