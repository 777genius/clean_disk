# Frontend I18n And Localization Decision

Last updated: 2026-05-16.

This document records the accepted Flutter i18n/l10n library decision and the
frontend localization boundary for Clean Disk.

## Research Snapshot

Checked on 2026-05-16:

- Flutter official internationalization docs recommend `flutter_localizations`,
  generated `AppLocalizations`, ARB files, and `MaterialApp`
  `localizationsDelegates` / `supportedLocales`.
- Flutter `gen-l10n` is available in Flutter 3.41.9. `synthetic-package` is
  deprecated and cannot be enabled, so generated files should live in a real
  package output directory.
- `intl` latest checked pub.dev version is `0.20.2`.
- `slang` latest checked pub.dev version is `4.14.0`; `slang_flutter` latest
  checked version is `4.14.0`.
- `easy_localization` latest checked pub.dev version is `3.0.8`.

Useful references:

- Flutter official i18n docs:
  https://docs.flutter.dev/ui/internationalization
- `intl` package:
  https://pub.dev/packages/intl
- `slang` package:
  https://pub.dev/packages/slang
- `slang_flutter` package:
  https://pub.dev/packages/slang_flutter
- `easy_localization` package:
  https://pub.dev/packages/easy_localization

## Accepted Decision

Use Flutter official `gen-l10n` plus `flutter_localizations` plus `intl`.

Clean Disk localizations live in a shared Flutter package:

```text
packages/localization
  -> ARB files
  -> generated CleanDiskLocalizations
  -> BuildContext convenience extension
```

The app shell wires delegates and supported locales. Feature presentation code
may import `clean_disk_localization`, but domain, application, data,
repositories, and protocol DTOs must not.

## Top Options

1. Official Flutter `gen-l10n` in shared `packages/localization` - 🎯 10
   🛡️ 10  🧠 5, roughly 250-700 LOC for setup, initial ARB, generated code,
   tests, and wiring.
   Accepted. It is SDK-supported, uses ARB/ICU, integrates with Material,
   avoids a third-party runtime wrapper, and fits package boundaries.
2. `slang` + `slang_flutter` in shared package - 🎯 8  🛡️ 8  🧠 6, roughly
   350-900 LOC.
   Strong future candidate if we need richer namespacing or stronger generated
   translation ergonomics. Not first choice because it adds third-party runtime
   and codegen surface for a project that can use Flutter SDK tooling.
3. `easy_localization` - 🎯 6  🛡️ 7  🧠 4, roughly 250-800 LOC.
   Good for fast apps, but its string-key and context-extension style is easier
   to misuse in feature widgets, and it adds runtime localization state we do
   not need for MVP.

## Boundary Rules

Localization is presentation concern.

Allowed:

- `apps/clean_disk` wires localization delegates and supported locales;
- `features/*/presentation` imports `clean_disk_localization`;
- design-system primitives accept already-localized strings or semantic labels;
- presentation formatters convert value objects into display strings;
- widgets use localized strings through the shared localization package.

Forbidden:

- domain/application/data importing `clean_disk_localization`;
- protocol DTOs containing localized display copy;
- repositories returning localized strings;
- feature packages importing `apps/clean_disk` for generated localizations;
- raw `Intl.message` calls scattered across widgets;
- string keys passed around as command or domain identifiers.

## Package Shape

Accepted shape:

```text
packages/localization/
  pubspec.yaml
  l10n.yaml
  lib/
    clean_disk_localization.dart
    l10n/
      app_en.arb
      app_ru.arb
    src/
      generated/
        clean_disk_localizations.dart
        clean_disk_localizations_en.dart
        clean_disk_localizations_ru.dart
```

Generated files are produced by Flutter `gen-l10n`. They must not be edited by
hand.

## Formatting Boundary

Do not let widgets format domain facts directly.

Required flow:

```text
Application value object
  -> presentation formatter
  -> localized display string
  -> widget
```

Examples:

- byte sizes use one formatter policy;
- percentages use one formatter policy;
- dates/times use locale-aware formatters;
- plural text comes from ARB ICU messages;
- path display goes through safe path rendering rules before display.

## Locale Scope

MVP supported locales:

- `en`;
- `ru`.

English is the template locale. Russian is added immediately because the
project owner uses Russian and early UI wording decisions will be easier to
validate with real strings.

Future locale additions must include:

- ARB file;
- translator descriptions for new keys;
- golden/widget smoke for key screens;
- review of text length in wide and compact layouts.

## Stop Rules

Stop implementation and revisit if:

- a feature imports app-local generated localization code;
- a store/widget uses raw string keys instead of generated getters;
- domain/application code formats user-facing text;
- a localized string becomes command identity;
- generated localization files are hand-edited;
- adding a locale breaks compact layout or tree/table row height.

## Final Decision

Use official Flutter `gen-l10n` in `packages/localization`, export
`CleanDiskLocalizations`, and wire it through `apps/clean_disk`.

This keeps localization SDK-supported, type-safe enough for MVP, compatible with
Flutter web/desktop, and aligned with Clean Architecture package boundaries.
