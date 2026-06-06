# Implementation Edge Cases - Product Workflows And Protocol Correctness

This file records product workflow and protocol edge cases that sit above raw filesystem scanning.

The lower-level filesystem, platform, daemon, and storage risks are already covered in:

- [Implementation edge cases](implementation-edge-cases.md)
- [Implementation edge cases deep dive](implementation-edge-cases-deep-dive.md)
- [Implementation edge cases advanced scenarios](implementation-edge-cases-advanced-scenarios.md)
- [Implementation edge cases filesystem model](implementation-edge-cases-filesystem-model.md)

This document focuses on the part that can quietly break user trust even if the scanner is fast and correct:

- long-running operation state;
- multi-window and web reconnect behavior;
- delete queue and delete plan correctness;
- duplicate commands and retries;
- export/report safety;
- selection, pagination, focus, and accessibility correctness;
- remote/server mode semantics.

## Sources Reviewed

- Microsoft Azure Architecture Center, [Asynchronous Request-Reply pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/asynchronous-request-reply). Useful for long-running scan/delete operations: return an accepted operation, expose a status endpoint, include status fields, and avoid over-polling.
- Microsoft Azure Architecture Center, [Compensating Transaction pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/compensating-transaction). Useful for partial delete failures: compensation is application-specific, may not fully restore the original state, and compensation steps should be idempotent.
- Stripe API docs, [Idempotent requests](https://docs.stripe.com/api/idempotent_requests). Useful for duplicate mutating requests: store first result by idempotency key, reject parameter mismatch, and avoid sensitive data in keys.
- Google API Improvement Proposals, [AIP-155 Request identification](https://google.aip.dev/155). Useful for request IDs: UUID-style request IDs should guarantee idempotency for the request they identify.
- RFC 9110, [HTTP Semantics](https://www.rfc-editor.org/rfc/rfc9110). Useful for safe/idempotent method semantics and avoiding unsafe actions behind `GET`.
- OWASP, [CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection). Useful for report exports: untrusted filenames and paths can become formulas in spreadsheet tools.
- W3C WAI-ARIA APG, [Treegrid pattern](https://www.w3.org/WAI/ARIA/apg/patterns/treegrid/). Useful for the central folder tree/table: focus, selection, expansion, sorting, and multi-select need explicit semantics.
- FreeDesktop.org, [Trash Specification](https://specifications.freedesktop.org/trash/latest/). Useful for receipts and restore expectations: Trash file names are not authoritative; `.trashinfo` stores original path and deletion date.
- Apple Developer Documentation, [FileManager.trashItem](https://developer.apple.com/documentation/foundation/filemanager/trashitem%28at%3Aresultingitemurl%3A%29). Useful for macOS Trash receipts: the resulting Trash URL can differ from the original name.
- Microsoft Learn, [Windows confirmation UX guidance](https://learn.microsoft.com/en-us/windows/win32/uxguide/mess-confirm). Useful for destructive UI: prevent errors, separate destructive commands, provide undo where true, and confirm risky actions.
- GNOME Human Interface Guidelines, [Dialogs](https://developer.gnome.org/hig/patterns/feedback/dialogs.html). Useful for destructive UX: prefer undo when real, otherwise use confirmation for non-undoable risk.
- Material Design, [Dialogs](https://m1.material.io/components/dialogs.html). Useful for batch/queued operations: dialogs are interruptive, avoid stacked dialogs, use explicit actions, and disable confirmation until required inputs are present.

## Severity Scale

- `P0` - can cause wrong deletion, unrecoverable user harm, security bypass, or major privacy leak.
- `P1` - can cause broken trust, stuck workflow, wrong UI state, or hard-to-debug reliability issues.
- `P2` - important polish, accessibility, internationalization, or supportability risk.

## Highest-ROI Guardrails

1. Operation state model + idempotent mutating commands - 🎯 10 🛡️ 10 🧠 5, roughly 400-900 LOC across Rust application, protocol, adapters, and tests.
2. DeletePlan aggregate with plan hash, confirmation token, item outcomes, and receipt - 🎯 10 🛡️ 10 🧠 6, roughly 700-1500 LOC once cleanup adapters exist.
3. Stable tree query protocol with node IDs, cursor versions, focus/selection separation, and resync path - 🎯 9 🛡️ 9 🧠 5, roughly 400-900 LOC across Rust query service, protocol snapshots, Flutter stores, and tests.

These are stronger priorities than cosmetic UI polish because they protect the user's files and make desktop/web clients behave consistently.

## Product Workflow Principle

Long-running and destructive workflows must be modeled as explicit state machines. A scan, delete plan, move-to-trash job, export job, and support bundle job should never be represented as a loose boolean set like `isLoading`, `isDeleting`, `hasError`, `isDone`.

Required shape:

```text
Created -> Validating -> Running -> Completed
                         -> CompletedWithFailures
                         -> CancelRequested -> Cancelled
                         -> Failed
                         -> Expired
```

Each operation state needs:

- stable operation ID;
- creation time;
- last update time;
- terminal timestamp;
- user-visible status;
- machine-readable reason code;
- whether it can be cancelled;
- whether it can be retried;
- whether it invalidates existing UI state or delete plans.

## Scan Session Workflow

### Status Query Must Be Authoritative - `P0`

WebSocket events are notifications, not the source of truth. Desktop and browser clients can refresh, reconnect, sleep, pause, or be throttled. A client must always be able to query the current scan state.

Required behavior:

- `start_scan` returns a `scan_session_id` and initial status.
- `GET /scan-sessions/{id}` returns current authoritative state.
- WebSocket event batches carry `scan_session_id`, monotonic sequence, and summary deltas.
- A reconnecting client first queries state, then subscribes from `after_seq` if possible.
- If replay is unavailable, server returns `resync_required` and client reloads summary/tree pages.

Do not make WebSocket delivery a prerequisite for correctness.

### Multiple Windows And Multiple Clients - `P1`

The same daemon can be observed by:

- desktop Flutter window;
- browser Flutter web UI;
- second desktop window;
- CLI/debug client;
- future remote dashboard.

Required behavior:

- shared state lives in Rust daemon: scan sessions, delete plans, receipts, event log;
- per-client state stays in client: scroll offset, focused row, expanded UI path, temporary filter text;
- event subscriptions are per client and bounded;
- one slow client must not slow scanner, indexer, or other clients;
- scan cancellation policy must be explicit: closing a UI window does not cancel a scan unless the user issued cancel.

### Overlapping Scan Targets - `P1`

Users can start scans for both a parent and its child, for example `/Users/belief` and `/Users/belief/Library`.

Risk:

- duplicate disk work;
- confusing total sizes;
- delete candidates shown in multiple sessions;
- stale queue from one session acting on another.

Required behavior:

- detect containment relationships before scan start;
- warn or ask whether to replace/continue when the new target overlaps an active session;
- do not merge sessions invisibly in MVP;
- delete plans reference one source session and one tree index version;
- UI can compare sessions later, but cleanup actions should stay scoped to one session.

### Rescan While Delete Queue Exists - `P0`

If a user rescans while a queue exists, queued items may no longer match the current filesystem.

Required behavior:

- queue items are tied to `scan_session_id`, `tree_index_version`, `node_id`, and identity snapshot;
- rescan marks old queued items as `needs_revalidation`;
- confirmation token expires when plan hash or identity snapshot changes;
- user must review changed items before move-to-trash can run.

### Pause And Resume Semantics - `P1`

Pause is often expected to freeze work immediately, but scanner libraries may only support cooperative cancellation or throttling.

Required behavior:

- MVP may support `cancel` before real `pause`;
- if pause exists, define whether it pauses traversal, aggregation, event delivery, or just UI updates;
- pausing should not leave directory iterators or handles open indefinitely;
- resume should not silently double-count partial state;
- UI copy must not promise stronger semantics than implementation provides.

### Progress Accuracy - `P2`

Disk traversal often cannot know total work upfront. Progress based on discovered entries is not the same as progress toward completion.

Required behavior:

- show `files_scanned`, `bytes_accounted`, `current_path`, `elapsed`, `throughput`, `skipped`, and `errors`;
- use percentage only when denominator is meaningful;
- distinguish estimated progress from exact progress;
- avoid ETA until there is enough stable signal.

## Delete Plan Workflow

### DeletePlan Is A Domain Aggregate, Not A UI List - `P0`

The UI delete queue is a projection. The real safety boundary is a `DeletePlan` aggregate in the cleanup domain.

The plan owns:

- source scan session;
- tree index version;
- selected node IDs;
- identity snapshots;
- parent/child conflict resolution;
- risk classification;
- total reclaim estimate;
- per-item warnings;
- confirmation requirements;
- plan hash;
- confirmation token state;
- execution status;
- per-item outcomes;
- receipt reference.

The UI must not be able to call a Trash adapter directly with raw paths.

### Confirmation Token Must Bind To Plan Hash - `P0`

A destructive confirmation is only valid for the exact plan the user reviewed.

Required behavior:

- confirmation token binds to `delete_plan_id`, `plan_hash`, `session_id`, and `tree_index_version`;
- token expires after timeout, rescan, plan edit, identity mismatch, or daemon restart policy change;
- token is single-use for move-to-trash execution;
- token is never logged or exported;
- UI disables move-to-trash if any item moved to `needs_revalidation`.

### Batch Trash Is Not Atomic - `P0`

Moving 100 items to Trash can partly succeed and partly fail. OS Trash implementations and cloud providers do not provide one universal transaction.

Required behavior:

- execute as item-level operations with recorded outcome;
- write receipt incrementally according to durability policy;
- after partial failure, show `completed_with_failures`, not `failed` as if nothing happened;
- do not retry failed items automatically without user action;
- do not promise rollback unless the specific adapter implements and proves it;
- keep enough data for a user to inspect what moved and what did not.

This maps to compensating-transaction thinking: compensation is specific, not generic, and may not restore the initial state.

### Duplicate Move-To-Trash Command - `P0`

Browser retry, desktop retry, reconnect, double-click, or a slow response can send the same destructive command twice.

Required behavior:

- every mutating command that can cause deletion accepts an idempotency/request key;
- repeated command with the same key returns the first result or current compatible terminal state;
- repeated command with same key but different payload is rejected;
- keys must not contain path, email, username, or other sensitive data;
- idempotency store retention is documented;
- stale idempotency key behavior is deterministic.

Do not rely on button disabling in Flutter as the safety mechanism.

### Parent And Child Queue Conflicts - `P0`

The user can queue both a parent folder and a child folder/file. If executed naively, the child operation can fail, double-count, or produce confusing receipts.

Required behavior:

- normalize queue into a conflict-free plan before confirmation;
- if parent is selected, children inside it are marked as covered and not executed separately;
- total reclaim estimate avoids double-counting;
- receipt can still record that children were originally selected and covered by parent move;
- UI shows covered items clearly or collapses them under the parent.

### Undo Is Not A Generic Promise - `P1`

Some design guidelines recommend undo for destructive actions when possible. For Clean Disk, "undo" is dangerous as a generic product promise because:

- platform Trash behavior differs;
- remote daemon may not have a local GUI Trash;
- external volumes may use different Trash locations;
- provider/cloud moves can sync deletion elsewhere;
- restoring into the original path may conflict with new files;
- permissions, xattrs, ACLs, and names can differ after move.

Required behavior:

- first release should say "Move to Trash", not "Delete forever";
- after success, show receipt and platform action such as "Reveal in Trash" where supported;
- do not show "Undo" unless the exact adapter implements a verified restore flow;
- receipt stores resulting Trash location when the platform provides it;
- restore, if added later, is adapter-specific and revalidates destination conflicts.

### Close, Quit, Sleep, And Update During Delete - `P0`

The user can close a window, quit app, sleep laptop, or app updater can restart while a delete is running.

Required behavior:

- app blocks or warns before quit during active Trash operation;
- daemon writes operation state and receipt before or during item moves according to durability policy;
- after restart, daemon can show "operation interrupted" or terminal receipt;
- daemon never resumes destructive execution automatically after crash without fresh user action;
- auto-update is delayed during delete execution.

### Delete Candidate Risk Tiers - `P1`

All bytes are not equal. A cache file, app support database, source checkout, VM image, and cloud placeholder all need different copy and friction.

Required behavior:

- recommendation engine returns reason codes, not just "safe";
- candidate tiers: `reclaimable`, `review`, `app_managed`, `system_managed`, `dangerous`, `unsupported`;
- one-click cleanup only allowed for low-risk, adapter-owned classes after enough tests;
- mixed-risk delete plan uses the highest required confirmation friction;
- future app-specific cleanup adapters should own their own safety copy.

## Protocol Correctness

### No Unsafe Actions Behind GET - `P0`

RFC 9110 defines safe methods as read-only from the user's point of view. Any endpoint that changes state must not be reachable via `GET`, including:

- start scan;
- cancel scan;
- create delete plan;
- confirm delete plan;
- move to Trash;
- export support bundle if it changes persisted state.

Required behavior:

- `GET` endpoints are query-only;
- commands use explicit command endpoints;
- browser prefetch, link preview, crawler, or history restore cannot trigger destructive actions;
- query parameters like `?action=delete` are forbidden.

### Command/Query Separation - `P1`

The API does not need to be "pure CQRS", but product correctness improves if commands and queries are distinct.

Recommended shape:

- commands return operation IDs, plan IDs, status, and warnings;
- queries return read models, pages, summaries, and receipts;
- WebSocket only notifies about state changes and progress;
- clients can reconstruct current UI from queries if all events are lost.

### Operation Status Endpoint - `P1`

Long-running operations should expose a status resource with a consistent set of states. This follows the async request-reply pattern and makes web, desktop, and future remote mode simpler.

Required fields:

- `operation_id`;
- `kind`;
- `status`;
- `created_at`;
- `last_updated_at`;
- `terminal_at`;
- `progress`;
- `can_cancel`;
- `can_retry`;
- `error_code`;
- `result_ref`.

### Idempotency Store Scope - `P1`

The idempotency store is not a global cache of all requests. It should scope keys by:

- daemon instance;
- authenticated local session/user;
- operation kind;
- endpoint/command name;
- request payload hash;
- retention window.

For local daemon mode, in-memory may be enough for non-destructive commands. Destructive commands need stronger handling because a crash after moving items can otherwise make duplicate user actions ambiguous.

### Optimistic Concurrency For Plans - `P1`

Delete plans are edited by the user and may be visible in multiple windows.

Required behavior:

- plan has `plan_version`;
- update command includes expected version;
- server rejects stale updates with `conflict`;
- client reloads plan and asks user to resolve;
- confirmation token is invalidated by version change.

### Event Ordering And Resync - `P1`

WebSocket batches must be ordered, but clients should not depend on receiving every progress tick.

Required behavior:

- every event batch has `seq_start`, `seq_end`, `session_id`, and `schema_version`;
- semantic events are replayable within a bounded window;
- progress events may be coalesced;
- if client is too far behind, server sends `resync_required`;
- client responds by querying authoritative status/pages;
- slow client queues are bounded.

### Schema Versioning - `P1`

Desktop app and daemon can be out of sync during development, updater rollout, or remote mode.

Required behavior:

- every protocol response/event has `schema_version`;
- daemon exposes `/version` and capability list;
- client checks compatibility before enabling destructive actions;
- incompatible client cannot call cleanup commands;
- protocol snapshot tests cover command, query, event, and error DTOs.

### Error Codes Are Product Contracts - `P1`

Raw OS errors are useful for diagnostics, but UI needs stable reason codes.

Required behavior:

- errors include `code`, `message`, `severity`, `retryable`, `path_ref`, and optional redacted diagnostics;
- code examples: `path_not_found`, `identity_mismatch`, `permission_denied`, `trash_not_supported`, `cloud_placeholder`, `scan_cancelled`, `plan_conflict`, `idempotency_payload_mismatch`;
- UI maps codes to copy and action buttons;
- logs can include platform error details after redaction.

## Tree Query And UI Correctness

### Selection Must Be By Node Identity, Not Row Index - `P0`

The central tree/table can sort, filter, expand, collapse, search, and paginate. Row index is not stable enough for delete queue selection.

Required behavior:

- selected rows store `node_id` and source `index_version`;
- visible row index is view-only;
- after sort/filter/search, selection resolves by node ID;
- if node ID is absent from the current page, queue still shows stable item summary;
- if node identity is invalidated, queue item moves to `needs_revalidation`.

### Focus And Selection Are Different - `P1`

W3C treegrid guidance separates focus from selection, especially in multi-select grids. This matters because keyboard users can move around without selecting deletion candidates.

Required behavior:

- focused row is visual and accessibility state;
- selected/queued row is action state;
- multi-select has explicit `selected` state;
- details panel follows focus or selection by documented policy;
- delete queue follows selected/queued items only.

### Expansion State Cannot Be The Data Model - `P1`

Expanded folders are UI state, not proof that children are scanned or loaded.

Required behavior:

- Rust owns tree index and child paging;
- client requests children page by `node_id`, sort/filter, and cursor;
- expansion state stores node IDs only;
- collapsed children can still be queued if selected through search/top list, but UI must show full path;
- if children page cursor expires, reload page from current index.

### Pagination Cursor Must Include Version - `P1`

Filesystem and scan index can change during and after scan.

Required behavior:

- cursor includes `index_version`, parent node ID, sort key, filter hash, and page boundary;
- server rejects stale cursor with `stale_cursor` or returns compatible refreshed page with a flag;
- UI does not append stale page data to a newer list;
- tests simulate tree mutation between page 1 and page 2.

### Details Panel Must Be Snapshot-Aware - `P1`

User can select a folder, then scan updates or rescan changes that folder.

Required behavior:

- details panel shows which snapshot/version it represents;
- if stale, panel displays "needs refresh" or quietly refetches;
- "Add to Queue" uses current details only after revalidation;
- "Reveal in Finder/Explorer" uses current path but never proves delete safety.

### Search Results Are Not Delete Proof - `P1`

Search results are a convenience view and can span multiple parents, risk tiers, and snapshots.

Required behavior:

- search result item includes full path, node ID, size, type, risk summary, and index version;
- add-to-queue from search still creates a DeletePlan candidate that revalidates identity;
- bulk queue from search requires parent/child conflict normalization;
- search ranking does not affect execution order.

### Locale, Units, And Sort Stability - `P2`

Size text, date text, and names differ by locale. Sorting must be deterministic.

Required behavior:

- protocol sends raw bytes, item count, timestamps, and sort keys separately from display strings;
- Flutter formats display strings locally;
- default size unit policy is documented: binary or decimal;
- sorting by size uses numeric bytes, not formatted text;
- equal sizes use stable tie-breakers such as type, name, path, node ID.

## Export, Reports, And Support Bundles

### CSV Injection In File Reports - `P0`

Filenames can start with characters that spreadsheet programs interpret as formulas. OWASP lists `=`, `+`, `-`, `@`, tab, carriage return, line feed, and some full-width variants as dangerous formula starts.

Required behavior:

- CSV export is not the default report format for raw paths;
- prefer JSON or a safe HTML report for detailed technical export;
- if CSV exists, every cell containing user-controlled path/name/comment is formula-safe;
- test filenames beginning with `=`, `+`, `-`, `@`, tab, CR, LF, and full-width variants;
- document that spreadsheet tools can modify escaping after save/reopen;
- never place daemon tokens or headers in exports.

### HTML And Markdown Report Injection - `P1`

Paths can contain characters that become HTML, Markdown, terminal escape sequences, or misleading line breaks.

Required behavior:

- reports escape HTML and Markdown content;
- code blocks do not contain unescaped triple backticks from filenames;
- terminal-friendly logs strip or encode control characters;
- copied paths preserve raw value but display uses safe-rendered text;
- receipt export includes a redaction mode.

### Support Bundle Privacy - `P0`

Support bundles are useful but can leak home paths, project names, app usage, daemon tokens, and scan history.

Required behavior:

- support bundle creation is explicit user action;
- preview shows what data classes are included;
- default redaction replaces home prefix and private path segments;
- daemon tokens, request headers, auth material, and raw WebSocket URLs are excluded;
- destructive receipts are included only with explicit consent;
- remote/server mode has tenant/user isolation in bundles.

### Scan History Retention - `P1`

Scan history is helpful, but it is sensitive local behavior data.

Required behavior:

- history retention is configurable;
- default stores summaries, not full raw trees, unless user enables detailed history;
- user can clear history and receipts separately;
- receipts have stronger retention than disposable scan cache;
- remote mode documents where history is stored.

### Clipboard And Drag-Out - `P2`

Copying paths, exporting selected rows, or dragging items out of the app can leak private paths.

Required behavior:

- copy commands are explicit;
- multi-copy format is predictable and safe for newlines;
- UI can offer "Copy full path" and "Copy redacted path";
- drag-out from remote mode should not imply local filesystem access.

## Desktop, Web, And Remote Mode

### Same Protocol, Different Authority - `P0`

Desktop local daemon, browser local daemon, and remote server daemon are not the same security model.

Required behavior:

- local mode binds to loopback and uses local session token/origin allowlist;
- remote mode uses real authentication and authorization, not local token assumptions;
- delete permissions are server-side, not UI-side;
- "Reveal in Finder" exists only for local desktop or local browser with helper support;
- remote mode UI labels targets by host/user/context to avoid deleting on the wrong machine.

### Web UI Cannot Rely On Browser Disk Access - `P0`

The browser is only a visual client for full disk scanning.

Required behavior:

- web UI calls daemon over HTTP/WebSocket;
- any browser file picker feature is an import/export helper, not scanner authority;
- local daemon pairing must make target host visible;
- remote daemon connection must not look like local disk unless it is local.

### Multi-User Server Mode - `P0`

If Clean Disk later runs on servers, a scan result can expose other users' paths and file names.

Required behavior:

- daemon has an authorization model before remote multi-user use;
- scan targets are allowlisted per user/session;
- delete plans are scoped to authenticated principal;
- logs and events do not cross user sessions;
- admin mode is a separate product mode with separate warnings.

## Dialog And Confirmation UX

### Confirmation Must Contain Enough Information - `P0`

Confirmation dialogs are only useful if the user can make a real decision.

Required content:

- exact action: "Move selected items to Trash";
- number of items and total estimated reclaim;
- target host/volume;
- highest risk tier in plan;
- changed/stale item count;
- representative paths with ability to inspect all;
- note that Trash behavior depends on platform/provider;
- confirmation button label uses explicit destructive verb.

### Avoid Dialog Stacks - `P1`

Material and GNOME guidance both warn against disruptive dialogs and stacked modal complexity.

Required behavior:

- delete plan review should be a panel/sheet/full page when it contains many items;
- final confirmation is one focused step;
- no nested confirmation inside a confirmation;
- file picker or permission prompt should happen before final destructive confirmation;
- if OS permission prompt appears, plan must revalidate after permission is granted.

### Required Acknowledgement - `P1`

For high-risk plans, the user should acknowledge the real consequence.

Recommended policy:

- low-risk Trash plan: normal confirm;
- medium-risk mixed plan: checkbox "I reviewed the selected items";
- high-risk or permanent delete: typed confirmation or require removing high-risk items;
- remote/server delete: include target host in confirmation.

Do not add friction to every action. Friction should follow risk.

## Observability And Receipts

### Receipt Is Not A Log File - `P1`

The receipt is a product artifact the user can inspect. Logs are diagnostics.

Receipt should include:

- receipt ID;
- operation ID;
- user-facing summary;
- start/end times;
- app/daemon version;
- source session/index version;
- item outcomes;
- original path display;
- stable identity snapshot;
- resulting Trash path when provided by OS;
- failure code and redacted diagnostics;
- redaction/export metadata.

Logs should include tracing spans and debugging fields, but must not replace receipts.

### Metrics Must Not Leak Paths - `P1`

Performance metrics are useful: scan throughput, files per second, event queue lag, page query latency, delete duration.

Required behavior:

- metrics labels do not include raw path names;
- high-cardinality labels are avoided;
- path/extension/category statistics are opt-in and local;
- telemetry, if ever added, is off by default unless explicitly accepted.

## Testing Matrix

These tests should become fixtures before cleanup reaches production quality.

### State And Protocol Tests

- duplicate `start_scan` with same idempotency key returns same compatible result;
- duplicate `move_to_trash` with same idempotency key does not move twice;
- same idempotency key with different payload returns `idempotency_payload_mismatch`;
- mutating `GET` endpoint does not exist;
- stale `plan_version` update returns conflict;
- stale WebSocket `after_seq` returns `resync_required`;
- protocol snapshot tests for command/query/event/error DTOs;
- desktop/web clients can rebuild UI after losing all events.

### Delete Plan Tests

- plan hash changes when any item, identity snapshot, risk tier, or reclaim estimate changes;
- confirmation token invalid after plan edit;
- confirmation token invalid after rescan;
- parent/child conflict does not double-count;
- partial Trash success creates item-level outcomes;
- crash after item 1 of 3 does not auto-resume deletion;
- "Reveal in Trash" uses resulting Trash path when available;
- app close during delete is blocked or clearly warned.

### Tree UI Tests

- selection survives sort/filter by node ID;
- focus moves independently from queued selection;
- page 2 cursor from old index is rejected or marked stale;
- search result add-to-queue revalidates identity;
- details panel cannot queue stale selected node;
- screen reader has treegrid role, row labels, expansion state, and selection state where platform permits.

### Export And Privacy Tests

- CSV export escapes paths beginning with `=`, `+`, `-`, `@`, tab, CR, LF, and full-width variants;
- HTML report escapes `<`, `>`, `&`, quotes, backticks, and line breaks;
- support bundle redacts home path by default;
- daemon token never appears in logs, receipts, reports, support bundles, or URLs;
- copy full path and copy redacted path behave differently;
- scan history clear does not delete receipts unless user explicitly chooses that.

### Remote Mode Tests

- remote target host is visible in scan summary, delete plan, confirmation, and receipt;
- one user cannot subscribe to another user's events;
- local "Reveal in Finder" is hidden for remote sessions;
- remote delete requires server-side permission;
- web reconnect to remote daemon rebuilds state from queries.

## MVP Cut Line

MVP should include:

- authoritative scan status query;
- WebSocket progress as notification only;
- bounded event queues and reconnect/resync;
- DeletePlan aggregate;
- confirmation token bound to plan hash;
- per-item move-to-trash outcome;
- delete receipt;
- node-ID-based selection;
- cursor versioning;
- safe redacted support bundle basics;
- no generic undo promise.

MVP can defer:

- real restore/undo;
- one-click cleanup recommendations;
- detailed scan history trees;
- remote multi-user admin mode;
- CSV export if JSON/HTML report is enough;
- pause/resume if cancel is solid.

## Summary

Product correctness for Clean Disk is mostly about not letting stale UI, duplicate commands, partial failure, or unsafe exports turn a good scanner into an unsafe cleanup tool.

The strongest architecture rule is:

```text
UI intent -> application command -> validated domain aggregate -> adapter operation -> item outcomes -> receipt -> queryable read model
```

No UI surface should bypass this chain for destructive actions.
