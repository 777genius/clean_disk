# Extension Lifecycle Deprecation And Compatibility Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- Semantic Versioning: https://semver.org/
- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- MDN Web Components: https://developer.mozilla.org/en-US/docs/Web/API/Web_components
- MDN `ElementInternals`: https://developer.mozilla.org/en-US/docs/Web/API/ElementInternals
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/

## Scope

This standard defines lifecycle and compatibility rules for public Headless
extensions.

It applies to:

- renderer adapters;
- primitive extension packages;
- chart adapters;
- design-system wrappers;
- conformance plugins;
- migration tools;
- app-specific adapters;
- deprecated APIs.

It does not define package registry operations. It defines lifecycle contracts
that packages must follow to be trusted by the ecosystem.

## Decision Options

Option A: Extensions are just packages - 🎯 4   🛡️ 4   🧠 2, about
100-250 LOC.

- Easy.
- Compatibility, deprecation, and safety become informal.

Option B: Manual review for every extension - 🎯 6   🛡️ 7   🧠 6, about
500-1200 LOC process cost.

- Safer.
- Slow and not scalable for community ecosystem.

Option C: Extension lifecycle manifest with compatibility gates - 🎯 9
🛡️ 9   🧠 8, about 1000-2200 LOC.

- Accepted direction.
- Extensions declare compatibility, capabilities, trust, migration, and
  deprecation state.
- Review becomes evidence-driven.

## Accepted Direction

Every extension should publish an extension manifest:

- package id;
- extension type;
- supported Headless version range;
- semantic parity manifest;
- capability manifest;
- privacy class;
- security posture;
- migration hooks;
- deprecation status;
- known incompatibilities;
- conformance evidence.

## Lifecycle States

States:

- `experimental`;
- `preview`;
- `stable`;
- `deprecated`;
- `maintenance`;
- `securityOnly`;
- `retired`;
- `blocked`;

State affects whether package can be used by default in apps with safety
requirements.

## Compatibility Rules

Compatibility must specify:

- Headless API version;
- primitive contract version;
- renderer contract version;
- token contract version;
- conformance suite version;
- platform support;
- known degraded platforms.

Unknown compatibility fails closed for critical primitives.

## Deprecation Rules

Deprecation must include:

- replacement package or API;
- migration path;
- minimum warning period where practical;
- breaking change reason;
- security or accessibility impact;
- runtime diagnostic code;
- conformance downgrade if relevant.

Do not silently remove accessibility behavior.

## Migration Rules

Extensions may provide migration helpers for:

- token names;
- renderer manifests;
- component props;
- state envelopes;
- automation handles;
- semantic refs.

Migration helpers must not:

- access product secrets;
- change command authority;
- restore destructive state;
- emit network telemetry by default.

## Clean Disk Requirements

Clean Disk may use extensions for:

- disk map rendering;
- custom TreeGrid visual renderer;
- platform desktop shell;
- chart fallback;
- conformance testing.

Rules:

- optional Syncfusion adapter is extension-like and must declare capability;
- cleanup safety cannot depend on unverified extension;
- deprecated renderer must not block data migration;
- extension diagnostics must be redacted.

## API Shape Sketch

```text
ExtensionManifest
  packageId
  type
  lifecycleState
  compatibleVersions
  capabilities
  parityManifest
  privacyPolicy
  deprecation
  migrations
  evidence

ExtensionGate
  validate(manifest, appPolicy)
  allowUse()
  requireMigration()
  block(reason)
```

## Conformance Scenarios

- stable extension declares supported Headless version range;
- deprecated extension emits replacement guidance;
- incompatible extension is blocked for TreeGrid;
- migration helper cannot read daemon token;
- chart extension with visual-only accessibility is degraded;
- security-only extension cannot add new public API;
- app policy blocks untrusted renderer for destructive workflow;
- conformance evidence references suite version.

## Failure Catalog

- extension claims support without version range;
- breaking change shipped as minor version;
- deprecated API removed without migration path;
- extension telemetry enabled by default;
- migration helper changes command authority;
- visual renderer used without parity manifest;
- unknown compatibility treated as stable;
- security issue hidden as ordinary deprecation;
- extension stores raw paths in diagnostics;
- Clean Disk cleanup flow depends on unverified extension.

