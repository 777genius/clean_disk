# Release Stability And Versioning Gates

## Status

Spec-level release gate plan.

## Purpose

Public primitives need stability gates. A component can be useful before it is
stable, but users need honest labels.

## Stability Labels

```text
experimental
  API may change, conformance incomplete

beta
  API mostly stable, conformance evidence present, known gaps documented

stable
  breaking changes require major version or documented migration

deprecated
  replacement exists, removal timeline documented
```

## Gate Matrix

| Gate | Experimental | Beta | Stable |
| --- | --- | --- | --- |
| RFC | required | required | required |
| API docs | minimal | complete | complete |
| keyboard tests | smoke | required | required |
| semantics tests | smoke | required | required |
| renderer conformance | optional | required | required |
| performance fixture | optional | required for dense | required for dense |
| screen-reader evidence | optional | smoke | matrix for high priority |
| migration docs | no | draft | required |

## Versioning Rules

- Adding optional parameter can be minor.
- Removing public symbol is major after stable.
- Changing keyboard behavior is breaking if stable.
- Changing semantics facts is breaking if stable.
- Renderer capability signature changes are breaking.
- Adding new state enum value can be minor only if exhaustive users have safe
  fallback.

## Known Limitations Policy

Every beta/stable primitive needs:

- unsupported capabilities;
- degraded platform behavior;
- accessibility gaps;
- performance constraints;
- migration risks.

## Clean Disk Policy

Clean Disk may depend on experimental Headless through local path during product
development, but release builds should use pinned versions or a deliberate
workspace dependency policy.

## Stop Rules

- Do not mark beta without conformance report.
- Do not mark stable without migration policy.
- Do not hide breaking keyboard/semantics changes in patch releases.
