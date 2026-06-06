# Alert Banner Toast And Notification Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `alert` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role
- MDN `status` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN ARIA live regions: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Guides/Live_regions
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WAI-ARIA APG Alert Dialog Pattern: https://www.w3.org/WAI/ARIA/apg/patterns/alertdialog/
- Flutter SnackBar: https://docs.flutter.dev/cookbook/design/snackbars
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers alerts, banners, inline notices, toast/snackbar messages,
notification queues, connection banners, permission banners, scan warnings,
cleanup results, and dismissible informational messages.

It does not cover modal confirmation dialogs. If user response is required,
use dialog or alertdialog.

## Decision Options

1. Central `NotificationRegion` with severity, politeness, queueing, and privacy
   policy - 🎯 9   🛡️ 9   🧠 7, roughly 800-1600 LOC.
   Best fit. It avoids alert spam and gives consistent behavior across Flutter,
   web, and future daemon UI.
2. Use Flutter SnackBar directly everywhere - 🎯 5   🛡️ 6   🧠 3, roughly 200-500 LOC.
   Good for quick feedback, but weak for severity, live region, privacy, and
   queue policy.
3. Treat all notifications as assertive alerts - 🎯 2   🛡️ 3   🧠 3, roughly 150-400 LOC.
   Technically simple and practically awful. It interrupts assistive technology
   users constantly.

Accepted direction: option 1.

## Notification Types

Status:

- polite update;
- no focus move;
- short message;
- examples: scan started, search complete, queue updated.

Alert:

- assertive update;
- text only;
- no required user interaction;
- examples: daemon disconnected while operation is unsafe, cleanup failed.

Banner:

- persistent page or app-level notice;
- may contain actions;
- focus does not move automatically unless route/workflow requires it.

Toast/snackbar:

- transient visual notification;
- may include one action;
- must have accessible announcement policy;
- must not be the only place where critical information is stored.

Alert dialog:

- modal;
- requires user response;
- use existing dialog standard.

## Primitive Boundary

Headless owns:

- message id;
- severity: info, success, warning, error, critical;
- delivery kind: status, alert, banner, toast, snackbar, modal handoff;
- politeness policy;
- queueing and dedupe;
- timeout and persistence policy;
- dismissibility;
- actions and action labels;
- privacy class;
- source operation id;
- receipt or details link contract;
- announcement throttle.

Renderer owns:

- visual placement, animation, color, icon, close button, density, stacking, and
  compact layout.

Application owns:

- message generation;
- operation truth;
- recovery actions;
- localization;
- audit and support-bundle inclusion.

## Required Rules

MUST:

- use alert only for urgent, time-sensitive text;
- use status or polite live region for routine updates;
- avoid moving focus for toast/status messages;
- make persistent banners keyboard reachable;
- expose dismiss buttons with labels;
- queue or dedupe repeated messages;
- keep critical outcome available outside transient toast;
- classify message text before logging or announcing;
- avoid raw paths, daemon tokens, and full query text in notifications by
  default.

SHOULD:

- provide a details command for long errors;
- provide receipt link for cleanup outcomes;
- collapse repeated scan warnings into grouped status;
- let user reduce or mute noncritical announcements;
- persist critical banners until resolved or dismissed.

MUST NOT:

- put links or buttons inside `role="alert"` content;
- use toast as the only confirmation for destructive cleanup;
- announce every scan progress tick;
- auto-dismiss critical errors before user can read them;
- use color alone for severity.

## Clean Disk Mapping

Use status:

- search returned result count;
- scan started, paused, resumed;
- item added to queue;
- queue total updated.

Use banner:

- Full Disk Access missing;
- daemon disconnected;
- scan quality degraded;
- read-only remote mode active;
- incompatible daemon version.

Use alert:

- cleanup operation failed in a way that may leave user uncertain;
- daemon disconnected during a destructive operation;
- receipt persistence failed.

Use dialog:

- move to trash confirmation;
- irreversible cleanup;
- destructive remote operation.

## Conformance Tests

Minimum tests:

- info message uses status/polite announcement;
- critical text-only message can use alert;
- alert with interactive child fails conformance;
- toast with action exposes action label;
- repeated scan messages dedupe;
- critical banner persists after route rebuild;
- raw paths are redacted by default;
- focus remains in current context after toast;
- banner dismiss button is reachable and labelled;
- cleanup success toast links to durable receipt or details.

## Failure Catalog

- Alert spam from routine updates.
- Toast disappears before keyboard user can act.
- Critical cleanup result exists only in a transient snackbar.
- Interactive alert content is announced but not reachable.
- Severity conveyed only through red/yellow color.
