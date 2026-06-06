# Meter Comparison Value Indicator Standard

## Status

Accepted direction for Headless. Complements progress and quantity standards.
Not implemented yet.

## Source Standards

- MDN `meter`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/meter
- MDN ARIA `meter` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/meter_role
- MDN `progress`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/progress
- MDN `aria-valuenow`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-valuenow
- MDN `aria-valuetext`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-valuetext
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html

## Problem

Many bars in Clean Disk are not progress bars. A row percentage bar shows a
scalar value inside a known range. A disk capacity bar shows used storage
against capacity. A risk bar shows confidence or severity. If these are exposed
as progress, assistive technologies and users receive the wrong meaning.

Headless needs a clear distinction between progress, meter, gauge, ratio, and
decorative bars.

## Decision Options

1. Reuse progress primitive for every bar - 🎯 4   🛡️ 4   🧠 1, about
   40-120 LOC. Simple but semantically wrong.
2. Add a meter and comparison indicator primitive - 🎯 9   🛡️ 9   🧠 5,
   about 350-850 LOC. Best fit.
3. Build charting primitives for all scalar visuals - 🎯 5   🛡️ 6   🧠 9,
   about 1800-4500 LOC. Too broad for this layer.

Accepted: option 2.

## Accepted Contract

Headless models scalar indicators:

```dart
final class RMeterValue {
  final num value;
  final num min;
  final num max;
  final num? low;
  final num? high;
  final num? optimum;
  final RMeterKind kind;
  final String label;
  final String valueText;
  final RQuantityExactness exactness;
}
```

The product supplies the meaning and value. Headless renders and exposes it
without converting it into progress.

## Indicator Kinds

```text
meter:
  scalar measurement in a known range

capacity:
  used versus total capacity

ratio:
  numerator and denominator relationship

confidence:
  evidence confidence or uncertainty

severity:
  risk level in a known scale

decorative:
  purely visual emphasis with no semantic value
```

Decorative indicators must not be the only carrier of meaning.

## Meter Versus Progress

Use progress when:

- an operation is advancing toward completion;
- indeterminate loading is possible;
- value changes over time as work completes.

Use meter when:

- value is a measurement;
- range is known;
- value is not task completion.

Clean Disk row percent bars, disk capacity bars, and reclaim confidence bars
are meters. Scan completion is progress.

## Rules

- Every meaningful meter has label and value text.
- Color thresholds require text or icon alternatives.
- Percent bars need numerator and denominator when decision-critical.
- Unknown value is not zero.
- Indeterminate state belongs to progress, not meter.
- Animated meter changes are throttled for accessibility.
- Nested meters inside table cells inherit table header context.
- Low, high, optimum, or severity thresholds come from product policy.

## Clean Disk Requirements

Clean Disk uses meters for:

- disk used capacity;
- row percent of scanned root;
- cleanup candidate confidence;
- rule-pack risk level;
- support bundle size budget;
- daemon resource pressure;
- storage map legend proportions.

Scan progress uses progress semantics, not meter.

## Accessibility Rules

- Value text should include meaning, not just number.
- A table cell meter should be announced with column context.
- Visual bars can be hidden from accessibility if the adjacent text already
  communicates the same value.
- Severity colors need non-color cues.
- Reduced motion applies to animated meter changes.
- High contrast mode keeps boundaries and fill distinguishable.

## Web Mapping

For web adapters:

- native `meter` is preferred for scalar values when possible;
- ARIA `meter` role is fallback for custom renderers;
- `progress` is reserved for task completion;
- `aria-valuetext` carries human-readable quantity and uncertainty.

Flutter adapters should expose an equivalent semantic value and avoid labeling
non-progress bars as progress indicators.

## Testing Requirements

- Row percent bar is not announced as scan progress.
- Disk capacity meter has used and total values.
- Unknown meter value does not render as zero.
- Color threshold has text alternative.
- High contrast snapshot keeps bar readable.
- Accessible value changes only when meaningful.
- Table cell meter includes column context.

## Failure Catalog

- Folder size bar announces "progress 57 percent".
- Reclaim confidence color is the only warning.
- Unknown shared extent value appears as empty zero bar.
- Capacity bar lacks total capacity.
- Animated bar triggers repeated live announcements.
- Decorative bar adds redundant accessibility noise.

## Release Gates

- Design system separates `ProgressIndicator` and `MeterIndicator`.
- TreeTable percent cells use meter semantics or hide decorative bar semantics.
- Clean Disk scan footer uses progress semantics.
- Threshold policies are product-supplied.
- Meter fixtures cover unknown, exact, estimate, low, high, and optimum.

## Summary

Meters are measurements, not progress. Headless should expose scalar indicators
with label, value, range, thresholds, and exactness so dense UIs stay visually
rich without lying to assistive technologies.
