# Clipboard Data Transfer And Privacy Standard

## Status

Implementation standard for copy, cut, paste, export-like clipboard operations,
and privacy handling in Headless grid primitives.

## Purpose

Grids often support copy, paste, cut, and export. These operations are useful,
but they cross a sensitive boundary: system clipboard, browser permissions,
external apps, and user data. Headless needs command contracts without owning
product data or leaking private values.

## Standards And References

- MDN Clipboard API:
  https://developer.mozilla.org/docs/Web/API/Clipboard_API
- MDN Clipboard `read`:
  https://developer.mozilla.org/en-US/docs/Web/API/Clipboard/read
- WAI-ARIA APG Grid:
  https://www.w3.org/WAI/ARIA/apg/patterns/grid/
- Flutter Clipboard:
  https://api.flutter.dev/flutter/services/Clipboard-class.html
- Flutter Actions and Shortcuts:
  https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts

## Core Rule

Headless owns clipboard command intent. Application owns data serialization,
permission, privacy policy, and destructive cut semantics.

```text
keyboard/menu command
  -> Headless clipboard intent
  -> application data adapter
  -> platform clipboard adapter
  -> status/receipt
```

## Operation Types

```text
copySelection
copyFocusedCell
copyFocusedRow
copyVisibleRows
copyQueryResult
pasteIntoFocusedCell
pasteIntoSelection
cutSelection
```

Every operation declares:

- source scope;
- target scope;
- format;
- privacy class;
- capability requirement;
- confirmation requirement;
- undo/receipt policy.

## Format Policy

Possible formats:

- plain text;
- TSV;
- CSV;
- JSON;
- app-specific internal format;
- rich text or HTML, future only.

Clean Disk MVP should prefer explicit export commands over broad clipboard
copying of raw scan data.

## Browser Security Rules

Web clipboard access can require:

- secure context;
- user activation;
- browser permission;
- iframe permissions policy;
- platform-specific prompt.

The web adapter must fail gracefully and report capability, not assume clipboard
access is always available.

## Privacy Rules

Clipboard data can leave the app. Therefore:

- copying raw paths requires explicit product policy;
- sensitive columns can be excluded or redacted;
- hidden columns are not copied unless scope says so;
- diagnostics never log clipboard content;
- telemetry records operation category and size bucket only;
- paste data is treated as untrusted input.

## Grid Interaction Rules

Copy:

- uses current selection or focused cell by policy;
- includes headers only by explicit option;
- preserves visible order;
- does not include hidden filtered rows unless scope says so;
- status reports count, not content.

Paste:

- disabled unless component/app supports editing;
- validates shape and target;
- never executes commands from pasted content;
- handles large paste with limits;
- fails per-cell or all-or-nothing by declared policy.

Cut:

- disabled by default for read-only grids;
- destructive cut requires app-level confirmation or undo policy;
- not a Headless core behavior for Clean Disk cleanup.

## Keyboard Defaults

- Ctrl/Cmd + C copies allowed current scope;
- Ctrl/Cmd + V pastes only in editing-capable scope;
- Ctrl/Cmd + X cuts only where app policy allows;
- shortcuts are blocked in text editing scope unless editor handles them.

## Clean Disk Boundary

Clean Disk scan data can contain private paths and filenames.

Rules:

- no automatic copy of full paths from Headless;
- path copy is product command with explicit privacy treatment;
- support/debug exports are separate from clipboard commands;
- delete queue cannot be created by pasted path list without validation.

## Required Tests

Automated:

- copy command emits intent only;
- selected hidden rows not copied by default;
- clipboard content never appears in diagnostics;
- paste blocked in read-only grid;
- text editor receives copy/paste shortcuts before outer grid;
- web capability failure produces safe status.

Manual:

- keyboard copy selected cells;
- browser clipboard denied path;
- screen reader hears success/failure status;
- paste invalid shape error is recoverable.

## Stop Rules

- Do not let Headless serialize product data directly.
- Do not copy hidden sensitive columns by default.
- Do not log clipboard content.
- Do not implement destructive cut without application policy.
- Do not treat pasted paths as trusted cleanup targets.
