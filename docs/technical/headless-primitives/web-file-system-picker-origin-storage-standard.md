# Web File System Picker And Origin Storage Standard

## Status

Accepted direction for Headless. Not implemented yet.

## Source Standards

- MDN File System API: https://developer.mozilla.org/en-US/docs/Web/API/File_System_API
- MDN File API: https://developer.mozilla.org/en-US/docs/Web/API/File_API
- MDN file input: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/file
- MDN anchor `download`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/a#download
- MDN user activation: https://developer.mozilla.org/en-US/docs/Web/Security/Defenses/User_activation
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html
- WCAG 3.3.4 Error Prevention: https://www.w3.org/WAI/WCAG22/Understanding/error-prevention-legal-financial-data.html

## Problem

Web file access is heavily sandboxed. Browsers expose file input, downloads,
origin-private storage, and in some engines File System Access pickers. These
APIs differ from desktop filesystem authority and often require user activation.
Headless must not let a web renderer pretend it can scan disks or delete files
because a desktop adapter can.

## Decision Options

1. Treat browser file picking as ordinary path selection - 🎯 3   🛡️ 3
   🧠 2, about 40-100 LOC. Unsafe and misleading.
2. Add a web filesystem capability boundary - 🎯 9   🛡️ 10   🧠 6, about
   350-850 LOC. Best fit for Headless and Clean Disk.
3. Avoid all browser file APIs - 🎯 5   🛡️ 8   🧠 2, about 0-80 LOC. Safe but
   too limiting for exports and imports.

Accepted: option 2.

## Accepted Contract

Headless models web file capabilities:

```dart
final class RWebFileCapability {
  final bool supportsFileInput;
  final bool supportsDirectoryPicker;
  final bool supportsSavePicker;
  final bool supportsOriginPrivateStorage;
  final bool requiresUserActivation;
  final bool canReturnNativePath;
  final bool canDeleteUserFiles;
}
```

The web adapter must distinguish handles, blobs, downloads, and desktop paths.

## Rules

- Browser file handles are not native cleanup authority.
- Browser-selected directory does not authorize full disk scan.
- Origin-private storage is app storage, not user-visible filesystem storage.
- Downloads are exports, not proof the file remains on disk.
- File pickers open only from explicit user commands.
- Unsupported picker APIs fall back to file input or export download where
  possible.
- User-facing labels must say "choose file" or "export report", not "grant disk
  access" unless the platform really does.

## Clean Disk Requirements

Clean Disk web UI must treat browser filesystem APIs as UI/import/export helpers
only.

Full scan and cleanup require:

- local daemon;
- native desktop host;
- remote server agent;
- explicit platform capability.

The browser alone cannot scan `~/Library`, `C:\\Users`, or a full disk.

## Capability Classes

```text
readSelectedFile:
  user selected one or more files

readSelectedDirectory:
  user selected a directory handle where browser supports it

originPrivateStorage:
  app-private storage invisible as ordinary user files

downloadExport:
  browser initiates save/download

nativeFilesystemAuthority:
  not available to ordinary browser UI
```

## Testing Requirements

- Browser unsupported path uses fallback UI.
- Picker cannot open without user activation.
- Directory handle is not converted into a raw path.
- Export download works without cleanup authority.
- Denied picker state remains recoverable.
- Screen-reader labels describe selected file count and limitations.

## Failure Catalog

- Web UI says "scan disk" without daemon connection.
- File picker result is treated as a deletable native path.
- Directory picker opens on route load.
- Origin-private cache is shown as user cleanup target.
- Unsupported browser silently hides export.
- Support bundle includes a fake native path from browser file metadata.

## Release Gates

- Web file APIs stay behind capability adapter.
- Cleanup commands require native or daemon authority, never browser file input.
- File picker docs explain browser support variance.
- Tests cover unsupported, denied, and user-activation-required states.

## Summary

Browser file access is sandboxed and consent-scoped. Headless should model it as
capability evidence, not as native filesystem authority.
