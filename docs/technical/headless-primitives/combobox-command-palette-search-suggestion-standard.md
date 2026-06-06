# Combobox Command Palette And Search Suggestion Standard

## Status

Implementation standard for combobox, command palette, search suggestion,
select-like popup, and autocomplete primitives.

## Purpose

Search fields and command palettes look simple, but they combine text input,
popup focus, async results, active descendant, result counts, status messages,
and privacy-sensitive queries. Headless needs one standard before adding
`RCombobox`, `RCommandPalette`, `RSearchBox`, or filter popup primitives.

## Standards And References

- WAI-ARIA APG Combobox:
  https://www.w3.org/WAI/ARIA/apg/patterns/combobox/
- WAI-ARIA APG Listbox:
  https://www.w3.org/WAI/ARIA/apg/patterns/listbox/
- MDN `combobox` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/combobox_role
- MDN `listbox` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/listbox_role
- MDN `aria-autocomplete`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-autocomplete
- MDN `searchbox` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/searchbox_role
- Flutter `RawAutocomplete`:
  https://api.flutter.dev/flutter/widgets/RawAutocomplete-class.html

## Core Rule

Text input focus, popup active option, selected value, and submitted command
are separate state concepts.

```text
input text
  != active option
  != selected option
  != committed value
  != command execution target
```

## Primitive Families

Editable combobox:

- user can type;
- popup suggests values;
- committed value can be typed text or selected option by policy.

Select-only combobox:

- user does not type arbitrary text;
- trigger controls popup;
- committed value comes from option.

Command palette:

- text filters command list;
- active option is command candidate;
- Enter executes command through application boundary.

Search box with suggestions:

- text input is search criteria;
- suggestions are optional;
- submitted query is product data and privacy-sensitive.

Filter picker:

- popup selects typed filter descriptors;
- app owns query semantics.

## State Model

```text
closed
opening
openIdle
openLoading
openWithResults
openEmpty
openError
committing
closing
```

State facts:

- input text;
- composing state;
- active option key;
- selected option key;
- popup kind: listbox, grid, tree, dialog;
- result count;
- async request id;
- busy status;
- privacy class.

## Keyboard Rules

Common:

- Down opens popup or moves active option;
- Up moves active option;
- Enter commits active option or submits input by policy;
- Escape closes popup before clearing input unless policy says otherwise;
- Tab commits, closes, or moves focus by explicit policy;
- Home/End belong to text editing when input caret owns focus;
- typeahead is disabled when real text input is active.

Editable:

- text editing keys belong to input;
- IME composition blocks command mapping;
- popup active option can be controlled through active-descendant strategy.

Select-only:

- trigger can use button semantics;
- no `aria-autocomplete`;
- option activation updates selected value.

## Popup Relationship Rules

Core Headless exposes:

- popup role intent;
- controls relationship;
- active option facts;
- expanded state;
- autocomplete mode;
- option set facts.

Web adapter may map to:

- `aria-expanded`;
- `aria-controls`;
- `aria-haspopup`;
- `aria-activedescendant`;
- `aria-autocomplete`.

Core API must not require these exact ARIA strings.

## Search Result Status

Search result updates should use status policy:

- announce result count after debounce;
- announce loading sparingly;
- suppress duplicate count messages;
- do not announce every suggestion;
- use `aria-busy` intent while result set is incomplete;
- do not put raw query text in diagnostics.

## Privacy Rules

Search and command inputs can reveal user intent.

- do not log query text;
- do not include query in telemetry labels;
- support bundles redact input;
- command ids are stable and nonlocalized;
- option labels are display data, not ids.

## Clean Disk Usage

Clean Disk likely needs:

- path/search input;
- command palette later;
- filter picker;
- sort/filter popup.

Rules:

- Flutter does not search full scan tree directly;
- search query becomes typed application/Rust query;
- suggestions cannot become cleanup authority;
- stale suggestion disables destructive action.

## Required Tests

Automated:

- input focus remains while active option changes;
- IME composition does not execute command;
- result request id ignores late response;
- Escape order: popup, edit, outer overlay;
- query text absent from diagnostics;
- select-only does not expose autocomplete facts.

Manual:

- screen reader announces combobox/searchbox label;
- result count status is understandable;
- keyboard-only command execution;
- mobile soft keyboard path;
- empty and error result states.

## Stop Rules

- Do not use combobox role for every dropdown.
- Do not execute command from active option without explicit commit.
- Do not log search text.
- Do not use option label as stable id.
- Do not let popup focus trap keyboard users.
