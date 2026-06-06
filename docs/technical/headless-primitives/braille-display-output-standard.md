# Braille Display Output Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WAI-ARIA 1.3 `aria-braillelabel`: https://w3c.github.io/aria/#aria-braillelabel
- WAI-ARIA 1.3 `aria-brailleroledescription`: https://w3c.github.io/aria/#aria-brailleroledescription
- MDN `aria-braillelabel`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-braillelabel
- Accessible Name and Description Computation 1.2: https://www.w3.org/TR/accname-1.2/
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- ARIA-AT: https://w3c.github.io/aria-at/

## Problem

Refreshable braille displays are not just another screen-reader transcript.
Braille output has limited cells, different abbreviation pressure, different
punctuation behavior, and strong dependence on accessible names, roles, states,
and row context. Dense app surfaces like TreeGrid can become unusable when every
row emits a long path, redundant role text, or unstable abbreviated names.

Headless needs a braille-specific semantic contract without turning every
component into a braille renderer.

## Decision Options

1. Rely only on generic accessible names - 🎯 5   🛡️ 5   🧠 2, about 0-80 LOC.
   This is often acceptable, but weak for dense grids and long filenames.
2. Add braille metadata as an optional semantic projection - 🎯 9   🛡️ 9
   🧠 6, about 350-850 LOC. Best fit for Headless because it preserves generic
   semantics and adds braille-specific evidence only where needed.
3. Add a custom braille layout engine - 🎯 3   🛡️ 5   🧠 10, about
   2500-6000 LOC. Not appropriate for a UI primitive library.

Accepted: option 2.

## Accepted Contract

Headless exposes optional braille facts:

```dart
final class RBrailleSemanticProjection {
  final RSemanticId id;
  final String accessibleName;
  final String? brailleLabel;
  final String? brailleRoleDescription;
  final String? compactValue;
  final String? contextPrefix;
  final bool hasSensitiveContent;
  final RBrailleEvidence evidence;
}
```

The projection is advisory. Platform adapters decide whether to map it to
`aria-braillelabel`, platform APIs, or ordinary accessible names.

## Braille Label Rules

- Default to the normal accessible name.
- Use a braille-specific label only when the normal name is too verbose or
  ambiguous for a compact braille display.
- Do not use braille labels to hide visible text or contradict the accessible
  name.
- Keep role descriptions short and stable.
- Preserve state facts separately: selected, expanded, checked, busy, invalid,
  readonly, and disabled.
- For repeated row actions, include short row context.
- For sensitive content, prefer redacted summaries unless the user explicitly
  focuses the sensitive field.

## Dense Grid Rules

TreeGrid and table-like primitives must provide:

- row index and total where known;
- level for tree rows;
- expansion state;
- selected state;
- sorted column facts;
- concise cell value;
- optional full value command;
- stable row context.

Braille users should be able to understand "Caches, folder, 38.7 GB, selected,
level 4" without receiving the full path on every row movement.

## Clean Disk Requirements

Clean Disk must avoid flooding braille output with:

- full filesystem paths on every row;
- repeated "folder" or "file" words when role already conveys type;
- byte-level size unless requested;
- raw warning text on every focus movement;
- long cleanup queue descriptions before the item name.

Details panes may expose full path and byte counts through explicit focused
fields.

## Privacy Rules

- Braille transcript evidence is sensitive when it contains paths, filenames,
  user names, search text, or delete targets.
- Conformance fixtures use synthetic names.
- Support bundles redact braille transcript content by default.
- A braille label cannot be used as a hidden telemetry identity.

## Testing Requirements

- Snapshot braille projections for TreeGrid rows, command buttons, dialogs, and
  details fields.
- Test long file names, mixed RTL/LTR names, emoji, extensions, and duplicate
  names.
- Test selection, expansion, and sorted state changes.
- Test localized compact labels.
- Test that braille metadata does not remove normal accessible names.

## Failure Catalog

- Braille label differs from visible label in a way that changes command
  meaning.
- Every row starts with the same long folder prefix.
- Byte counts make the important name disappear from a 40-cell display.
- Row action buttons all say "Add" with no row context.
- Braille transcript stores real user paths in CI artifacts.
- A renderer sets `aria-braillelabel` without a normal accessible name.

## Release Gates

- Braille projection must be optional and adapter-owned.
- TreeGrid profile must include at least one braille compact-row fixture.
- Privacy-safe transcript policy must cover braille evidence.
- Public docs must state that braille output is tested as semantic projection,
  not as a promise about every display device.

## Summary

Braille support starts with clean semantic projection. Headless should expose
compact, truthful, privacy-safe braille facts while leaving actual device output
to assistive technology and platform adapters.
