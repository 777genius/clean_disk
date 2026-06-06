# Data Transfer Payload Governance Standard

## Status

Accepted as a Headless runtime interoperability standard. Not implemented yet.

## Source Standards

- MDN Clipboard API: https://developer.mozilla.org/en-US/docs/Web/API/Clipboard_API
- MDN ClipboardItem: https://developer.mozilla.org/en-US/docs/Web/API/ClipboardItem
- MDN DataTransfer: https://developer.mozilla.org/en-US/docs/Web/API/DataTransfer
- MDN HTML Drag and Drop API: https://developer.mozilla.org/docs/Web/API/HTML_Drag_and_Drop_API
- MDN Working with the drag data store: https://developer.mozilla.org/en-US/docs/Web/API/HTML_Drag_and_Drop_API/Recommended_drag_types
- WCAG 2.5.7 Dragging Movements: https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html
- W3C Privacy Principles: https://www.w3.org/TR/privacy-principles/

## Scope

This standard defines how Headless governs payloads that cross UI boundaries.

It applies to:

- copy;
- paste;
- cut;
- drag;
- drop;
- export-to-clipboard;
- import-from-clipboard;
- cross-window transfer;
- external file drops;
- internal reordering.

It does not own product data parsing. It defines payload classes, trust,
privacy, capability, and fallback behavior.

## Decision Options

Option A: Let each primitive set clipboard or drag payloads - 🎯 3   🛡️ 3
🧠 2, about 100-300 LOC.

- Fast.
- Creates privacy leaks and inconsistent paste/drop behavior.

Option B: Plain text only - 🎯 6   🛡️ 7   🧠 3, about 200-500 LOC.

- Safer.
- Too limiting for table copy, chart data, internal refs, and rich reports.

Option C: Typed transfer payload governance - 🎯 9   🛡️ 9   🧠 7, about
900-1800 LOC.

- Accepted direction.
- Payloads have type, trust, privacy, authority, and target compatibility.
- Adapters map to Clipboard, DataTransfer, or platform pasteboard.

## Accepted Direction

Headless should define `TransferPayload`.

Payload includes:

- payload kind;
- MIME or platform type;
- data class;
- source scope;
- target scope;
- trust level;
- privacy class;
- expiration;
- authority class;
- fallback text;
- redaction policy;
- size limits.

## Payload Kinds

Kinds:

- `plainText`;
- `tableText`;
- `structuredRows`;
- `internalRefs`;
- `pathList`;
- `chartData`;
- `reportSummary`;
- `operationReceipt`;
- `diagnosticBundle`;
- `externalFiles`;
- `unknownExternal`.

Internal refs are never authority by themselves.

## Clipboard Rules

Clipboard operations require:

- explicit user intent where platform requires it;
- capability check;
- privacy classification;
- target format selection;
- redaction decision;
- visible or announced result;
- failure handling.

Default:

- copy display text, not raw secrets;
- copy path only through explicit product command;
- paste external content as untrusted input;
- never write daemon tokens.

## Drag And Drop Rules

Drag payload rules:

- payload is writable only at drag start where platform requires it;
- payload may be readable only at drop;
- external drops are untrusted;
- file drops expose files, not arbitrary safe paths;
- reordering must have keyboard alternative;
- destructive drop targets require confirmation or safe policy.

Drop target must declare accepted payload kinds and rejected reasons.

## Cross-Context Rules

Cross-window or external transfer must downgrade authority:

- internal row ref becomes display or import candidate, not delete authority;
- operation receipt can be copied as report, not active operation;
- file path can be copied only if product policy permits;
- stale payload is rejected or imported as historical.

## Clean Disk Requirements

Clean Disk payloads:

- copy selected row summary;
- copy path with explicit privacy action;
- export table data;
- drag item into queue if supported later;
- drop custom scan folder;
- copy cleanup receipt;
- support bundle export.

Rules:

- delete queue cannot accept raw external path as cleanup authority.
- copied support data is redacted by default.
- drag-to-delete is not MVP.

## API Shape Sketch

```text
TransferPayload
  kind
  formats
  sourceRef
  dataClass
  trustLevel
  privacyClass
  authorityClass
  expiresAt
  fallbackText

TransferPolicy
  canCopy(payload)
  canPaste(payload, target)
  canDrop(payload, target)
  redact(payload, profile)
```

## Conformance Scenarios

- copying table selection preserves rows and columns without raw path leak;
- paste external text is marked untrusted;
- drop target rejects unsupported payload with reason;
- keyboard alternative exists for drag reorder;
- clipboard write fails gracefully without permission;
- internal ref copied to another window loses destructive authority;
- support receipt copy uses redaction profile;
- drag payload size limit prevents huge hidden data transfer.

## Failure Catalog

- raw path copied accidentally through row text;
- paste treated as trusted internal data;
- drag payload contains daemon token;
- external drop becomes delete target;
- unsupported drop silently does nothing;
- no keyboard alternative to drag;
- clipboard failure unreported;
- internal ref used after expiration;
- rich clipboard format lacks plain text fallback;
- renderer writes clipboard directly.

