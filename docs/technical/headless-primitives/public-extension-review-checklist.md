# Public Extension Review Checklist

## Status

Checklist for third-party renderers, adapters, and advanced extension packages.

## Purpose

Headless should be useful for the community without letting extensions weaken
core contracts. Every extension point needs a review path that protects
accessibility, privacy, performance, and API stability.

## Extension Types

Renderer extension:

- provides visuals for an existing primitive;
- implements renderer capability interfaces;
- may define visual tokens;
- must not own behavior state.

Platform adapter:

- maps platform semantics, focus, or input behavior;
- may be web, desktop, mobile, or embedded specific;
- must preserve core logical state.

Data adapter:

- maps application data into collection descriptors;
- must not be required by Headless core;
- must keep ids stable and labels separate.

Conformance adapter:

- adds tests, fixtures, or harness integrations;
- must not modify primitive behavior.

## Required Review Questions

API:

- Is the extension using public imports only?
- Does it depend on stable typed contracts?
- Does it avoid stringly command names?
- Can it fail closed when a capability is missing?

Accessibility:

- Does it preserve required focus facts?
- Does it expose icon-only labels?
- Does it preserve disabled state?
- Does it preserve selected versus focused state?
- Does it preserve live region policy?

Performance:

- Does it avoid rebuilding the full viewport?
- Does it avoid unbounded semantic nodes?
- Does it avoid synchronous layout measurement loops?
- Does it avoid retaining stale row widgets?

Privacy:

- Does it avoid logging labels and ids by default?
- Does diagnostics redact product data?
- Does it avoid sending telemetry from core packages?

Composition:

- Does it work inside SplitPane?
- Does it work inside Dialog?
- Does it restore focus after ContextMenu?
- Does it respect overlay stacking rules?

## Capability Declaration

Every renderer or platform adapter should declare:

```text
component:
adapter type:
supported package version:
semantic support:
keyboard support:
pointer support:
high contrast support:
text scaling support:
RTL support:
virtualization support:
known limitations:
```

## Failure Policy

If a required capability is missing:

- debug/test should fail loudly with a diagnostic;
- production can show explicit fallback only if configured;
- unsafe interaction must be disabled;
- docs must explain how to install the correct adapter.

If an optional capability is missing:

- component remains usable;
- feature is absent from capability DTO;
- docs show degraded behavior.

## Public Package Requirements

Every extension package should include:

- README with usage and limitation status;
- `llms.txt` or equivalent machine-readable usage notes;
- changelog;
- conformance report;
- minimum compatible Headless version;
- example fixture;
- no imports from another package `src/` directory.

## Clean Disk Rule

Clean Disk may use private adapters while proving UX, but public Headless must
not depend on Clean Disk-specific adapter names, disk paths, scan terms, or
cleanup workflows.

## Stop Rules

- Do not accept a renderer that implements keyboard behavior internally.
- Do not accept an adapter that logs product labels by default.
- Do not accept extension APIs that require importing private internals.
- Do not publish extension examples without keyboard and semantics coverage.
