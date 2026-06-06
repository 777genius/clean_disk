# Adaptive Symbol And Plain Language Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WAI-Adapt Overview: https://www.w3.org/WAI/adapt/
- WAI-Adapt Explainer: https://www.w3.org/TR/adapt/
- WAI-Adapt Symbols Module: https://www.w3.org/TR/adapt-symbols/
- AAC Symbols Registry: https://www.w3.org/TR/aac-registry/
- WCAG 1.1.1 Non-text Content: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 3.1.5 Reading Level: https://www.w3.org/WAI/WCAG21/Understanding/reading-level.html
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html

## Problem

Icons, labels, warnings, and command names are often too abstract for some users,
especially in technical tools. WAI-Adapt explores semantic personalization and
symbols for users who benefit from AAC-style symbols, plain-language labels, or
alternate explanations. Headless already handles visual tokens and localization,
but it also needs concept-level metadata that can support alternate symbol and
plain-language renderers.

This is not a replacement for normal labels. It is an additional semantic layer.

## Decision Options

1. Leave plain language and symbols to product copy - 🎯 5   🛡️ 5   🧠 2,
   about 0-100 LOC. Good for MVP apps, weak for public Headless.
2. Add concept metadata and optional adaptive symbol slots - 🎯 9   🛡️ 8
   🧠 6, about 350-900 LOC. Best fit for community primitives.
3. Bundle a full AAC symbol library - 🎯 3   🛡️ 4   🧠 9, about 2000-5000 LOC
   plus licensing risk. Not appropriate for Headless core.

Accepted: option 2.

## Accepted Contract

Headless primitives expose concept metadata:

```dart
final class RAdaptiveConcept {
  final RSemanticId id;
  final String stableConceptCode;
  final String defaultLabel;
  final String? plainLanguageLabel;
  final String? plainLanguageDescription;
  final List<String> symbolCodes;
  final bool isSafetyCritical;
  final bool isDestructive;
}
```

Renderers may use concept metadata to display alternate labels, helper text, or
symbols when an app profile enables them.

## Rules

- Default label remains present and localized.
- Plain-language text must not change command meaning.
- Symbols supplement labels, not replace them by default.
- Safety-critical commands need explicit plain-language descriptions.
- Concept codes are stable identifiers, not localized strings.
- Product-specific concept codes live outside Headless core.
- Symbol packs are adapters with license and cultural review.

## Clean Disk Requirements

Clean Disk can use adaptive concepts for:

- Scan;
- Pause;
- Stop;
- Search;
- Sort;
- Filter;
- Add to queue;
- Move to Trash;
- Skipped;
- Warning;
- System protected;
- In use;
- Reclaim estimate;
- Full path;
- Restore receipt.

Dangerous cleanup flows must provide plain-language summaries even in expert
mode.

## Plain Language Rules

Plain-language descriptions answer:

- What will happen?
- What will not happen?
- Can it be undone?
- Which items are affected?
- Is the estimate exact or uncertain?
- What should the user do next?

For Headless, these are slots and requirements. Product copy owns final wording.

## Symbol Adapter Rules

Symbol adapters must provide:

- symbol pack identity;
- license metadata;
- locale and culture assumptions;
- supported concept codes;
- fallback behavior;
- high contrast and text alternative support;
- review status.

No symbol pack becomes a core dependency.

## Testing Requirements

- Test concept metadata exists for safety-critical primitives.
- Test symbol adapter fallback when a concept has no symbol.
- Test plain-language profile in compact and wide layouts.
- Test labels remain available when symbols are enabled.
- Test localization and bidi with plain-language descriptions.
- Test destructive confirmation with simplified wording.

## Failure Catalog

- Symbol replaces text and becomes ambiguous.
- Plain-language label changes command identity.
- A warning icon has no concept code.
- Symbol pack license is incompatible with public distribution.
- Expert mode removes the only understandable explanation.
- Localized symbol meaning is culturally wrong.

## Release Gates

- Core primitives expose concept slots for safety-critical commands.
- Symbol packs are optional adapters.
- Plain-language content is localized and testable.
- Safety-critical flows cannot rely on icons alone.

## Summary

Adaptive symbols and plain language belong at concept level. Headless should
publish stable concept metadata and let apps or adapters choose how to render it.
