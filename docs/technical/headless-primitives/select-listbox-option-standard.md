# Select Listbox And Option Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Listbox Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/listbox/
- WAI-ARIA APG Combobox Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/combobox/
- MDN `listbox` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/listbox_role
- MDN `option` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/option_role
- MDN `select`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/select
- MDN `aria-activedescendant`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-activedescendant
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers select fields, listboxes, popup option lists, grouped
options, single-select, multi-select, typeahead, virtualized options, option
descriptions, and option privacy.

It does not cover command palettes or editable combobox search behavior, which
is defined in the combobox/search standard.

## Decision Options

1. Shared `SelectableCollection` foundation with `Select` and `Listbox`
   wrappers - 🎯 9   🛡️ 9   🧠 8, roughly 1000-2200 LOC.
   Best fit. It reuses collection identity, focus, typeahead, selection, and
   virtualization while preserving select/listbox semantics.
2. Build custom dropdowns directly on overlay/menu primitives - 🎯 5   🛡️ 6   🧠 6, roughly 700-1600 LOC.
   Tempting, but menus and listboxes have different selection semantics.
3. Use native select wherever possible and forbid custom listbox - 🎯 6   🛡️ 8   🧠 4, roughly 300-800 LOC.
   Strong for simple web forms, too restrictive for Flutter desktop/web custom
   renderer and rich option layouts.

Accepted direction: option 1.

## Choosing The Pattern

Use native-like select when:

- a single value is chosen from a compact list;
- options are plain text;
- custom row content is not needed.

Use listbox when:

- options are visible as a list;
- multi-selection is needed;
- typeahead and keyboard navigation are needed;
- options are static choices, not commands.

Use combobox when:

- the user can type or filter;
- the popup is tied to text input;
- suggestions are dynamic.

Use grid or TreeGrid when:

- options contain interactive descendants;
- row content has columns, buttons, checkboxes, or links;
- options require complex structure.

## Primitive Boundary

Headless owns:

- option ids and group ids;
- selected ids and focused option id;
- active descendant policy;
- typeahead buffer;
- selection follows focus policy;
- multi-selection model;
- grouped option labels;
- virtualized position metadata;
- disabled/readonly option policy;
- option text value for typeahead;
- privacy class for option labels.

Renderer owns:

- trigger visuals, popup visuals, option row layout, icons, check marks, density,
  and animations.

Application owns:

- option data source;
- validation rules;
- persistence;
- localization;
- domain meaning of selected values.

## Option Contract

Every option MUST have:

- stable option id;
- text value for typeahead;
- accessible name;
- optional description;
- disabled state;
- selection state where selectable;
- group id where grouped;
- privacy class.

Options SHOULD keep names short. If extra details are needed, use description or
secondary text. Long repeated prefixes should be moved into a group label or a
separate dependent select.

Options MUST NOT contain independently interactive controls under listbox
semantics. If the row needs buttons, links, or checkboxes, use grid/list with
actions instead.

## Keyboard Contract

MUST:

- focus selected option when entering single-select listbox if selection exists;
- focus first option when no selection exists;
- move with up/down arrows in vertical orientation;
- support `Home` and `End` for lists with more than five options;
- support typeahead for more than seven options;
- distinguish focus from selection;
- support `Space` selection for multi-select recommended model;
- expose multi-select with `aria-multiselectable` on web where applicable.

SHOULD:

- use the APG recommended multi-select model that does not require modifier keys;
- provide explicit select all and clear selection commands when bulk selection is
  important;
- support virtualization with `aria-posinset` and `aria-setsize` where platform
  adapter can expose it.

MUST NOT:

- use menu semantics for value selection;
- auto-select on focus if doing so triggers expensive or destructive side
  effects;
- mix `selected` and `checked` semantics without a documented reason.

## Clean Disk Mapping

Accepted uses:

- sort field: select or menu button depending on whether it chooses a value or
  runs a command;
- scan mode choice: radio/segmented when small, select when space constrained;
- filter by file kind: multi-select listbox only if options are visible and
  static;
- recent scan picker: list/navigation, not listbox if each item opens a route;
- cleanup recommendation category filter: select/listbox depending on layout.

Avoid listbox for filesystem tree rows. Tree rows are structured, hierarchical,
and action-bearing, so they belong to TreeGrid.

## Conformance Tests

Minimum tests:

- select/listbox has accessible label;
- entering listbox focuses selected or first option correctly;
- arrow navigation works without changing selection unless policy says so;
- typeahead finds option by text value;
- multi-select supports recommended Space model;
- grouped options expose group labels;
- virtualized options preserve position facts;
- disabled option can be focusable only by explicit policy;
- option with nested button fails listbox conformance;
- selected ids persist by stable id, not visual index.

## Failure Catalog

- Custom dropdown implemented as menu but used as form value.
- Option rows contain buttons under `option` semantics.
- Long repeated option names are impossible to scan with a screen reader.
- Virtualized list loses option position.
- Selection follows focus triggers expensive queries.
