# Compliance Playbook - Flutter Adapter

## Status

Compliance checklist for Flutter implementation details.

## Standards And APIs

- Flutter accessibility testing:
  https://docs.flutter.dev/ui/accessibility/accessibility-testing
- Flutter Focus:
  https://docs.flutter.dev/ui/interactivity/focus
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Flutter web accessibility:
  https://docs.flutter.dev/ui/accessibility/web-accessibility
- Flutter integration performance profiling:
  https://docs.flutter.dev/cookbook/testing/integration/profiling

## Required Flutter Practices

Focus:

- use `Focus` or `FocusableActionDetector` for root focus;
- use `FocusScope` for dialog/menu scopes;
- keep logical focus separate from `FocusNode`;
- external `FocusNode` is not disposed.

Actions:

- use `Shortcuts` for key mapping;
- use `Actions` for command invocation;
- avoid direct focused-widget type checks;
- disabled command disables shortcut.

Semantics:

- use `tester.ensureSemantics()` in tests;
- expose labels for icon-only controls;
- avoid semantics spam from offscreen virtual rows;
- do not log semantic labels.

Guidelines:

- use Flutter Guideline API for tap target, labels, contrast;
- run dark and light renderer fixtures.

Performance:

- profile large scroll fixtures;
- record built rows/cells;
- isolate progress/status rebuilds from viewport.

## Required Test Groups

- widget behavior tests;
- semantics tests;
- accessibility guideline tests;
- renderer capability tests;
- performance smoke tests for dense primitives;
- platform smoke tests for web semantics.

## Stop Rules

- Do not rely on visual screenshots as accessibility evidence.
- Do not put keyboard behavior only in `RawKeyboard` without Actions mapping.
- Do not use real user data in Flutter fixtures.
- Do not let semantics tree include all virtual rows.
