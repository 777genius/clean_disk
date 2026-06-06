# Community Governance Contract

## Status

Implementation contract for public Headless standard process.

## Problem

If Headless becomes a community UI kit, component APIs need governance:
stability labels, conformance claims, deprecation policy, compatibility reports,
and contribution rules. Otherwise primitives like TreeGrid become hard to trust.

## Stability Levels

```text
internal
experimental
beta
stable
deprecated
removed
```

Rules:

- `internal` cannot appear in public docs;
- `experimental` can change with changelog;
- `beta` requires conformance report;
- `stable` requires compatibility promise;
- `deprecated` includes replacement path and removal version.

## RFC Lifecycle

```text
idea
  -> research
  -> RFC
  -> prototype
  -> conformance draft
  -> beta
  -> stable
```

Complex primitives cannot jump from idea to stable.

## Compatibility Claim

A package can say "Headless-compatible" only if it has:

- spec version;
- conformance report;
- core package versions;
- renderer/preset versions;
- test commands;
- known limitations.

## Breaking Change Policy

Breaking changes require:

- migration note;
- deprecation when practical;
- changelog entry;
- version bump according to package policy;
- conformance report update.

## Third-Party Renderer Policy

Third-party renderer packages must:

- implement renderer capability interfaces;
- pass renderer boundary tests;
- document token coverage;
- document unsupported features;
- not claim full component conformance if only renderer conformance passes.

## Documentation Requirements

Every stable primitive needs:

- README quick start;
- API reference;
- accessibility notes;
- keyboard table;
- controlled/uncontrolled example;
- renderer customization example;
- conformance report;
- LLM.txt.

## Clean Disk Relationship

Clean Disk is an early proving app, not the standard itself.

Rules:

- if Clean Disk needs app-specific behavior, put it in design system or feature
  package;
- if behavior is generally useful, propose it through RFC;
- do not backfit Headless API around Clean Disk product names.

## Stop Rules

- Do not mark TreeGrid stable before large-fixture conformance.
- Do not accept third-party compatibility claims without evidence.
- Do not hide breaking changes in minor releases after stable.
- Do not let Clean Disk-specific needs leak into Headless names.
