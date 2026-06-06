# Browser Permission Prompt Orchestration Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN Permissions API: https://developer.mozilla.org/en-US/docs/Web/API/Permissions_API
- MDN Using the Permissions API: https://developer.mozilla.org/en-US/docs/Web/API/Permissions_API/Using_the_Permissions_API
- MDN Permissions Policy: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Permissions_Policy
- MDN user activation: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/User_activation
- WCAG 3.3.1 Error Identification: https://www.w3.org/WAI/WCAG22/Understanding/error-identification.html
- WCAG 3.3.3 Error Suggestion: https://www.w3.org/WAI/WCAG22/Understanding/error-suggestion.html
- WCAG 3.2.1 On Focus: https://www.w3.org/WAI/WCAG22/Understanding/on-focus.html
- WCAG 3.2.2 On Input: https://www.w3.org/WAI/WCAG22/Understanding/on-input.html

## Problem

Browser permissions are not ordinary app dialogs. They are controlled by the
user agent, may require user activation, can be blocked by Permissions Policy,
may be denied permanently, and often cannot be styled or fully described by the
app. A UI kit must not trigger prompts on render, hide denial state, or make the
same feature look available when the browser has blocked it.

## Decision Options

1. Let adapters call browser APIs directly - 🎯 4   🛡️ 4   🧠 2, about 0-100
   LOC. Easy, but causes surprise prompts and inconsistent recovery.
2. Add a permission prompt orchestration primitive - 🎯 9   🛡️ 9   🧠 6, about
   350-850 LOC. Best fit for Headless.
3. Build a full browser permission manager UI - 🎯 5   🛡️ 7   🧠 9, about
   1600-3500 LOC. Too large for core primitives.

Accepted: option 2.

## Accepted Contract

Headless models permission requests:

```dart
final class RPermissionPromptRequest {
  final RPermissionKind kind;
  final RPermissionPurpose purpose;
  final RPermissionState knownState;
  final bool requiresUserActivation;
  final bool blockedByPolicy;
  final bool canRetryInApp;
  final bool needsBrowserSettings;
}
```

The adapter owns browser calls. Components own affordance and recovery state.

## Rules

- Prompts are never triggered during build, mount, route restore, or hover.
- Prompts require an explicit user command.
- Pre-prompt explanation is visible and accessible.
- Denied, dismissed, unavailable, policy-blocked, and unsupported are distinct
  states.
- Retry loops are rate-limited and never nag.
- The app explains browser settings recovery when in-app retry cannot work.
- Permissions are capability evidence, not business authority.

## Clean Disk Requirements

Clean Disk may need web permissions for:

- notifications;
- file or directory picker where browser UI is used;
- local network access for hosted UI to daemon if that mode is ever enabled;
- clipboard copy of support bundles or pairing tokens;
- downloads and report export.

Daemon-served loopback UI should avoid unnecessary browser prompts in MVP.

## Prompt State Model

```text
unknown:
  not queried or cannot query

available:
  can ask after user activation

prompting:
  user agent prompt active or pending

granted:
  capability available

denied:
  user denied or browser denied

blockedByPolicy:
  Permissions Policy or embedding context blocks it

unsupported:
  browser does not support the API
```

## Testing Requirements

- Prompt cannot fire on render.
- Denied permission shows recoverable UI.
- Policy-blocked state does not offer useless retry.
- Unsupported browser path is visible.
- User activation requirement is tested with real click or test driver command.
- Screen-reader status announces state changes without repeating every frame.

## Failure Catalog

- Notification permission prompt appears on page load.
- File picker opens from a background reaction.
- Denied clipboard permission still shows "Copied".
- Embedded iframe blocks capability but UI says "Enable".
- Permission state is cached across sessions without rechecking.
- Prompt denial disables unrelated features.

## Release Gates

- Any browser permission use goes through the orchestration primitive.
- Prompt states are represented in DTOs or app state without raw browser text.
- Permission evidence is redacted in support bundles.
- Capability docs list unsupported and policy-blocked behavior.

## Summary

Browser permission prompts are controlled system UX. Headless should orchestrate
them through explicit user intent, clear states, and accessible recovery paths.
