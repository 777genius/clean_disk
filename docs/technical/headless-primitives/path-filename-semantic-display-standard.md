# Path Filename Semantic Display Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN `wbr`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/wbr
- MDN `bdi`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/bdi
- MDN `code`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/code
- WCAG 1.3.1 Info and Relationships: https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html
- WCAG 3.1.2 Language of Parts: https://www.w3.org/WAI/WCAG22/Understanding/language-of-parts.html
- WCAG 4.1.2 Name, Role, Value: https://www.w3.org/WAI/WCAG22/Understanding/name-role-value.html
- W3C Internationalization bidi guidance: https://www.w3.org/International/articles/inline-bidi-markup/

## Problem

Paths and filenames are not ordinary labels. They can be long, private,
directionally mixed, punctuation-heavy, duplicate, truncated, generated,
virtual, cloud-backed, case-sensitive or case-insensitive, and unsafe as
identity. A component that treats a path as plain text creates layout overflow,
wrong copy behavior, broken screen-reader output, privacy leaks, and dangerous
cleanup authority.

Headless needs a reusable path and filename display contract.

## Decision Options

1. Render paths as plain strings - 🎯 3   🛡️ 3   🧠 1, about 20-80 LOC.
   Fast, but breaks privacy, bidi, truncation, copy, and long-table layouts.
2. Add a semantic path display model - 🎯 9   🛡️ 9   🧠 6, about
   450-1000 LOC. Best fit for Clean Disk and public Headless.
3. Build a filesystem path library inside Headless - 🎯 4   🛡️ 5   🧠 9,
   about 1800-4000 LOC. Too much domain ownership for a UI kit.

Accepted: option 2.

## Accepted Contract

Headless receives path display facts, not raw filesystem authority:

```dart
final class RPathDisplayModel {
  final String displayName;
  final List<RPathSegment> segments;
  final String? redactedDisplayPath;
  final String? copyValue;
  final RPathDisplayKind kind;
  final RTextDirectionPolicy directionPolicy;
  final RPrivacyClass privacyClass;
  final RTruncationPolicy truncationPolicy;
  final bool copyRequiresExplicitCommand;
}
```

The app decides the real path, redaction policy, and cleanup authority.
Headless only renders, navigates, copies through policy, and exposes semantics.

## Path Kinds

```text
nativeAbsolute:
  ordinary local path with platform separators

nativeRelative:
  relative path shown only as context, never authority

virtual:
  provider path, cloud path, archive path, package path, or remote path

displayOnly:
  friendly label with no copyable filesystem value

redacted:
  privacy-preserving path summary
```

## Segment Model

Each segment should support:

- stable segment id;
- visible text;
- raw copy value if allowed;
- separator before or after segment;
- direction isolation flag;
- truncation priority;
- privacy class;
- optional icon or provider marker;
- issue marker, such as inaccessible, cloud-only, symlink, mount, deleted;
- optional tooltip or details command.

Segment ids are not filesystem identity. They only stabilize rendering.

## Display Rules

- Use middle truncation for long paths when the last segment is important.
- Preserve the filename or selected segment before preserving ancestors.
- Do not use raw path as DOM id, test id, semantics id, route id, or command id.
- Use bidi isolation for unknown or user-provided segments.
- Provide line-break opportunities at separators and safe boundaries.
- Do not insert visible punctuation that changes copy value.
- Do not depend on visual order for copy, selection, or cleanup commands.
- Ellipsis indicates hidden display text, not hidden authority.
- Display path and copy path can differ by policy.
- Redacted path must be visibly different from complete path.

## Web Mapping

For web adapters:

- `wbr` can represent safe break opportunities in long paths.
- `bdi` or equivalent isolation protects mixed-direction filenames.
- `code` can be used for technical path fragments when the visual design wants
  monospace semantics.
- accessible names should summarize the current item first, then path context.
- details views may expose full path only through an explicit disclosure or
  copy command when privacy policy permits.

Flutter adapters need equivalent text spans, semantics labels, and copy policy.

## Clean Disk Requirements

Clean Disk must distinguish:

- display name in the tree row;
- visible breadcrumb path;
- details full path;
- copy path command;
- DeletePlan target identity;
- scan snapshot node id;
- daemon query path filters;
- support-bundle redacted path.

Only DeletePlan and daemon validation can authorize cleanup. A path shown in UI
is never enough.

## Accessible Output Rules

Tree rows should not announce the full absolute path on every movement. A good
row announcement is:

```text
Caches, folder, 38.7 gigabytes, selected, level 4, 24,981 items.
```

Details pane may expose:

```text
Path, Users slash belief slash Library slash Caches.
```

Long path disclosure should be user-controlled, copyable, and redaction-aware.

## Privacy Rules

Raw paths can reveal user names, company names, project names, account names,
cloud providers, secrets, and customer data.

Default Headless diagnostics must avoid:

- raw path text;
- filename-derived ids;
- path-bearing accessibility snapshots;
- path-bearing screenshots without redaction;
- path-bearing telemetry labels.

## Testing Requirements

- Long LTR path wraps without overflow.
- Mixed RTL and LTR filename keeps copy value correct.
- Redacted path does not expose hidden segments.
- Full path is not announced in every virtualized row.
- Copy command returns policy-approved value only.
- Path segments survive theme, zoom, density, and text-scale changes.
- Duplicate filenames remain distinguishable through context.
- Truncation does not hide selected node name.

## Failure Catalog

- Raw path becomes cleanup authority.
- Row semantics announce 400 characters per arrow key.
- RTL filename reorders separators visually and corrupts copy.
- Ellipsis hides the selected filename.
- Support bundle stores real user path from accessibility tree snapshot.
- Copy selection accidentally includes hidden path columns.
- Breadcrumb path overflows compact layout.

## Release Gates

- Every public path-rendering primitive uses `RPathDisplayModel`.
- Copy is an explicit command with privacy policy.
- Bidi and long-path fixtures pass.
- Clean Disk does not pass raw paths into Headless diagnostics.
- Cleanup actions use validated domain objects, not displayed text.

## Summary

Paths need their own semantic display model. Headless should render segmented,
redaction-aware, bidi-safe paths while keeping filesystem authority outside UI.
