# Localized Accessible Name Catalog Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- Accessible Name and Description Computation 1.2: https://www.w3.org/TR/accname-1.2/
- MDN `aria-label`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Attributes/aria-label
- WAI ARIA technique ARIA14: https://www.w3.org/WAI/WCAG21/Techniques/aria/ARIA14
- WCAG 2.5.3 Label in Name: https://www.w3.org/WAI/WCAG22/Understanding/label-in-name.html
- WCAG 3.1.1 Language of Page: https://www.w3.org/WAI/WCAG22/Understanding/language-of-page.html
- WCAG 3.1.2 Language of Parts: https://www.w3.org/WAI/WCAG22/Understanding/language-of-parts.html
- WCAG 3.2.4 Consistent Identification: https://www.w3.org/WAI/WCAG22/Understanding/consistent-identification.html
- W3C Internationalization: https://www.w3.org/International/

## Problem

Accessible names are often added late with hardcoded strings. That breaks
localization, speech control, label-in-name, consistency, and support triage.
For a public component library, accessible labels must be part of the same
catalog discipline as visible text, command ids, descriptions, errors, and
status messages.

## Decision Options

1. Let renderers pass arbitrary strings - 🎯 4   🛡️ 4   🧠 2, about 0-80 LOC.
   Easy but causes drift.
2. Add localized accessible-name catalog contracts - 🎯 9   🛡️ 9   🧠 6, about
   300-750 LOC. Best fit for public Headless.
3. Generate all labels from command ids only - 🎯 5   🛡️ 6   🧠 7, about
   600-1400 LOC. Tempting, but too rigid for real localization.

Accepted: option 2.

## Accepted Contract

Headless defines accessibility text keys:

```dart
final class RAccessibleTextKey {
  final String key;
  final RAccessibleTextPurpose purpose;
  final Set<RInterpolationSlot> slots;
  final bool mustIncludeVisibleLabel;
  final bool safetyCritical;
}
```

Apps and renderer packages provide localized values. Primitives consume
resolved text through a localization adapter.

## Catalog Rules

- Accessible names, descriptions, hints, errors, and status messages use keys.
- Visible label and accessible name share source data where possible.
- Label-in-name is enforced per locale, not only in English.
- Descriptions may include extra context, but names stay concise.
- Safety-critical labels require review in every supported locale.
- Interpolation slots are typed and escaped.
- Localized strings never become command ids.

## Clean Disk Requirements

Clean Disk must catalog labels for:

- Scan;
- Pause scan;
- Cancel scan;
- Search files and folders;
- Sort and filter;
- Reveal in Finder or platform equivalent;
- Add to queue;
- Remove from queue;
- Move to Trash;
- selected row details;
- cleanup candidate warning;
- skipped protected items.

Path names and file names are data, not localization keys.

## Locale Stress Rules

Tests cover:

- long German-like labels;
- compact CJK labels;
- RTL labels;
- mixed LTR/RTL path data;
- plural and count-sensitive status messages;
- command names with noun order changes;
- speech-control label-in-name in each locale.

## Description Versus Name Rules

- Name answers "what is this control?"
- Description answers "what extra context do I need?"
- Hint answers "how do I use it?"
- Error answers "what is wrong and how can I recover?"
- Status answers "what changed?"

Do not pack all of these into `aria-label`.

## Testing Requirements

- Missing key fails tests.
- Unused safety-critical key is reported.
- Label-in-name lint runs per locale.
- Interpolation slot mismatch fails tests.
- Bidi stress fixtures include accessible names and visible labels.
- Snapshot tests include name, description, and visible label separately.

## Failure Catalog

- English accessible name is localized, visible label is not.
- Button visible label says "Trash" but accessible name translates to "Delete
  forever".
- Safety warning string misses plural handling.
- `aria-label` contains long instructions instead of name.
- Command id is derived from localized text.
- RTL path is interpolated without bidi isolation.

## Release Gates

- No public primitive ships with hardcoded user-facing accessible text.
- Safety-critical labels pass locale review or the locale is not claimed.
- Accessible names are versioned with the localization catalog.
- Fallback locale behavior is explicit and visible in diagnostics.

## Summary

Accessible text is product text, not hidden code. Headless should catalog,
localize, lint, and test accessible names and descriptions with the same rigor
as visible UI.
