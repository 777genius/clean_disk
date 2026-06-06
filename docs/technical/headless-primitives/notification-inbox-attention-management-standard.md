# Notification Inbox Attention Management Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `alert` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role
- MDN `status` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN `log` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/log_role
- MDN Notifications API: https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html
- WCAG 3.2.6 Consistent Help: https://www.w3.org/WAI/WCAG22/Understanding/consistent-help.html

## Scope

This standard covers notification inboxes, notification centers, attention
badges, persistent alerts, dismissible warnings, quiet mode, unread counts,
notification grouping, and notification-to-operation links.

It extends alert/banner/toast and operation center standards. It focuses on
attention management and persistence.

## Problem

Toasts are not enough for serious tools. Clean Disk may need to surface scan
errors, permission issues, daemon reconnects, update warnings, cleanup
receipts, support bundle readiness, and low-space conditions. Some should
interrupt. Most should not. Some must persist. Headless needs a model that
prevents alert spam while preserving discoverability.

## Decision Options

1. `NotificationInbox` with severity, persistence, and attention policy -
   🎯 9   🛡️ 9   🧠 8, roughly 900-1900 LOC.
   Best fit. It gives public apps a scalable notification model without forcing
   every event into a toast.
2. Toast-only system -
   🎯 5   🛡️ 4   🧠 3, roughly 200-600 LOC.
   Fine for quick feedback, poor for persistent errors, receipts, and support.
3. Audit feed as notifications -
   🎯 5   🛡️ 6   🧠 4, roughly 300-900 LOC.
   Audit is evidence. Notifications are attention and next action.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- notification id;
- severity;
- attention level;
- persistence policy;
- unread/read state;
- dismiss state;
- group id;
- related operation or receipt ref;
- command descriptors;
- announcement policy;
- privacy class.

Renderer owns:

- toast, banner, badge, inbox, and drawer visuals;
- grouping visuals;
- animation;
- iconography;
- placement;
- compact overflow behavior.

Application owns:

- notification source;
- message text;
- command authorization;
- retention policy;
- telemetry;
- audit connection;
- user preferences.

## Attention Levels

Levels:

- silent;
- passive;
- status;
- toast;
- persistentBanner;
- requiresAttention;
- blocking;

Rules:

- urgent does not always mean modal;
- blocking requires application policy;
- unread count excludes silent diagnostic messages unless app chooses;
- dismissed does not delete audit or receipt evidence;
- repeated identical notifications coalesce by policy.

## Live Region Rules

Use:

- `status` intent for advisory updates;
- `alert` intent only for immediate attention;
- `log` intent for append-only notification histories where order matters.

Do not:

- put interactive controls inside an alert live region;
- announce every repeated warning;
- focus notifications unless they require a user decision;
- use alert on page-load static warnings.

## Persistence And Dismissal

Notification persistence:

- transient;
- untilRead;
- untilDismissed;
- untilResolved;
- untilOperationReceipt;
- retainedInHistory.

Dismissal rules:

- dismissing notification does not cancel underlying operation;
- resolving operation can auto-resolve notification;
- destructive or safety warnings require explicit policy before hiding;
- dismissed notification remains accessible in history when required.

## Clean Disk Usage

Notifications:

- scan completed;
- scan completed with skipped items;
- permission degraded;
- daemon disconnected;
- cleanup completed with receipt;
- cleanup failed;
- update available;
- support bundle ready;
- low disk warning.

Rules:

- cleanup receipt notifications link to receipt;
- permission notification links to repair flow;
- daemon disconnected disables risky actions;
- raw paths are redacted by privacy policy;
- notification center does not execute destructive commands directly.

## Community API Sketch

```dart
final class RNotificationItem {
  const RNotificationItem({
    required this.id,
    required this.severity,
    required this.attention,
    required this.persistence,
    required this.commands,
  });

  final String id;
  final RNotificationSeverity severity;
  final RAttentionLevel attention;
  final RNotificationPersistence persistence;
  final List<RCommandDescriptor> commands;
}
```

## Conformance Scenarios

- urgent alert is announced once;
- passive notification is discoverable in inbox;
- unread count ignores dismissed read items;
- cleanup receipt notification persists until receipt seen or dismissed;
- repeated daemon reconnect warnings coalesce;
- notification command uses command router;
- raw path does not appear in notification telemetry;
- keyboard user can open notification inbox.

## Failure Catalog

- Every warning is an assertive alert.
- Toast disappears and failure becomes undiscoverable.
- Dismiss cancels operation unexpectedly.
- Notification action bypasses policy.
- Unread count includes hidden diagnostics.
- Same warning repeats endlessly.
- Receipt notification has no receipt link.

