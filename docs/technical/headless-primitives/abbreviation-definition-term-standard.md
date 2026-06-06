# Abbreviation Definition And Term Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN `abbr`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/abbr
- MDN `dfn`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/dfn
- WCAG 3.1.3 Unusual Words: https://www.w3.org/WAI/WCAG22/Understanding/unusual-words.html
- WCAG 3.1.4 Abbreviations: https://www.w3.org/WAI/WCAG22/Understanding/abbreviations.html
- WCAG 3.1.6 Pronunciation: https://www.w3.org/WAI/WCAG22/Understanding/pronunciation.html
- WCAG 3.1.5 Reading Level: https://www.w3.org/WAI/WCAG22/Understanding/reading-level.html

## Problem

Storage tools contain terms that are obvious to engineers and opaque to many
users: APFS, NTFS, inode, hardlink, symlink, clone, sparse file, snapshot,
reparse point, reflink, quota, allocated size, exclusive reclaim, daemon,
origin, token, capability, and receipt. Public Headless components also expose
technical vocabulary in tables, diagnostics, docs, tooltips, and status text.

If terms are not modeled, teams either over-explain every row or hide critical
meaning behind jargon.

## Decision Options

1. Let products write prose manually - 🎯 5   🛡️ 5   🧠 2, about
   0-120 LOC. Works for small apps, inconsistent for public Headless.
2. Add glossary-backed term descriptors - 🎯 9   🛡️ 9   🧠 5, about
   350-900 LOC. Best fit.
3. Build full documentation CMS into Headless - 🎯 2   🛡️ 4   🧠 10, about
   3000-8000 LOC. Not UI-kit responsibility.

Accepted: option 2.

## Accepted Contract

Headless receives term descriptors:

```dart
final class RTermDescriptor {
  final String termId;
  final String displayText;
  final String? expandedForm;
  final String? shortDefinition;
  final String? pronunciation;
  final RTermKind kind;
  final RDisclosurePolicy disclosurePolicy;
  final RLocalizationKey? glossaryKey;
}
```

The product owns glossary content and translation. Headless owns term rendering,
definition discovery, and accessible disclosure behavior.

## Term Kinds

```text
abbreviation:
  shortened term such as APFS or GB

acronym:
  abbreviation pronounced as a word

jargon:
  domain-specific word needing definition

commandTerm:
  product command or policy word

technicalName:
  protocol, file system, API, or OS concept

plainLanguageAlias:
  user-friendly term mapped to technical term
```

## Rules

- First meaningful occurrence of uncommon term should have definition access.
- Abbreviations need expanded form when not commonly understood in context.
- Pronunciation hints are allowed where ambiguity changes meaning.
- Stable technical terms are not translated as identifiers, but definitions are
  localized.
- Tooltip-only definitions are insufficient. Keyboard and screen-reader users
  need access.
- Terms inside virtualized rows should not repeat long definitions on every
  focus move.
- Glossary links must not steal focus unexpectedly.
- Definition text must not contain cleanup authority or hidden commands.

## Clean Disk Required Terms

Clean Disk should define at least:

- allocated size;
- logical size;
- exclusive reclaim;
- APFS clone;
- snapshot;
- hardlink;
- symlink;
- permission denied;
- Full Disk Access;
- Trash;
- quarantine;
- daemon;
- local token;
- scan snapshot;
- DeletePlan;
- receipt.

## Disclosure Patterns

```text
inlineExpanded:
  first occurrence shows full term with abbreviation

detailsOnDemand:
  term has focusable help or details action

glossaryLink:
  navigates to glossary entry

descriptionAssociation:
  definition associated with field or message

silentKnownTerm:
  no disclosure because term is common for selected audience
```

## Accessibility Rules

- Definition affordance is reachable by keyboard.
- Screen readers can discover expanded form or definition.
- Definition disclosure does not interrupt table navigation.
- Repeated abbreviations may use short accessible text after first definition.
- Plain-language summary should exist for destructive or safety-critical terms.
- Term ids are stable and locale-independent.

## Testing Requirements

- First occurrence has definition access.
- Keyboard user can open and close definition.
- Screen-reader output includes expanded form where configured.
- Virtualized row navigation is not flooded by repeated definitions.
- Glossary localization does not change term ids.
- High-density table can suppress visual clutter while preserving help access.

## Failure Catalog

- APFS clone appears with no explanation near reclaim estimate.
- Tooltip is the only definition.
- Definition appears on hover and blocks row selection.
- Translated glossary text is used as stable policy code.
- Screen reader repeats "Application Programming File System" incorrectly.
- Definition panel contains raw user path.

## Release Gates

- Technical terms in core Headless examples use term descriptors.
- Clean Disk safety and filesystem terms have glossary entries.
- Definition disclosure works without pointer hover.
- Term ids are stable across locales.
- Accessibility snapshots verify abbreviation expansion paths.

## Summary

Technical vocabulary needs a glossary-backed contract. Headless should expose
abbreviations, definitions, pronunciation hints, and plain-language aliases
without turning every dense UI into a wall of explanatory text.
