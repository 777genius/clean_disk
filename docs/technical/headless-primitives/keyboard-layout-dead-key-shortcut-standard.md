# Keyboard Layout Dead Key And Shortcut Standard

## Status

Accepted as a Headless runtime interoperability standard. Not implemented yet.

## Source Standards

- MDN KeyboardEvent: https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent
- MDN `KeyboardEvent.key`: https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key
- MDN `KeyboardEvent.code`: https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/code
- MDN Keyboard event key values: https://developer.mozilla.org/en-US/docs/Web/API/UI_Events/Keyboard_event_key_values
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.1.4 Character Key Shortcuts: https://www.w3.org/WAI/WCAG22/Understanding/character-key-shortcuts.html
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Scope

This standard defines how Headless handles keyboard layouts, dead keys,
physical key positions, character keys, shortcuts, and shortcut display.

It applies to:

- command shortcuts;
- typeahead;
- search inputs;
- grid navigation;
- menu navigation;
- text editing;
- command palette;
- custom shortcut remapping;
- automation traces.

It does not replace the existing command router. It defines keyboard identity
and layout safety rules for the router.

## Decision Options

Option A: Use one hard-coded shortcut map - 🎯 3   🛡️ 3   🧠 2, about
100-250 LOC.

- Easy.
- Breaks non-US layouts, dead keys, IME, and text editing.

Option B: Use only logical characters - 🎯 5   🛡️ 5   🧠 4, about
250-600 LOC.

- Better for display.
- Physical navigation and app shortcuts can still conflict.

Option C: Dual logical and physical shortcut model - 🎯 9   🛡️ 9   🧠 7,
about 900-1700 LOC.

- Accepted direction.
- Command shortcut can declare logical, physical, text-entry, and remapping
  behavior.
- Dead keys and IME composition are protected.

## Accepted Direction

Headless must represent key input through `KeyBindingIntent`.

It includes:

- logical key;
- physical key where available;
- modifiers;
- location;
- input mode;
- text editing context;
- IME composition state;
- dead key state;
- platform shortcut family;
- display string policy.

## Logical Versus Physical

Logical key:

- represents the character or semantic key after layout and modifiers.
- useful for text commands and display.

Physical code:

- represents key position on hardware where available.
- useful for layout-independent game-like controls or legacy app shortcuts.

Headless command must declare which identity it uses and why.

## Dead Key And IME Rules

If key event is part of composition:

- do not trigger character shortcuts;
- do not consume text input shortcuts incorrectly;
- allow platform text editing behavior;
- preserve before-input or composition pipeline where adapter supports it;
- delay typeahead until committed text.

Dead key must not trigger command just because a physical key matched.

## Character Shortcut Rules

Single-character shortcuts must be safe:

- disabled or remappable;
- inactive while text input focused;
- not triggered during IME;
- documented in command help;
- avoid letters that conflict with localization or screen reader shortcuts
  where practical.

## Shortcut Display Rules

Displayed shortcut must match platform and layout where possible.

Rules:

- do not show US-layout symbol if logical layout differs;
- show platform modifier names;
- show remapped user shortcut;
- avoid localized label as command id;
- indicate when shortcut is unavailable in current scope.

## Clean Disk Requirements

Clean Disk shortcuts:

- scan;
- pause;
- cancel;
- search;
- sort;
- reveal;
- add to queue;
- remove from queue;
- command palette.

Rules:

- search input owns text editing shortcuts.
- destructive shortcut opens confirmation only.
- keyboard layout differences must not break command discovery.

## API Shape Sketch

```text
KeyBindingIntent
  logicalKey
  physicalCode
  modifiers
  location
  platform
  compositionState
  context
  displayPolicy

ShortcutPolicy
  identityMode
  allowDuringTextEditing
  allowDuringComposition
  remappable
```

## Conformance Scenarios

- Ctrl+C in text field copies selected text;
- dead key does not trigger command;
- typeahead waits for committed character;
- shortcut help displays platform modifier;
- physical shortcut works only when declared physical;
- remapped shortcut updates menu and toolbar display;
- command disabled in current scope ignores shortcut;
- automation trace records logical and physical facts.

## Failure Catalog

- using deprecated keyCode as command identity;
- shortcut fires during IME composition;
- dead key triggers delete or navigation;
- text field loses standard shortcut;
- shortcut help shows wrong key for layout;
- physical key used for localized character command;
- menu shows shortcut that command router rejects;
- shortcut cannot be remapped or disabled;
- screen reader shortcut conflict ignored;
- automation only records display label.

