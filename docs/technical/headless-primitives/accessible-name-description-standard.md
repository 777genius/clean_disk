# Accessible Name And Description Standard

## Status

Implementation standard for names, descriptions, labels, and announcement text
across Headless primitives.

## Purpose

Accessible names are not decoration. They are the primary identity that
assistive technology uses to present controls and regions. A Headless primitive
must make names and descriptions explicit enough for Flutter, web ARIA, and
native platform adapters without leaking product data into diagnostics.

## Standards And References

- Accessible Name and Description Computation 1.2:
  https://www.w3.org/TR/accname-1.2/
- WAI-ARIA APG Names and Descriptions:
  https://www.w3.org/WAI/ARIA/apg/practices/names-and-descriptions/
- MDN `aria-labelledby`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Attributes/aria-labelledby
- MDN `aria-label`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Attributes/aria-label
- MDN text labels and names:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/Guides/Understanding_WCAG/Text_labels_and_names

## Core Rule

Every interactive primitive part must have:

- stable identity key;
- visible label or accessible name source;
- optional description source;
- privacy class;
- localization boundary;
- evidence status.

The visible label, accessible name, and stable id are separate concepts.

## Name Source Policy

Preferred order:

1. visible text label referenced by adapter where possible;
2. explicit localized accessible label when no visible text exists;
3. renderer-provided icon label through typed slot metadata;
4. fallback diagnostic in debug only.

Do not generate user-facing accessible names from:

- enum names;
- class names;
- command ids;
- product ids;
- file paths;
- translated labels used as stable identity.

## Description Source Policy

Descriptions are for supplemental help, not replacement names.

Allowed descriptions:

- short state explanation;
- validation hint;
- keyboard mode hint when not obvious;
- destructive consequence summary in confirmation dialogs;
- status context.

Forbidden descriptions:

- massive table row content;
- raw debug data;
- hidden product authority;
- instructions required to complete a mandatory action if no visible equivalent
  exists.

## Component Requirements

TreeGrid:

- root has a label;
- column headers have names;
- icon-only row actions have names;
- row name is concise;
- row description may include level, count, status, and warning;
- selected/focused state is not duplicated in label text if semantic state
  exists.

ContextMenu:

- trigger has name;
- menu has name or is labelled by trigger;
- each menu item has name;
- shortcut labels are not part of required item name unless platform convention
  requires it.

Dialog:

- dialog has title/name;
- alert dialog uses concise urgent title;
- long body text should not become the dialog name;
- destructive dialog description includes consequence and target summary;
- primary/secondary actions have names that match visible text.

Tooltip:

- trigger has name without tooltip;
- tooltip provides supplemental description only;
- tooltip text is not the only way to know the control purpose.

SplitPane:

- handle name references controlled pane;
- value text describes current size where helpful;
- collapse/restore action name is explicit.

StatusRegion:

- status text is concise;
- duplicate announcements are suppressed;
- severity prefix is policy-driven, not hardcoded in renderer.

## Localization Rules

Localization belongs in app/design-system layer. Headless accepts already
localized display strings or message builders through public contracts.

Rules:

- command ids are not localized;
- privacy classes are not localized;
- semantic state ids are not localized;
- examples must not use English strings as ids;
- bidi direction must be preserved for labels and descriptions.

## Privacy Rules

Accessible labels can contain sensitive product data. Therefore:

- diagnostics log only whether a label exists;
- conformance fixtures use synthetic labels;
- support bundles redact labels by default;
- telemetry never records label text;
- error messages name the missing part, not row content.

## Test Requirements

Automated:

- every interactive slot has name source;
- icon-only action requires label;
- no duplicate role words in generated label;
- description exists where required;
- semantic label absent from diagnostics;
- localized label does not become stable id.

Manual:

- screen reader reads dialog title before body;
- menu item names are concise;
- tooltip does not replace trigger name;
- TreeGrid row name is not overloaded with every cell.

## Stop Rules

- Do not ship icon-only controls without accessible names.
- Do not put raw paths or user data in diagnostics.
- Do not use `aria-label` style overrides to hide bad visible labels.
- Do not make tooltip text required-only information.
- Do not treat visible label as stable identity.
