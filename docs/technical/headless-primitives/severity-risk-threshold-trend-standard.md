# Severity Risk Threshold Trend Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `<meter>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/meter
- MDN `aria-valuenow`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-valuenow
- MDN `aria-valuetext`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-valuetext
- MDN SVG `<title>`: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/title
- MDN SVG `<desc>`: https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/desc
- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- WCAG 1.4.11 Non-text Contrast: https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

## Scope

This standard covers severity labels, risk tiers, threshold indicators,
trend arrows, sparklines, status scales, warning scales, confidence bands,
and compact risk markers used across Headless primitives.

It does not define product policy. Headless transports and renders scale facts.
Application owns the meaning and consequences of risk.

## Problem

Risk UI often degrades into red/yellow/green decoration. That fails users who
cannot perceive color and fails product safety when a visual marker hides the
actual policy. Clean Disk needs risk tiers for cleanup candidates, skipped
items, low confidence estimates, provider states, and destructive commands.
Those tiers must be semantic, auditable, and not color-only.

## Decision Options

1. Shared `RiskScale` and `ThresholdScale` contracts -
   🎯 9   🛡️ 9   🧠 7, roughly 700-1600 LOC.
   Best fit. It makes severity/risk reusable across metrics, charts, tables,
   cards, alerts, and confirmations.
2. Per-component enum values -
   🎯 6   🛡️ 6   🧠 4, roughly 300-800 LOC.
   Easier early, but inconsistent labels, colors, announcements, and policy
   mapping spread across Headless.
3. Visual token only: info/warning/error colors -
   🎯 3   🛡️ 3   🧠 2, roughly 100-300 LOC.
   Not enough for accessibility or safety.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- scale id;
- scale kind;
- level id;
- level order;
- label slot;
- description slot;
- threshold facts;
- current value;
- trend facts;
- confidence facts;
- announcement policy;
- non-color alternative requirement.

Renderer owns:

- colors;
- icons;
- badges;
- arrows;
- sparklines;
- meter visuals;
- contrast adaptation;
- reduced motion behavior.

Application owns:

- policy meaning;
- thresholds;
- risk calculation;
- localized text;
- command enablement;
- support/receipt evidence.

## Scale Types

Scale kinds:

- severity;
- risk;
- confidence;
- health;
- priority;
- threshold;
- trend;
- estimate quality;
- data quality.

Scale level examples:

- none;
- info;
- low;
- medium;
- high;
- critical;
- unknown;
- blocked.

Rules:

- unknown is not low;
- risk is not confidence;
- severity is not command permission;
- visual color is not the scale id;
- scale order must be explicit.

## Threshold Model

Threshold fact:

- value;
- unit;
- comparison operator;
- inclusive/exclusive flag;
- policy source;
- freshness;
- confidence;
- label;
- explanation.

Examples:

- "files larger than 5 GB";
- "skip count above 0";
- "reclaim estimate confidence below medium";
- "free space below 10 percent";
- "operation failed more than 3 times".

Threshold crossing can be announced when user-relevant and not noisy.

## Trend Model

Trend fact:

- direction;
- magnitude;
- unit;
- period;
- baseline;
- current;
- confidence;
- sample count;
- stale state.

Trend directions:

- increased;
- decreased;
- unchanged;
- volatile;
- unknown.

Sparklines:

- are visual summaries;
- require accessible text summary;
- must not be the only source of exact data;
- should be hidden from semantics when a better textual value exists.

## Accessibility Rules

Risk and severity must not rely on:

- color alone;
- icon alone;
- position alone;
- animation alone;
- glow alone.

Required alternatives:

- text label or accessible label;
- icon shape distinct from color where visual icon is used;
- description for non-obvious risk;
- high contrast-safe tokens;
- exact value or value text for meters.

For web:

- use `<meter>` only for scalar values in a known range;
- use `aria-valuetext` when the numeric value alone is not enough;
- SVG sparklines need title/description or must be decorative with text
  alternative nearby.

For Flutter:

- semantic label includes level and value;
- custom painters provide equivalent semantics outside the painter;
- reduced motion disables pulsing threshold animations.

## Clean Disk Usage

Use scales for:

- cleanup candidate risk;
- delete plan safety;
- reclaim estimate confidence;
- skipped/protected state;
- permission quality;
- scan health;
- daemon compatibility;
- provider/cloud state;
- low disk urgency;
- recommendation trust.

Rules:

- `critical` cleanup risk does not mean "delete now";
- low confidence estimate blocks exact reclaim claims;
- warning state must appear in confirmation and receipt;
- risk scale ids are stable and can be audited;
- support bundles include scale ids, not private path labels.

## Community API Sketch

```dart
final class RScaleFact {
  const RScaleFact({
    required this.scaleId,
    required this.levelId,
    required this.kind,
    required this.value,
    required this.confidence,
  });

  final String scaleId;
  final String levelId;
  final RScaleKind kind;
  final Object? value;
  final RConfidence confidence;
}

final class RTrendFact {
  const RTrendFact({
    required this.direction,
    required this.magnitude,
    required this.period,
    required this.baseline,
    required this.current,
  });

  final RTrendDirection direction;
  final Object? magnitude;
  final RTimeRange period;
  final Object? baseline;
  final Object? current;
}
```

## Conformance Scenarios

- risk marker has text alternative;
- color-only threshold fails review;
- unknown risk does not map to low risk;
- confidence and severity are separate;
- threshold crossing announces once when user-relevant;
- sparkline has textual summary or is decorative;
- high contrast preserves non-text contrast;
- delete confirmation includes risk level and reason.

## Failure Catalog

- Red/yellow/green is the only meaning.
- Unknown risk defaults to safe.
- Severity enum controls command permission directly.
- Sparkline has no accessible summary.
- Threshold value is hidden in theme tokens.
- Risk labels differ across components for the same level id.
- Low confidence reclaim estimate displayed as exact.

