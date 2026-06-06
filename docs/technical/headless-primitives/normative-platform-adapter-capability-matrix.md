# Normative Platform Adapter Capability Matrix

## Status

Normative matrix for platform and renderer adapters.

## Purpose

Headless primitives run on Flutter desktop, mobile, and web. Some behaviors are
native Flutter semantics, some may need platform-specific adapters, and some
must remain unsupported until proven.

## Capability Levels

```text
native
  supported by Flutter/core APIs directly

adapter
  supported through Headless adapter

measured
  must be manually validated on target platform

future
  reserved, not promised

unsupported
  fail closed
```

## Matrix

| Capability | Desktop Flutter | Flutter Web | Headless adapter | Notes |
| --- | --- | --- | --- | --- |
| keyboard focus | native | native | focus contract | logical focus separate from FocusNode |
| shortcuts/actions | native | native | shortcut registry | scope must be explicit |
| Semantics roles | native | native-ish | semantic intent adapter | web may need measurement |
| ARIA treegrid parity | n/a | measured | optional web bridge | do not promise early |
| live region status | adapter | measured | StatusRegion | Flutter behavior varies by platform |
| tooltip description | native/adapter | measured | RTooltip | no focusable content |
| context menu key | native | measured | ContextMenu | Shift + F10 required |
| right click menu | native | native | pointer adapter | touch long press optional |
| split pane value | adapter | adapter | RSplitPane | maps to adjustable semantics |
| large 2D viewport | native package | native package | viewport adapter | `TableView` candidate |
| reduced motion | app/preset | app/preset | motion tokens | renderer must respect |
| bidi path display | app/preset | app/web bridge optional | text policy | identity separate from display |

## Platform Degradation

Every optional capability needs a fallback:

```text
full
  capability works

degraded
  read-only or reduced behavior

unavailable
  command hidden/disabled with reason
```

Clean Disk examples:

- web scanner unavailable without daemon;
- web ARIA bridge unavailable falls back to Flutter Semantics;
- context menu unavailable through right click still works through keyboard.

## Adapter Ownership

```text
headless_foundation
  behavior mechanics

component package
  logical behavior and semantic facts

preset package
  renderer visuals and tokens

platform adapter
  bridges platform-specific gaps
```

## Conformance Checks

- capability state exposed to app/design system;
- unsupported capability fails closed;
- degraded mode has visible/semantic reason;
- web bridge optional does not break desktop;
- native/mobile behavior does not depend on DOM.

## Stop Rules

- Do not make web-only ARIA fields core API.
- Do not promise a capability before measurement.
- Do not silently drop keyboard path on any platform.
- Do not let platform adapter own product workflow.
