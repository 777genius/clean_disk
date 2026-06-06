# Compliance Playbook - TreeGrid

## Status

Compliance checklist for `RTreeGrid`.

## Standards

- WAI-ARIA APG Treegrid:
  https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/
- MDN `treegrid` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/treegrid_role
- MDN `aria-activedescendant`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-activedescendant
- WAI-ARIA APG Names and Descriptions:
  https://www.w3.org/WAI/ARIA/apg/practices/names-and-descriptions/

## Compliance Strategy

Flutter default uses logical focus and Semantics. Web may later map to roving
tabindex or `aria-activedescendant`, but core Headless must expose platform-
neutral focus facts.

## Required Evidence

Behavior:

- rows-first keyboard navigation;
- expand/collapse through keyboard;
- focus and selection independent;
- disabled row policy applied;
- range selection if enabled;
- context menu opens from keyboard.

Semantics:

- root labelled;
- row/column counts where known;
- row index for visible rows;
- level/depth;
- expanded only for expandable rows;
- selected state separate from focus;
- sorted header state.

Virtualization:

- built rows bounded by visible range plus overscan;
- semantic rows bounded by visible range;
- scroll-to-focused offscreen target works;
- no full tree required.

## Roving Focus Vs Active Descendant

Allowed strategies:

1. Logical focus on root plus active descendant facts.
2. Roving platform focus between visible rows/cells.

Core API must not force either. Web bridge can choose based on measured
screen-reader behavior.

## Flutter Test Cases

- `tester.ensureSemantics()`;
- keyboard script for row movement;
- semantics matcher for selected/expanded/sorted facts;
- built row count assertion;
- guideline checks for labels and tap target where renderer exposes actions.

## Manual AT Cases

- VoiceOver reads row and level;
- NVDA reads selected state;
- sorted header announced;
- context menu opens from focused row;
- virtual row index does not claim built-row count as total.

## Stop Rules

- Do not claim APG treegrid parity without keyboard and AT evidence.
- Do not expose `aria-activedescendant` as core Flutter API.
- Do not make leaf rows expandable.
- Do not let virtualization hide focus target without scroll effect.
