# PWA Service Worker Install And Offline Boundary Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN Progressive Web Apps: https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps
- MDN making PWAs installable: https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Making_PWAs_installable
- MDN standalone app: https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/How_to/Create_a_standalone_app
- MDN offline and background operation: https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Offline_and_background_operation
- MDN Service Worker API: https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API
- MDN using service workers: https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API/Using_Service_Workers
- MDN Web app manifest: https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Manifest

## Problem

Installable web apps and service workers can make a UI feel native, but they
also create dangerous ambiguity for daemon-driven apps. A cached UI may be
available while the daemon is offline, stale, incompatible, or no longer
authorized. Offline shell availability must not imply scan or cleanup authority.

## Decision Options

1. Add service worker immediately for app-like feel - 🎯 4   🛡️ 4   🧠 4,
   about 250-600 LOC. Risky for Clean Disk because stale UI can mislead users.
2. Add explicit install/offline boundary before enabling service worker - 🎯 9
   🛡️ 10   🧠 6, about 350-900 LOC. Best fit.
3. Never support installable web UI - 🎯 5   🛡️ 8   🧠 1, about 0-80 LOC. Safe
   but unnecessarily limits future remote UI.

Accepted: option 2.

## Accepted Contract

Headless exposes web shell state:

```dart
final class RWebShellRuntimeState {
  final bool isInstalled;
  final bool isServedByServiceWorker;
  final bool uiShellMayBeStale;
  final bool daemonReachable;
  final bool protocolCompatible;
  final bool commandsAllowed;
  final ROfflineAuthority offlineAuthority;
}
```

Offline UI is presentation state. It is not command authority.

## Rules

- Service worker does not cache daemon auth tokens.
- Cached UI must verify daemon version and capability before risky commands.
- Offline state is explicit and visible.
- Installed PWA mode does not hide origin, daemon identity, or capability.
- Service worker update can force compatibility recheck.
- Background sync does not perform destructive operations.
- Push or notification state does not imply daemon connection.
- App shell cache has version and invalidation policy.

## Clean Disk Requirements

Clean Disk should not enable offline-first service worker for daemon-served UI
until:

- protocol compatibility UX is designed;
- daemon identity display exists;
- stale shell state is visible;
- destructive actions fail closed;
- update and rollback policy exists;
- support bundle can show shell version and daemon version separately.

Scan history may be viewed offline only if it is clearly historical and not a
current cleanup target.

## Offline Authority Classes

```text
none:
  shell can show unavailable state only

readCached:
  shell can show cached snapshots marked stale

queueIntent:
  shell may store non-destructive draft intent

executeSafe:
  shell may execute safe commands after reconnect validation

executeDestructive:
  prohibited for offline UI in Headless baseline
```

## Testing Requirements

- Cached shell with daemon offline disables cleanup.
- Cached shell with incompatible daemon shows protocol state.
- Service worker update triggers revalidation.
- Installed mode still shows daemon identity.
- Offline history cannot create a delete plan.
- Support diagnostics include shell version and cache status.

## Failure Catalog

- User opens installed UI and sees stale "connected" state.
- Cached snapshot lets user queue delete against old node ids.
- Background sync retries cleanup after reconnect.
- Service worker serves old JS against new daemon protocol.
- Installed PWA hides that it is a hosted UI controlling local service.
- Support report cannot tell shell version from daemon version.

## Release Gates

- No service worker for Clean Disk until stale UI gates pass.
- Destructive commands require live daemon validation.
- Offline cached views are labeled historical or stale.
- Service worker cache policy is documented and testable.

## Summary

PWA installability is useful, but offline shell availability must never imply
fresh daemon authority. Headless should model installed, cached, stale, and
authorized states separately.
