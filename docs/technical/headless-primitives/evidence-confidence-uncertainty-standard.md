# Evidence Confidence And Uncertainty Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- MDN `meter` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/meter_role
- MDN `progressbar` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/progressbar_role
- MDN `aria-valuetext`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-valuetext

## Scope

This standard defines how Headless primitives represent uncertain, estimated,
partial, stale, or evidence-backed facts.

It applies to:

- disk usage metrics;
- reclaim estimates;
- progress estimates;
- cleanup safety;
- diagnostics;
- scan quality;
- recommendation cards;
- charts;
- details inspectors;
- exports and receipts.

It does not compute evidence. It exposes evidence quality from product layers
without overstating certainty.

## Decision Options

Option A: Show one value and hide uncertainty - 🎯 3   🛡️ 3   🧠 2, about
80-200 LOC.

- Clean visuals.
- Misleads users when sizes, reclaim estimates, or scan coverage are partial.

Option B: Per-feature warning text - 🎯 5   🛡️ 5   🧠 4, about
300-900 LOC.

- Flexible.
- Inconsistent and hard to test across UI kit.

Option C: Evidence and confidence model in view contracts - 🎯 9   🛡️ 9
🧠 7, about 900-1700 LOC.

- Accepted direction.
- Values carry confidence, evidence source, and uncertainty display policy.
- Destructive actions can fail closed when confidence is insufficient.

## Accepted Direction

Headless must allow values and commands to carry evidence facts:

- evidence source;
- confidence level;
- freshness;
- completeness;
- estimate type;
- affected scope;
- user-facing qualifier;
- action safety impact.

Visual renderers must not remove uncertainty qualifiers.

## Confidence Levels

Levels:

- `verified`;
- `high`;
- `medium`;
- `low`;
- `unknown`;
- `conflicting`;
- `notApplicable`.

Confidence is not severity. A low-confidence value can be harmless or safety
critical depending on context.

## Evidence Sources

Sources:

- direct platform API;
- scanner result;
- cached snapshot;
- user input;
- daemon receipt;
- rule pack;
- heuristic;
- third-party tool;
- remote source;
- unavailable.

Each source can have freshness and compatibility information.

## Uncertainty Display Rules

Uncertainty should be visible through:

- text qualifier;
- icon with accessible label;
- details row;
- tooltip or popover for explanation;
- export field;
- receipt evidence section;
- command disable reason.

Do not rely on color alone.

Examples:

- `Estimated reclaim: 28.6 GB`;
- `Partial scan: 17 skipped items`;
- `Low confidence because snapshots may retain storage`;
- `Verified receipt: moved to Trash`.

## Action Rules

Commands can specify minimum confidence:

- view details: unknown allowed;
- export report: low allowed with label;
- add to queue: medium maybe allowed;
- move to Trash: requires current validation;
- permanent destructive action: requires verified plan and policy.

Unknown confidence fails closed for risky actions.

## Clean Disk Requirements

Clean Disk evidence facts:

- scan quality;
- allocated size source;
- logical size source;
- reclaim estimate confidence;
- platform identity validation;
- Trash capability;
- cleanup receipt durability;
- cloud placeholder state;
- snapshot or shared extent caveat.

Rules:

- approximate reclaim is labeled approximate;
- cleanup plan confidence is separate from scan size confidence;
- receipt confidence is separate from restore confidence;
- details panel can explain why confidence is low.

## API Shape Sketch

```text
EvidenceFact
  source
  confidence
  freshness
  completeness
  estimateKind
  qualifierKey
  safetyImpact

EvidencedValue<T>
  value
  unit
  evidence
  displayPolicy
```

## Conformance Scenarios

- low-confidence reclaim estimate shows qualifier;
- warning icon has accessible label and text alternative;
- export includes evidence source and confidence;
- destructive command disabled when validation confidence is unknown;
- chart segment with estimated data is distinguishable without color;
- stale cache is visible as stale;
- receipt shows verified operation outcome separately from restore support;
- conflicting evidence shows conflict, not averaged truth.

## Failure Catalog

- approximate value shown as exact;
- color-only confidence indicator;
- scan quality hidden in details only;
- destructive command ignores evidence confidence;
- receipt implies restore support without proof;
- chart hides estimated data status;
- export drops uncertainty fields;
- stale cached data displayed as current;
- conflicting sources merged silently;
- renderer removes qualifier for compact layout.

