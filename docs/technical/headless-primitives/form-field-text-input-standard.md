# Form Field And Text Input Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `input`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input
- MDN `label`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/label
- MDN `textbox` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/textbox_role
- MDN `searchbox` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/searchbox_role
- MDN `aria-invalid`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-invalid
- MDN `aria-errormessage`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-errormessage
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html
- Flutter form validation: https://docs.flutter.dev/cookbook/forms/validation
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers text fields, search fields, path filters, numeric text
inputs, multiline text areas, field labels, descriptions, placeholders, helper
text, validation errors, required state, readonly state, and form-level error
summary.

It does not cover combobox popup behavior, which is defined in the
combobox/search standard.

## Decision Options

1. `FieldController` plus `FieldSemantics` contract around native Flutter inputs - 🎯 9   🛡️ 9   🧠 6, roughly 700-1400 LOC.
   Best fit. We keep native text editing behavior while standardizing labels,
   descriptions, validation, and state.
2. Fully custom editable text primitive - 🎯 3   🛡️ 4   🧠 10, roughly 2500-6000 LOC.
   Too risky. Native text editing, IME, selection, screen reader editing, and
   platform shortcuts are hard to reproduce correctly.
3. Raw Material `TextField` wrappers only - 🎯 6   🛡️ 6   🧠 3, roughly 200-500 LOC.
   Good for MVP but weak for a public Headless package because accessibility
   and validation rules stay scattered.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- field id and control id;
- label, description, helper text, error text, and required indicator contract;
- value state and validation state;
- dirty, touched, focused, readonly, disabled, busy, and submitting states;
- privacy class for field value and messages;
- text input mode metadata;
- field-to-error association facts;
- form-level error summary projection;
- focus request target for validation failures.

Renderer owns:

- visual label placement;
- borders, colors, density, icons, counters, clear buttons;
- error visuals;
- layout and responsive behavior.

Application owns:

- validation rules;
- persistence;
- command side effects;
- localization;
- sensitive value policy.

## Label And Description Contract

MUST:

- provide a visible label or a clearly justified hidden accessible label;
- never use placeholder as the only label;
- keep label text available after the user enters a value;
- associate helper text and descriptions programmatically;
- associate error text with the field when invalid;
- expose required state and required instructions;
- keep privacy-sensitive values out of logs, telemetry, route state, and support
  bundles.

SHOULD:

- use visible label plus helper text for complex fields;
- keep error text concise and actionable;
- focus the first invalid field only after user submits or asks to validate;
- summarize multiple errors at form level in complex dialogs.

MUST NOT:

- rename fields dynamically based on current value;
- put raw daemon tokens or local paths in accessible field names;
- trap text editing keys for parent shortcuts;
- block IME composition with validation on every key;
- treat readonly as disabled.

## Text Editing Contract

MUST:

- delegate caret movement, selection, clipboard, IME, and platform text editing
  shortcuts to native text input where possible;
- suspend composite navigation shortcuts while the field is editing or composing;
- expose multiline state for text areas;
- expose obscured state for password or secret fields;
- support clear button as a separate labeled command when visible;
- preserve undo/redo expectations for local text editing.

SHOULD:

- debounce search and validation side effects;
- provide pending state for async validation;
- make clear buttons reachable by keyboard and assistive technology;
- support input purpose hints where platform adapters can expose them.

## Validation Contract

Validation states:

- none: no validation performed;
- valid: current value accepted;
- warning: accepted but noteworthy;
- invalid: value rejected;
- pending: async validation running;
- stale: validation result no longer matches current value.

MUST:

- fail closed for stale validation before destructive commands;
- expose invalid state only when there is a current validation result;
- keep error text associated with the invalid field;
- avoid announcing validation on every character unless the field is explicitly
  live-validating and throttled;
- distinguish field validation from command authorization.

## Clean Disk Mapping

Search field:

- role intent is searchbox;
- debounced query state belongs to application/store layer;
- raw query text is privacy-sensitive;
- parent TreeGrid shortcuts must not steal typing;
- search results count is status text, not part of field name.

Custom folder path field:

- value can contain private path data;
- accessible name should be generic, description may mention path selection;
- browse/reveal buttons are separate commands;
- invalid path errors must be associated with the field.

Settings fields:

- numeric worker count or resource budget fields should prefer spinbutton or
  slider semantics where appropriate;
- text fields should not be used for bounded ranges unless direct editing is
  genuinely needed.

## Conformance Tests

Minimum tests:

- field has accessible name;
- placeholder-only label fails conformance;
- helper text is associated as description;
- invalid field exposes error relation;
- readonly field remains focusable when product policy requires reading;
- disabled field is not commandable;
- IME composition does not trigger parent shortcuts;
- clear button has accessible name and command id;
- search field typing does not move TreeGrid focus;
- form-level error summary can focus first invalid field.

## Failure Catalog

- Placeholder disappears and the field becomes unlabeled.
- Parent shortcuts steal arrow keys or composition events.
- Error text is visual only.
- Async validation result arrives after value changed and overwrites current
  state.
- Raw paths leak through field labels.
