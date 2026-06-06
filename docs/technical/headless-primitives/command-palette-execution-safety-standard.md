# Command Palette Execution Safety Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WAI-ARIA APG Combobox Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/combobox/
- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Menu Button Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/menu-button/
- MDN `aria-activedescendant`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-activedescendant
- MDN User activation: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/User_activation
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html

## Scope

This standard covers command palette execution, command search result safety,
active command versus executed command, destructive command blocking, stale
command invalidation, command previews, and command palette audit facts.

It extends combobox/command palette, command routing, command provenance, and
destructive action standards. It focuses on execution safety.

## Problem

A command palette can become a universal bypass if it executes commands without
the same policy as buttons, menus, and context menus. In Clean Disk, a palette
could expose "Move to Trash", "Add all to queue", or "Cancel scan". It must not
execute risky commands from search result focus alone or from stale context.

## Decision Options

1. Palette result is a command candidate routed through command authority -
   🎯 10   🛡️ 10   🧠 8, roughly 900-2000 LOC.
   Best fit. It lets Headless provide powerful command search while preserving
   application policy.
2. Palette directly invokes callbacks from result items -
   🎯 4   🛡️ 4   🧠 3, roughly 200-600 LOC.
   Fast, but bypasses authorization, stale checks, audit, and confirmation.
3. Read-only command palette for navigation only -
   🎯 7   🛡️ 8   🧠 3, roughly 200-600 LOC.
   Safe for MVP, but too limited for community Headless.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- input text state;
- active result id;
- command candidate list;
- command group metadata;
- enabled/disabled/stale facts;
- preview requirement facts;
- keyboard model;
- execution intent event;
- close/restore focus policy;
- privacy class.

Renderer owns:

- overlay layout;
- result row visuals;
- icons and shortcut hints;
- preview panel visuals;
- loading visuals;
- empty/error visuals.

Application owns:

- command catalog;
- command authorization;
- command execution;
- confirmation policy;
- stale context validation;
- audit and telemetry.

## Core Rule

Active result is not executed command.

```text
input text
  != active command candidate
  != selected command
  != authorized command execution
```

Execution path:

```text
palette commit
  -> command intent
  -> command router
  -> policy validation
  -> optional preview/confirmation
  -> execution
  -> receipt/status
```

## Command Candidate Facts

Each candidate includes:

- stable command id;
- scope id;
- display label;
- accessible label;
- description;
- group;
- shortcut;
- enabled state;
- disabled reason;
- risk;
- stale state;
- requires preview;
- requires confirmation;
- privacy class.

Display label is not command identity.

## Keyboard And Focus Rules

Rules:

- text input owns text editing and IME composition;
- arrow keys move active option by combobox/list policy;
- Enter commits active candidate only when candidate is executable or previewable;
- Escape closes palette before clearing outer state;
- Tab behavior is explicit and tested;
- focus returns to invoker or safe app region after close;
- stale active candidate is not executed.

## Destructive Command Rules

Destructive commands from palette:

- are never executed immediately if policy requires confirmation;
- can open preview/confirmation flow;
- must show current scope;
- must show disabled reason if unavailable;
- must revalidate context after palette close/open;
- must not rely on visible result ordering.

Clean Disk default:

- palette can navigate to cleanup queue or open delete review;
- palette cannot directly execute Move to Trash;
- palette cannot "delete selected" from stale selection;
- palette can expose "cancel scan" if command routing authorizes it.

## Stale Context Rules

Invalidate candidates when:

- selection changes;
- route changes;
- scan snapshot changes;
- daemon capability changes;
- permission quality changes;
- queue changes;
- command catalog version changes.

When invalidated:

- active candidate is re-evaluated;
- stale destructive candidates become disabled;
- result label can remain visible with stale marker;
- execution path must re-query authority.

## Privacy Rules

Palette input and result context can reveal intent:

- do not log raw palette query;
- do not put query in route;
- telemetry uses command id only after execution or explicit selection policy;
- support bundles redact query text;
- result labels with private paths follow path display policy.

## Community API Sketch

```dart
final class RCommandCandidate {
  const RCommandCandidate({
    required this.commandId,
    required this.scope,
    required this.availability,
    required this.risk,
    required this.previewPolicy,
  });

  final String commandId;
  final RCommandScope scope;
  final RCommandAvailability availability;
  final RCommandRisk risk;
  final RPreviewPolicy previewPolicy;
}
```

## Conformance Scenarios

- active candidate does not execute until explicit commit;
- IME composition does not execute command;
- disabled candidate exposes reason;
- destructive candidate opens confirmation instead of direct action;
- stale candidate cannot execute;
- query text is absent from diagnostics;
- focus returns to invoker after close;
- command id is shared with toolbar/menu invocation.

## Failure Catalog

- Palette result callback bypasses command router.
- Enter executes stale destructive command.
- Query text is logged.
- Visible result label is used as command id.
- Palette can delete selected items without current plan.
- Escape closes app dialog before closing palette.
- Disabled command silently disappears with no recovery path.

