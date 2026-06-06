# Internationalization And Bidi Contract

## Status

Implementation contract. Not implemented yet.

## Primary Standards

- Flutter internationalization:
  https://docs.flutter.dev/ui/internationalization
- Flutter `TextDirection`:
  https://api.flutter.dev/flutter/dart-ui/TextDirection.html
- MDN `dir` attribute:
  https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/dir
- WCAG 2.2 Label in Name:
  https://www.w3.org/TR/WCAG22/
- W3C Internationalization:
  https://www.w3.org/International/

## Core Decision

Headless must be direction-aware and locale-aware without owning product
localization.

## Direction Rules

Flutter low-level APIs do not assume a default text direction. Headless
components must not hardcode left/right when start/end is intended.

Use:

```text
start/end
before/after
TextDirection
EdgeInsetsDirectional
AlignmentDirectional
```

Use visual left/right only when physical direction is intended, for example
"move splitter left".

## External Text Direction

MDN recommends `dir=auto` for external/user data with unknown directionality.
Flutter does not expose HTML `dir=auto` directly in native widgets, so Headless
needs a display-text policy:

```text
TextDirectionPolicy
  ambient
  explicitLtr
  explicitRtl
  contentAuto
```

`contentAuto` is an adapter policy. It may require utility detection or web
bridge support later.

## File Paths And Mixed Direction Text

Clean Disk displays paths that may contain mixed LTR/RTL names, symbols, and
separators.

Rules:

- path identity is not display text;
- display path can use bidi isolation strategy;
- separators should not reorder unpredictably;
- truncation should preserve meaningful end segments where possible;
- copy path command copies raw path, not visually reordered text.

## Localization Boundaries

Headless owns no product strings except generic component diagnostics.

Component accepts:

```text
label
semanticLabel
description
textValue
localizedShortcutLabel
```

Application/localization package provides user-facing strings.

## Label In Name

WCAG requires visible text labels to be included in accessible names for user
interface components.

Rules:

- if button/menu item has visible text, accessible label includes that text;
- icon-only controls require semantic label;
- localized label and semantic label must stay in sync;
- tooltip cannot be the only accessible name for a control.

## Sorting And Collation

Headless should not implement locale collation for backend-owned data.

For eager local collections:

```text
CollationPolicy
  none
  localeAware(locale)
  customComparator
```

Clean Disk sorting lives in Rust/daemon contracts.

## Conformance Tests

- RTL layout flips start/end spacing;
- visual left/right commands remain physical when specified;
- visible label is contained in semantic label;
- icon-only controls require label;
- path display with mixed direction does not corrupt copy value;
- textValue used for typeahead is separate from widget rendering;
- locale change does not change command identity.

## Stop Rules

- Do not hardcode LTR layout.
- Do not use localized text as command id.
- Do not let tooltip be the only control name.
- Do not sort backend-owned data in Flutter for locale behavior.
