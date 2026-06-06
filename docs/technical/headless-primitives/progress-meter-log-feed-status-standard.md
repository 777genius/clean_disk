# Progress Meter Log Feed And Status Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN `progressbar` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/progressbar_role
- MDN `meter` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/meter_role
- MDN `log` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/log_role
- MDN `status` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/status_role
- MDN `feed` role: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/Reference/Roles/feed_role
- MDN ARIA live regions: https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA/ARIA_Live_Regions
- Flutter `LinearProgressIndicator`: https://api.flutter.dev/flutter/material/LinearProgressIndicator-class.html
- Flutter Semantics: https://api.flutter.dev/flutter/widgets/Semantics-class.html

## Scope

This standard covers determinate progress, indeterminate progress, bounded
meters, live status messages, append-only logs, and feed-like event lists.

For Clean Disk this applies to scan progress, file count progress, throughput,
skipped count, cleanup operation progress, daemon connection state, event logs,
support diagnostics, and future agent/orchestrator log surfaces.

## Decision Options

1. Dedicated primitives for `Progress`, `Meter`, `StatusRegion`, `LogView`, and
   `FeedView` over one live-update scheduler - 🎯 9   🛡️ 9   🧠 8, roughly 1100-2200 LOC.
   Best fit. It avoids role confusion and gives one throttling/backpressure
   model for assistive technology announcements.
2. One generic live region primitive with visual variants - 🎯 5   🛡️ 6   🧠 5, roughly 500-900 LOC.
   Too ambiguous. A progress bar, health meter, and append-only log have
   different semantics and user expectations.
3. Render text updates only and let products choose roles manually - 🎯 4   🛡️ 5   🧠 3, roughly 200-400 LOC.
   Fast, but it would make Headless weak for community-grade accessibility.

Accepted direction: option 1.

## Role Selection

Use progress when:

- a task is underway;
- progress is known or unknown;
- completion will end the task.

Use meter when:

- a current value is measured within a known range;
- the value is not task completion;
- examples include disk fullness, battery, memory, quota, or scan quality score.

Use status when:

- the UI needs a short polite update;
- the update is not an error requiring immediate interruption;
- the content is not meant to be navigated as a list.

Use log when:

- new entries are added over time;
- order and append history matter;
- the user may review entries after they arrive.

Use feed when:

- entries are rich, individually focusable, virtualized, and may load
  continuously as the user reads;
- the UI needs browse-mode reading and scrolling cooperation.

Clean Disk scan progress uses progress. Disk fullness uses meter. Scan path text
uses status with throttling and path redaction. Diagnostics use log. Future
event timelines can use feed only if entries become rich, focusable articles.

## Primitive Boundary

Headless owns:

- value range and indeterminate state;
- percentage formatting hooks;
- announcement throttling;
- live region politeness;
- log append and pruning policy;
- busy state;
- entry identity and ordering;
- privacy class for status/log text;
- virtualized log focus and scroll contract.

Renderer owns:

- bar, circle, ring, sparkline, and meter visuals;
- animation and color;
- skeleton display;
- iconography;
- layout and truncation.

Application owns:

- task lifecycle;
- actual operation state;
- raw event content;
- redaction policy;
- persistence of logs or receipts.

## Progress Contract

MUST:

- distinguish determinate and indeterminate progress;
- keep determinate values monotonic for a single task phase unless a new phase
  starts with a new progress id;
- expose value, min, max, and accessible value text when available;
- expose a human label separate from the numeric value;
- mark the related region busy while loading if the platform supports it;
- announce completion once, not on every final repaint;
- throttle announcements so rapid scan events do not spam assistive tech.

SHOULD:

- support phase labels: discovering, scanning, indexing, finalizing, cleanup;
- support ETA as optional descriptive text, never as the primary value;
- support degraded confidence when total work is unknown.

MUST NOT:

- represent disk usage percentage as progress when no task is running;
- announce every file path scanned;
- rely on color alone to show error, skipped, or warning states.

## Meter Contract

MUST:

- represent a bounded current value;
- expose min, max, current value, and value text;
- define whether higher is better, worse, or neutral;
- keep thresholds separate from color tokens.

SHOULD:

- support warning and critical thresholds;
- support range labels such as free, used, reclaimable, protected;
- expose exact values to details panes and approximate values to compact meters.

## Status And Log Contract

StatusRegion MUST:

- be polite by default;
- replace previous short status text rather than append;
- suppress duplicate messages;
- classify privacy of content before announcing or logging;
- support user-muted announcements.

LogView MUST:

- preserve append order;
- support bounded memory and visible paging;
- avoid stealing focus when new entries arrive;
- support pause, resume, filter, and copy with privacy policy;
- expose new-entry announcement policy separately from visible append policy.

FeedView MUST:

- expose focusable article-like entries where platform semantics allow;
- set busy during batch loading;
- support stable position metadata when available;
- never mutate the middle of a feed without a visible and semantic explanation.

## Clean Disk Mapping

Scan footer:

- progress bar: determinate only when pdu or engine has credible total work;
- file count and throughput: status or text metrics, not progress;
- skipped count: status plus details link;
- current path: visually useful but privacy-sensitive, default not announced on
  every update.

Cleanup:

- delete plan validation: indeterminate progress until plan is ready;
- move to trash: progress with item counts when known;
- partial failures: status and log entries, with receipt link.

Remote/headless:

- daemon connection state uses status;
- event stream diagnostics use log with redaction;
- long operation history uses feed only if rich entries and focus navigation are
  implemented.

## Conformance Tests

Minimum tests:

- determinate progress exposes label and value text;
- indeterminate progress omits misleading percentage;
- meter is not used as task progress;
- rapid updates are throttled;
- duplicate status messages are collapsed;
- log append does not move focus;
- log memory cap preserves visible paging behavior;
- privacy-sensitive status can be redacted or muted;
- completion is announced once;
- Flutter progress semantics include label/value where provided.

## Failure Catalog

- Announcing every scan event makes the app unusable with a screen reader.
- Using progress for disk fullness confuses task completion with measurement.
- Log auto-scroll stealing focus breaks review.
- Path text in live regions leaks private information.
- Resetting progress percentage inside the same phase looks like regression.
