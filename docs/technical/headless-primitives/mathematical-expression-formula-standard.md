# Mathematical Expression And Formula Standard

## Status

Accepted direction for Headless. Optional for Clean Disk MVP, important for
community Headless and evidence-rich products. Not implemented yet.

## Source Standards

- MDN `math`: https://developer.mozilla.org/en-US/docs/Web/MathML/Reference/Element/math
- MDN MathML getting started: https://developer.mozilla.org/en-US/docs/Web/MathML/Tutorials/For_beginners/Getting_started
- MDN MathML `semantics`: https://developer.mozilla.org/en-US/docs/Web/MathML/Reference/Element/semantics
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 1.1.1 Non-text Content: https://www.w3.org/WAI/WCAG22/Understanding/non-text-content.html
- W3C MathML Core: https://www.w3.org/TR/mathml-core/

## Problem

Most product UIs avoid full mathematical notation, but formulas still appear in
confidence scores, benchmark reports, storage accounting explanations, percent
calculations, cost estimates, charts, documentation, and support evidence. If a
formula is rendered as plain styled text or an image, users lose structure and
copy/export quality. If Headless tries to evaluate formulas, it takes on domain
logic it should not own.

Headless needs a display-only mathematical expression contract.

## Decision Options

1. Treat formulas as plain text - 🎯 5   🛡️ 5   🧠 1, about 20-80 LOC.
   Acceptable for MVP prose, weak for public Headless.
2. Add display-only formula semantics - 🎯 8   🛡️ 8   🧠 5, about
   300-800 LOC. Best fit.
3. Add formula parser/evaluator - 🎯 3   🛡️ 5   🧠 10, about 2500-7000 LOC.
   Not Headless responsibility.

Accepted: option 2.

## Accepted Contract

Headless receives formula display facts:

```dart
final class RFormulaDisplayModel {
  final String formulaId;
  final String plainText;
  final String? mathMl;
  final String? latexSource;
  final String? spokenText;
  final String? explanationRef;
  final RFormulaKind kind;
  final RCopyPolicy copyPolicy;
}
```

Evaluation, units, confidence, and accounting remain product or domain logic.

## Formula Kinds

```text
calculation:
  human-readable formula behind a displayed value

definition:
  notation defining a term

benchmark:
  performance or throughput equation

estimate:
  formula with uncertainty or assumptions

constraint:
  min, max, threshold, or policy condition

decorative:
  visual math style without decision meaning
```

## Rules

- Formula display is not executable logic.
- Product supplies plain text fallback.
- Complex formulas can include MathML where adapter supports it.
- Copy policy decides plain text, MathML, LaTeX, or blocked.
- Explanation link is required when formula affects decisions.
- Units and exactness are represented by quantity models, not inferred from
  formula text.
- Unknown or estimated values must not be hidden inside a formula.
- Formula ids are stable only inside current document or component scope.

## Clean Disk Requirements

Clean Disk may use formulas for:

- reclaim estimate explanation;
- percent of scanned root;
- scan throughput;
- benchmark comparison;
- confidence score explanation;
- support evidence.

MVP can use plain-language explanations instead of visible formulas. If a
formula appears near cleanup decisions, it must link to evidence and exactness.

## Web Mapping

For web adapters:

- MathML `math` can represent structured formulas;
- MathML `semantics` can carry alternate text or source annotation;
- plain text fallback is required when support is incomplete;
- images of formulas require text alternative and should be avoided for
  important formulas.

Flutter adapters may render plain text first, then support MathML or a renderer
adapter later.

## Accessibility Rules

- Users can access spoken or plain-text formula.
- Formula does not rely on visual baseline, superscript, or color alone.
- Explanation is reachable by keyboard.
- Copy preserves a useful source representation.
- Long formulas are not announced automatically in dense table cells.
- Formula references in charts and reports remain linked to data.

## Testing Requirements

- Plain text fallback exists for every non-decorative formula.
- Copy policy returns expected representation.
- Formula explanation is reachable.
- Dense table formula does not flood announcements.
- Export includes formula source and fallback.
- Localization does not change stable formula id.
- Estimated formula exposes uncertainty.

## Failure Catalog

- Formula image has no text alternative.
- Reclaim estimate formula implies exactness it does not have.
- Copy loses superscript or denominator meaning.
- Formula text is used as executable business logic.
- Screen reader announces a long formula inside every row.
- MathML unavailable path renders blank.

## Release Gates

- Public formula component is display-only.
- Formula fallback is mandatory.
- Clean Disk cleanup decisions use evidence models, not formula text.
- Export adapters preserve formula source and plain text.
- MathML support is adapter capability, not core requirement.

## Summary

Formulas are display and explanation artifacts in Headless. They need fallback,
copy policy, optional MathML, and evidence links, but evaluation remains outside
the UI kit.
