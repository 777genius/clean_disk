# Speech Control And Label In Name Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 2.5.3 Label in Name: https://www.w3.org/WAI/WCAG22/Understanding/label-in-name.html
- Accessible Name and Description Computation 1.2: https://www.w3.org/TR/accname-1.2/
- MDN `aria-label`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-label
- MDN `aria-labelledby`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-labelledby
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers visible labels, accessible names, icon-only controls,
shortcut hints, tooltips, command names, menu items, table headers, chart marks,
tabs, disclosures, validation messages, and translated UI text.

The goal is simple: if a user sees text on a control, speech control should be
able to target that control using that visible text.

## Decision Options

1. Central `AccessibleTextContract` and label-in-name conformance for all
   Headless command-like primitives - 🎯 9   🛡️ 9   🧠 7, roughly 700-1500 LOC.
   Best fit. It makes labels testable across Material, Cupertino, web, and
   custom renderers.
2. Leave labels to individual widgets and lint obvious mistakes - 🎯 5   🛡️ 6   🧠 4, roughly 300-700 LOC.
   Cheaper, but inconsistent. Community components will drift.
3. Use `aria-label` or `Semantics.label` for everything - 🎯 3   🛡️ 4   🧠 3, roughly 200-500 LOC.
   Dangerous. It often hides visible text from the accessible name and breaks
   speech control.

Accepted direction: option 1.

## Label Contract

Every labelable primitive MUST separate:

- stable id;
- visible label;
- accessible name;
- accessible description;
- tooltip;
- shortcut hint;
- validation message;
- status text;
- internal analytics name;
- localization key.

These are not interchangeable.

Visible label:

- user-facing text rendered on screen;
- localized;
- may be abbreviated if the accessible name still includes the visible text.

Accessible name:

- how assistive technology identifies the control;
- must include the visible label text when a visible label exists;
- may add context after the visible label;
- must not expose private paths, tokens, or raw daemon data.

Accessible description:

- additional help, reason, or state;
- should not duplicate the accessible name;
- may include disabled reason or consequence.

Tooltip:

- visual hover/focus help;
- does not replace accessible name.

Shortcut hint:

- a hint, not part of stable command identity;
- must not be the only label.

## Required Rules

MUST:

- ensure visible text is contained in the accessible name for every control with
  visible text;
- prefer visible text or `aria-labelledby` over hidden `aria-label` when a
  visible label exists;
- make icon-only controls provide an accessible name from the command
  descriptor;
- keep accessible names stable across loading and disabled states unless the
  visible label changes;
- put dynamic state in value, state, or description, not by renaming the
  control every frame;
- support automated label-in-name tests for renderers;
- preserve label-in-name after localization and bidi formatting;
- use product privacy policy before exposing file names or paths in labels.

SHOULD:

- place extra context after visible label text, not before it;
- keep names short and descriptions richer;
- use visible labels for destructive commands when space allows;
- expose hidden text only when it improves clarity and does not break speech
  matching.

MUST NOT:

- use a completely different `aria-label` than visible text;
- make tooltip text the only accessible name;
- use localized display labels as command ids;
- concatenate shortcut keys into accessible names;
- expose raw file paths in command names like "Delete /Users/name/secret";
- change a button name from "Scan" to "Scanning 42 percent" during progress.

## Primitive API

`AccessibleText`:

- `visibleLabel: LocalizedText?`;
- `accessibleName: LocalizedText?`;
- `description: LocalizedText?`;
- `tooltip: LocalizedText?`;
- `shortcutHint: ShortcutHint?`;
- `privacyClass: TextPrivacyClass`;
- `nameComposition: visibleOnly | visiblePlusContext | iconOnlyGenerated`;
- `labelInNamePolicy: required | notApplicable | intentionallyDifferent`;

`labelInNamePolicy: intentionallyDifferent` requires a documented exception and
must fail public conformance unless the primitive pattern permits it.

## Clean Disk Mapping

Examples:

- visible "Scan", accessible name "Scan";
- visible "Add to Queue", accessible name "Add to Queue";
- visible "Move to Trash", accessible name "Move to Trash";
- visible "Sort / Filter", accessible name "Sort / Filter";
- icon-only reveal command, accessible name "Reveal in Finder" on macOS and
  platform-equivalent label elsewhere;
- selected row actions should include visible row context in description, not
  raw path in command name;
- delete confirmation checkbox name must include its visible confirmation text.

The details pane may show full paths visually. Commands should use node display
name or generic command name plus safe description, not raw path as the primary
accessible name.

## Localization And Bidi

MUST:

- run label-in-name checks after localization;
- compare normalized visible label and accessible name with locale-aware
  whitespace handling;
- preserve path and code direction with bidi isolation in descriptions;
- avoid splitting visible label text across inaccessible decorative spans;
- keep plural and count changes out of command names unless visible text also
  changes.

## Conformance Tests

Minimum tests:

- every visible command label is contained in accessible name;
- icon-only controls have generated names;
- visible label changes update accessible name consistently;
- tooltip-only controls fail conformance;
- shortcut text is not part of accessible name unless visible label includes it;
- disabled reason appears as description or value, not as renamed command;
- localized labels pass label-in-name checks;
- path privacy classifier blocks sensitive path labels by default.

## Failure Catalog

- "Scan" visually but accessible name "Start analysis" breaks speech control.
- Icon-only controls without names are invisible to assistive technology.
- Using tooltip as the only label fails keyboard and touch discoverability.
- Dynamic accessible names create noisy announcements.
- Raw paths in labels leak private information.
