# Normative Screen Reader Test Matrix

## Status

Normative test matrix for accessibility validation.

## Primary References

- Flutter web accessibility:
  https://docs.flutter.dev/ui/accessibility/web-accessibility
- WAI-ARIA APG Patterns:
  https://www.w3.org/WAI/ARIA/apg/patterns/
- MDN ARIA Reference:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference

## Purpose

Flutter Semantics is the default accessibility adapter. Complex widgets still
need real assistive-technology validation. This matrix defines what to test
before claiming high accessibility confidence.

## Test Environments

| Platform | Browser/runtime | Screen reader | Priority |
| --- | --- | --- | --- |
| macOS | native Flutter desktop | VoiceOver | high |
| macOS | Safari web | VoiceOver | high |
| macOS | Chrome web | VoiceOver | medium |
| Windows | native Flutter desktop | Narrator | medium |
| Windows | Chrome web | NVDA | high |
| Windows | Firefox web | NVDA | high |
| Windows | Chrome web | JAWS | medium |
| Linux | native Flutter desktop | Orca | future |

## Primitive Scenarios

TreeGrid:

- announce grid label and row/column counts when known;
- move row focus with arrows;
- announce selected state separately from focus;
- announce expanded/collapsed for expandable rows only;
- announce sorted header;
- handle virtualized row indexes;
- open context menu from focused row.

Dialog:

- initial focus lands as policy says;
- modal background is not reachable;
- Tab cycles inside;
- Escape policy works;
- alertdialog urgency is announced.

ContextMenu:

- menu opens from keyboard;
- focused item is announced;
- disabled item policy is clear;
- submenu opens and closes;
- focus restores to invoker.

SplitPane:

- handle announces separator/value;
- arrow keys change value;
- collapse/restore announced.

Tooltip:

- trigger description available;
- tooltip does not become focus target;
- Escape closes.

StatusRegion:

- polite message announced without focus move;
- progress coalesced;
- alert message interrupts only when urgent.

## Evidence Format

```text
Test date:
Component:
Platform/browser:
Screen reader:
Scenario:
Expected:
Observed:
Pass/fail:
Notes:
Known limitation:
```

## Release Thresholds

Experimental:

- Flutter widget semantics tests pass;
- manual screen-reader smoke for one high-priority environment.

Beta:

- macOS VoiceOver and Windows NVDA pass key flows;
- known limitations documented.

Stable:

- high-priority matrix passes or gaps are documented with mitigations.

## Stop Rules

- Do not claim full accessibility from widget tests alone.
- Do not promise full ARIA parity before web measurement.
- Do not log screen-reader transcript with raw user paths.
- Do not stabilize TreeGrid without manual AT evidence.
