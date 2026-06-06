# Badge Chip Tag And Token Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 1.4.1 Use of Color: https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 2.5.3 Label in Name: https://www.w3.org/WAI/WCAG22/Understanding/label-in-name.html
- MDN `status` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN `button` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/button_role
- MDN `checkbox` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/checkbox_role
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers badges, chips, tags, pills, tokens, counters, status chips,
filter chips, removable chips, selectable chips, risk tags, category tags,
permission badges, and compact metadata tokens.

There is no single ARIA role called "chip". The primitive must choose semantics
based on behavior: static text, status, button, checkbox, radio, option, or
navigation item.

## Decision Options

1. Behavior-driven `TokenPrimitive` with role adapters - 🎯 9   🛡️ 9   🧠 7, roughly 700-1400 LOC.
   Best fit. It prevents visual chips from hiding whether they are static,
   selectable, removable, or commandable.
2. Treat all chips as buttons - 🎯 4   🛡️ 5   🧠 4, roughly 300-700 LOC.
   Overstates interactivity and creates false actions.
3. Treat all chips as static text - 🎯 5   🛡️ 5   🧠 3, roughly 200-500 LOC.
   Fine for metadata, but fails filter/removable/selectable chips.

Accepted direction: option 1.

## Token Types

Static metadata token:

- conveys a label or category;
- not focusable unless it has tooltip/details command;
- example: "System protected".

Status badge:

- conveys state or count;
- may be included in a status region if dynamic;
- example: "17 skipped".

Filter chip:

- toggles a filter value;
- checkbox or toggle semantics depending on model;
- must expose selected/checked state.

Choice chip:

- mutually exclusive choice;
- radio or segmented control semantics.

Removable token:

- value plus remove command;
- remove button must be separately accessible or token must expose a clear
  action.

Navigation token:

- navigates to a route or filtered view;
- link/navigation semantics.

## Primitive Boundary

Headless owns:

- token id;
- token type;
- label and description;
- state: static, selected, checked, current, disabled, warning, error, stale;
- count/value metadata;
- remove action contract;
- role adapter choice;
- color-independent meaning;
- privacy class;
- grouping and overflow behavior.

Renderer owns:

- shape, color, icon, border, density, wrap layout, hover and focus visuals;
- removable affordance visual;
- compact truncation.

Application owns:

- token values and business meaning;
- filter/query state;
- localization;
- privacy and redaction.

## Required Rules

MUST:

- choose semantics from behavior, not shape;
- provide text meaning for color-coded statuses;
- keep visible token text inside accessible name when token is interactive;
- make remove command keyboard reachable and labelled;
- expose count changes through status only when important and throttled;
- use stable ids separate from localized labels;
- keep raw path/query/token values classified before display/logging.

SHOULD:

- avoid focusable static metadata tokens;
- group many tokens with an accessible label;
- collapse overflow tokens behind a labelled control;
- provide details for truncated token text;
- keep chip text short and predictable.

MUST NOT:

- make every chip a button because it has hover styling;
- use color alone for risk tier or warning;
- make remove icons unlabeled;
- use token label as domain id;
- put destructive behavior behind a tiny removable chip without confirmation.

## Clean Disk Mapping

Accepted token uses:

- risk tier badge: static/status token with text;
- "Skipped 17": status badge with details action nearby;
- filter chips: checkbox-like filters;
- scan target chips in compact layout: navigation or choice depending behavior;
- path segments: breadcrumb standard, not generic chips;
- delete queue item tags: metadata tokens, not cleanup authority.

For cleanup safety, selecting or removing a token never creates delete
authority. Delete authority comes only from validated DeletePlan.

## Conformance Tests

Minimum tests:

- static token is not focusable by default;
- filter chip exposes checked/selected state;
- removable chip exposes remove action with label;
- color-only status token fails conformance;
- token overflow remains keyboard reachable;
- dynamic count update does not spam announcements;
- token id survives localization;
- risk token exposes text and icon/color is redundant;
- raw path token is redacted where policy requires;
- chip group has accessible label when ambiguous.

## Failure Catalog

- Pill shape used as button without keyboard activation.
- Red badge means error but no text says error.
- Removable chip has an unlabeled "x".
- Filter chips update query but expose no checked state.
- Huge path token leaks private folder names into logs.
