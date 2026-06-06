# IME Text Editing And Composition Standard

## Status

Implementation standard for text input, IME composition, inline editing,
search, rename, typeahead, and editable grid cells.

## Purpose

Keyboard handling breaks easily when a component treats all key events as
commands. Text input is not just Latin key presses. IMEs, composition regions,
mobile keyboards, paste, autocomplete, dictation, dead keys, and before-input
events all change the model. Headless primitives need explicit rules so
TreeGrid, SearchField, CommandMenu, editable cells, and rename flows do not
steal text input or corrupt composing text.

## Standards And References

- MDN `beforeinput` event:
  https://developer.mozilla.org/en-US/docs/Web/API/Element/beforeinput_event
- MDN `compositionstart` event:
  https://developer.mozilla.org/en-US/docs/Web/API/Element/compositionstart_event
- MDN `compositionend` event:
  https://developer.mozilla.org/en-US/docs/Web/API/Element/compositionend_event
- MDN `KeyboardEvent.isComposing`:
  https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/isComposing
- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- Flutter `TextEditingValue.composing`:
  https://api.flutter.dev/flutter/dart-ui/TextEditingValue/composing.html
- Flutter text input client current value:
  https://docs.flutter.dev/release/breaking-changes/text-input-client-current-value

## Core Rule

Text editing scope has priority over composite navigation while composing or
editing. Headless must not interpret composition keystrokes as component
commands.

```text
input method
  -> editable scope
  -> text editing model
  -> commit/cancel/submit command
  -> outer primitive command only after edit scope releases
```

## Editing Scope Types

```text
plainTextInput
searchInput
renameInput
gridCellEditor
typeaheadBuffer
commandPaletteInput
filterExpressionInput
```

Every editing scope declares:

- owner component;
- focus target;
- composing state;
- dirty state;
- commit policy;
- cancel policy;
- validation policy;
- privacy class;
- keyboard escape policy.

## IME Composition Rules

During composition:

- printable keys belong to IME;
- Enter may commit composition instead of submitting outer command;
- Escape may cancel composition before closing outer overlay;
- arrow keys may move IME candidate selection;
- shortcut resolver must not treat composing key events as grid navigation;
- status announcements should not read provisional composing text.

When composition ends:

- committed text becomes ordinary editing input;
- outer primitive may process submit/cancel only after editing scope confirms;
- stale reducer events from before composition are ignored.

## Flutter Rules

Flutter editing code must respect `TextEditingValue.composing`.

Rules:

- do not mutate composing region from Headless reducer;
- do not normalize or format text while composing unless editor adapter proves
  it preserves composing range;
- keep `TextEditingController` in widget/adapter layer, not domain state;
- app/application layer receives committed text or explicit draft state, not
  controller object;
- keyboard shortcuts use `Actions` and `Shortcuts`, but editing scope can block
  outer shortcuts.

## Web Rules

Web adapters should listen to text input semantics, not only `keydown`.

Rules:

- `beforeinput` can describe intended edit before DOM change;
- composition events mark active IME composition;
- `KeyboardEvent.isComposing` should block command mapping;
- paste can enter text without keydown;
- mobile keyboards can produce input without hardware key equivalents.

## Grid Cell Editing

Editable cell states:

```text
navigation
editPending
editing
validating
committed
cancelled
error
```

Default commands:

- Enter or F2 may enter edit mode;
- Escape exits edit mode or cancels composition first;
- Tab commits or moves by policy;
- arrow keys navigate grid in navigation mode;
- arrow keys move caret or IME candidate in editing mode;
- Ctrl/Cmd shortcuts belong to editor only when editor supports them.

## Typeahead Rules

Typeahead is not text editing. It is a transient search buffer for navigation.

Rules:

- disabled when real text input is focused;
- paused during IME composition unless adapter supports composed typeahead;
- buffer timeout is policy;
- matches use app-provided collation where needed;
- typed characters are not logged.

## Privacy Rules

Text input can contain sensitive data.

- never log typed text;
- diagnostics may log field kind and event kind only;
- support bundles redact drafts and typeahead buffers;
- telemetry records command categories, not query text.

## Required Tests

Automated:

- composing key does not move TreeGrid focus;
- Escape cancels edit before closing parent menu/dialog;
- Enter during composition does not submit outer command;
- paste updates editor through editing path;
- late validation does not overwrite newer draft;
- text input guard blocks global shortcuts.

Manual:

- CJK IME in search field;
- CJK IME in grid rename cell;
- mobile soft keyboard input;
- dictation or accessibility text input where available;
- screen reader announces edit mode and validation.

## Stop Rules

- Do not handle text editing only through `keydown`.
- Do not mutate IME composing range in Headless core.
- Do not let grid arrow navigation steal editor caret movement.
- Do not log typed text or typeahead content.
- Do not make labels or ids from draft input.
