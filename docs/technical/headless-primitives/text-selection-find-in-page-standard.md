# Text Selection And Find In Page Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN Selection API: https://developer.mozilla.org/en-US/docs/Web/API/Selection_API
- MDN Selection interface: https://developer.mozilla.org/en-US/docs/Web/API/Selection
- MDN CSS `user-select`: https://developer.mozilla.org/docs/Web/CSS/user-select
- MDN `Window.find()`: https://developer.mozilla.org/en-US/docs/Web/API/Window/find
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 1.4.10 Reflow: https://www.w3.org/WAI/WCAG22/Understanding/reflow.html

## Problem

Users rely on text selection, copy, browser find, translation tools, dictionary
extensions, screen magnifiers, and assistive overlays. UI kits often break this
by using `user-select: none`, canvas-only text, virtualized hidden text, custom
selection models, or search widgets that conflict with browser find.

Headless needs rules for selectable text and findability.

## Decision Options

1. Leave text selection to renderer CSS - 🎯 4   🛡️ 4   🧠 2, about 0-80 LOC.
   Too easy to break.
2. Add selection and findability metadata - 🎯 9   🛡️ 9   🧠 6, about 300-750
   LOC. Best fit.
3. Build a full custom selection engine - 🎯 4   🛡️ 5   🧠 10, about
   1800-4000 LOC. Too heavy and likely worse than platform behavior.

Accepted: option 2.

## Accepted Contract

Headless exposes text selection policy:

```dart
final class RTextSelectionPolicy {
  final RSemanticId id;
  final bool userSelectable;
  final bool copyAllowed;
  final bool appearsInFind;
  final bool isVirtualized;
  final RTextPrivacyClass privacyClass;
}
```

Renderers map policy to platform selection and searchable text behavior.

## Rules

- User-facing text is selectable by default unless it is an interactive control
  label where selection conflicts with activation.
- Long paths, error messages, diagnostics, and report text are copyable through
  explicit commands even when row text itself is not freely selectable.
- Browser find is not replaced by product search.
- Custom search controls do not hijack Ctrl+F or platform find shortcuts unless
  the app explicitly owns an application-mode surface and provides equivalent
  behavior.
- Virtualized content declares that not all rows are present in browser find.
- Canvas or custom-painted text needs semantic text alternatives.
- Selection is privacy-aware for tokens, secrets, and sensitive paths.

## Clean Disk Requirements

Clean Disk must support copying:

- selected item path through explicit command;
- warning text;
- error code;
- support bundle id;
- report summary;
- daemon version.

TreeGrid virtualization means browser find cannot search the full scan result.
Product search must be clearly separate and backed by Rust indexes.

## Findability Classes

```text
nativeFindable:
  text is present in platform text layer

productSearchable:
  text is searchable through application query

notFindable:
  text is decorative or intentionally hidden

sensitive:
  text is not exposed to global find or copy by default
```

## Testing Requirements

- Important static text is selectable or has copy command.
- Ctrl+F remains browser find unless explicitly overridden.
- Product search does not claim to be browser find.
- Virtualized TreeGrid documents find limitations.
- Sensitive values are redacted from copy fixtures by default.
- Text scaling and high contrast do not remove selection visibility.

## Failure Catalog

- `user-select: none` applied to the whole app.
- Error message cannot be copied into support.
- Browser find misses visible text with no explanation.
- Product search steals Ctrl+F and cannot search current visible labels.
- Canvas treemap labels are visually visible but absent from semantics.
- Copy command includes hidden token.

## Release Gates

- Text-bearing primitives declare selection policy.
- Full-app `user-select: none` is forbidden.
- Virtualized search limitations are documented.
- Sensitive copy requires explicit command and redaction policy.

## Summary

Selectable and findable text is an accessibility feature. Headless should make
selection, copy, native find, product search, and privacy boundaries explicit.
