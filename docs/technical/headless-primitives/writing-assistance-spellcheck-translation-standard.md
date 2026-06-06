# Writing Assistance Spellcheck And Translation Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN `autocorrect`: https://developer.mozilla.org/docs/Web/HTML/Reference/Global_attributes/autocorrect
- MDN `inputmode`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/inputmode
- MDN `spellcheck`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/spellcheck
- MDN `translate`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/translate
- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 3.3.3 Error Suggestion: https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html
- WCAG 3.1.1 Language of Page: https://www.w3.org/WAI/WCAG22/Understanding/language-of-page.html
- WCAG 3.1.2 Language of Parts: https://www.w3.org/WAI/WCAG22/Understanding/language-of-parts.html

## Problem

Users depend on spellcheck, autocorrect, grammar tools, machine translation,
dictionary popups, and input mode hints. Technical apps often disable these
features globally or enable them where they corrupt tokens, paths, commands, and
codes. Headless needs a policy that treats writing assistance as a scoped user
aid.

## Decision Options

1. Leave writing assistance to raw attributes - 🎯 5   🛡️ 5   🧠 2, about
   40-120 LOC. Flexible but inconsistent.
2. Add writing assistance policy descriptors - 🎯 9   🛡️ 9   🧠 5, about
   250-650 LOC. Best fit.
3. Build custom spelling and translation UI - 🎯 3   🛡️ 5   🧠 10, about
   2500-6000 LOC. Not Headless responsibility.

Accepted: option 2.

## Accepted Contract

Text inputs expose writing assistance policy:

```dart
final class RWritingAssistancePolicy {
  final bool spellcheck;
  final bool autocorrect;
  final bool grammarSuggestions;
  final bool machineTranslationAllowed;
  final String? inputMode;
  final String languageTag;
  final RTextSensitivity sensitivity;
}
```

Adapters map policy to HTML attributes, native text input traits, or no-op.

## Rules

- Natural language fields may enable spellcheck and autocorrect.
- Paths, commands, tokens, one-time codes, regexes, and IDs disable autocorrect
  by default.
- Spellcheck and autocorrect are not used as validation.
- Machine translation is not applied to code, tokens, paths, or command ids.
- Language of text is explicit where it differs from app locale.
- Error suggestions are visible text, not only native spellcheck underline.
- User preference can override assistance where safe.
- Translation never changes stable command identity.

## Clean Disk Requirements

Clean Disk fields:

- search text: spellcheck optional, autocorrect off by default for paths;
- custom path: spellcheck off, autocorrect off, translation off;
- pairing token: spellcheck off, autocorrect off, translation off;
- support note: spellcheck on, autocorrect user preference;
- command palette: spellcheck off, command identity stable;
- filter value: depends on typed filter kind.

## Sensitivity Classes

```text
naturalLanguage:
  notes, descriptions, support text

technical:
  paths, commands, file extensions, regexes

secret:
  tokens, passwords, one-time codes

localizedDisplay:
  UI text that may be translated

stableIdentifier:
  command ids, policy codes, schema keys
```

## Testing Requirements

- Field policy snapshots for each input type.
- Path fields do not enable autocorrect.
- Token fields do not enable translation.
- Natural-language support fields expose language.
- Error suggestions remain visible without spellcheck UI.
- Localized command labels do not alter command ids.

## Failure Catalog

- Autocorrect changes `/usr/bin` into ordinary words.
- Browser translates command id used by automation.
- Pairing token is spellchecked and leaked to dictionary service.
- Search field autocorrect changes file extension.
- Validation relies only on red spellcheck underline.
- App disables spellcheck globally, hurting support note entry.

## Release Gates

- Every text primitive declares writing assistance policy.
- Secret and technical fields fail closed.
- Translation boundaries are explicit.
- Clean Disk path and token fields are protected before web release.

## Summary

Writing assistance helps users when scoped correctly. Headless should expose
spellcheck, autocorrect, translation, and input-mode policy per text field.
