# Normative Traceability Matrix

## Status

Normative traceability map for implementation, review, and conformance.

## Purpose

Every public primitive must trace from standard requirement to Headless contract
to test evidence. This prevents "we probably support accessibility" claims.

## Traceability Shape

```text
Standard requirement
  -> Headless contract
  -> implementation owner
  -> conformance test
  -> evidence artifact
```

## Matrix

| Requirement | Contract | Owner | Test evidence |
| --- | --- | --- | --- |
| keyboard operation | keyboard command matrix | component | keyboard behavior script |
| focus visible | focus system and tokens | component plus renderer | visual/semantics fixture |
| focus restore | focus return target | component | close menu/dialog test |
| role/name/value | accessibility role matrix | component | semantics test |
| selection separate from focus | collection contract | foundation/component | selection/focus test |
| disabled semantics | async/disabled contract | foundation/component | disabled matrix test |
| modal focus trap | dialog deep dive | dialog component | Tab loop test |
| context menu keyboard open | command menu deep dive | context menu | Shift + F10 test |
| splitter keyboard resize | split pane contract | split pane | arrow/Home/End test |
| tooltip noninteractive | tooltip contract | tooltip | no focusable descendant test |
| status no focus move | status contract | status region | focus stability test |
| virtualization bounded | viewport performance | viewport adapter | built count test |
| renderer boundary | renderer contract | component/renderer | no direct callback test |
| privacy | security contract | all | redacted diagnostics test |
| bidi direction | i18n contract | component/renderer | RTL fixture test |

## Evidence Artifacts

Each stable primitive should keep:

- conformance report;
- test command output;
- semantic fixture snapshots;
- keyboard script results;
- performance fixture result if dense/virtualized;
- manual assistive technology notes for complex primitives.

## Review Checklist

Before merging a primitive:

- every normative row has a test or documented exception;
- exceptions include risk and owner;
- renderer tests run separately from component behavior tests;
- app-specific tests do not replace Headless conformance;
- public docs mention unsupported/degraded capabilities.

## Stop Rules

- Do not mark a primitive stable without traceability.
- Do not count app-only tests as public Headless conformance.
- Do not accept "manual checked" without date/platform notes.
- Do not hide unsupported behavior from public docs.
