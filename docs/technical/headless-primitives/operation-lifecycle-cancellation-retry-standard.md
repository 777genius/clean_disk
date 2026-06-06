# Operation Lifecycle Cancellation And Retry Standard

## Status

Accepted as a Headless system primitive design. Not implemented yet.

## Source Standards

- MDN AbortController: https://developer.mozilla.org/en-US/docs/Web/API/AbortController
- MDN AbortSignal: https://developer.mozilla.org/en-US/docs/Web/API/AbortSignal
- MDN `<progress>`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/progress
- MDN `progressbar` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/progressbar_role
- MDN `aria-valuenow`: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Attributes/aria-valuenow
- WCAG 2.2.2 Pause, Stop, Hide: https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide.html
- WCAG 4.1.3 Status Messages: https://www.w3.org/WAI/WCAG22/Understanding/status-messages.html

## Scope

This standard defines UI contracts for long-running operations.

It applies to:

- scans;
- exports;
- support bundle creation;
- cleanup operations;
- search indexing;
- report generation;
- metadata enrichment;
- renderer preload;
- daemon reconnect workflows.

It does not define backend execution. It defines operation state exposed to
Headless components and user controls.

## Decision Options

Option A: Simple loading boolean - 🎯 3   🛡️ 3   🧠 2, about 80-200 LOC.

- Easy.
- Cannot represent pause, cancel, retry, partial, receipt, or unknown progress.

Option B: Per-feature operation states - 🎯 6   🛡️ 6   🧠 5, about
400-1000 LOC per feature.

- Flexible.
- Creates inconsistent controls and announcements.

Option C: Shared operation lifecycle model - 🎯 9   🛡️ 9   🧠 7, about
900-1800 LOC.

- Accepted direction.
- All primitives consume the same operation phases.
- Product adapters map real backend semantics into this model.

## Accepted Direction

Headless must model operations as state machines.

Core phases:

- `idle`;
- `queued`;
- `preparing`;
- `running`;
- `pausing`;
- `paused`;
- `cancelling`;
- `cancelled`;
- `retrying`;
- `succeeded`;
- `failed`;
- `partial`;
- `receiptAvailable`;
- `disposed`.

Each phase must declare allowed commands and user-facing status.

## Progress Rules

Progress can be:

- determinate;
- indeterminate;
- estimated;
- multi-phase;
- unknown total;
- degraded confidence.

Rules:

- do not set numeric current value when total is unknown;
- expose text value when numeric percent is misleading;
- show phase label for multi-step work;
- avoid announcing every tick;
- preserve exact operation status for receipt and support.

## Cancellation Rules

Cancel means request to stop, not proof that work stopped.

Cancellation states:

- `canRequestCancel`;
- `cancelRequested`;
- `cancelAccepted`;
- `cancelCompleted`;
- `cancelRejected`;
- `cancelTimedOut`;
- `cleanupRequired`.

Headless controls must show the difference between "Cancel requested" and
"Cancelled".

Destructive operations need stronger semantics:

- cancelling after commit may not undo work;
- receipt must record final outcome;
- UI must not imply rollback unless platform confirms it.

## Retry Rules

Retry must specify:

- same operation id or new operation id;
- preserved inputs;
- changed capability state;
- idempotency;
- stale data check;
- user confirmation requirement;
- retry limit or backoff.

Retry cannot silently repeat destructive operation without explicit policy.

## Pause Stop Hide Rules

Long-running visible activity must support at least one of:

- pause;
- cancel;
- hide;
- background;
- reduce updates;
- open details.

If operation cannot be paused or cancelled, UI must say so rather than showing
a fake control.

## Clean Disk Requirements

Clean Disk operation lifecycle:

- scan session;
- metadata enrichment;
- delete plan validation;
- move to Trash;
- export report;
- support bundle generation.

Rules:

- scan cancellation is best-effort until daemon confirms;
- move-to-trash cancellation does not imply undo;
- progress footer uses operation phase, not raw boolean;
- cleanup receipt is separate from progress success state.

## API Shape Sketch

```text
OperationState
  operationId
  phase
  progress
  allowedCommands
  cancelState
  retryPolicy
  resultSummary
  receiptRef
  privacyClass

OperationProgress
  kind
  current
  total
  valueText
  confidence
```

## Conformance Scenarios

- indeterminate operation has no numeric `aria-valuenow`;
- cancel button changes to cancelling until confirmed;
- failed export offers retry without losing options;
- destructive retry requires confirmation policy;
- scan progress announces milestones only;
- partial operation result is not shown as success;
- receipt remains discoverable after operation completes;
- fake pause button is not rendered when pause is unsupported.

## Failure Catalog

- loading boolean hides failure and partial states;
- cancel request shown as completed cancellation;
- destructive cancel implies rollback;
- numeric percent displayed with unknown total;
- retry repeats stale destructive operation;
- progressbar descendants used for semantic content;
- operation completion announced before receipt is durable;
- operation controls vary by feature without reason;
- pause button shown but not supported;
- progress tick causes live-region spam.

