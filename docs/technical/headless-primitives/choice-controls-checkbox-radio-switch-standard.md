# Choice Controls Checkbox Radio And Switch Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Checkbox Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/checkbox/
- WAI-ARIA APG Radio Group Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/radio/
- WAI-ARIA APG Switch Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/switch/
- MDN `checkbox` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/checkbox_role
- MDN `radio` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/radio_role
- MDN `switch` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/switch_role
- MDN `aria-checked`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-checked
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers checkboxes, tri-state checkboxes, radio groups, switches,
settings toggles, consent checkboxes, row selection checkboxes, and menu
checkbox/radio item shared behavior.

It complements the state semantics standard, which defines the difference
between checked, selected, current, and pressed.

## Decision Options

1. Unified `ChoiceControl` foundation with role-specific wrappers - 🎯 9   🛡️ 9   🧠 7, roughly 800-1600 LOC.
   Best fit. It standardizes label, grouping, focus, checked state, validation,
   and controlled state while preserving exact role semantics.
2. Separate checkbox/radio/switch implementations - 🎯 6   🛡️ 7   🧠 6, roughly 1000-2200 LOC.
   Simple per component, but shared grouping and validation logic duplicates.
3. Use Material controls directly everywhere - 🎯 6   🛡️ 6   🧠 3, roughly 250-600 LOC.
   Fine for app MVP, not enough for community Headless contracts.

Accepted direction: option 1.

## Choosing The Control

Use checkbox when:

- multiple independent options can be on or off;
- a required consent or acknowledgement is needed;
- row selection is visible as a checkbox;
- tri-state represents aggregate child selection.

Use radio group when:

- exactly one option from a small set is chosen;
- options are mutually exclusive;
- changing focus may intentionally change selection outside toolbar context.

Use switch when:

- a setting is on/off;
- state is applied immediately or clearly on save;
- labels can stay stable while state changes.

Do not use switch for destructive confirmation. Use a checkbox with explicit
confirmation text.

## Primitive Boundary

Headless owns:

- choice id and group id;
- checked value: true, false, mixed, or undefined where role permits;
- group label and description;
- required and invalid state;
- focus model;
- toolbar-embedded radio behavior;
- controlled/uncontrolled state;
- aggregate tri-state derivation;
- label-in-name contract;
- disabled and readonly policy.

Renderer owns:

- visual check mark, radio dot, switch thumb, animation, density, and color;
- error styling;
- grouping layout.

Application owns:

- choice values;
- validation rules;
- persistence and side effects;
- cleanup policy and consent copy.

## Checkbox Contract

MUST:

- toggle with `Space`;
- expose checked, unchecked, or mixed state;
- keep label visible or programmatically associated;
- support group label and group description;
- distinguish selection checkbox from row selection state when both exist;
- preserve controlled state across virtualization.

SHOULD:

- support tri-state only for aggregate group semantics;
- remember previous partial child selection only when product explicitly defines
  that behavior;
- make "select all" and "clear selection" available as separate commands when
  important.

MUST NOT:

- use mixed state as vague loading or unknown state;
- hide the checkbox label and rely only on visual position;
- make a checkbox look like a switch while exposing checkbox semantics unless
  product intentionally wants checkbox meaning.

## Radio Contract

MUST:

- expose radio group semantics;
- keep no more than one checked option in the group;
- focus checked option when entering a group, or first option when none checked;
- support arrow key movement according to APG outside toolbar;
- support toolbar-embedded mode where arrow movement changes focus without
  changing checked value;
- expose required/invalid group state when no option is selected but required.

SHOULD:

- avoid radio groups with too many options;
- use listbox or combobox for large option sets;
- support `Space` to check focused option.

MUST NOT:

- use radio buttons for independent toggles;
- allow multiple checked values;
- rely on color alone for checked state.

## Switch Contract

MUST:

- represent on/off state;
- expose stable label;
- toggle with `Space`;
- avoid mixed state because switch is binary;
- clearly define whether changes apply immediately or on form submission.

SHOULD:

- use switch for preferences, background features, and mode enablement;
- use checkbox for consent, legal acknowledgement, and batch selection;
- expose pending state if immediate apply is asynchronous.

MUST NOT:

- use "Enable X" and "Disable X" as changing switch labels;
- use switch for irreversible or high-risk destructive actions;
- hide consequences in tooltip-only text.

## Clean Disk Mapping

Accepted use:

- delete confirmation: checkbox;
- cleanup queue item included: checkbox;
- scan mode preference: radio group or segmented control, not switch;
- "follow symlinks" or "include hidden files" setting: switch only if immediate
  preference, checkbox if part of a scan form;
- row selected for cleanup: selection model plus visible checkbox if shown;
- top toolbar mode toggles: toggle buttons, not switches.

## Conformance Tests

Minimum tests:

- checkbox toggles with `Space`;
- tri-state aggregate reflects children;
- radio group keeps one checked value;
- radio group inside toolbar does not change value on arrow focus;
- switch exposes on/off and stable label;
- required group exposes invalid state and error text;
- virtualized checkbox state restores by id;
- disabled choice does not toggle;
- label-in-name passes for visible labels;
- cleanup confirmation checkbox cannot be bypassed by row selection.

## Failure Catalog

- Using switch for consent makes the consequence unclear.
- Radio arrow keys accidentally change settings inside toolbar.
- Mixed state is used for loading.
- Virtualized checkboxes lose state by row index.
- Row selection, queue inclusion, and delete authority get conflated.
