# Voice Control And Speech Command Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG 2.5.3 Label in Name: https://www.w3.org/WAI/WCAG22/Understanding/label-in-name.html
- Accessible Name and Description Computation 1.2: https://www.w3.org/TR/accname-1.2/
- WCAG 2.4.6 Headings and Labels: https://www.w3.org/WAI/WCAG22/Understanding/headings-and-labels.html
- WCAG 3.2.4 Consistent Identification: https://www.w3.org/WAI/WCAG22/Understanding/consistent-identification.html
- WAI-ARIA APG Keyboard Interface: https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/
- Apple Voice Control on Mac: https://support.apple.com/guide/mac-help/use-voice-control-mh40719/mac
- Android Voice Access: https://support.google.com/accessibility/android/answer/6151848

## Problem

Speech-input users commonly activate controls by saying visible labels. A
component can have a technically valid accessible name and still fail speech
control when the visible text is missing from the accessible name, when duplicate
labels cannot be disambiguated, or when icon-only actions rely on hidden names.

Headless needs a speech-command contract that is stricter than generic
accessible naming.

## Decision Options

1. Rely only on accessible-name conformance - 🎯 5   🛡️ 5   🧠 2, about
   0-80 LOC. Correct for screen readers, incomplete for voice control.
2. Add a speech command metadata layer and label-in-name linting - 🎯 9   🛡️ 9
   🧠 6, about 300-700 LOC. Best for community-grade Headless.
3. Implement a voice grammar engine - 🎯 4   🛡️ 6   🧠 9, about 1500-3000 LOC.
   Too platform-specific and not needed for primitives.

Accepted: option 2.

## Accepted Contract

Every interactive primitive exposes speech facts:

```dart
final class RSpeechCommandTarget {
  final RSemanticId id;
  final String? visibleLabel;
  final String accessibleName;
  final List<String> commandAliases;
  final String? disambiguator;
  final bool isIconOnly;
  final bool isDestructive;
  final bool requiresConfirmation;
}
```

The primitive does not run speech recognition. It makes speech control possible
for OS and assistive technologies by preserving labels, names, and action
metadata.

## Label Rules

- If visible text labels a control, the accessible name contains that text.
- Prefer visible label text at the start of the accessible name.
- Icon-only buttons must have a stable accessible name and optional tooltip, but
  should not create hidden destructive commands.
- Duplicate visible labels need a visible or semantic disambiguator, such as
  row name, section name, or ordinal context.
- Localized labels and command aliases are generated from localization data, not
  hardcoded English strings.
- Placeholder text is not the only long-term label for form controls.
- State words like selected, checked, expanded, paused, and unavailable are state
  metadata, not replacements for the control name.

## Command Safety Rules

- Destructive commands require confirmation through a separate target.
- Voice activation must not bypass the command provenance standard.
- Ambiguous commands produce a disambiguation state, not a random activation.
- Hidden aliases are allowed only for well-known platform commands and must be
  documented.
- Commands that affect app data must have stable command ids independent of
  localized labels.

## Clean Disk Requirements

Voice control must work for:

- "Scan";
- "Pause scan";
- "Cancel scan";
- "Search";
- "Sort";
- "Filter";
- "Reveal in Finder";
- "Add to queue";
- "Remove from queue";
- "Move to Trash";
- expanding named folders in the tree;
- selecting a row by visible folder or file name where the row is visible.

Danger commands such as "Move to Trash" require confirmation even if the speech
system can activate the visible button directly.

## Duplicate Label Strategy

For repeated controls inside rows:

```text
visible label: Add to queue
accessible name: Add to queue Caches
disambiguator: Caches
command id: cleanupQueue.add
```

The visible label remains speech-friendly, while the accessible name contains
enough context for assistive technologies.

## Testing Requirements

- Lint every interactive target for label-in-name when visible text exists.
- Snapshot speech metadata for representative primitives.
- Test duplicate row actions with same visible label and different row context.
- Test localized labels where noun order changes.
- Test icon-only commands and ensure their accessible names are discoverable.
- Test destructive command activation path and confirmation provenance.

## Failure Catalog

- Visible button says "Trash" but accessible name is "Delete selected items".
- Icon-only action has a hidden name that accidentally matches a common word.
- Two "Remove" controls exist with no row context.
- The accessible name includes state before label, making speech commands fail.
- Localization changes the visible label but not command aliases.
- Tooltip text is the only source of command identity.

## Release Gates

- Label-in-name lint must pass for all public primitives.
- Every command target must expose stable command id and localized label.
- Destructive speech targets must have a confirmation path.
- Public docs must explain duplicate label handling.

## Summary

Headless should not implement voice recognition. It should make OS voice control
reliable by preserving visible labels, stable command ids, disambiguation, and
safe destructive flows.
