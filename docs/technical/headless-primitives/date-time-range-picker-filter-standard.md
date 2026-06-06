# Date Time Range Picker Filter Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Date Picker Combobox Example: https://www.w3.org/WAI/ARIA/apg/patterns/combobox/examples/combobox-datepicker/
- WAI-ARIA APG Combobox Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/combobox/
- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- MDN `datetime-local`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/datetime-local
- MDN `enterkeyhint`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/enterkeyhint
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html
- WCAG 3.3.3 Error Suggestion: https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html

## Scope

This standard covers date pickers, time pickers, date-time range filters,
relative time presets, calendar popups, modified-before/after filters,
history range selectors, and typed temporal values.

It extends combobox, dialog, grid, validation, locale formatting, time/date
semantics, and query/filter standards.

## Problem

Date and range inputs are deceptively hard:

- display format is locale-specific;
- query value must be stable and timezone-aware;
- typed input and calendar selection must stay equivalent;
- screen-reader users need format and range instructions;
- mobile and desktop input methods differ;
- invalid partial input must not silently change filters;
- relative values like "last 7 days" need explicit anchoring.

For Clean Disk this matters for modified-date filters, scan history, receipts,
operation timelines, support bundles, and snapshot comparison.

## Decision Options

1. Typed temporal picker contract with pluggable renderer -
   🎯 9   🛡️ 9   🧠 8, roughly 1000-2200 LOC.
   Best fit. It keeps locale display separate from query truth and supports
   text entry, calendar grid, and relative presets.
2. Use platform/native date fields only -
   🎯 6   🛡️ 6   🧠 3, roughly 200-500 LOC.
   Simple, but behavior varies heavily across web, desktop, and Flutter.
3. Store and compare localized date strings -
   🎯 2   🛡️ 2   🧠 2, roughly 100-300 LOC.
   Fast to draw, but breaks sorting, filtering, i18n, and auditability.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- temporal value type;
- open/close state;
- text input parse state;
- active calendar cell;
- selected date/time/range;
- range anchor;
- validation state;
- keyboard model;
- accessible descriptions;
- locale-independent command facts.

Renderer owns:

- calendar layout;
- date cell visuals;
- range highlight;
- input chrome;
- popup placement;
- compact/mobile presentation.

Application owns:

- timezone policy;
- min/max constraints;
- relative preset definitions;
- query mapping;
- persistence;
- domain validation.

## Value Model

Supported values:

- instant;
- local date;
- local date-time;
- closed range;
- open-start range;
- open-end range;
- relative range preset;
- invalid partial input.

Rules:

- display text is never the stored value;
- range endpoints are ordered by value, not entry order;
- relative ranges include anchor policy;
- timezone must be explicit when converting to instant;
- date-only filters define inclusive/exclusive boundaries in the application
  contract.

## Keyboard Rules

Combobox/input:

- `Down Arrow` or `Alt+Down Arrow` opens popup when configured;
- `Enter` commits valid typed value or selected cell;
- `Escape` closes popup before clearing input;
- IME composition prevents premature commit;
- `Tab` leaves according to normal focus order.

Calendar grid:

- one active date is in the tab sequence;
- arrow keys move by day/week depending on orientation;
- month/year buttons are ordinary commands;
- live region announces month/year changes only at a throttled rate;
- focus returns to input on close.

## Validation Rules

Validation facts:

- parse status;
- boundary status;
- range completeness;
- timezone ambiguity;
- relative preset validity;
- disabled date reason;
- suggested correction.

Rules:

- invalid partial text does not mutate committed query;
- errors are announced through validation channel, not alert spam;
- a disabled date has a reason;
- ambiguous daylight-saving transitions are resolved by application policy;
- current system time is captured once for relative preset preview.

## Clean Disk Usage

Use cases:

- modified before/after filters;
- scan history date range;
- receipt timestamp filters;
- support bundle time window;
- operation journal filtering;
- "recently changed" views.

Rules:

- Rust query receives typed time constraints;
- Flutter display may localize but does not re-sort full result sets;
- relative filters are materialized into explicit query DTOs before execution;
- cleanup authority never comes from an old date-filtered visible list without
  current validation.

## Community API Sketch

```dart
sealed class RTemporalValue {
  const RTemporalValue();
}

final class RTemporalRangeValue extends RTemporalValue {
  const RTemporalRangeValue({
    required this.start,
    required this.end,
    required this.boundaryPolicy,
  });

  final RTemporalEndpoint? start;
  final RTemporalEndpoint? end;
  final RTemporalBoundaryPolicy boundaryPolicy;
}
```

## Conformance Scenarios

- typed valid date and selected calendar date produce the same value;
- invalid partial input does not change committed filter;
- date range with reversed entry order normalizes predictably;
- popup close returns focus to invoker;
- month navigation announces updated month without flooding;
- localized display changes do not change query value;
- relative preset captures explicit anchor time.

## Anti-Patterns

- storing localized strings as date values;
- treating date picker popup as a menu;
- placing every date cell in the tab order;
- using current time repeatedly during one query build;
- allowing hidden invalid input to keep filtering;
- using browser-only input behavior as the cross-platform contract.

## Clean Architecture Note

Headless owns temporal interaction. Application ports own query semantics.
Domain owns business meaning. Renderer adapters only display date controls and
must not decide timezone or filter inclusivity.

