# Guided Repair Onboarding Coachmark Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- WCAG 3.2.6 Consistent Help: https://www.w3.org/WAI/WCAG22/Understanding/consistent-help.html
- WCAG 2.4.3 Focus Order: https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html
- WCAG 2.4.11 Focus Not Obscured Minimum: https://www.w3.org/WAI/WCAG22/Understanding/focus-not-obscured-minimum.html
- WAI-ARIA APG Dialog Modal Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/
- WAI-ARIA APG Disclosure Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/
- MDN `dialog` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/dialog_role
- MDN Popover API: https://developer.mozilla.org/en-US/docs/Web/API/Popover_API

## Scope

This standard covers onboarding hints, coachmarks, guided tours, permission
repair walkthroughs, contextual help cards, first-run explainers, and guided
multi-step repair surfaces.

It extends wizard/stepper, popover, dialog, and recoverable error assistance
standards. It focuses on guidance without trapping or misleading users.

## Problem

Clean Disk needs guided flows for Full Disk Access, daemon connection, scan
target choice, cleanup review, and support export. Many apps implement this as
overlays that block the UI, steal focus, or hide the actual controls. Headless
needs a standard that lets guidance help without becoming a second UI with
different authority.

## Decision Options

1. `GuidedFlow` contract with step target, repair action, and focus policy -
   🎯 9   🛡️ 9   🧠 8, roughly 900-2000 LOC.
   Best fit. It can power onboarding and repair without hardcoding product
   workflows into Headless.
2. Ad hoc popovers around controls -
   🎯 5   🛡️ 5   🧠 3, roughly 200-600 LOC.
   Fast, but target/focus/escape/skip semantics become inconsistent.
3. Modal wizard for every guide -
   🎯 5   🛡️ 7   🧠 5, roughly 500-1200 LOC.
   Safer for linear repair, too heavy for contextual help and coachmarks.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- guide id;
- step id;
- target relationship;
- step order;
- progress facts;
- focus policy;
- skip/dismiss policy;
- repair command descriptor;
- resume state;
- announcement policy;
- privacy class.

Renderer owns:

- popover/dialog/sheet visuals;
- highlight visuals;
- arrow/anchor visuals;
- progress indicator visuals;
- animation;
- responsive placement.

Application owns:

- guide content;
- product workflow;
- permission probes;
- repair commands;
- completion criteria;
- persistence;
- localization.

## Guide Types

Types:

- onboarding;
- contextualHelp;
- permissionRepair;
- featureTour;
- destructiveReviewGuide;
- supportWorkflow;
- keyboardHelp;
- appDefined.

Each type declares:

- whether steps are optional;
- whether focus moves;
- whether target must exist;
- whether guide blocks background interaction;
- whether completion is product-confirmed;
- whether the guide can be resumed later.

## Focus And Target Rules

Coachmark:

- should not steal focus by default;
- must not hide focused control;
- target can be described by relationship;
- target absence yields fallback content.

Repair flow:

- can move focus to current step;
- must preserve user choices where possible;
- must explain external platform steps;
- completion requires re-probe from application/platform adapter.

Modal guide:

- uses dialog semantics;
- traps focus only while modal;
- returns focus to logical workflow target;
- includes visible close or cancel action.

## Help Consistency Rules

When guide/help entry points appear across routes:

- keep them in consistent order relative to other UI;
- use stable command ids;
- do not move help entry only on error;
- preserve keyboard access in compact layouts.

This supports WCAG consistent help without forcing every app to use the same
visual placement.

## Clean Disk Usage

Guides:

- first scan target selection;
- Full Disk Access repair;
- daemon connection repair;
- cleanup review explanation;
- Trash/receipt recovery explanation;
- support bundle export preview;
- keyboard shortcut help.

Rules:

- guidance cannot authorize cleanup;
- guide skip does not bypass safety confirmation;
- permission repair success requires real capability re-probe;
- external OS steps are represented as instructions, not Headless actions;
- guide state never stores raw paths or daemon tokens.

## Community API Sketch

```dart
final class RGuidedFlowModel {
  const RGuidedFlowModel({
    required this.id,
    required this.kind,
    required this.steps,
    required this.currentStepId,
    required this.focusPolicy,
  });

  final String id;
  final RGuidedFlowKind kind;
  final List<RGuideStep> steps;
  final String? currentStepId;
  final RGuideFocusPolicy focusPolicy;
}
```

## Conformance Scenarios

- coachmark does not obscure focused control;
- keyboard user can skip guide;
- modal guide restores focus;
- missing target shows fallback;
- permission repair re-probes before marking success;
- help entry appears consistently across routes;
- guide content is localized outside Headless;
- skip does not bypass confirmation policy.

## Failure Catalog

- Tour overlay traps focus with no escape.
- Highlight hides the actual focused control.
- Guide completion trusts user click instead of capability re-probe.
- Skip onboarding disables safety hints permanently.
- Help appears in different places per route without user choice.
- Coachmark target uses localized label as id.
- External OS permission step pretends to be automated.

