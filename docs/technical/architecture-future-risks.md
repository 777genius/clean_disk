# Architecture Future Risks

Last updated: 2026-05-13.

This document records future pitfalls for the accepted three-layer architecture:

```text
Reusable fs_usage_* library
  -> Clean Disk Rust host
  -> Flutter client
```

The goal is not to solve every case upfront. The goal is to know which risks must shape boundaries before implementation starts.

## Severity Scale

- `P0` - can delete the wrong target, expose user data, corrupt trust, break protocol compatibility, or make cleanup claims unsafe.
- `P1` - can create major performance, reliability, upgrade, UX, or maintainability problems.
- `P2` - important polish, packaging, governance, observability, or future ecosystem concern.

## Sources Reviewed

- Apple Developer, [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox?changes=_3). Relevant points: sandboxed macOS apps have restricted filesystem access, can persist user-granted access with security-scoped bookmarks, and can still hit discretionary or mandatory access errors.
- Apple Developer, [Enabling Security-Scoped Bookmark and URL Access](https://developer.apple.com/documentation/professional-video-applications/enabling-security-scoped-bookmark-and-url-access). Relevant points: persistent sandboxed access needs bookmark entitlements and explicit security-scoped URL handling.
- Apple Developer, [`startAccessingSecurityScopedResource()`](https://developer.apple.com/documentation/Foundation/NSURL/startAccessingSecurityScopedResource%28%29?language=_3). Relevant point: security-scoped resource access can leak kernel resources if not balanced.
- Microsoft Learn, [Reparse Points](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-points). Relevant point: reparse points are used for filesystem links and remote/storage behaviors, so path traversal and cleanup must not treat every directory as ordinary.
- Microsoft Support, [Controlled folder access](https://support.microsoft.com/en-us/windows/allow-an-app-to-access-controlled-folders-b5b6627a-b008-2ca2-7931-7e51e912b034). Relevant points: Windows can block untrusted apps from changing protected folders and users can allow apps explicitly.
- Microsoft Learn, [Enable controlled folder access](https://learn.microsoft.com/en-us/microsoft-365/security/defender-endpoint/enable-controlled-folders?view=o365-21vianet). Relevant point: enterprise-managed Windows environments can configure controlled folder access through MDM, Configuration Manager, Group Policy, or PowerShell.
- Microsoft Learn, [CfCreatePlaceholders](https://learn.microsoft.com/en-us/windows/win32/api/cfapi/nf-cfapi-cfcreateplaceholders). Relevant points: Cloud Files placeholders live under registered sync roots, have hydration policy constraints, and operations can partially fail per entry.
- Microsoft Learn, [DeleteFileA](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-deletefilea). Relevant points: Windows deletion can fail with open handles, can mark a file for deletion on close, and symbolic-link deletion affects the link rather than the target.
- Microsoft Learn, [File streams](https://learn.microsoft.com/en-us/windows/win32/fileio/file-streams). Relevant points: NTFS streams have independent allocation size, actual size, valid data length, compression, encryption, and sparseness.
- Microsoft Learn, [File Access Rights Constants](https://learn.microsoft.com/en-us/windows/win32/fileio/file-access-rights-constants). Relevant point: Windows has separate file rights such as `FILE_DELETE_CHILD`, so delete ability is not the same as read ability.
- Linux man-pages, [unlink(2)](https://man7.org/linux/man-pages/man2/unlink.2.html). Relevant points: unlink can fail because directory write/search permission is missing, sticky bit restrictions apply, or a file is immutable/append-only.
- Linux man-pages, [link(2)](https://man7.org/linux/man-pages/man2/link.2.html). Relevant points: hard links cannot span filesystems, symbolic-link behavior can be implementation-dependent, and NFS can report ambiguous link outcomes.
- Linux man-pages, [inode(7)](https://man7.org/linux/man-pages/man7/inode.7.html). Relevant points: inode metadata includes file type, link count, allocated blocks, timestamps with varying precision, and special file types such as sockets, FIFOs, block devices, and character devices.
- Microsoft Learn, [Hard Links and Junctions](https://learn.microsoft.com/en-us/windows/win32/fileio/hard-links-and-junctions). Relevant points: hard links are multiple directory entries for one file on the same volume, attributes are shared, and junctions reference separate directory storage objects through reparse points.
- Microsoft Learn, [Opportunistic Locks](https://learn.microsoft.com/en-us/windows/win32/fileio/opportunistic-locks). Relevant points: SMB/local file access can involve oplocks for caching/coherency, and scanners/indexers should get out of the way of other file access.
- Microsoft Learn, [File Encryption](https://learn.microsoft.com/en-us/windows/win32/fileio/file-encryption). Relevant point: EFS adds file/directory encryption beyond ordinary ACL checks.
- Microsoft Learn, [BitLocker FAQ](https://learn.microsoft.com/en-us/windows/security/operating-system-security/data-protection/bitlocker/faq). Relevant point: fixed and removable data drives can be locked and unlocked separately from ordinary filesystem permissions.
- Linux kernel docs, [fscrypt](https://www.chiark.greenend.org.uk/doc/linux-doc/html/filesystems/fscrypt.html). Relevant points: encrypted directories can become locked, making names/data unavailable and restricting create/link/rename operations.
- Rust std, [`std::fs::remove_dir_all`](https://doc.rust-lang.org/beta/std/fs/fn.remove_dir_all.html?search=std%3A%3Avec). Relevant points: recursive removal has platform-specific TOCTOU behavior, is not idempotent, can partially remove contents if concurrent writes occur, and may fail with `DirectoryNotEmpty`.
- OWASP, [Path Traversal](https://owasp.org/www-community/attacks/Path_Traversal). Relevant point: path input must not allow access outside intended roots through `../`, absolute paths, or encoded variants.
- Android Developers, [Zip Path Traversal](https://developer.android.com/privacy-and-security/risks/zip-path-traversal?hl=en). Relevant point: archive extraction can write outside the target directory if entry names are not validated.
- Kaspersky IT Encyclopedia, [Zip bomb](https://encyclopedia.kaspersky.com/glossary/zip-bomb/). Relevant point: archive decompression can exhaust disk, memory, or CPU because compressed and decompressed sizes can differ massively.
- Apple Developer, [About Apple File System](https://developer.apple.com/documentation/foundation/about-apple-file-system?changes=_8_5). Relevant points: APFS supports clones, snapshots, space sharing, fast directory sizing, atomic safe-save, and sparse files, so size and reclaim semantics can differ from a simple directory total.
- Apple Developer Archive, [APFS FAQ](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/FAQ/FAQ.html). Relevant points: APFS filename normalization and case behavior can differ from HFS+ and can affect stored external filenames.
- Microsoft Learn, [Naming Files, Paths, and Namespaces](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file). Relevant points: Windows path syntax includes reserved characters/names, UNC roots, long-path behavior, alternate streams, and non-default case sensitivity behavior.
- Linux kernel docs, [Quota subsystem](https://www.kernel.org/doc/html/latest/filesystems/quota.html). Relevant point: filesystems can enforce user/group inode and space limits, so cleanup effect may be quota-visible without matching global free-space changes.
- Rust std, [`std::fs::read_dir`](https://doc.rust-lang.org/std/fs/fn.read_dir.html). Relevant point: directory entry order is platform and filesystem dependent, so stable UI/pagination cannot rely on raw traversal order.
- Rust `ignore` crate, [`WalkBuilder`](https://docs.rs/ignore/latest/ignore/struct.WalkBuilder.html). Relevant point: fast walkers may respect ignore files and hidden-file filters by default, which is useful for search tools but dangerous if silent in a disk-usage product.
- Unicode Consortium, [Unicode Collation Algorithm](https://www.unicode.org/reports/tr10/). Relevant points: collation varies by language, customization, and application, and simple binary/codepoint ordering does not match user expectations for sorted text.
- Dart docs, [Numbers in Dart](https://dart.dev/resources/language/number-representation). Relevant point: Dart native and Dart web use different number implementations, and web `int` is backed by JavaScript double precision with 53 bits of integer precision.
- MDN, [`Number.MAX_SAFE_INTEGER`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER). Relevant point: JavaScript integers are only safely exact up to `2^53 - 1`.
- RFC 8259, [JSON](https://www.rfc-editor.org/rfc/rfc8259). Relevant point: JSON number precision and range are implementation-limited, so exact integer interoperability requires explicit constraints.
- The Cargo Book, [SemVer Compatibility](https://doc.rust-lang.org/cargo/reference/semver.html). Relevant points: Rust library compatibility includes type/API details and Rust version expectations, not just function names.
- The Cargo Book, [Features](https://doc.rust-lang.org/stable/cargo/reference/features.html). Relevant point: Cargo features should be additive because feature unification can enable features selected by other dependencies.
- The Cargo Book, [Rust version](https://doc.rust-lang.org/cargo/reference/rust-version.html). Relevant point: `package.rust-version` documents the minimum supported Rust version and lets Cargo surface clearer diagnostics.
- Apple Developer, [FSEvents `kFSEventStreamEventFlagMustScanSubDirs`](https://developer.apple.com/documentation/coreservices/1455361-fseventstreameventflags/kfseventstreameventflagmustscansubdirs/). Relevant point: clients must recursively rescan when events are coalesced or dropped.
- Apple Developer Archive, [Using the File System Events API](https://developer.apple.com/library/archive/documentation/Darwin/Conceptual/FSEvents_ProgGuide/UsingtheFSEventsFramework/UsingtheFSEventsFramework.html). Relevant points: dropped events imply recursive rescan and symlink-related changes may require `lstat`.
- Linux man-pages, [inotify(7)](https://man7.org/linux/man-pages/man7/inotify.7.html). Relevant point: event queues can overflow and produce `IN_Q_OVERFLOW`, requiring recovery instead of trusting incremental events.
- Apple Developer, [`URLResourceValues.mayHaveExtendedAttributes`](https://developer.apple.com/documentation/foundation/urlresourcevalues/mayhaveextendedattributes). Relevant point: files may have extended attributes and Apple exposes resource values for allocated size, sparse state, purgeable state, and shared content hints.
- Apple Developer Archive, [`copyfile(3)`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/copyfile.3.html). Relevant point: macOS copy semantics explicitly include extended attributes, ACLs, resource forks, and AppleDouble handling.
- Apple Developer, [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution?changes=_1). Relevant points: Developer ID distribution requires notarization flow, notary checks, and stapled tickets for offline Gatekeeper validation.
- Apple Developer, [Hardened Runtime](https://developer.apple.com/documentation/security/hardened_runtime?changes=l_6&language=objc). Relevant point: notarized macOS apps must use hardened runtime, which can restrict less common runtime behavior unless entitlements are configured.
- Apple Developer, [`providerTranslocated`](https://developer.apple.com/documentation/fileprovider/nsfileprovidererror/providertranslocated). Relevant point: Gatekeeper can translocate recently downloaded apps from disk images, archives, or Downloads to randomized read-only locations.
- Flatpak, [Sandbox Permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html?highlight=portal). Relevant points: sandboxed apps see a restricted filesystem, and app-local paths can map to sandbox storage such as `~/.var/app/$FLATPAK_ID`.
- Snapcraft, [home interface](https://snapcraft.io/docs/reference/interfaces/home-interface/). Relevant point: strict snaps do not have arbitrary `$HOME` access and need connected interfaces for user files.
- Docker Docs, [OverlayFS storage driver](https://docs.docker.com/engine/storage/drivers/overlayfs-driver/). Relevant points: Docker overlay/overlay2 uses union layers, lower/upper/merged directories, and direct manipulation under Docker's storage directory is warned against.
- Docker Docs, [Prune unused Docker objects](https://docs.docker.com/engine/manage-resources/pruning/). Relevant point: Docker conservatively keeps unused objects until explicit prune commands are run.
- Docker Docs, [Storage drivers](https://docs.docker.com/engine/storage/drivers/). Relevant point: storage driver accounting can over-estimate total disk usage in non-trivial ways.
- Microsoft Learn, [How to manage WSL disk space](https://learn.microsoft.com/en-us/windows/wsl/disk-space). Relevant points: WSL 2 stores distributions in ext4 VHDX files with large maximum sizes and separate host/guest disk-space behavior.
- Apple Developer, [`URLResourceValues.isPurgeable`](https://developer.apple.com/documentation/foundation/urlresourcevalues/ispurgeable?changes=l__8). Relevant point: APFS can mark resources as purgeable, meaning the filesystem can delete them when space is needed.
- Microsoft Support, [Manage drive space with Storage Sense](https://support.microsoft.com/en-us/windows/manage-drive-space-with-storage-sense-654f6ada-7bfc-45e5-966b-e24aded96ad5). Relevant point: Windows Storage Sense can automatically clean temporary files and cloud-backed files according to system policy.
- WICG, [Private Network Access](https://wicg.github.io/private-network-access/). Relevant point: browsers are tightening access from public/private contexts to local/private network resources, which affects web UI talking to a localhost daemon.
- Chrome for Developers, [Private Network Access preflights](https://developer.chrome.com/blog/private-network-access-preflight?hl=en). Relevant point: Chrome has moved toward requiring secure contexts and preflight behavior for private network requests.
- freedesktop.org, [Desktop Trash Can Specification](https://specifications.freedesktop.org/trash/latest). Relevant points: Trash directories can vary by filesystem/user, original filenames in Trash are not authoritative, and directory size caches may exist.

## Top 3 Future Risk Areas

1. Cleanup authority and stale identity - 🎯 10 🛡️ 9 🧠 8, roughly 800-1800 LOC across identity snapshots, revalidation, delete plans, receipts, and tests.
2. Protocol/version/capability drift between Flutter and daemon - 🎯 9 🛡️ 9 🧠 6, roughly 400-1000 LOC across handshake, compatibility DTOs, schema fixtures, and client fallbacks.
3. Reusable library becoming Clean Disk-specific - 🎯 9 🛡️ 8 🧠 7, roughly 300-900 LOC across boundary tests, API review rules, naming discipline, and mapper separation.

## P0 Risks

### Cleanup TOCTOU And Path Replacement

Risk: user selects a node after scan, then a path is replaced by a symlink, junction, reparse point, hardlink, mounted folder, or different file before cleanup.

Required:

- cleanup commands must not trust path-only authority;
- delete candidate carries scan-time identity evidence;
- cleanup revalidates current metadata and identity immediately before Trash/delete;
- mismatch returns a structured stale/moved/replaced reason;
- UI must require re-review when candidate identity is stale.

Architecture placement:

- reusable identity model: `fs_usage_core`;
- revalidation port: `fs_usage_engine` or `fs_usage_cleanup`;
- platform implementation: `fs_usage_platform`;
- delete plan workflow: `fs_usage_cleanup`;
- UI warning copy: Flutter presentation.

Avoid:

- `move_to_trash(path: String)` as the authority;
- using row index or path text from Flutter as cleanup identity;
- accepting a scan result after target path changed.

### Remote Mode Is Not Local Mode With A Public Port

Risk: local daemon security assumptions are reused for remote/headless deployments.

Required:

- remote mode has explicit auth, configured listen address, and clear enablement;
- local mode binds to loopback only by default;
- destructive commands require authorization in every mode;
- remote mode supports allowed roots and audit logs;
- docs explain TLS/reverse proxy expectations before remote release.

Architecture placement:

- local/remote config: `apps/clean_disk_server/config`;
- auth/session token: `clean_disk_http_ws`;
- authorization policy: Clean Disk host/application boundary;
- reusable library remains transport-agnostic.

Avoid:

- `--host 0.0.0.0` without a security profile;
- wildcard CORS in local or remote mode;
- assuming browser origin checks are enough for destructive commands.

### Protocol And Capability Version Mismatch

Risk: Flutter app connects to an older or newer daemon with incompatible DTOs, event semantics, or backend capabilities.

Required:

- handshake includes protocol version, daemon version, build id, and capability set;
- Flutter refuses incompatible major protocol versions;
- clients handle unknown enum variants and unknown capabilities;
- protocol compatibility fixtures exist before beta;
- every event batch includes schema/version context or is scoped by negotiated version.

Architecture placement:

- versioned DTOs: `clean_disk_protocol`;
- handshake route: `clean_disk_http_ws`;
- compatibility checks: Flutter data layer;
- capability facts: `fs_usage_engine`.

Avoid:

- Flutter assuming a field exists because current daemon has it;
- Rust protocol DTOs doubling as domain types;
- silent fallback that hides missing cleanup safety capability.

### Exact Integer Transport And Unit Semantics

Risk: byte counts, allocated blocks, item counts, node ids, cursors, event sequence numbers, and operation ids exceed safe JavaScript/Dart web precision or get mixed between logical bytes, allocated bytes, blocks, and formatted UI strings. The UI can then sort, compare, or confirm the wrong value.

Required:

- protocol uses exact string-encoded integers for values that must survive Flutter web and JavaScript boundaries exactly;
- domain value objects separate logical bytes, allocated bytes, block count, item count, sequence number, node id, and cursor token;
- UI formatting is one-way and never parsed back into command data;
- schema fixtures include values around `2^53`, multi-terabyte totals, huge file counts, and cursor/event sequence boundaries;
- compatibility tests assert that desktop and web clients decode the same exact values.

Architecture placement:

- exact numeric value objects: `fs_usage_core`;
- protocol encoding policy: `clean_disk_protocol`;
- Flutter DTO parsing and formatting: data/presentation boundary;
- schema/fixture tests: protocol test suite.

Avoid:

- sending exact bytes as JSON numbers where Flutter web can lose precision;
- parsing `"38.7 GB"` or localized UI text back into command payloads;
- one generic `size` field when the unit/accounting mode matters.

### Orphan Daemon Process

Risk: Flutter desktop crashes or is killed while `clean-disk-server` keeps running with an active token, open port, or active scan.

Required:

- local daemon records parent process/session ownership where possible;
- idle timeout shuts down unowned local daemon;
- graceful shutdown endpoint exists;
- startup checks for stale prior daemon and verifies token ownership;
- active scan workers are cancelled or drained according to shutdown policy.

Architecture placement:

- process lifecycle: `apps/clean_disk_server`;
- shutdown coordination: server host;
- scan cancellation: `fs_usage_engine`;
- Flutter launch/healthcheck: app shell data adapter.

Avoid:

- using a fixed port and long-lived token;
- leaving remote mode defaults enabled for desktop local mode;
- treating app exit as the only daemon cleanup path.

### False Cleanup Confidence

Risk: UI claims "safe to delete" or exact reclaim when evidence is incomplete.

Required:

- recommendations include evidence, risk tier, and rule version;
- reclaim estimate is separate from folder size;
- unknown shared extents, snapshots, cloud placeholders, compression, and hardlinks lower confidence;
- delete receipt reports actual action outcome and observed free-space delta when available.

Architecture placement:

- evidence/risk facts: `fs_usage_accounting` and `fs_usage_cleanup`;
- recommendation rules: Clean Disk product layer or reusable optional rules only if generic;
- UI language: Flutter.

Avoid:

- one boolean `is_safe`;
- exact reclaim labels based only on scan size;
- auto-selecting destructive candidates without review.

### OS Privacy Permission Blind Spots

Risk: macOS Full Disk Access, Windows Controlled Folder Access, Linux sandbox/package permissions, or enterprise policy blocks parts of the filesystem and the app presents a partial scan as complete.

Required:

- scan result includes permission coverage and skipped protected locations;
- root-target permission failure is distinct from nested skipped paths;
- platform permission status is reported as capability/evidence, not guessed from errors alone;
- UI can guide the user to grant permission without implying the scan was complete;
- support diagnostics can show permission category without leaking full paths.

Architecture placement:

- permission capability model: `fs_usage_core`;
- platform checks: `fs_usage_platform`;
- error classification: `fs_usage_engine`;
- user guidance: Flutter presentation and platform packaging docs.

Avoid:

- treating permission denied as a generic IO error;
- hiding protected folders from totals without warning;
- prompting repeatedly or unexpectedly for permissions during scan.

### Cloud File Hydration By Accident

Risk: reading metadata, thumbnails, extended attributes, or content-adjacent details causes iCloud, OneDrive, Dropbox, Google Drive, or File Provider placeholders to download data.

Required:

- default scan must be metadata-only and no-hydrate where platform allows;
- placeholder/offline state is a first-class node detail;
- category/recommendation logic must not require opening file contents by default;
- any future content inspection requires explicit opt-in and a separate capability;
- cleanup estimate for cloud placeholders is local-space-aware, not cloud-size-only.

Architecture placement:

- placeholder facts: `fs_usage_platform`;
- accounting semantics: `fs_usage_accounting`;
- scan policy: `fs_usage_engine`;
- UI warnings: Flutter details/recommendation views.

Avoid:

- reading file contents for icons, MIME detection, or duplicate detection in the main scan;
- showing cloud logical size as local reclaim;
- triggering downloads just because a row is selected.

### Browser Localhost Policy Drift

Risk: a Flutter web UI that talks to `clean-disk-server` over localhost stops working or becomes security-sensitive because browser Private Network Access, secure-context, local-network permission, or CORS behavior changes.

Required:

- daemon-served local web UI is the default for local mode until hosted pairing is designed;
- hosted web UI to localhost requires explicit pairing, token, origin allowlist, and browser compatibility tests;
- protocol fallback states explain blocked local-network access clearly;
- browser support matrix includes Chrome/Edge/Safari/Firefox behavior for localhost/private network access;
- remote mode does not rely on browser localhost exemptions.

Architecture placement:

- transport policy: `clean_disk_http_ws`;
- hosted/local UI mode selection: `apps/clean_disk_server` and Flutter app shell;
- compatibility/error mapping: `clean_disk_protocol` and Flutter data layer.

Avoid:

- wildcard CORS to make localhost work;
- hosted website auto-probing localhost ports;
- assuming browser policy will stay stable across releases.

### Path Semantics And Canonicalization Traps

Risk: path equality and display differ across macOS, Windows, Linux, WSL, network shares, Unicode normalization, case sensitivity, long paths, reserved names, alternate data streams, and trailing dots/spaces.

Required:

- path display string is separate from path authority;
- identity checks rely on filesystem identity when available;
- search normalization is filesystem-aware where possible;
- Windows long-path and reserved-name behavior is tested;
- invalid Unicode paths are representable without lossy command authority.

Architecture placement:

- path value objects: `fs_usage_core`;
- platform identity/canonicalization: `fs_usage_platform`;
- protocol path encoding: `clean_disk_protocol`;
- UI display/truncation: Flutter.

Avoid:

- `to_string_lossy()` as command authority;
- lowercasing paths as a universal equality strategy;
- canonicalizing through symlinks before cleanup policy decides whether that is allowed.

### Scan History And Receipts As Sensitive Data

Risk: local scan history, receipts, support bundles, screenshots, or crash reports expose private folder names, project names, client names, or delete history.

Required:

- persisted history is opt-in or has clear retention defaults;
- support bundles redact or hash paths by default;
- receipts store only what is needed for audit and user recovery;
- telemetry never includes raw paths, search terms, or delete targets;
- export/import flows warn about private filesystem metadata.

Architecture placement:

- persistence schema: future local state package/crate;
- redaction policy: Clean Disk host and Flutter support export;
- protocol DTOs: `clean_disk_protocol`;
- reusable library must not decide product telemetry.

Avoid:

- storing full scan trees indefinitely by default;
- including raw query text in logs;
- treating local-only data as automatically safe.

### Trash Semantics Are Not Uniform

Risk: "Move to Trash" behaves differently across macOS, Windows, Linux desktops, network shares, removable volumes, headless servers, and cross-filesystem moves.

Required:

- Trash availability is a capability, not assumed;
- Linux/XDG Trash behavior is adapter-specific and can depend on filesystem/user trash directories;
- Trash receipt stores actual result path/status only when safe and meaningful;
- permanent delete fallback is never automatic;
- restore expectations are platform-specific and shown honestly.

Architecture placement:

- capability model: `fs_usage_cleanup`;
- platform Trash adapter: `fs_usage_cleanup` infrastructure;
- protocol receipt DTOs: `clean_disk_protocol`;
- UI confirmation and receipt: Flutter cleanup presentation.

Avoid:

- using Trash path/name as identity;
- assuming original filename is preserved in Trash;
- moving across filesystems in a way that loses metadata without warning.

### Crash Recovery During Destructive Operations

Risk: app, daemon, OS, power, or update process crashes after some cleanup items moved to Trash and before receipts/events/cache state are fully written. The UI can later show stale candidates, duplicate operations, or unclear "what happened" state.

Required:

- destructive operations are journaled before action with operation id, plan hash, candidate identities, and target scope;
- each item outcome is persisted as it becomes known, not only at operation end;
- daemon restart reconciles in-progress cleanup operations into `completed`, `partial`, `unknown`, or `needs_review`;
- retrying a mutating command is idempotent by operation id and rejects payload mismatches;
- updater/shutdown policy waits, cancels, or blocks during active destructive operations.

Architecture placement:

- delete operation aggregate: `fs_usage_cleanup`;
- local operation journal: Clean Disk local state;
- idempotency and receipts: `clean_disk_protocol` and server application layer;
- UI recovery workflow: Flutter cleanup presentation.

Avoid:

- "fire and forget" cleanup commands;
- writing one receipt only after the full recursive operation finishes;
- automatically retrying an unknown destructive operation after crash.

### Open Handles And Delete-Pending Semantics

Risk: Windows and some network filesystems can block deletion because another process has an open handle, memory map, sync-provider handle, or share mode that prevents delete. Windows can also mark a file for deletion on close, making UI state temporarily confusing.

Required:

- cleanup result distinguishes locked, delete-pending, disappeared, access-denied, and partial-success outcomes;
- retry policy is bounded and user-visible;
- delete receipts avoid claiming completion until the platform confirms the action or records a pending state;
- details panel can show "in use" or "locked" as a warning when detectable;
- background rescans reconcile paths that vanish after handles close.

Architecture placement:

- cleanup result model: `fs_usage_cleanup`;
- platform delete adapter: `fs_usage_cleanup` infrastructure;
- revalidation and lock classification: `fs_usage_platform`;
- receipt and UI state: Clean Disk protocol and Flutter.

Avoid:

- treating all delete failures as permission denied;
- spinning retries while another process owns a handle;
- showing item reclaimed while the file is only marked delete-pending.

### Alternate Streams, Extended Attributes, And Forks

Risk: NTFS alternate data streams, macOS extended attributes/resource forks, ACLs, Finder metadata, quarantine flags, or AppleDouble files make "file size" and "what gets moved/deleted/copied" more complex than the main data stream.

Required:

- scan/details model can report "has extra metadata/streams" as a warning or capability;
- accounting separates main apparent size from allocated size when stream metadata is not fully counted;
- cleanup/trash receipts do not imply metadata preservation unless the platform adapter confirms it;
- support bundles avoid dumping xattr/stream names unless redacted and opt-in;
- tests include NTFS alternate stream and macOS extended-attribute fixtures where possible.

Architecture placement:

- metadata capability: `fs_usage_core`;
- platform detection: `fs_usage_platform`;
- accounting estimate: `fs_usage_accounting`;
- protocol warnings/details: `clean_disk_protocol`;
- UI explanation: Flutter details panel.

Avoid:

- assuming `metadata.len()` covers every byte associated with a file;
- deleting AppleDouble `._` files as generic junk without context;
- ignoring quarantine/resource-fork metadata when recommending app bundle cleanup.

### Quota, Purgeable, Reserved, And Virtual Free Space

Risk: "free space" and "reclaim" differ under user quotas, project quotas, APFS purgeable storage, Windows reserved/system storage, cloud dehydration, and virtual disks. Deleting bytes may improve one quota but not global free space, or may appear not to help until another system component compacts or purges.

Required:

- distinguish physical free space, quota-visible free space, purgeable space, and estimated reclaim;
- report when free-space measurement is unavailable, virtualized, or quota-limited;
- after cleanup, observe actual free-space delta separately from estimated reclaim;
- APFS purgeable and Windows Storage Sense-managed files are warnings/capabilities, not ordinary cache;
- UI copy must not promise that deleting a node immediately increases host disk free space.

Architecture placement:

- volume/free-space model: `fs_usage_core`;
- platform free-space provider: `fs_usage_platform`;
- reclaim estimate confidence: `fs_usage_accounting`;
- receipt and UI totals: `clean_disk_protocol` and Flutter.

Avoid:

- one `freeBytes` field with no source or confidence;
- claiming VHD or container storage shrank after deleting guest files;
- mixing system-managed purgeable space with user-selected cleanup.

### Virtual Disk, Overlay, And Union Filesystem Accounting

Risk: Docker Desktop, WSL2, overlayfs, containerd snapshotters, VM images, bind mounts, and union mounts can share layers, hide lower files through whiteouts, or store guest data in host VHD/raw disk images. Scanning either the host path or the guest mount can misrepresent reclaim and ownership.

Required:

- detect known virtual/managed storage roots and classify them separately;
- prefer official tool adapters for Docker/WSL cleanup instead of deleting internal storage files;
- mark overlay/union filesystem accounting as shared/estimated;
- do not recurse into Docker/WSL internals as ordinary folders by default;
- explain when deleting inside a guest does not compact the host VHD/raw image.

Architecture placement:

- managed-storage detection: `fs_usage_platform` or tool-specific adapters;
- accounting confidence: `fs_usage_accounting`;
- recommendation rules: Clean Disk tool-managed cleanup layer;
- UI warnings: Flutter details and cleanup recommendation views.

Avoid:

- direct manipulation of `/var/lib/docker`, Docker Desktop VM data, or WSL ext4.vhdx as ordinary cleanup;
- treating overlay lower layers as exclusively reclaimable;
- assuming host-visible file size equals guest-visible cleanup result.

### Allowed Root Escape And Path Traversal In Daemon API

Risk: a local web client, remote client, browser bug, malicious local process, or stale UI sends a path that escapes the intended scan/cleanup root through `../`, absolute paths, URL encoding, Unicode normalization, symlinks, junctions, reparse points, bind mounts, or path replacement between validation and action.

Required:

- daemon commands must be authorized against explicit root grants, not raw path strings;
- root grants carry stable identity evidence where the platform can provide it;
- protocol accepts opaque root/session/node/candidate identifiers for destructive actions, with path only as display/evidence;
- path parsing, decoding, normalization, and root-containment checks happen at the server boundary before query planning;
- cleanup revalidates the current object against the selected candidate identity immediately before Trash/delete;
- tests cover traversal, encoded separators, invalid Unicode, symlink/reparse replacement, mount-boundary changes, and case-normalization traps.

Architecture placement:

- grant and path authority model: `fs_usage_core`;
- root policy and authorization: `clean-disk-server` application layer;
- protocol command DTOs: `clean_disk_protocol`;
- platform identity/revalidation: `fs_usage_platform`;
- cleanup candidate validation: `fs_usage_cleanup`.

Avoid:

- any API where `path: String` alone authorizes scan or cleanup;
- trusting Flutter row text, browser URL params, or search result paths as authority;
- canonicalizing once at selection time and reusing that result for deletion later.

### Delete Permission Is Not Read Permission

Risk: scanning can succeed while deletion fails, or deletion can be allowed through a parent directory right even when file-level expectations differ. Windows has separate delete-related rights such as `DELETE` and `FILE_DELETE_CHILD`; POSIX deletion depends on parent directory write/search permissions, sticky-bit rules, and immutable/append-only flags.

Required:

- scan permission and delete permission are separate capabilities;
- cleanup preflight reports structured reasons such as `read_only_filesystem`, `sticky_directory`, `immutable`, `append_only`, `delete_child_denied`, `parent_write_denied`, `controlled_folder_blocked`, and `unknown`;
- UI never treats "we scanned it" as "we can remove it";
- delete permission is rechecked at action time because ACLs and directory ownership can change after scan;
- platform adapters expose delete capability confidence, not only a boolean.

Architecture placement:

- delete capability facts: `fs_usage_cleanup`;
- platform permission adapters: `fs_usage_platform`;
- protocol reason enums: `clean_disk_protocol`;
- UI confirmation/details: Flutter cleanup presentation.

Avoid:

- one generic `accessDenied` error;
- assuming owner can delete on every platform;
- doing expensive permission probes for every file during the main scan when a cheaper candidate-level preflight is enough.

### Recursive Delete Primitive Footguns

Risk: a library or adapter eventually calls a convenient recursive-delete primitive too directly. Recursive removal can be non-idempotent, platform-dependent, partially complete under concurrent writes, and exposed to symlink/reparse/path-replacement races if not guarded by our own delete plan.

Required:

- recursive delete is never a public use case; it is an adapter detail behind `DeletePlan`/`TrashPlan`;
- every recursive operation is scoped by root grant, candidate identity, target type, policy, and operation id;
- partial outcomes are expected and stored per item/subtree where possible;
- concurrent directory mutations return structured retryable/partial states, not generic failure;
- tests include directory replaced by symlink/junction during cleanup and directory receiving new children during cleanup.

Architecture placement:

- delete plan model: `fs_usage_cleanup`;
- adapter implementation: platform cleanup infrastructure;
- operation journal/receipts: Clean Disk local state and `clean_disk_protocol`;
- destructive tests: platform fixture lab.

Avoid:

- exposing `remove_dir_all(path)` style APIs across Clean Architecture boundaries;
- retrying recursive delete blindly after partial failure;
- treating `DirectoryNotEmpty` or stale path as user error.

### Hardlink And Link-Count Reclaim Ambiguity

Risk: one file can have multiple names. Removing one hardlink unlinks one directory entry, but bytes may remain because other links still point to the same file. A hardlink inside an allowed root may also represent content visible elsewhere, and content-addressable stores use this deliberately.

Required:

- scan model records link count and hardlink policy where available;
- reclaim estimate downgrades confidence when link count is greater than one or link identity is unknown;
- cleanup copy says "remove this directory entry" semantics when applicable, not "destroy unique file content";
- hardlink dedupe mode is recorded in scan metadata and visible in diagnostics;
- tool-managed stores such as pnpm, Nix, package caches, and system component stores need specific rules before recommending cleanup.

Architecture placement:

- file identity/link facts: `fs_usage_core`;
- platform metadata adapter: `fs_usage_platform`;
- accounting confidence: `fs_usage_accounting`;
- recommendation rules: product/tool adapters;
- protocol explanation fields: `clean_disk_protocol`.

Avoid:

- counting every hardlinked path as independently reclaimable;
- using path count instead of link count/identity when estimating reclaim;
- treating hardlinks as duplicate files safe to delete automatically.

### Special Files, Pseudo Filesystems, And Device Nodes

Risk: `/proc`, `/sys`, `/dev`, FIFOs, sockets, block devices, character devices, named pipes, procfs/sysfs entries, and other virtual files are not ordinary files. Opening them can block, expose live system state, trigger side effects, or report meaningless sizes.

Required:

- main scan uses metadata/lstat-style inspection and does not open special files for content;
- file type is a first-class node fact, not inferred from extension;
- pseudo filesystems and device roots are skipped or shown as special targets by default;
- cleanup is disabled for special file types unless an explicit platform/tool adapter owns the operation;
- UI can show "special/system entry" warnings without suggesting ordinary cleanup.

Architecture placement:

- file type model: `fs_usage_core`;
- platform metadata classification: `fs_usage_platform`;
- scan skip policy: `fs_usage_engine`;
- cleanup capability check: `fs_usage_cleanup`;
- UI details warning: Flutter.

Avoid:

- reading from devices/FIFOs/sockets to "measure" them;
- treating zero-size pseudo files as free cleanup opportunities;
- recursing into `/proc`, `/sys`, device roots, or platform equivalents as ordinary directories.

## P1 Risks

### Linux Package Confinement Modes

Risk: Flatpak, Snap, AppImage wrappers, distro packages, and portals give different filesystem visibility and permission semantics. A confined build may not see hidden files, removable media, host paths, or real home directories.

Required:

- package mode is part of runtime capabilities;
- confined builds expose clear scan limitations;
- broad host filesystem access is not silently requested just to make scan work;
- portal-selected roots are represented as grants, not global permissions;
- package-specific docs explain required interfaces/permissions.

Architecture placement:

- package capability detection: app shell and `clean-disk-server`;
- root grant model: `fs_usage_core` and Clean Disk local state;
- Linux packaging docs: release/installer docs;
- UI permission guidance: Flutter.

Avoid:

- assuming a Flatpak/Snap build can scan `~` like a native build;
- storing sandbox-internal paths as if they were host paths;
- making unsupported package modes look like product bugs.

### macOS App Translocation And Bundled Daemon Path

Risk: a directly downloaded macOS app can be translocated by Gatekeeper to a randomized read-only path, and hardened runtime/notarization rules can affect helper binaries, relative paths, dynamic libraries, and daemon launch.

Required:

- `clean-disk-server` launch uses bundle/resource APIs, not fragile relative paths;
- app and daemon are signed/notarized as one distribution unit;
- first-launch translocation is tested from DMG/ZIP/Downloads;
- daemon update/replace flow accounts for read-only/translocated app locations;
- hardened runtime entitlements are reviewed before distribution.

Architecture placement:

- distribution packaging: release pipeline;
- daemon launch: Flutter app shell/native platform adapter;
- server binary verification: `apps/clean_disk_server` startup/health;
- update flow: installer/auto-update layer.

Avoid:

- launching `./clean-disk-server` relative to current working directory;
- writing mutable data into the app bundle;
- testing only from a development build outside Gatekeeper.

### Signing, Reputation, And Security Product Trust

Risk: macOS Gatekeeper/notarization, Windows SmartScreen reputation, enterprise WDAC/Defender policy, and security software can block or warn on the app/daemon even if code is correct.

Required:

- signing/notarization is part of release gates, not a late packaging task;
- Windows distribution plan accounts for SmartScreen reputation per new file/build;
- daemon binary identity is stable and visible to users/admins;
- enterprise allowlisting docs identify executable names, signatures, and network behavior;
- failed launch due to OS trust policy becomes a clear diagnostic.

Architecture placement:

- release engineering: CI/CD and installer docs;
- daemon launch diagnostics: Flutter app shell and `clean_disk_protocol`;
- observability: Clean Disk host.

Avoid:

- unsigned helper daemon in production;
- changing binary name/path every release without reason;
- treating SmartScreen/Gatekeeper failures as generic "server not reachable".

### Snapshot-Scoped Node IDs

Risk: consumers persist `NodeId` and expect it to stay valid across scans.

Required:

- document `NodeId` as scan-session/snapshot scoped;
- persistent history uses a different identity model;
- protocol errors include `stale_node_id` or `wrong_snapshot`;
- UI clears selection when snapshot epoch changes.

Avoid:

- globally stable `NodeId` promises;
- deriving cleanup authority from `NodeId` alone;
- comparing nodes across scans without identity mapping.

### Cursor Invalidation

Risk: a page cursor from one sort/filter/search/snapshot is reused after query state changes.

Required:

- cursors include snapshot epoch and query fingerprint;
- server rejects stale or mismatched cursors;
- cursor payload is opaque to Flutter;
- query result pages include enough metadata for UI recovery.

Avoid:

- offset-only pagination for huge mutable read models;
- Flutter building cursors from row numbers;
- reusing search cursors after sort or filter changes.

### Huge Single Directory

Risk: one folder has hundreds of thousands or millions of direct children, causing sort, memory, pagination, or UI stalls.

Required:

- children index handles huge sibling lists;
- sorting is Rust-side and paginated;
- first page can be returned without materializing every formatted DTO;
- UI virtualization is mandatory for tree rows;
- benchmark includes huge-sibling fixtures.

Avoid:

- `Vec<TreeRowDto>` for all children in protocol;
- Flutter sorting visible plus hidden children;
- details pane operations that scan all siblings synchronously.

### Traversal Policy And Silent Filters

Risk: a fast traversal library or adapter silently applies hidden-file rules, ignore-file rules, same-filesystem rules, follow-link rules, max-depth limits, or unstable raw directory ordering. The app then looks fast but shows an incomplete or non-reproducible disk usage picture.

Required:

- effective traversal policy is explicit in every scan: hidden entries, ignore files, symlinks, reparse points, mount crossing, max depth, open-file limit, and thread count;
- default full-disk scan does not respect `.gitignore`/hidden filters unless the UI labels the scan as filtered;
- deterministic sorting and pagination are server-owned and cannot depend on filesystem `read_dir` order;
- filter presets are product features with visible scope, not adapter defaults;
- benchmarks include filtered and unfiltered scans so performance shortcuts are visible.

Architecture placement:

- scan options/value objects: `fs_usage_core`;
- adapter policy mapping: `fs_usage_engine` and pdu/traversal adapters;
- scan metadata DTOs: `clean_disk_protocol`;
- UI scope labels: Flutter scan header/status.

Avoid:

- adopting search-tool walker defaults without reviewing them for disk-usage semantics;
- hiding ignored/hidden/system files without a scope badge;
- offset pagination over unsorted raw filesystem iteration.

### Timestamp Metadata Is Evidence, Not Identity

Risk: modified, created, changed, and accessed timestamps differ by filesystem and OS. Access time may be disabled or coarse, birth time may be missing, directory mtime can change for reasons unrelated to contents, and timestamp precision can differ. Cleanup rules based on "old files" can become unsafe if timestamps are treated as truth.

Required:

- timestamp fields include source, availability, precision/confidence, and timezone/display handling;
- recommendations never rely only on timestamp age for destructive cleanup;
- stale identity revalidation uses stronger identity facts when available, not only size and mtime;
- sorting by modified date is a UI/query feature, not a cleanup authority;
- tests include missing birth time, coarse timestamp, future timestamp, and clock-skew fixtures.

Architecture placement:

- timestamp value objects: `fs_usage_core`;
- platform metadata adapter: `fs_usage_platform`;
- recommendation evidence model: product/rule adapters;
- protocol display/query fields: `clean_disk_protocol`;
- UI sorting and explanation: Flutter.

Avoid:

- using `mtime` as a stable id;
- deleting "old" folders without tool-specific evidence;
- assuming all filesystems expose the same timestamp set or precision.

### Locale, Natural Sort, And Stable Ordering Drift

Risk: users expect natural and locale-aware sorting, while backend pagination needs deterministic ordering. Locale collation can put the same names in different order across OS, language, ICU version, and user preferences. If page cursors depend on a mutable locale sort, rows can jump or duplicate.

Required:

- every sorted query declares sort key, direction, locale/natural-sort policy, tie-breaker, and snapshot epoch;
- Rust read model owns authoritative sort order for paginated results;
- UI can display locale-friendly names but must not reorder hidden backend pages locally;
- ties use stable internal keys so pagination is repeatable;
- tests cover numeric names (`file2`/`file10`), accents, case variants, RTL names, emoji, and invalid Unicode display.

Architecture placement:

- sort policy value objects: `fs_usage_core`;
- indexed query implementation: `fs_usage_engine`;
- protocol query/cursor fields: `clean_disk_protocol`;
- display formatting and accessibility: Flutter.

Avoid:

- local Flutter sort over only the visible page;
- raw byte/codepoint order presented as "alphabetical" without knowing the policy;
- changing sort policy without invalidating cursors.

### Multi-Client Event Fanout

Risk: desktop UI, web UI, and CLI subscribe to the same session, and a slow client blocks scan progress or fills memory.

Required:

- bounded per-subscriber queues;
- event replay window with `after_seq`;
- slow client policy: drop progress snapshots, disconnect, or force polling;
- terminal events and errors are preserved.

Avoid:

- one unbounded broadcast queue;
- per-file WebSocket events;
- tying scan worker lifetime to a WebSocket connection.

### Query And Command Abuse Against Local Daemon

Risk: a compromised local client, browser session, extension, or remote user with a valid token repeatedly asks for expensive search/sort/top-file queries, huge page sizes, repeated rescans, or cleanup preflights until the daemon consumes CPU, memory, file handles, or disk IO.

Required:

- protocol has max page sizes, max concurrent sessions, max active queries, and query time budgets;
- expensive queries are cancellable and associated with client/session identity;
- search/filter syntax has bounded cost and avoids untrusted backtracking regex;
- local tokens still get rate limits because local does not mean trusted;
- server exposes overload/backpressure states so Flutter can switch to polling or narrow the query.

Architecture placement:

- protocol limits: `clean_disk_protocol`;
- resource governance and query scheduler: `clean-disk-server` application layer;
- index/search implementation: `fs_usage_engine`;
- UI recovery states: Flutter data/presentation.

Avoid:

- accepting arbitrary page sizes or unbounded search;
- using one global task pool where query load blocks cleanup cancellation;
- logging raw abusive query text while diagnosing overload.

### Cancellation, Pause, And Dispose Semantics Diverge

Risk: UI labels a session as paused/cancelled/disposed while the scanner backend keeps walking, a query keeps indexing, or cleanup preflight still holds resources. Different clients can then disagree about whether a session exists or whether resources are still in use.

Required:

- lifecycle states distinguish `cancel_requested`, `cancelling`, `cancelled`, `completed`, `failed`, `disposed`, and `unknown_after_disconnect`;
- backend capability says whether cancellation is immediate, cooperative, or unsupported;
- closing a browser tab or desktop window does not imply scan cancellation unless the user sent a command;
- dispose releases read-model/index resources only after active operations reach a safe terminal state;
- UI copy does not promise pause/resume unless the backend and resource scheduler actually support it.

Architecture placement:

- lifecycle state machine: `fs_usage_core` and `fs_usage_engine`;
- scanner/query worker coordination: `fs_usage_engine`;
- protocol commands/events: `clean_disk_protocol`;
- Flutter stores and button states: presentation/application boundary.

Avoid:

- one boolean `is_cancelled`;
- treating WebSocket disconnect as cancel;
- freeing session resources while slow backend work still owns handles.

### UI-Shaped Library API

Risk: `fs_usage_*` starts exposing Clean Disk UI concepts such as row color, badge labels, panel sections, or localized text.

Required:

- reusable library exposes facts, capabilities, reasons, and structured warnings;
- Clean Disk protocol maps those facts for clients;
- Flutter owns labels, icons, layout state, and visual priority;
- boundary tests prevent Clean Disk protocol imports in reusable crates.

Avoid:

- `displayLabel`, `rowColor`, `cleanupBadge`, or localized strings in `fs_usage_core`;
- designing reusable APIs around one screen layout;
- putting recommendation copy inside scanner library.

### Async Runtime Coupling

Risk: reusable crates require one async runtime or leak `tokio` into core types.

Required:

- `fs_usage_core` stays sync and runtime-free;
- runtime-specific code lives in `fs_usage_engine` jobs or host adapters;
- blocking filesystem scan is isolated behind worker boundaries;
- thread pool and CPU/IO budgets are configurable.

Avoid:

- value objects that require async constructors;
- public core types containing channels, task handles, or runtime-specific errors;
- mixing Rayon and Tokio without resource budget rules.

### Persistence And Migration Drift

Risk: scan history, receipts, settings, and protocol DTOs evolve separately and become incompatible.

Required:

- persisted data has its own schema version;
- protocol DTOs are not persistence models;
- migration tests cover old fixtures;
- scan history records scanner backend, pdu version, size mode, hardlink mode, and capability set.

Avoid:

- storing pdu JSON as durable scan cache;
- storing Flutter view state as domain history;
- comparing historical scans without scanner/config metadata.

### Scanner Backend Semantic Drift

Risk: `pdu`, future scanner adapters, or platform APIs change behavior without changing our domain contract: hardlink counting, allocated-size mode, skipped paths, traversal filters, progress frequency, cancellation support, root symlink handling, mount-boundary behavior, or error mapping.

Required:

- `fs_usage_engine` defines semantic contracts independent of each backend;
- every scanner adapter reports backend name, backend version, feature/capability set, and effective scan policy;
- shared adapter contract tests run against fake and real adapters where practical;
- benchmark results separate raw backend scan time from metadata enrichment, indexing, and protocol mapping;
- backend upgrades require golden fixture comparison for totals, skipped paths, hardlinks, symlinks, and errors.

Architecture placement:

- backend port and semantic contract: `fs_usage_engine`;
- pdu adapter mapping: `fs_usage_pdu`;
- capability/version reporting: `fs_usage_core` and protocol;
- test fixtures/benchmarks: Rust fixture lab.

Avoid:

- treating pdu's current tree shape as our public library model;
- persisting backend-specific raw output as durable state;
- changing user-visible accounting semantics silently after dependency updates.

### Platform Privilege Escalation

Risk: user asks for admin/root scan or system-protected folders, and daemon gains broad permissions without a clear boundary.

Required:

- privileged mode is explicit and separate from normal local daemon;
- UI explains elevated scope before launch;
- server records elevated capability;
- destructive commands remain separately confirmed.

Avoid:

- silently relaunching the daemon with elevated privileges;
- reusing elevated daemon for ordinary app sessions;
- broad allowed roots after one elevated scan.

### Encrypted And Locked Storage States

Risk: BitLocker-protected drives, EFS files, FileVault-protected user data, locked fscrypt directories, removable encrypted volumes, or enterprise key policies make parts of a scan unavailable even when the mount point exists.

Required:

- encrypted/locked/unavailable storage is represented as a capability or warning state, not collapsed into generic permission denied;
- headless/remote mode must not assume an interactive unlock prompt is possible;
- scan results distinguish locked root, locked subtree, encrypted metadata unavailable, and ordinary access denied;
- cleanup never retries destructive actions against a locked target without fresh user authorization;
- diagnostics can show encryption category without exposing private path names.

Architecture placement:

- storage protection facts: `fs_usage_core`;
- platform detection: `fs_usage_platform`;
- scan error classification: `fs_usage_engine`;
- protocol warnings and UI guidance: `clean_disk_protocol` and Flutter.

Avoid:

- repeated OS unlock prompts during recursive scan;
- treating locked encrypted folders as empty folders;
- persisting sensitive key/error details in scan history or support bundles.

### Network Filesystem Coherency And Stale Handles

Risk: SMB, NFS, NAS, corporate shares, and FUSE-over-network mounts can have stale handles, server-side renames, advisory or mandatory locks, oplocks/leases, high latency, inconsistent free-space reporting, and watcher gaps.

Required:

- mount kind and network/local confidence are part of volume facts where detectable;
- stale handles, timeout, server disconnect, and lease/oplock conflicts are classified separately;
- network targets use bounded retry/backoff and lower cleanup recommendation confidence;
- watcher/incremental mode treats network filesystem events as hints only;
- cleanup confirmations call out remote propagation and restore uncertainty.

Architecture placement:

- volume/mount facts: `fs_usage_platform`;
- retry and scan state model: `fs_usage_engine`;
- cleanup confidence: `fs_usage_cleanup` and `fs_usage_accounting`;
- UI warnings: Flutter details and cleanup workflow.

Avoid:

- aggressive parallel traversal against fragile network shares by default;
- assuming local inode/device identity semantics on every network filesystem;
- claiming exact reclaim/free-space effect on server-managed storage.

### Security-Scoped Bookmark Lifetime

Risk: macOS sandboxed builds persist folder access incorrectly, leak security-scoped access resources, or lose access after restart.

Required:

- bookmarked roots are stored with explicit scope and versioned metadata;
- `startAccessingSecurityScopedResource` and stop/release are balanced;
- stale bookmark resolution is handled as a permission state;
- access grants are tied to user-selected roots, not inferred paths;
- non-sandboxed and sandboxed builds have separate capability behavior.

Architecture placement:

- macOS permission adapter: `fs_usage_platform`;
- persisted root grants: Clean Disk local state;
- UI permission recovery: Flutter app shell.

Avoid:

- storing raw paths as persistent permission grants;
- keeping security-scoped access open for whole app lifetime without accounting;
- assuming a bookmark from one build/profile works in another.

### Sleep, Resume, And Volume Removal

Risk: laptop sleeps, external drive is unplugged, network mount drops, or volume identity changes while scan or cleanup is in progress.

Required:

- scan session has explicit interrupted/lost-target states;
- cleanup revalidation detects missing or changed volume identity;
- event stream reports interruption separately from cancellation and failure;
- UI can resume, restart, or discard stale session intentionally;
- benchmarks and tests include removable/slow target behavior where practical.

Architecture placement:

- lifecycle states: `fs_usage_core`;
- scan worker/session coordination: `fs_usage_engine`;
- volume identity: `fs_usage_platform`;
- UI recovery flow: Flutter.

Avoid:

- retry loops that keep a removed drive busy;
- treating missing volume as successful empty scan;
- letting cleanup continue after target volume changed.

### Watcher Overflow And Incremental Rescan Drift

Risk: future incremental scan/watch mode trusts filesystem events after FSEvents coalescing, dropped events, inotify queue overflow, rename storms, editor atomic-save patterns, or network filesystem watcher gaps.

Required:

- watcher events are invalidation hints, not source of truth;
- overflow/coalesced/drop flags trigger subtree or full rescan;
- snapshot epoch changes after any recovery rescan;
- persisted watcher cursor includes backend type and root identity;
- UI can mark cached scan data as stale.

Architecture placement:

- watcher ports and stale-state model: `fs_usage_engine`;
- platform watchers: future `fs_usage_platform` or dedicated adapter crate;
- cache invalidation: read-model/session layer;
- UI stale badges: Flutter.

Avoid:

- updating totals only from individual file events forever;
- trusting rename events without identity recheck;
- keeping cleanup candidates valid after watcher overflow.

### Internal Cache And Index Disk Pressure

Risk: Clean Disk writes scan history, read-model snapshots, logs, thumbnails, support bundles, or caches while the user's disk is already nearly full.

Required:

- default active scan indexes stay in memory unless persistence is explicitly needed;
- persistent cache has size limits, TTL, and emergency cleanup;
- low-disk-space mode reduces logging/support bundle size;
- support bundle creation checks available space before writing;
- app reports when its own storage contributes meaningful disk usage.

Architecture placement:

- cache policy: Clean Disk local state package/crate;
- active read model: `fs_usage_engine`;
- low-space checks: `fs_usage_platform`;
- UI storage settings: Flutter.

Avoid:

- persisting full scan trees by default;
- writing large debug artifacts during low-space scans;
- hiding Clean Disk's own cache from cleanup candidates.

### Package And Bundle Directory Semantics

Risk: macOS `.app`, `.photoslibrary`, `.xcodeproj`, `.playground`, browser profiles, VM bundles, and some package formats are directories that users mentally treat as single files. Deleting or drilling into internals can be dangerous or confusing.

Required:

- platform/file-kind detection can mark package/bundle directories;
- default UI can display bundles as grouped nodes while still allowing expert expansion;
- cleanup recommendations treat package internals as protected unless a tool-specific rule owns them;
- delete candidate text makes bundle-level action clear.

Architecture placement:

- file-kind facts: `fs_usage_platform`;
- node metadata and warnings: `fs_usage_core`;
- recommendation rules: Clean Disk product layer or tool adapters;
- tree rendering: Flutter.

Avoid:

- recommending deletion inside `.app` or library bundles as ordinary folders;
- hiding a huge bundle completely from top lists;
- treating package directories the same on every platform.

### Archive And Compressed Container Introspection

Risk: future features may try to inspect `.zip`, `.tar`, `.7z`, app backups, VM archives, browser exports, or nested compressed containers as if they were normal directories. That can create Zip Slip/path traversal bugs, zip-bomb CPU/memory/disk pressure, misleading logical sizes, and cleanup recommendations that cannot be safely applied without extraction.

Required:

- default scan treats archives as files, not trees;
- archive contents require an explicit optional adapter with strict limits;
- archive adapters never extract files for metadata during the main scan;
- entry names are validated before any future extraction workflow;
- reported archive content size is separate from local reclaim size;
- nested archive depth, entry count, compressed size, and uncompressed size have hard caps.

Architecture placement:

- archive capability model: future optional `fs_usage_archive`;
- main scan policy: `fs_usage_engine`;
- protocol size semantics: `clean_disk_protocol`;
- UI labels and warnings: Flutter details/recommendation views.

Avoid:

- auto-expanding archives in the primary folder tree;
- recommending deletion of individual archive entries before an extraction/edit workflow exists;
- trusting archive entry paths or declared uncompressed sizes without bounded validation.

### OS Cleanup Tools Racing Or Disagreeing

Risk: Windows Storage Sense, macOS purgeable storage, Linux log rotation, Docker prune, package-manager cleanup, or enterprise policies clean files while Clean Disk is scanning, or disagree with our estimates.

Required:

- tool-managed cleanup adapters prefer official commands and dry-run/preflight where available;
- scan snapshot records that a path is managed by another cleanup authority when detectable;
- cleanup recommendations can become stale if an external cleaner runs;
- observed post-cleanup free-space delta is shown separately from estimate;
- UI avoids presenting OS-managed/purgeable data as ordinary user-owned junk.

Architecture placement:

- managed authority detection: tool-specific adapters and `fs_usage_platform`;
- stale state: `fs_usage_engine`;
- accounting confidence: `fs_usage_accounting`;
- UI workflow: Flutter cleanup/recommendation views.

Avoid:

- duplicating Storage Sense or Docker prune behavior through raw deletes;
- fighting OS cleanup by recreating caches/logs;
- hiding estimate mismatch after external cleanup.

### Native Package Mode Matrix

Risk: the same app behaves differently as DMG/ZIP, App Store sandbox, MSI/MSIX, portable EXE, Flatpak, Snap, AppImage, Homebrew, or distro package. Permission model, update path, daemon location, filesystem access, and user trust differ by package mode.

Required:

- package mode is explicit in runtime capabilities and diagnostics;
- unsupported package modes fail clearly before scan/cleanup;
- installer docs list expected filesystem, network, and background-process behavior;
- packaging tests include daemon launch, update, uninstall, and permission prompts;
- app data paths are package-mode aware.

Architecture placement:

- package capability detection: app shell and `clean-disk-server`;
- daemon launch/update policy: platform app adapters;
- diagnostics: Clean Disk host;
- local state paths: app composition/root config.

Avoid:

- assuming development launch paths match installed app paths;
- storing daemon/config under a package directory that may be read-only or translocated;
- shipping a confined Linux package that looks feature-complete but cannot scan real targets.

### Docker, WSL, And Tool Storage Reclaim Mismatch

Risk: Docker/WSL cleanup can remove guest-layer data while the host-visible disk image remains large, or a host scan shows a huge VHD/raw image without explaining which guest data caused it.

Required:

- distinguish host file size from guest filesystem usage;
- Docker/WSL recommendations use official tooling or clearly point to manual tool action;
- VHD/raw image compaction is a separate capability from deleting files inside it;
- scan UI can link a large virtual disk to tool-specific details when adapter support exists;
- receipts say whether host free space changed.

Architecture placement:

- tool adapters: Clean Disk product layer;
- virtual disk classification: `fs_usage_platform`;
- accounting confidence: `fs_usage_accounting`;
- UI explanation: Flutter details and recommendations.

Avoid:

- deleting `ext4.vhdx`, `Docker.raw`, or overlay internals as generic large files;
- claiming Docker prune will shrink host disk image in every environment;
- double-counting overlay layers as exclusive reclaim.

### Antivirus, EDR, And Indexer Interference

Risk: security software, Spotlight, Windows Search, backup tools, or enterprise EDR slows scans, locks files, quarantines binaries, or treats high-volume traversal as suspicious.

Required:

- scan performance diagnostics include lock/permission/slow-IO categories;
- code signing/notarization and installer reputation are part of release planning;
- scanner respects resource budgets and supports background mode;
- locked/in-use files are warnings, not generic failures;
- retry policy is bounded and observable.

Architecture placement:

- error taxonomy: `fs_usage_core`;
- scan policy and throttling: `fs_usage_engine`;
- platform packaging: Clean Disk release/installer docs;
- diagnostics: Clean Disk host.

Avoid:

- aggressive retries on locked files;
- treating antivirus slowdown as app hang with no progress state;
- unsigned daemon binaries in production distribution.

### Global Thread Pool And Embedded Library Side Effects

Risk: `fs_usage_*` as a public library changes global process state, global Rayon pools, logging, panic hooks, environment variables, or signal handlers in a host application.

Required:

- reusable library avoids global initialization by default;
- thread budgets are explicit config;
- logging/tracing is caller-controlled;
- panic and signal handling stay in `clean-disk-server`, not library crates;
- adapter docs state whether any dependency uses global resources.

Architecture placement:

- library config: `fs_usage_engine`;
- pdu/thread mapping: `fs_usage_pdu`;
- process hooks: `apps/clean_disk_server`;
- docs/examples: future public crate docs.

Avoid:

- initializing tracing/logging inside reusable crates;
- setting global Rayon thread pool implicitly;
- assuming Clean Disk is the only process embedding the engine.

### Error Taxonomy Drift

Risk: every backend returns different errors, making UI, protocol, tests, and recommendations inconsistent.

Required:

- stable domain/application error categories exist in `fs_usage_core`;
- adapter errors are mapped into stable reason codes plus optional debug details;
- protocol error codes are versioned and unknown-tolerant;
- UI logic uses reason codes, not text matching.

Architecture placement:

- reusable error taxonomy: `fs_usage_core`;
- adapter mapping: `fs_usage_pdu`, `fs_usage_platform`, `fs_usage_cleanup`;
- wire error DTOs: `clean_disk_protocol`;
- client fallback: Flutter data layer.

Avoid:

- exposing raw `std::io::ErrorKind` as the whole product reason;
- parsing human-readable error messages;
- adding backend-specific protocol fields without mapping.

### Multi-Tenant Or Embedded Server Usage

Risk: other users embed `fs_usage_*` in a service scanning multiple users, containers, or remote roots, and library assumptions leak data or share state across tenants.

Required:

- sessions are isolated by explicit owner/context passed by host if needed;
- no global mutable session registry in reusable crates;
- host owns authorization and allowed roots;
- path redaction hooks are available for host diagnostics;
- docs state which APIs are single-process local assumptions.

Architecture placement:

- session isolation primitives: `fs_usage_engine`;
- auth/tenant policy: host application, not reusable core;
- redaction hooks: Clean Disk host and future library extension points.

Avoid:

- global singleton engine;
- storing all sessions in static state;
- reusable library deciding tenant authorization.

## P2 Risks

### Public Crate Governance

Risk: publishing `fs_usage_*` before governance is ready creates ecosystem debt.

Required before public-stable:

- license policy;
- MSRV policy;
- semver and deprecation policy;
- feature policy;
- security/advisory policy;
- examples for scanner-only and full engine use;
- contract tests for adapter authors.
- public API review that classifies types as stable API, experimental API, adapter-only API, or internal;
- rustdoc examples that avoid destructive real-home scans.

Avoid:

- promising stable public API while Clean Disk flows are still changing;
- exposing internal module names as public surface;
- publishing app-specific naming.
- increasing MSRV or changing default features without treating it as a compatibility event.

### Feature Flag Sprawl

Risk: one crate grows many flags and untested combinations.

Required:

- prefer adapter crates over many flags;
- document supported feature combinations;
- CI tests the minimal and default dependency graph;
- dependencies are checked before adding or upgrading.
- feature flags are additive; enabling a feature must not silently change core scan/accounting semantics;
- separate experimental adapters from the stable default feature set.

Avoid:

- enabling CLI, JSON, platform, cleanup, server, and test helpers in one default feature set;
- optional dependencies that change core semantics.
- feature combinations that compile but report different meaning for the same API contract.

### Observability Privacy Leaks

Risk: logs, metrics, traces, crash reports, or support bundles expose private paths and queries.

Required:

- path/search/delete target redaction by default;
- low-cardinality metrics only;
- support bundle export review;
- no tokens or auth headers in logs;
- debug path logging requires explicit local opt-in.

Avoid:

- metrics labels with raw paths;
- panic reports that include full command payloads;
- storing full scan trees in support bundles.

### Installer And Auto-Update Split Brain

Risk: Flutter app, daemon binary, and protocol schema update at different times.

Required:

- installer updates app and daemon atomically where possible;
- startup validates daemon binary version;
- old daemon cleanup path exists;
- protocol mismatch UI is actionable.

Avoid:

- launching the first `clean-disk-server` found on PATH;
- hidden background daemon from an old install;
- auto-update while active cleanup operation is running.

### Test Environment False Confidence

Risk: fake filesystem tests pass, but real APFS, NTFS, SMB, cloud placeholders, or permission behavior fails.

Required:

- layered tests: pure domain, fake adapter, temp filesystem, platform fixtures, manual destructive matrix;
- destructive tests require explicit opt-in roots;
- benchmarks record filesystem and cache state.

Avoid:

- only testing with small temp directories;
- assuming POSIX fixtures cover Windows reparse points;
- running cleanup tests against real user folders.

### Documentation And Example Drift

Risk: public examples, architecture docs, protocol samples, and actual code diverge as the API evolves.

Required:

- examples compile in CI when public crates exist;
- protocol examples are generated or snapshot-tested;
- architecture decision changes update `START_HERE.md`;
- old examples are removed or versioned when API changes.

Avoid:

- docs that show path-only cleanup commands;
- README examples using unstable internal modules;
- protocol examples with numeric `u64` byte fields for web-facing JSON.

### Naming And Ecosystem Positioning

Risk: `fs_usage_*` names collide with existing crates, are too generic, or imply guarantees the library does not provide.

Required:

- final crate naming review before publication;
- README explains exact scope: filesystem usage inventory, not guaranteed free-space prediction;
- capability model is visible in docs;
- Clean Disk-specific names do not appear in reusable crate APIs.

Avoid:

- publishing `clean_disk_engine` as the reusable crate;
- names that imply exact reclaim on all filesystems;
- API names that hide "estimate" or "best effort" semantics.

## Architecture Guardrails To Carry Forward

```text
clean-disk-server and Flutter negotiate protocol and capabilities.
cleanup commands never trust path-only authority.
local daemon has ownership, random token, random port, and idle shutdown.
remote/headless mode has separate security defaults.
node ids are scan-snapshot scoped unless explicitly mapped to persistent identity.
query cursors include snapshot epoch and query fingerprint.
fs_usage_* exposes facts, capabilities, warnings, and reasons, not UI concepts.
protocol DTOs, persistence models, Flutter view state, and domain models stay separate.
scan history, receipts, logs, and support bundles are private data by default.
cloud placeholders are not hydrated by default.
path display is not path authority.
formatted UI text is not command data.
exact integers cross web/protocol boundaries as exact values, not lossy JSON numbers.
recursive delete is an adapter detail behind a delete plan, not an application API.
reusable crates avoid global process side effects.
package mode is a runtime capability, not an installer footnote.
virtual disk size, guest filesystem usage, and actual host free-space delta are separate facts.
OS/tool-managed cleanup uses official adapters before raw deletion.
quota, purgeable, reserved, and physical free space are separate measurements.
scanner backend semantics are tested against our contract, not trusted by dependency name.
sort/filter/traversal policy is explicit scan metadata.
```

## When To Revisit

Revisit this document before:

- implementing `clean-disk-server` process launch;
- adding the first `fs_usage_*` crate;
- adding cleanup/delete plan support;
- enabling remote/headless mode;
- publishing any `fs_usage_*` crate externally;
- adding persistent scan history;
- adding auto-update or installers.
