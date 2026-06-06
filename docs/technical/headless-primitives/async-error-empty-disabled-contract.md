# Async, Error, Empty, And Disabled State Contract

## Status

Implementation contract. Not implemented yet.

## Primary Standards

- MDN `aria-busy`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-busy
- MDN `aria-disabled`:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-disabled
- MDN `alert` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/alert_role
- MDN `status` role:
  https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- WAI-ARIA APG Keyboard Interface:
  https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/

## Core Decision

Loading, empty, error, disabled, stale, and partial states are first-class
state model values. They are not just renderer decorations.

## State Taxonomy

```text
DataState
  idle
  loadingInitial
  loadingMore
  refreshing
  stale
  empty
  partial
  errorRecoverable
  errorFatal

InteractionState
  enabled
  disabledFocusable
  disabledSkipped
  readonly
  blockedByPolicy
```

## Async Request Identity

Every async request needs:

```text
requestId
sourceVersion
queryVersion
targetKey optional
startedAt
```

Late responses must not overwrite newer state.

## Empty State

Empty is not always the same:

```text
EmptyReason
  noDataYet
  queryNoResults
  filteredOut
  permissionDenied
  targetUnavailable
  featureUnavailable
```

Renderer can show different visuals. Component owns semantic reason.

## Error State

```text
ErrorState
  recoverable
  retryable
  permission
  incompatibleVersion
  unsupportedPlatform
  fatal
```

Error rows in virtualized collections can be synthetic view rows. They must not
be treated as product data rows.

## Disabled State

Do not use one boolean for everything:

```text
DisabledReason
  appPolicy
  permission
  staleData
  unsupportedPlatform
  busy
  readonlyMode

DisabledCapability
  focusable
  selectable
  activatable
  visible
```

APG allows disabled controls in composites to remain focusable in some cases,
so disabled policy must be explicit.

## Busy Semantics

For async regions:

- expose busy state when updates are ongoing;
- do not spam announcements for every progress tick;
- use status region for advisory progress;
- use alert/dialog for urgent blocking errors.

## Clean Disk Examples

- Scan still running: table can be partially populated and busy.
- Permission denied folder: recoverable error row or skipped issue.
- Stale scan after daemon restart: visible data can be stale read-only.
- DeletePlan stale: destructive action disabled with reason.
- No search results: query empty state, not app empty state.

## Conformance Tests

- late response ignored by request id;
- empty reasons render distinct semantic facts;
- disabled focus policy works;
- stale state disables destructive commands;
- retry command is available only for retryable errors;
- busy progress coalesces announcements;
- synthetic loading/error rows are not selectable product rows.

## Stop Rules

- Do not model all disabled states as one bool.
- Do not render loading/error rows as real product data.
- Do not announce every progress tick.
- Do not allow stale data to enable destructive action.
