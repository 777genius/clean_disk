# Description Details And Help Association Standard

## Status

Accepted direction for Headless. Extends accessible name and description rules.
Not implemented yet.

## Source Standards

- MDN accessible description: https://developer.mozilla.org/en-US/docs/Glossary/Accessible_description
- MDN `aria-describedby`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-describedby
- MDN `aria-description`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-description
- MDN `aria-details`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-details
- MDN `details`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/details
- MDN `summary`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/summary
- Accessible Name and Description Computation: https://www.w3.org/TR/accname-1.2/
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html

## Problem

Many components need supporting explanation: why a button is disabled, what a
warning means, why a cleanup candidate is risky, how to repair permission, or
where detailed evidence lives. Teams often misuse labels, tooltips, hidden text,
or huge descriptions. The result is either inaccessible help or overwhelming
screen-reader output.

Headless needs explicit association types for descriptions, details, help, and
evidence.

## Decision Options

1. Use `aria-describedby` everywhere - 🎯 5   🛡️ 5   🧠 2, about
   80-200 LOC. Works for short text, wrong for structured details.
2. Add typed association contracts - 🎯 9   🛡️ 9   🧠 5, about
   350-900 LOC. Best fit.
3. Build a full help system primitive - 🎯 4   🛡️ 6   🧠 9, about
   1500-4000 LOC. Useful later, too broad for core semantics.

Accepted: option 2.

## Accepted Contract

Headless models related explanatory content:

```dart
final class RHelpAssociation {
  final String ownerId;
  final RHelpAssociationKind kind;
  final String? shortDescription;
  final String? detailsRef;
  final String? helpActionId;
  final RDisclosurePolicy disclosurePolicy;
  final RPrivacyClass privacyClass;
}
```

Components decide where association slots exist. Products decide content and
privacy. Adapters map to platform semantics.

## Association Kinds

```text
shortDescription:
  concise plain text supplement

instruction:
  guidance needed before input or command

errorMessage:
  validation or operation error explanation

structuredDetails:
  navigable details with lists, tables, links, or evidence

helpLink:
  external or in-app help target

evidence:
  supporting facts behind risk, estimate, or recommendation

disabledReason:
  why a control is unavailable
```

## Rules

- Name answers "what is it"; description answers "what else should I know".
- Short flat descriptions can use description semantics.
- Structured content uses details association, not a giant description.
- Disabled controls need discoverable reasons where action is expected.
- Tooltip-only help is insufficient.
- Repeated row descriptions should not flood virtualized navigation.
- Help content must not contain hidden authority or surprise commands.
- Details panes can be associated with selected row, but selection alone does
  not transfer command authority.

## Clean Disk Requirements

Clean Disk uses these associations for:

- disabled cleanup actions;
- stale scan warnings;
- permission repair cards;
- reclaim estimate evidence;
- skipped item explanations;
- scan quality details;
- rule-pack recommendation evidence;
- delete queue validation errors;
- daemon disconnected or incompatible state;
- support bundle redaction explanation.

## Description Versus Details

Use short description for:

- one-sentence disabled reason;
- form instruction;
- concise warning.

Use structured details for:

- evidence list;
- table of skipped reasons;
- permission repair steps;
- cleanup receipt item outcomes;
- risk explanation with links.

## Web Mapping

For web adapters:

- `aria-describedby` references short descriptive text;
- `aria-description` can provide flat text where references are not practical;
- `aria-details` points to structured, navigable content;
- native `details` and `summary` can expose disclosure UI where appropriate.

Flutter adapters should represent the same association in `Semantics` and
keyboard navigation even when ARIA attributes are unavailable.

## Accessibility Rules

- Associated content must be reachable by keyboard.
- Details content should have heading or label.
- Screen reader should not announce long evidence on every focus.
- User can open details on demand.
- Help links must have clear destination and context.
- Live updates to descriptions are announced only when meaningful.

## Testing Requirements

- Disabled button exposes disabled reason.
- Short description is included in accessibility snapshot.
- Structured details are reachable and not flattened into giant label.
- Tooltip-hidden help has keyboard alternative.
- Virtualized rows avoid repeated long descriptions.
- Privacy-sensitive evidence is redacted in diagnostics.
- Details association survives renderer replacement.

## Failure Catalog

- Tooltip is the only explanation for destructive disabled button.
- Entire receipt JSON is put into accessible description.
- Row warning repeats 20 seconds of text per arrow key.
- Details panel is visual only.
- Disabled reason contains raw path or daemon token.
- Help link says "learn more" without context.

## Release Gates

- Headless exposes typed help associations.
- Design system maps disabled reasons and details links consistently.
- Clean Disk destructive controls show current validation reason.
- Long evidence uses structured details, not flat description.
- Accessibility snapshots cover short and structured association paths.

## Summary

Descriptions and details are different semantic tools. Headless should model
short descriptions, structured details, help links, evidence, and disabled
reasons so complex apps stay understandable without becoming verbose.
