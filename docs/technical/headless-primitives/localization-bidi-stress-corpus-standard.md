# Localization Bidi And Stress Corpus Standard

## Status

Accepted as a Headless assurance standard. Not implemented yet.

## Source Standards

- MDN Internationalization guide: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Internationalization
- MDN `Intl.Segmenter`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/Segmenter
- MDN `Intl.NumberFormat`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/NumberFormat
- Unicode Bidirectional Algorithm: https://www.unicode.org/reports/tr9/
- W3C Internationalization: https://www.w3.org/International/
- WCAG 3.1.1 Language of Page: https://www.w3.org/WAI/WCAG22/Understanding/language-of-page.html
- WCAG 3.1.2 Language of Parts: https://www.w3.org/WAI/WCAG22/Understanding/language-of-parts.html

## Scope

This standard defines a localization and bidi stress corpus for Headless
primitives.

It applies to:

- labels;
- accessible names;
- descriptions;
- paths;
- filenames;
- numbers;
- units;
- dates;
- plurals;
- command names;
- table cells;
- charts;
- exports;
- diagnostics.

It does not define product translations. It defines test inputs that expose
layout, semantics, and parsing failures.

## Decision Options

Option A: Test English only - 🎯 2   🛡️ 2   🧠 1, about 50-100 LOC.

- Fast.
- Misses real failures in public UI kits.

Option B: Test a few translated screenshots - 🎯 5   🛡️ 5   🧠 4, about
300-800 LOC.

- Better.
- Not enough for bidi paths, long labels, plural rules, and grapheme clusters.

Option C: Shared localization stress corpus plus semantic assertions - 🎯 9
🛡️ 9   🧠 7, about 900-1800 LOC.

- Accepted direction.
- Reusable by every primitive and renderer.
- Catches overflow, bidi, sorting, and accessible-name regressions.

## Accepted Direction

Headless should maintain a stress corpus.

Corpus includes:

- pseudo-localized long strings;
- RTL labels;
- mixed LTR and RTL paths;
- emoji and grapheme clusters;
- combining marks;
- CJK strings;
- narrow and wide glyph scripts;
- plural edge cases;
- unit formatting fixtures;
- date and time fixtures;
- filenames with control-like characters;
- truncated text expectations.

## Bidi Rules

Any inserted user or filesystem text must be isolated.

Rules:

- do not concatenate raw path into sentence without isolation;
- preserve segment order in path display;
- avoid using punctuation as only separator cue;
- test RTL app locale with LTR path;
- test LTR app locale with RTL filename;
- keep accessible name meaningful after isolation.

## Grapheme And Selection Rules

Text ranges must respect grapheme clusters.

Applies to:

- search highlighting;
- typeahead;
- truncation;
- copy selection;
- cursor movement;
- accessible label slicing;
- diagnostic excerpts.

Do not split emoji sequences, combining marks, or surrogate pairs.

## Layout Stress Rules

Stress tests must include:

- 200 percent text scale equivalent;
- very long command labels;
- long folder names;
- narrow compact width;
- high contrast mode;
- dense table rows;
- right-to-left layout;
- mixed-direction table cells.

Text may truncate only when full text is discoverable by policy.

## Clean Disk Requirements

Clean Disk stress fixtures:

- long localized scan target labels;
- RTL folder name inside LTR path;
- long cache folder path;
- bytes and rates in locale formats;
- delete confirmation in German-like long text;
- plural skipped items;
- compact toolbar labels;
- disk map legend labels.

Rules:

- raw path display uses bidi isolation.
- table sort uses raw quantity, not localized display.
- delete confirmation must not overflow in long locale.

## API Shape Sketch

```text
LocalizationStressCase
  id
  locale
  direction
  textSamples
  quantitySamples
  pathSamples
  expectedAssertions

StressCorpusRunner
  runPrimitive(primitive, cases)
  assertNoOverflow()
  assertSemanticName()
  assertBidiIsolation()
```

## Conformance Scenarios

- pseudo-localized toolbar does not overlap;
- RTL path segment remains readable and isolated;
- search highlight does not split grapheme;
- plural count uses locale rule;
- table sort ignores localized number text;
- accessible name remains stable under long translation;
- compact delete dialog fits or reflows;
- chart legend labels have full accessible text.

## Failure Catalog

- English-only conformance;
- raw path breaks RTL sentence;
- truncation splits emoji;
- label overflow hidden without accessible full text;
- plural message concatenated manually;
- quantity sorted as localized string;
- pseudo-locale changes command id;
- chart legend clips critical label;
- control character in filename affects layout;
- long translation hides destructive warning.

