# File Picker Dropzone Path Target Standard

## Status

Draft accepted as a Headless design constraint. Not implemented yet.

## Source Standards

- MDN File API: https://developer.mozilla.org/en-US/docs/Web/API/File_API
- MDN Using files from web applications: https://developer.mozilla.org/en-US/docs/Web/API/File_API/Using_files_from_web_applications
- MDN HTML Drag and Drop API: https://developer.mozilla.org/docs/Web/API/HTML_Drag_and_Drop_API
- MDN `input type=file`: https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/input/file
- WCAG 2.1.1 Keyboard: https://www.w3.org/WAI/WCAG22/Understanding/keyboard.html
- WCAG 2.5.7 Dragging Movements: https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html
- WCAG 3.3.2 Labels or Instructions: https://www.w3.org/WAI/WCAG22/Understanding/labels-or-instructions.html
- Flutter drag and drop cookbook: https://docs.flutter.dev/cookbook/effects/drag-a-widget

## Scope

This standard covers file pickers, folder pickers, scan target pickers,
dropzones, drag-over target hints, path displays, selected target chips,
platform file dialogs, web file input adapters, and daemon-backed path
selection.

It does not make selected paths authoritative. Clean Disk authority comes from
application and daemon validation.

## Decision Options

1. `PathTargetPicker` primitive with adapter-provided capabilities and explicit
   authority separation - 🎯 9   🛡️ 10   🧠 8, roughly 1000-2300 LOC.
   Best fit. It handles desktop folders, web limitations, drag alternatives,
   privacy, and Clean Disk target validation.
2. Use platform picker plugins directly in feature UI -
   🎯 5   🛡️ 6   🧠 4, roughly 300-800 LOC.
   Fast, but leaks platform, permissions, and path privacy into presentation.
3. Make dropzone the primary target selection model -
   🎯 3   🛡️ 4   🧠 5, roughly 400-1000 LOC.
   Visually convenient but fails keyboard, mobile, and authority semantics.

Accepted direction: option 1.

## Primitive Boundary

Headless owns:

- target picker state;
- picker capability model;
- selected target display model;
- drag-over and drop intent states;
- keyboard equivalent commands;
- accepted target kind: file, folder, volume, virtual provider, snapshot, URL,
  or opaque app target;
- validation pending/error/success states;
- privacy class for display name and full path;
- dropzone semantics and announcements;
- clear/remove target command contract.

Renderer owns:

- dropzone visuals;
- drag highlight;
- folder/file icons;
- compact selected target chips;
- browse button visuals;
- loading and validation progress visuals.

Application owns:

- actual platform picker adapter;
- daemon path validation;
- target authorization;
- scan target creation;
- duplicate/recent target policy;
- platform-specific permission repair.

## Authority Separation

There are three separate concepts:

- display target: what user sees;
- selected target intent: what user asked to scan;
- authorized scan target: what daemon validated and can scan.

The primitive may display and edit target intent. It must not create scan
authority by itself.

## Capability Model

Capability flags:

- canPickFile;
- canPickFolder;
- canPickVolume;
- canDropFile;
- canDropFolder;
- canRevealPath;
- canShowFullPath;
- canValidateBeforeSubmit;
- canReadDirectoryTree;
- canRememberRecentTarget;
- webFileOnly;
- desktopPathAvailable;
- remoteOpaqueTargetOnly.

Unknown capability must fail closed for destructive or scan-authoritative use.

## Web Constraints

Browser file APIs can expose user-selected files and metadata, but full
filesystem scanning is not available to ordinary web UI. Web picker adapters
must be explicit about:

- file versus folder support;
- no arbitrary full disk paths;
- user gesture requirement;
- drag and drop availability;
- browser-specific directory behavior;
- private path not available or not reliable.

Clean Disk web UI should use daemon-backed target selection when scanning local
or remote disks.

## Keyboard And Drag Alternatives

Required:

- Browse/select command reachable by keyboard;
- remove selected target command reachable by keyboard;
- dropzone has a non-drag alternative;
- validation errors are announced;
- instructions are associated with the picker;
- drag state is not the only way to discover accepted targets.

Drag/drop:

- visual drag-over state is advisory;
- drop intent must be validated;
- dropped target is not trusted;
- keyboard equivalent must exist for dragging movement features.

## Path Display Rules

Display path:

- may be abbreviated;
- may use breadcrumb/path-bar standard;
- must use bidi isolation for mixed-direction names;
- can show full path only by explicit product policy.

Authority path:

- never comes from display text;
- never comes from route string;
- never comes from DOM id;
- always validated by application/daemon.

Privacy:

- raw paths are sensitive by default;
- diagnostics and logs use redacted labels;
- accessible labels avoid full paths unless user requested path reading.

## Clean Disk Usage

Target picker:

- Home, Downloads, Library, Apps, System, Custom Folder;
- custom folder uses platform picker or daemon target endpoint;
- recent targets are intents, not authority;
- network/cloud/removable targets need capability and warning facts.

Dropzone:

- optional shortcut for custom target;
- not required for MVP;
- must not imply browser web can scan full disk.

Validation:

- validate path existence;
- validate access quality;
- detect stale target;
- return scan quality and permission warnings.

## Conformance Scenarios

- keyboard-only user selects custom folder;
- drag/drop has browse alternative;
- web adapter reports no arbitrary full disk path capability;
- full path is redacted in logs and support evidence;
- dropped folder requires daemon validation;
- selected target display cannot start destructive cleanup;
- validation failure focuses error summary or field;
- remote target uses opaque id instead of path.

## Failure Catalog

- Dropzone is the only way to choose a target.
- UI treats dropped path as scan authority.
- Web app promises full disk scan from browser picker.
- Full path appears in accessible label or route.
- Recent target starts scan without revalidation.
- Drag-over highlight is the only accepted-type indicator.
- Renderer stores path string as widget key.
