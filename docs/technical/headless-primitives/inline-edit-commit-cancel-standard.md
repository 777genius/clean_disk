# Inline Edit Commit Cancel Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Grid Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- WAI-ARIA APG Combobox Pattern text editing note: https://www.w3.org/WAI/ARIA/apg/patterns/combobox/
- MDN `textbox` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/textbox_role
- MDN `enterkeyhint`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/enterkeyhint
- MDN `inputmode`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inputmode
- MDN IME composition events: https://developer.mozilla.org/en-US/docs/Web/API/Element/compositionstart_event
- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 3.3.3 Error Suggestion: https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html
- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html

## Scope

This standard covers inline editing in grids, editable cells, rename fields,
filter chip editing, tag editing, command labels, commit/cancel flows, dirty
state, validation, IME composition, and keyboard interaction between collection
navigation and text editing.

It extends form fields, grid cell edit mode, validation, IME, command routing,
and timing/data loss standards.

## Problem

Inline editing mixes two keyboard models:

- collection navigation uses arrows, Enter, Escape, Home, End;
- text editing uses the same keys for caret movement, commit, cancel, and IME.

If Headless does not define mode switching, users can lose edits, execute wrong
commands, or be unable to navigate a grid. For Clean Disk, inline editing is
less central than scanning, but still appears in saved views, filters, labels,
comments, support bundle names, and future rule packs.

## Decision Options

1. Explicit view/edit mode state machine with commit intent -
   🎯 9   🛡️ 9   🧠 8, roughly 1000-2200 LOC.
   Best fit. It separates navigation from editing and protects dirty data.
2. Let each editable widget handle keys locally -
   🎯 5   🛡️ 5   🧠 4, roughly 300-800 LOC.
   Works until editable cells live inside virtualized grids.
3. Avoid inline editing entirely -
   🎯 6   🛡️ 7   🧠 2, roughly 100-300 LOC.
   Safe for MVP, but too limited for a public Headless kit.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- edit mode state;
- draft value;
- dirty flag;
- validation state;
- commit/cancel intent;
- focus restoration;
- IME composition guard;
- keyboard conflict policy;
- async commit lifecycle.

Renderer owns:

- edit field visuals;
- dirty indicator;
- validation visuals;
- spinner/progress;
- compact editor layout;
- focus ring.

Application owns:

- validation rules;
- persistence;
- conflict handling;
- authorization;
- operation receipts.

## State Machine

```text
view
  -> enteringEdit
  -> editing
  -> validating
  -> committing
  -> committed
  -> failed
  -> canceled
```

Rules:

- view mode owns collection navigation keys;
- edit mode owns text editing keys;
- dirty state survives transient focus changes only by explicit policy;
- virtualization cannot unmount dirty editor without asking policy;
- async commit has a visible pending state;
- failed commit keeps draft available for correction.

## Keyboard Rules

View mode:

- `Enter` may enter edit mode when item is editable;
- `F2` may enter edit mode for desktop data grids;
- arrows navigate collection;
- printable key may start edit by policy.

Edit mode:

- `Enter` commits single-line editor unless IME composition is active;
- `Shift+Enter` inserts newline when multiline;
- `Escape` cancels or reverts depending on dirty policy;
- arrows move caret unless editor allows grid handoff;
- `Tab` commits or moves focus by explicit policy.

## IME Rules

Rules:

- composition start blocks Enter/Escape commit shortcuts;
- composition update is not validation commit;
- composition end may trigger validation but not destructive side effects;
- validation messages wait until meaningful user action;
- screen reader announcements avoid repeating every composition update.

## Validation And Conflict Rules

Validation facts:

- local format validity;
- server/application validity;
- stale version;
- permission state;
- conflict version;
- suggested repair;
- blocking severity.

Rules:

- validation errors identify the field;
- suggestions are available when possible;
- stale version does not overwrite newer data silently;
- cancel reverts to original committed value;
- failed commit does not lose draft.

## Clean Disk Usage

Likely uses:

- saved scan name;
- saved filter name;
- custom target label;
- support bundle label;
- rule pack override name;
- future comment/note field.

Rules:

- scan tree filenames are not renamed by MVP inline editing;
- cleanup labels are UI metadata, not filesystem authority;
- destructive cleanup is not committed from inline editor Enter;
- edits in virtualized rows use stable ids, not row indexes.

## Community API Sketch

```dart
final class RInlineEditState<T> {
  const RInlineEditState({
    required this.mode,
    required this.originalValue,
    required this.draftValue,
    required this.validation,
    required this.isComposing,
  });

  final RInlineEditMode mode;
  final T originalValue;
  final T draftValue;
  final RValidationState validation;
  final bool isComposing;
}
```

## Conformance Scenarios

- F2 enters edit mode in grid cell;
- arrows move caret in edit mode and rows in view mode;
- Enter during IME composition does not commit;
- Escape cancels and restores original value;
- failed async commit keeps draft and announces error;
- virtualized row cannot discard dirty draft silently;
- validation message is connected to edited field.

## Anti-Patterns

- using row selection state as edit mode state;
- committing on every keypress to application state;
- treating IME Enter as submit;
- losing draft when row scrolls out of view;
- validating localized display string as protocol identity;
- hiding async commit failure in a toast only;
- letting renderer decide conflict policy.

## Clean Architecture Note

Headless owns edit interaction. Application use cases own validation and
persistence. Domain owns business invariants. Renderer adapters never commit
edited data directly.
