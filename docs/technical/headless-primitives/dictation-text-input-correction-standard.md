# Dictation Text Input And Correction Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN `beforeinput`: https://developer.mozilla.org/en-US/docs/Web/API/Element/beforeinput_event
- MDN `InputEvent`: https://developer.mozilla.org/en-US/docs/Web/API/InputEvent
- MDN `InputEvent.inputType`: https://developer.mozilla.org/en-US/docs/Web/API/InputEvent/inputType
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.5.3 Label in Name: https://www.w3.org/WAI/WCAG22/Understanding/label-in-name.html
- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 3.3.3 Error Suggestion: https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html
- Flutter text input: https://docs.flutter.dev/ui/interactivity

## Problem

Dictation is text input, not command input. Users may dictate search text, file
names, notes, filters, and paths. Components break dictation when they treat
spoken punctuation as commands, collapse undo units incorrectly, reject
composition-style updates, hide correction feedback, or make destructive changes
based on raw dictated phrases.

Headless needs a text-input contract that separates dictation, speech commands,
IME composition, shortcuts, and product commands.

## Decision Options

1. Treat dictation as ordinary text editing - 🎯 5   🛡️ 5   🧠 2, about
   0-80 LOC. Works for simple fields, weak for command palettes and filters.
2. Add a dictation-aware input event policy - 🎯 9   🛡️ 9   🧠 6, about
   300-750 LOC. Best fit for Headless.
3. Build a speech-to-text integration layer - 🎯 3   🛡️ 5   🧠 9, about
   1600-3000 LOC. Not Headless responsibility.

Accepted: option 2.

## Accepted Contract

Text primitives expose input provenance:

```dart
enum RTextInputProvenance {
  keyboard,
  paste,
  imeComposition,
  dictation,
  autofill,
  programmatic,
  unknown,
}

final class RTextInputIntent {
  final RTextInputProvenance provenance;
  final String textDelta;
  final RTextRange affectedRange;
  final bool isComposing;
  final bool isCorrection;
  final bool mayBeUndoBoundary;
}
```

When provenance is unknown, text input remains accepted unless validation fails
for normal product reasons.

## Rules

- Dictated text stays in the text field. It is not parsed as a global command.
- Command palettes must distinguish "insert text" from "execute command".
- Validation errors are visible and recoverable.
- Corrections produce undoable changes without wiping unrelated input.
- Text fields do not rely on keydown events alone.
- Single-character shortcuts are disabled while text input is active.
- Placeholder text is not the only label.
- Dictation of punctuation, paths, or file extensions is supported as text.

## Clean Disk Requirements

Clean Disk must support dictation in:

- search field;
- filter values;
- custom path entry;
- command palette search;
- notes or support bundle descriptions if added later.

Dictating "delete cache" into search must search that text. It must not trigger
cleanup.

## Correction And Undo Rules

- Each accepted dictation phrase may become one undo boundary.
- Correction replacements are scoped to the affected range.
- Validation does not erase invalid text unless user confirms reset.
- Clear buttons are explicit commands with command provenance.
- Search result updates are debounced and cancellable.

## Security And Privacy

- Dictated text can contain sensitive paths, names, or search terms.
- Do not log raw text deltas.
- Diagnostics may record provenance class and validation code only.
- Support bundles redact text input snapshots by default.

## Testing Requirements

- Simulate insertion, replacement, deletion, and correction events.
- Test command palette with dictated command-like text.
- Test path-like text with spaces, punctuation, and Unicode.
- Test undo after dictation correction.
- Test validation errors under dictated input.
- Test that shortcuts do not fire inside text fields.

## Failure Catalog

- Dictated "slash users slash belief" triggers navigation instead of text input.
- Command palette executes the top command when user is still dictating.
- `keydown` shortcut deletes selected rows while search has focus.
- Correction replaces the whole field instead of the intended range.
- Validation clears dictated text with no recovery.
- Raw search text is stored in telemetry.

## Release Gates

- Text primitives must support provenance or explicit unknown fallback.
- Command primitives must not consume text input as command activation without
  an explicit submit action.
- Diagnostics redact text input by default.
- Dictation fixtures are part of form, search, and command palette conformance.

## Summary

Dictation is a text editing path. Headless should preserve it through input
provenance, correction-safe undo, validation recovery, and strong separation
from command execution.
