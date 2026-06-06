# Web Notification Permission And Attention Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN Notifications API: https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API
- MDN using the Notifications API: https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API/Using_the_Notifications_API
- MDN `Notification.requestPermission`: https://developer.mozilla.org/en-US/docs/Web/API/Notification/requestPermission_static
- MDN Permissions API: https://developer.mozilla.org/en-US/docs/Web/API/Permissions_API
- MDN Page Visibility API: https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html
- WCAG 2.3.3 Animation from Interactions: https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions.html

## Problem

System notifications can be helpful for long scans, background work, and
attention recovery. They can also be spammy, inaccessible, privacy-leaking, or
blocked by browser policy. Headless already has in-app alerts and status
regions, but web notifications need a separate permission and attention
contract.

## Decision Options

1. Use in-app notifications only - 🎯 6   🛡️ 8   🧠 2, about 0-120 LOC. Good
   MVP default, but not enough for long background operations.
2. Add a web notification adapter contract - 🎯 8   🛡️ 9   🧠 5, about
   250-650 LOC. Best fit.
3. Add push notification infrastructure - 🎯 4   🛡️ 6   🧠 9, about
   1500-3500 LOC. Too product-specific for Headless core.

Accepted: option 2.

## Accepted Contract

Headless models notification capability:

```dart
final class RExternalNotificationCapability {
  final bool supported;
  final RPermissionState permissionState;
  final bool requiresUserActivation;
  final bool pageVisible;
  final bool canNotifyInBackground;
  final RNotificationPrivacyClass privacyClass;
}
```

In-app status remains the source of truth. External notifications are optional
attention aids.

## Rules

- Notification permission is requested only after explicit user command.
- Every external notification has an in-app status equivalent.
- Notifications avoid raw paths, file names, tokens, and delete target details
  by default.
- Denied notification permission does not break scan or cleanup.
- Repeated progress notifications are throttled.
- Completion notifications are actionable only through safe resume into the app.
- System notification click revalidates session and command authority.
- Reduced motion, quiet mode, and do-not-disturb-like app policy can suppress
  external attention.

## Clean Disk Requirements

Clean Disk may use web notifications for:

- scan complete;
- scan failed;
- daemon disconnected;
- cleanup finished;
- cleanup needs review;
- low disk warning after scan.

It must not send "Moved `/Users/name/...` to Trash" as an external notification
unless user explicitly opts into detailed notifications.

## Privacy Classes

```text
generic:
  "Scan complete"

summary:
  "Scan complete, 42.8 GB candidates"

sensitive:
  includes path, file name, user name, token, or delete target

prohibited:
  includes secrets or full cleanup target list
```

Default external notifications use generic or summary only.

## Testing Requirements

- Permission prompt does not appear on page load.
- Denied state keeps in-app status working.
- Notification click resumes app and revalidates daemon session.
- Hidden page and visible page behavior differ only by attention channel.
- Privacy redaction runs before external notification creation.
- Reduced notification setting suppresses non-critical notifications.

## Failure Catalog

- Notification prompt appears during onboarding without user intent.
- External notification leaks full path.
- User clicks stale notification and destructive action executes.
- Denied notification permission hides scan completion.
- Scan progress sends hundreds of notifications.
- Notification text is not localized.

## Release Gates

- External notification adapter is optional.
- In-app status region covers every notification event.
- Privacy classification is required for every notification template.
- Notification click handlers never bypass session validation.

## Summary

Web notifications are attention aids, not workflow truth. Headless should keep
them permission-aware, privacy-safe, throttled, and backed by in-app status.
