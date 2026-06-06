# Dwell Eye Tracking And Hover Activation Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.1.2 No Keyboard Trap: https://www.w3.org/WAI/WCAG22/Understanding/no-keyboard-trap.html
- WCAG 2.5.2 Pointer Cancellation: https://www.w3.org/WAI/WCAG22/Understanding/pointer-cancellation.html
- WCAG 2.5.5 Target Size: https://www.w3.org/WAI/WCAG22/Understanding/target-size.html
- WCAG 2.5.8 Target Size Minimum: https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html
- WCAG 2.4.7 Focus Visible: https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html
- Switch access and linear scanning standard: switch-access-linear-scanning-standard.md

## Problem

Some users activate controls through dwell, eye tracking, head tracking, hover
selection, sip-and-puff systems, or assistive pointer devices. These systems can
accidentally trigger hover menus, destructive buttons, drag handles, or
auto-advancing interactions. Standard pointer support is not enough.

Headless needs a dwell-safe activation contract.

## Decision Options

1. Treat dwell as pointer hover and click - 🎯 4   🛡️ 4   🧠 2, about 0-80
   LOC. Too dangerous for dense productivity apps.
2. Add dwell-safe command and hover policy - 🎯 9   🛡️ 9   🧠 6, about
   300-750 LOC. Best fit.
3. Build an eye-tracking adapter - 🎯 3   🛡️ 5   🧠 9, about 1800-4500 LOC.
   Not Headless core responsibility.

Accepted: option 2.

## Accepted Contract

Interactive primitives expose dwell safety:

```dart
final class RDwellActivationPolicy {
  final RSemanticId id;
  final bool canActivateByDwell;
  final bool requiresExplicitConfirm;
  final Duration? minimumDwellTime;
  final bool hoverRevealsCommands;
  final bool hoverTriggersStateChange;
  final RCommandRisk risk;
}
```

Assistive input adapters can use this to avoid accidental activation.

## Rules

- Hover alone does not execute product commands.
- Hover-revealed controls have keyboard and non-hover alternatives.
- Destructive commands are not dwell-activated without confirmation.
- Dwell activation has cancel and undo where applicable.
- Target size and spacing account for imprecise gaze or head tracking.
- Auto-dismiss timers are adjustable or disabled in dwell mode.
- Focus and hover state are visually distinct.
- Dwell progress indicators are optional and not the only state signal.

## Clean Disk Requirements

Clean Disk must be dwell-safe for:

- TreeGrid row actions;
- add to cleanup queue;
- remove from queue;
- reveal in Finder;
- Move to Trash;
- pause or cancel scan;
- permission repair buttons.

Move to Trash is never a single dwell activation. It requires validated plan,
explicit review, and confirmation.

## Dwell Risk Classes

```text
safe:
  opens details or moves focus

reversible:
  can be undone without data loss

stateChanging:
  changes queue, filter, or scan state

destructive:
  can remove, delete, revoke, or expose data
```

State-changing and destructive actions need stricter confirmation.

## Testing Requirements

- Hover never executes commands.
- Dwell mode can reveal row actions without pointer precision.
- Destructive action requires confirmation.
- Auto-dismiss overlays stay open in dwell profile.
- Targets meet dwell target size profile.
- Dwell cancel path exists.

## Failure Catalog

- Hovering over a row auto-adds it to cleanup queue.
- Dwell opens menu and immediately activates first item.
- Tooltip covers the target being dwelled.
- Destructive button has no confirmation.
- Auto-dismiss closes menu before user can dwell-select.
- Focus ring is confused with dwell progress.

## Release Gates

- Every pointer-capable primitive declares dwell policy.
- Hover-triggered UI has non-hover access.
- Destructive commands cannot be direct dwell targets.
- Dwell conformance fixtures run for menu, TreeGrid, dialog, and queue actions.

## Summary

Dwell and eye-tracking users need stable targets and safe activation. Headless
should separate hover, focus, dwell, and command execution.
