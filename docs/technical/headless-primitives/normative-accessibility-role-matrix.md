# Normative Accessibility Role Matrix

## Status

Normative matrix for implementation and conformance.

## Primary Standards

- WAI-ARIA APG Patterns: https://www.w3.org/WAI/ARIA/apg/patterns/
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- MDN ARIA roles:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles
- Flutter accessibility:
  https://docs.flutter.dev/ui/accessibility

## Purpose

This file maps Headless primitive semantic intents to WAI-ARIA, MDN, and
Flutter Semantics expectations. It is not a direct ARIA implementation plan.
Flutter Semantics remains the default adapter; a web ARIA bridge is optional.

## Role Matrix

| Headless primitive | Semantic intent | ARIA/APG reference | Flutter mapping | Required notes |
| --- | --- | --- | --- | --- |
| `RTreeGrid` root | hierarchical grid | `treegrid` | `Semantics` container with row/column facts | expose multiselect/readonly/counts when known |
| TreeGrid row | row in treegrid | `row` with level/expanded/selected | row semantic node | no expanded fact for leaf rows |
| TreeGrid cell | grid cell | `gridcell` | labeled cell semantic node | cell focus optional in rows-first mode |
| TreeGrid column header | column header | `columnheader`, `aria-sort` | semantic label plus sort fact | focusable only if interactive |
| `RTreeView` future | tree | `tree`, `treeitem`, `group` | tree semantic group | expansion belongs to tree item |
| `RContextMenu` | command menu | `menu` | menu scope semantics | not arbitrary popover content |
| Menu item | command | `menuitem` | button/menu item semantics | disabled focus policy explicit |
| Checkbox menu item | toggle command | `menuitemcheckbox` | checked semantic fact | command id separate from label |
| Radio menu item | radio command | `menuitemradio` | checked semantic fact | group required |
| `RDialog` | modal dialog | `dialog` | route/scope semantics plus focus trap | label required |
| `RAlertDialog` | urgent dialog | `alertdialog` | dialog plus alert intent | use for urgent interruptive content |
| `RSplitPane` handle | splitter | `separator` with value | adjustable semantic value | keyboard resize required |
| `RTooltip` | description popup | `tooltip` | tooltip semantics/description | no focusable content |
| `RStatusRegion` | advisory live status | `status` | announcement/status effect | no focus movement |
| Alert status | urgent live update | `alert` | assertive announcement | not for ordinary progress |

## ARIA Attribute Intent Matrix

| Intent | ARIA equivalent | Headless source | Notes |
| --- | --- | --- | --- |
| selected | `aria-selected` | selection state | never equal to focus by default |
| disabled | `aria-disabled` | disabled policy | may remain focusable in composites |
| expanded | `aria-expanded` | expansion state | only for expandable nodes/triggers |
| busy | `aria-busy` | async state | coalesce progress announcements |
| readonly | `aria-readonly` | editability policy | useful for grid cells |
| multiselect | `aria-multiselectable` | selection mode | root grid/treegrid fact |
| sort | `aria-sort` | column sort descriptor | header only |
| key shortcuts | `aria-keyshortcuts` | shortcut registry | expose only implemented shortcuts |
| current | `aria-current` | navigation/current marker | not selection replacement |
| live | `aria-live` | StatusRegion policy | polite by default, assertive sparingly |

## Flutter Semantics Adapter Rules

- semantic facts are built from component state, not renderer guesses;
- semantic labels are provided by app/localization where user-facing;
- semantic values must not be logged by default;
- visible label must be included in accessible name;
- long structured dialog content should not become one giant description;
- virtualized row count means logical count, not built widget count.

## Required Conformance Checks

- every interactive primitive has role-equivalent semantic facts;
- every icon-only command has an accessible label;
- treegrid leaf rows do not expose expanded/collapsed;
- sorted column exposes sort fact on header;
- disabled states match configured focusability;
- status updates do not move focus;
- tooltip has no interactive descendants;
- split pane exposes adjustable value.

## Stop Rules

- Do not expose raw ARIA strings as core API.
- Do not let renderer invent semantic state.
- Do not use `aria-selected` to mean current page/path.
- Do not use `alert` for routine progress.
