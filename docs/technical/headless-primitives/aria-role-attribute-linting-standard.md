# ARIA Role Attribute And Semantics Linting Standard

## Status

Accepted as a Headless assurance standard. Not implemented yet.

## Source Standards

- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- ARIA in HTML: https://www.w3.org/TR/html-aria/
- MDN ARIA reference: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference
- MDN `aria-activedescendant`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-activedescendant
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html

## Scope

This standard defines lint rules for ARIA roles, states, properties, and
Headless semantic contracts.

It applies to:

- web DOM adapters;
- Flutter semantics adapters;
- renderer manifests;
- component specs;
- conformance fixtures;
- generated documentation;
- third-party renderer review.

It does not replace runtime tests. It blocks known invalid patterns before
they reach runtime.

## Decision Options

Option A: Rely on browser and framework warnings - 🎯 4   🛡️ 4   🧠 2,
about 100-300 LOC.

- Low effort.
- Many invalid semantic combinations are not caught consistently.

Option B: Use generic a11y linters only - 🎯 6   🛡️ 6   🧠 4, about
300-800 LOC.

- Good baseline.
- Does not know Headless primitives, command contracts, or adapter gaps.

Option C: Headless semantic lint rules plus adapter-specific checks - 🎯 9
🛡️ 9   🧠 8, about 1000-2200 LOC.

- Accepted direction.
- Generic rules catch web errors.
- Headless rules catch primitive-specific contract violations.

## Accepted Direction

Headless should provide a semantic lint rule set.

Rule categories:

- role validity;
- required owned elements;
- required states and properties;
- prohibited nested roles;
- name and description requirements;
- focus relationship validity;
- active descendant validity;
- command routing consistency;
- disabled and readonly consistency;
- live region policy;
- privacy-safe semantic ids.

## Rule Severity

Severity levels:

- `error`: invalid or unsafe semantics, blocks release.
- `warning`: degraded behavior, requires review.
- `advisory`: improvement or platform-specific caveat.
- `adapterGap`: acceptable only when manifest declares degradation.
- `experimental`: rule under review.

Release gates decide which severities block.

## Required-Owned Rules

Examples:

- grid must own rows through valid structure or relationship;
- row must expose cells according to grid contract;
- tree item expansion state requires children or lazy loading state;
- menu owns menu items, not arbitrary tabbable widgets;
- listbox owns options;
- tablist owns tabs.

Virtualized widgets may use adapter-specific projection, but the semantic
contract must remain coherent.

## Relationship Rules

Lint must validate:

- `aria-activedescendant` target exists and is owned or controlled correctly;
- `aria-controls` target exists when relevant;
- `aria-owns` does not reorder content into nonsense;
- described-by and labelled-by targets are safe and present;
- no relationship points to hidden or stale element unless pattern allows it.

## Headless-Specific Rules

Examples:

- command id must match command router registry;
- disabled visual state must match semantic disabled state;
- selected row state must match selection model;
- active descendant must match focus model;
- renderer cannot add role outside primitive contract;
- raw product data cannot become DOM id;
- destructive command must have safety policy.

## Clean Disk Requirements

Clean Disk lint must catch:

- raw path as DOM id;
- row action bypassing command router;
- duplicate frozen cell semantics;
- move-to-trash command without disabled reason;
- progressbar with misleading value;
- chart without accessible fallback;
- stale row still marked actionable.

## API Shape Sketch

```text
SemanticLintRule
  id
  severity
  appliesTo
  check(snapshot, manifest)
  messageKey
  remediationKey

SemanticLintReport
  scenarioId
  adapterId
  findings
  blocked
```

## Conformance Scenarios

- invalid nested button fails lint;
- missing gridcell in row fails lint;
- active descendant pointing to removed node fails lint;
- raw path in id fails lint;
- renderer-added role outside contract fails lint;
- chart visual-only adapter reports blocked claim;
- disabled button without reason warns or errors by policy;
- adapter gap can pass only with declared degradation.

## Failure Catalog

- relying on visual review for ARIA correctness;
- generic linter misses Headless command mismatch;
- required owned elements missing in virtualized grid;
- stale `aria-activedescendant` after filter;
- disabled visual state but active command;
- raw query used in labelled-by id;
- warning ignored without release gate;
- third-party renderer bypasses lint;
- relationship target hidden by renderer;
- lint rule has no remediation guidance.

