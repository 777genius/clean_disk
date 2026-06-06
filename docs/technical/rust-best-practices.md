# Rust Best Practices Research

Last updated: 2026-05-12.

This document records Rust-specific practices we should apply when the Clean Disk Rust daemon/workspace is added. It is guidance for implementation, not a dependency installation plan.

## Sources Reviewed

Primary and high-signal Rust sources:

- Rust API Guidelines, [Checklist](https://rust-lang.github.io/api-guidelines/checklist.html), [Documentation](https://rust-lang.github.io/api-guidelines/documentation.html), [Type safety](https://rust-lang.github.io/api-guidelines/type-safety.html), and [Dependability](https://rust-lang.github.io/api-guidelines/dependability.html).
- Rust Reference, [diagnostic attributes](https://doc.rust-lang.org/reference/attributes/diagnostics.html), including `#[must_use]`, `#[expect]`, and lint reasons, and [codegen attributes](https://doc.rust-lang.org/stable/reference/attributes/codegen.html), including `#[track_caller]`.
- Rust Book, [Packages and Crates](https://doc.rust-lang.org/book/ch07-01-packages-and-crates.html), [Modules and Privacy](https://doc.rust-lang.org/book/ch07-02-defining-modules-to-control-scope-and-privacy.html), and [Error Handling](https://doc.rust-lang.org/book/ch09-00-error-handling.html).
- Cargo Book, [Workspaces](https://doc.rust-lang.org/cargo/reference/workspaces.html), [Features](https://doc.rust-lang.org/cargo/reference/features.html), [Dependency Resolution](https://doc.rust-lang.org/cargo/reference/resolver.html), [Rust version](https://doc.rust-lang.org/cargo/reference/rust-version.html), [platform-specific dependencies](https://doc.rust-lang.org/cargo/reference/specifying-dependencies.html#platform-specific-dependencies), and [profiles](https://doc.rust-lang.org/cargo/reference/profiles.html).
- Rust Blog, [Change in Guidance on Committing Lockfiles](https://blog.rust-lang.org/2023/08/29/committing-lockfiles/).
- Rust standard library, [std::path::Path](https://doc.rust-lang.org/std/path/struct.Path.html), [std::ffi::OsStr](https://doc.rust-lang.org/std/ffi/struct.OsStr.html), and [std::error::Error](https://doc.rust-lang.org/std/error/trait.Error.html).
- Rust standard library, [`std::fs::metadata`](https://doc.rust-lang.org/std/fs/fn.metadata.html), [`std::fs::symlink_metadata`](https://doc.rust-lang.org/std/fs/fn.symlink_metadata.html), [`std::fs::canonicalize`](https://doc.rust-lang.org/std/fs/fn.canonicalize.html), [`std::fs::remove_dir_all`](https://doc.rust-lang.org/std/fs/fn.remove_dir_all.html), [`std::fs::read_dir`](https://doc.rust-lang.org/std/fs/fn.read_dir.html), [`std::fs::Metadata`](https://doc.rust-lang.org/std/fs/struct.Metadata.html), and [`std::fs::Permissions`](https://doc.rust-lang.org/std/fs/struct.Permissions.html).
- Rust standard library, [`std::io::Error`](https://doc.rust-lang.org/std/io/struct.Error.html), [`std::io::ErrorKind`](https://doc.rust-lang.org/std/io/enum.ErrorKind.html), [`Vec::try_reserve`](https://doc.rust-lang.org/std/vec/struct.Vec.html#method.try_reserve), [`HashMap::try_reserve`](https://doc.rust-lang.org/std/collections/struct.HashMap.html#method.try_reserve), and [`TryReserveError`](https://doc.rust-lang.org/std/collections/struct.TryReserveError.html).
- Rust standard library, [`std::panic::catch_unwind`](https://doc.rust-lang.org/std/panic/fn.catch_unwind.html) and [`std::panic::set_hook`](https://doc.rust-lang.org/std/panic/fn.set_hook.html).
- Rust standard library, [`std::sync::OnceLock`](https://doc.rust-lang.org/std/sync/struct.OnceLock.html) and [`std::sync::LazyLock`](https://doc.rust-lang.org/std/sync/struct.LazyLock.html).
- Rust standard library, [`std::sync::Mutex`](https://doc.rust-lang.org/std/sync/struct.Mutex.html), [`std::sync::RwLock`](https://doc.rust-lang.org/std/sync/struct.RwLock.html), and [poisoning](https://doc.rust-lang.org/std/sync/poison/index.html).
- Rust Async Book, [Blocking and cancellation](https://rust-lang.github.io/async-book/part-guide/more-async-await.html#blocking-and-cancellation).
- Tokio docs, [Channels](https://tokio.rs/tokio/tutorial/channels), [`mpsc::channel`](https://docs.rs/tokio/latest/tokio/sync/mpsc/fn.channel.html), [`broadcast`](https://docs.rs/tokio/latest/tokio/sync/broadcast/), [`watch`](https://docs.rs/tokio/latest/tokio/sync/watch/), [`Semaphore`](https://docs.rs/tokio/latest/tokio/sync/struct.Semaphore.html), [Shared state](https://tokio.rs/tokio/tutorial/shared-state), [select](https://docs.rs/tokio/latest/tokio/macro.select.html), [spawn_blocking](https://docs.rs/tokio/latest/tokio/task/fn.spawn_blocking.html), [`tokio::fs`](https://docs.rs/tokio/latest/tokio/fs/), [JoinHandle](https://docs.rs/tokio/latest/tokio/task/struct.JoinHandle.html), [Graceful Shutdown](https://tokio.rs/tokio/topics/shutdown), and [Tracing](https://tokio.rs/tokio/topics/tracing).
- Clippy docs, [Usage](https://doc.rust-lang.org/clippy/usage.html).
- Clippy lint docs, [`must_use_candidate`](https://rust-lang.github.io/rust-clippy/master/index.html#must_use_candidate), [`allow_attributes`](https://rust-lang.github.io/rust-clippy/master/index.html#allow_attributes), [`disallowed_methods`](https://rust-lang.github.io/rust-clippy/stable/index.html#disallowed_methods), and [`disallowed_types`](https://rust-lang.github.io/rust-clippy/stable/index.html#disallowed_types).
- Rustfmt docs, [Rustfmt](https://rust-lang.github.io/rustfmt/).
- Rustdoc Book, [documentation tests](https://doc.rust-lang.org/rustdoc/write-documentation/documentation-tests.html), and Rust API Guidelines, [Documentation](https://rust-lang.github.io/api-guidelines/documentation.html).
- RustSec, [Advisory Database](https://rustsec.org/).
- Rust Blog, [Announcing async fn and return-position impl Trait in traits](https://blog.rust-lang.org/2023/12/21/async-fn-rpit-in-traits/).
- Rust API Guidelines, [Future proofing](https://rust-lang.github.io/api-guidelines/future-proofing.html).
- Rust API Guidelines, [Interoperability](https://rust-lang.github.io/api-guidelines/interoperability.html).
- Rustonomicon, [Send and Sync](https://doc.rust-lang.org/nomicon/send-and-sync.html).
- Rust Design Patterns, [Builder](https://rust-unofficial.github.io/patterns/patterns/creational/builder.html), [Newtype](https://rust-unofficial.github.io/patterns/patterns/behavioural/newtype.html), [RAII Guards](https://rust-unofficial.github.io/patterns/patterns/behavioural/RAII.html), and [Strategy](https://rust-unofficial.github.io/patterns/patterns/behavioural/strategy.html).
- Firezone, [Sans-IO: The secret to effective Rust for network services](https://www.firezone.dev/blog/sans-io), and examples from Sans-IO Rust libraries such as [str0m](https://lib.rs/crates/str0m) and [sansio](https://docs.rs/sansio).
- The Rust Performance Book, [Introduction](https://nnethercote.github.io/perf-book/introduction.html), [Profiling](https://nnethercote.github.io/perf-book/profiling.html), [Heap allocations](https://nnethercote.github.io/perf-book/heap-allocations.html), and [Iterators](https://nnethercote.github.io/perf-book/iterators.html).
- Rayon, [parallel iterators](https://docs.rs/rayon/latest/rayon/iter/) and [`ThreadPoolBuilder`](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html).
- ArcSwap, [read-mostly Arc snapshots](https://docs.rs/arc-swap/latest/arc_swap/).
- bytes, [shared byte buffers](https://docs.rs/bytes/latest/bytes/struct.Bytes.html), and Rust std, [`Arc`](https://doc.rust-lang.org/std/sync/struct.Arc.html).
- parking_lot, [`Mutex`](https://amanieu.github.io/parking_lot/parking_lot/struct.Mutex.html) and [deadlock detection](https://docs.rs/parking_lot/latest/parking_lot/deadlock/index.html).
- camino, [UTF-8 path types](https://docs.rs/camino/latest/camino/).
- cargo-nextest, [home](https://www.nexte.st/), [running tests](https://nexte.st/docs/running/), and [repository configuration](https://nexte.st/docs/configuration/).
- cargo-xtask, [project-local Rust automation pattern](https://github.com/matklad/cargo-xtask).
- matklad, [Call Site Dependency Injection](https://matklad.github.io/2020/12/28/csdi.html).
- Julio Merino, [Rust traits and dependency injection](https://jmmv.dev/2022/04/rust-traits-and-dependency-injection.html).
- cap-std, [capability-based filesystem APIs](https://docs.rs/cap-std) and [Introducing cap-std](https://blog.sunfishcode.online/introducing-cap-std/), plus [openat](https://docs.rs/openat/latest/openat/) and [remove_dir_all](https://docs.rs/remove_dir_all) as references for race-aware filesystem operations.
- Tokio docs, [JoinSet](https://docs.rs/tokio/latest/tokio/task/struct.JoinSet.html), [TaskTracker](https://docs.rs/tokio-util/latest/tokio_util/task/task_tracker/struct.TaskTracker.html), and [Channels](https://tokio.rs/tokio/tutorial/channels).
- Proptest, [Introduction](https://proptest-rs.github.io/proptest/intro.html), [`Config::failure_persistence`](https://docs.rs/proptest/latest/proptest/test_runner/struct.Config.html), and Loom, [concurrency permutation testing](https://docs.rs/loom/latest/loom/).
- Rust compiler internals, [`newtype_index`](https://doc.rust-lang.org/nightly/nightly-rustc/rustc_index/macro.newtype_index.html) and `IndexVec` pattern.
- Candidate arena/index crates: [indextree](https://docs.rs/indextree), [slotmap](https://docs.rs/slotmap), [genarena](https://docs.rs/genarena), and [index_type](https://docs.rs/index_type).
- Cargo Book, [SemVer Compatibility](https://doc.rust-lang.org/cargo/reference/semver.html), and Rust Project Goals, [`cargo-semver-checks`](https://rust-lang.github.io/rust-project-goals/2024h2/cargo-semver-checks.html).
- Cargo Book, [minimal versions and direct-minimal-versions](https://doc.rust-lang.org/cargo/reference/unstable.html#minimal-versions).
- Insta, [snapshot testing](https://insta.rs/docs/) and [redactions](https://insta.rs/docs/redactions/).
- Comprehensive Rust, [`thiserror` and `anyhow`](https://comprehensive-rust.pages.dev/error-handling/thiserror-and-anyhow.html).
- cargo-deny, [checks for advisories, licenses, bans, and sources](https://docs.rs/cargo-deny).
- cargo-vet, [how it works](https://mozilla.github.io/cargo-vet/how-it-works.html), [setup](https://mozilla.github.io/cargo-vet/setup.html), and [importing audits](https://mozilla.github.io/cargo-vet/importing-audits.html).
- cargo-auditable, [embedding dependency information in binaries](https://docs.rs/auditable/latest/auditable/).
- Cargo Book, [Build Scripts](https://doc.rust-lang.org/cargo/reference/build-scripts.html), and Rust Reference, [Procedural Macros](https://doc.rust-lang.org/reference/procedural-macros.html).
- Rust Fuzz Book, [Introduction](https://rust-fuzz.github.io/book/), and Testing Handbook, [cargo-fuzz](https://appsec.guide/docs/fuzzing/rust/cargo-fuzz/).
- Miri, [Undefined Behavior detection for Rust](https://rust.googlesource.com/miri/).
- Criterion.rs, [documentation](https://bheisler.github.io/criterion.rs/book/) and [crate docs](https://docs.rs/criterion).
- Serde, [attributes](https://serde.rs/attributes.html), [field attributes](https://serde.rs/field-attrs.html), [enum representations](https://serde.rs/enum-representations.html), and [`flatten`](https://serde.rs/attr-flatten.html).
- serde_path_to_error, [deserialization error paths](https://docs.rs/serde_path_to_error/latest/serde_path_to_error/).
- Rust std collections, [`HashMap`](https://doc.rust-lang.org/std/collections/struct.HashMap.html), [`BTreeMap`](https://doc.rust-lang.org/std/collections/btree_map/struct.BTreeMap.html), and [collection ordering notes](https://doc.rust-lang.org/std/collections/index.html).
- Binary serialization candidates: [bincode](https://docs.rs/crate/bincode/2.0.0), [postcard](https://docs.rs/postcard), and [rkyv validation](https://rkyv.org/validation.html).
- secrecy, [secret value wrapper](https://docs.rs/secrecy/latest/secrecy/), and subtle, [constant-time utilities](https://docs.rs/subtle/latest/subtle/).
- Rust Edition Guide 2024, [unsafe attributes](https://doc.rust-lang.org/stable/edition-guide/rust-2024/unsafe-attributes.html) and [Cargo resolver](https://doc.rust-lang.org/beta/edition-guide/rust-2024/cargo-resolver.html).
- Rust Reference, [external blocks](https://doc.rust-lang.org/reference/items/external-blocks.html).
- Cargo Book, [workspace lints](https://doc.rust-lang.org/cargo/reference/workspaces.html#the-lints-table), and Clippy, [configuration](https://doc.rust-lang.org/clippy/configuration.html).
- cargo-mutants, [home](https://mutants.rs/), [how it works](https://mutants.rs/how-it-works.html), [controlling runs](https://mutants.rs/controlling.html), and [limitations](https://mutants.rs/limitations.html).
- Rust Project Primer, [Mutation Testing](https://rustprojectprimer.com/testing/mutations.html) and [Unused Dependencies](https://rustprojectprimer.com/checks/unused.html).
- cargo-machete, [docs](https://docs.rs/crate/cargo-machete/latest), and cargo-udeps, [docs](https://docs.rs/crate/cargo-udeps/0.1.59).
- Cargo Book, [build timings](https://doc.rust-lang.org/cargo/reference/timings.html), [build cache](https://doc.rust-lang.org/cargo/reference/build-cache.html), and sccache, [Rust support](https://github.com/mozilla/sccache/blob/main/docs/Rust.md).
- cargo-hakari, [docs](https://docs.rs/cargo-hakari).
- Advanced Rust testing, [Mocks](https://rust-exercises.com/advanced-testing/03_mocks/00_intro.html), and Julio Merino, [Rust traits and dependency injection](https://jmmv.dev/2022/04/rust-traits-and-dependency-injection.html).
- tracing-subscriber, [EnvFilter](https://docs.rs/tracing-subscriber/latest/tracing_subscriber/filter/struct.EnvFilter.html), and tracing, [`#[instrument]`](https://docs.rs/tracing/latest/tracing/attr.instrument.html).
- trybuild, [compile-fail tests](https://docs.rs/trybuild/latest/trybuild/).
- file-id, [cross-platform file identifiers](https://docs.rs/file-id), Rust std, [Unix MetadataExt](https://doc.rust-lang.org/std/os/unix/fs/trait.MetadataExt.html), and Rust std, [Windows MetadataExt](https://doc.rust-lang.org/std/os/windows/fs/trait.MetadataExt.html).
- GNU Coreutils, [`du` invocation](https://www.gnu.org/software/coreutils/manual/html_node/du-invocation.html), especially apparent size and hard-link counting behavior.
- Filesystem traversal candidates: [walkdir](https://docs.rs/walkdir/latest/walkdir/), especially [`WalkDir::max_open`](https://docs.rs/walkdir/latest/walkdir/struct.WalkDir.html#method.max_open), [jwalk](https://docs.rs/jwalk/latest/jwalk/), and [ignore](https://docs.rs/ignore/latest/ignore/), especially [`WalkBuilder`](https://docs.rs/ignore/latest/ignore/struct.WalkBuilder.html).
- Filesystem change references: [notify](https://docs.rs/notify), Apple [File System Events](https://developer.apple.com/documentation/coreservices/file_system_events), Apple [`kFSEventStreamEventFlagMustScanSubDirs`](https://developer.apple.com/documentation/coreservices/1455361-fseventstreameventflags/kfseventstreameventflagmustscansubdirs/), and Microsoft [Change Journal Records](https://learn.microsoft.com/en-us/windows/win32/fileio/change-journal-records).
- Disk/free-space references: [fs2](https://docs.rs/fs2/latest/fs2/), [sysinfo Disk](https://docs.rs/sysinfo/latest/sysinfo/struct.Disk.html), [nix Statvfs](https://docs.rs/nix/latest/nix/sys/statvfs/struct.Statvfs.html), and Microsoft [`GetDiskFreeSpaceExW`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getdiskfreespaceexw).
- Filesystem naming references: Microsoft [case sensitivity](https://learn.microsoft.com/en-us/windows/wsl/case-sensitivity), Apple [APFS FAQ](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/APFS_Guide/FAQ/FAQ.html), and Apple [Files and directories](https://developer.apple.com/documentation/technologyoverviews/files-and-directories).
- APFS references: Apple [About Apple File System](https://developer.apple.com/documentation/foundation/file_system/about_apple_file_system), Apple [APFS snapshots in Disk Utility](https://support.apple.com/guide/disk-utility/view-apfs-snapshots-dskuf82354dc/mac), and Apple [`volumeSupportsSparseFiles`](https://developer.apple.com/documentation/foundation/urlresourcevalues/volumesupportssparsefiles).
- Rust std, [`BinaryHeap`](https://doc.rust-lang.org/std/collections/struct.BinaryHeap.html), for bounded top-K style indexes.
- Platform deletion/trash references: [trash crate](https://docs.rs/trash/latest/trash/) and [FreeDesktop Trash Specification](https://specifications.freedesktop.org/trash/latest/).
- Platform access references: Apple, [Accessing files from the macOS App Sandbox](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox), Apple, [Security-scoped resource access](https://developer.apple.com/documentation/Foundation/URL/startAccessingSecurityScopedResource%28%29), and Apple Platform Security, [controlling app access to files](https://support.apple.com/guide/security/controlling-app-access-to-files-secddd1d86a6/web).
- Windows filesystem references: Microsoft Learn, [Reparse Points](https://learn.microsoft.com/en-us/windows/win32/fileio/reparse-points), and Rust std, [Windows FileTypeExt](https://doc.rust-lang.org/std/os/windows/fs/trait.FileTypeExt.html).
- Windows path and stream references: Microsoft Learn, [Maximum Path Length Limitation](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation), [Naming Files, Paths, and Namespaces](https://learn.microsoft.com/en-us/windows/win32/fileio/naming-a-file), [File Streams](https://learn.microsoft.com/en-us/windows/win32/fileio/file-streams), [`FindFirstStreamW`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-findfirststreamw), and [`GetCompressedFileSize`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getcompressedfilesizew).
- macOS bundle/package references: Apple, [About Bundles](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/AboutBundles/AboutBundles.html), Apple, [Bundle](https://developer.apple.com/documentation/foundation/bundle), Apple, [Placing content in a bundle](https://developer.apple.com/documentation/bundleresources/placing-content-in-a-bundle), and Apple, [Caches directory](https://developer.apple.com/documentation/foundation/url/3988453-cachesdirectory).
- Metadata/xattr references: [filetime](https://docs.rs/filetime), [xattr](https://docs.rs/xattr/latest/xattr/), [xattrs](https://docs.rs/xattrs/latest/xattrs/), and Apple, [`mayHaveExtendedAttributes`](https://developer.apple.com/documentation/foundation/urlresourcevalues/mayhaveextendedattributes).
- Directory classification references: [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/), [dirs crate](https://docs.rs/dirs/latest/dirs/), [directories crate](https://docs.rs/directories/latest/directories/), and Apple, [macOS Library directory details](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/MacOSXDirectories/MacOSXDirectories.html).
- Privacy/logging references: OWASP, [Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html), OWASP, [Poor Logging Practice](https://owasp.org/www-community/vulnerabilities/Poor_Logging_Practice), and NIST SP 800-122, [Guide to Protecting PII](https://www.nist.gov/publications/guide-protecting-confidentiality-personally-identifiable-information-pii).
- tempfile, [temporary files and directories](https://docs.rs/tempfile/latest/tempfile/) and [`NamedTempFile::persist`](https://docs.rs/tempfile/latest/tempfile/struct.NamedTempFile.html#method.persist), [atomic-write-file](https://docs.rs/atomic-write-file/latest/atomic_write_file/), and assert_fs, [filesystem fixtures and assertions](https://docs.rs/assert_fs).
- Browser/local API security references: OWASP, [CSRF Prevention Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html), OWASP, [REST Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html), and MDN, [CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS).
- axum, [State extractor](https://docs.rs/axum/latest/axum/extract/struct.State.html), [middleware](https://docs.rs/axum/latest/axum/middleware/), [DefaultBodyLimit](https://docs.rs/axum/latest/axum/extract/struct.DefaultBodyLimit.html), and [graceful shutdown](https://docs.rs/axum/latest/axum/serve/struct.WithGracefulShutdown.html).
- Axum/Tungstenite WebSocket references: axum [`WebSocket`](https://docs.rs/axum/latest/axum/extract/ws/struct.WebSocket.html), axum [`Message`](https://docs.rs/axum/latest/axum/extract/ws/enum.Message.html), and tungstenite [`WebSocketConfig`](https://docs.rs/tungstenite/latest/tungstenite/protocol/struct.WebSocketConfig.html).
- Local IPC and single-instance references: Tokio [`net`](https://docs.rs/tokio/latest/tokio/net/index.html), Tokio Windows [`named_pipe::ServerOptions`](https://docs.rs/tokio/latest/tokio/net/windows/named_pipe/struct.ServerOptions.html), [interprocess local sockets](https://docs.rs/interprocess/latest/interprocess/local_socket/index.html), and [fs4 file locking](https://docs.rs/fs4/latest/fs4/fs_std/trait.FileExt.html).
- tower-http, [request body limit middleware](https://docs.rs/tower-http/latest/tower_http/limit/) and [timeout middleware](https://docs.rs/tower-http/latest/tower_http/timeout/).
- Tower, [ServiceBuilder](https://tower-rs.github.io/tower/tower/struct.ServiceBuilder.html).
- OpenAPI candidates for Rust HTTP contracts: [utoipa](https://docs.rs/utoipa/latest/utoipa/) and [aide](https://docs.rs/aide/latest/aide/axum/struct.ApiRouter.html).
- Crossbeam candidates, [channels](https://docs.rs/crossbeam/latest/crossbeam/channel/) and [work-stealing deques](https://docs.rs/crossbeam/latest/crossbeam/deque/).
- Human diagnostic report candidates: [miette](https://docs.rs/miette/latest/miette/trait.Diagnostic.html), [eyre](https://docs.rs/eyre/latest/eyre/), and [color-eyre](https://docs.rs/color-eyre/latest/color_eyre/).
- public-api, [public API listing and diffing](https://docs.rs/public-api/latest/public_api/), and cargo-public-api, [CLI](https://github.com/cargo-public-api/cargo-public-api).

## Core Rust Rules For Clean Disk

### Public APIs Must Be Small And Typed

Rust API Guidelines strongly favor meaningful types, common trait implementations, private fields, sealed traits when external implementations would be unsafe for evolution, and stable public dependencies.

Clean Disk rules:

- Crate roots should re-export only stable public types.
- Keep struct fields private unless they are pure immutable DTOs in `shared/protocol`.
- Use constructors/smart constructors for domain and application types with invariants.
- Use `From`, `TryFrom`, `AsRef`, and `Borrow` where they express real conversions.
- Implement common traits where useful: `Debug`, `Clone`, `Eq`, `Hash`, `Ord`, `Display`.
- Use `#[non_exhaustive]` or private fields for public types that may need future extension.
- Do not expose `pdu`, `axum`, WebSocket, Tokio task, or platform Trash types from domain/application crate public APIs.

### Public API Review Is A Required Step

Rust API Guidelines are practical checklists, not ceremony. They are especially useful for `shared/protocol`, CLI output models, and any crate that may later become a reusable SDK.

Clean Disk API review checklist:

- Public type names follow Rust conventions and domain language.
- Arguments carry meaning through types, not unclear `bool` or generic `Option` flags.
- Public structs have private fields unless they are deliberate immutable DTOs.
- Public enums that may grow use `#[non_exhaustive]` from the beginning.
- Public types implement `Debug`; many value types should also implement `Clone`, `Eq`, `Hash`, `Ord`, or `Display` when meaningful.
- Constructors validate invariants before the value exists.
- Public functions document errors, panics, and safety constraints where relevant.
- Destructors must not fail and must not perform long blocking work. If cleanup can fail or block, expose an explicit method.
- Traits are sealed when downstream implementations would make future evolution unsafe.
- Public APIs do not leak unstable dependency types unless that dependency is intentionally part of the contract.

Practical default: every public protocol DTO and public application port gets an API review before being treated as stable.

### Important Return Values Should Be `#[must_use]`

Rust's `#[must_use]` attribute can mark functions, composite types, and traits so ignoring the returned value produces a diagnostic. This is useful for APIs where "fire and forget" would silently drop a safety decision.

Clean Disk rules:

- Add `#[must_use]` to safety-critical values such as `DeletePlan`, `ConfirmationToken`, validated path identities, query cursors, and builder/config values whose result must be consumed.
- Prefer a short `#[must_use = "..."]` message when the reason is not obvious.
- Use it on builder methods that return a modified builder by value, especially if ignoring the returned builder would lose scan/delete options.
- Do not add `#[must_use]` everywhere. The Clippy `must_use_candidate` lint is intentionally noisy and can produce many false positives.
- When intentionally discarding a must-use value, write `let _ = value;` so the discard is visible in review.
- Do not use `#[must_use]` as a replacement for typed errors, confirmations, or use-case-level delete validation.

### Modules Are Encapsulation Boundaries

Rust modules and crates should hide implementation details, not just mirror folders.

Clean Disk rules:

- Prefer `pub(crate)` and private modules by default.
- Public modules should express domain/use-case language.
- Adapter internals stay private behind application ports.
- Avoid "god prelude" exports. A tiny context prelude may be acceptable for tests or internal ergonomics, but not as a dumping ground.
- Use crate boundaries to make illegal dependencies hard to write.

### Use Newtypes And Enums Instead Of Primitive Obsession

Rust makes type-driven design cheap. This is one of the biggest wins over a looser daemon design.

Clean Disk rules:

- Use newtypes for `ScanSessionId`, `NodeId`, `DeletePlanId`, `ByteSize`, `ItemCount`, `SessionToken`, `ConfirmationToken`, and validated path wrappers.
- Use enums for lifecycle and mode choices: scan status, delete plan status, hardlink strategy, mount boundary behavior, delete mode, scan scope.
- Avoid APIs like `scan(path: String, recursive: bool, include_hidden: bool)`.
- Prefer typed option structs/builders when a command has several meaningful settings.
- Use `NonEmpty<T>` or equivalent when empty input is invalid.

### Paths Are Not Strings

Rust's `Path` and `OsStr` exist because OS paths are platform-native values, not guaranteed UTF-8 strings. The standard library explicitly exposes `to_str()` as optional and `to_string_lossy()` as lossy.

Clean Disk rules:

- Domain/infrastructure path values should wrap `PathBuf`/`OsString` or a deliberate platform-aware representation, not plain `String`.
- Protocol/display can use strings, but must be treated as a representation, not the authoritative path identity.
- For UI, expose both exact identity/reference data and display-safe path text where needed.
- Do not use lossy path strings for delete identity or stale-data validation.
- Be explicit about invalid Unicode, long Windows paths, root/prefix handling, symlinks, and reparse points.

### UTF-8 Path Types Are For UTF-8 Boundaries

`camino` adds `Utf8Path` and `Utf8PathBuf`, which can be useful when a layer has already validated that paths are UTF-8. Clean Disk cannot assume real filesystem paths are UTF-8, especially when scanning arbitrary user directories.

Clean Disk rules:

- Use `Path`/`PathBuf`/`OsStr`/`OsString` for scanner, delete, Trash, identity, and platform adapters.
- Consider `camino` only for config files, generated project paths, tests, CLI fixtures, or protocol display helpers where UTF-8 is an explicit invariant.
- Do not convert real scanned paths to `Utf8PathBuf` before delete safety checks.
- Protocol display strings may be UTF-8, but they are not authoritative filesystem identity.
- If a path is invalid UTF-8, UI should still show a safe display representation and preserve enough identity for safe operations.

### Search And Display Need Case/Unicode Policy

Filesystems differ in case sensitivity and Unicode normalization behavior. Apple documents APFS as case-insensitive by default but configurable as case-sensitive, and Microsoft documents per-directory case-sensitivity behavior on Windows. Clean Disk search and display must be user-friendly without corrupting identity.

Clean Disk rules:

- Never use lowercased or normalized display paths as delete identity.
- Search can use a separate normalized text index, but results must point back to original node identity.
- Store original display name/path representation separately from search keys.
- Case-insensitive search should be a UI/query policy, not a filesystem identity rule.
- On Windows and macOS, assume case behavior can vary by volume or directory.
- Unicode normalization crates are candidates only for search/display indexes, not for authoritative filesystem paths.

### File Identity Is Not Just A Path

Clean Disk deletion safety depends on revalidating that the thing selected during scan is still the thing being moved to Trash. A path alone is not enough because another process can replace it between scan and delete.

Clean Disk rules:

- Capture a platform-aware scanned identity for delete candidates.
- On Unix-like systems, device ID plus inode is the usual stable identity for one machine at one time.
- On Windows, volume serial plus file index/file ID is the corresponding concept, but APIs vary by stability and availability.
- Treat size, modified time, file type, and path as supporting metadata, not as the full identity.
- Revalidate identity immediately before delete/trash.
- If identity cannot be collected for a path, downgrade the delete plan to a higher-friction confirmation or reject automated cleanup for that item.
- Candidate crates such as `file-id` or `same-file` are adapter candidates only. Verify versions, platform behavior, and edge cases before adopting.

### Metadata Flavor Must Match The Question

Rust's standard filesystem APIs make a critical distinction: `metadata` follows symlinks, while `symlink_metadata` inspects the link itself. `canonicalize` returns an absolute canonical path after resolving symlinks and normalizing intermediate components. Those are useful tools, but each answers a different product question.

Clean Disk rules:

- Scanner adapters must choose link metadata versus target metadata deliberately.
- If the UI row is a symlink, junction, or reparse point, the protocol must say whether the displayed size is for the link object, the target, or a skipped target.
- Do not `canonicalize` a user-selected path and then treat the resolved path as the user's delete intent.
- Keep original path/display path, resolved target information, and platform identity as separate fields.
- If following links is enabled later, record the policy in the scan result and protect against loops.
- Direct recursive removal APIs such as `remove_dir_all` are not the default cleanup mechanism. They belong only behind an explicit permanent-delete adapter, with identity revalidation and stronger confirmation.
- Tests need separate fixtures for file symlink, directory symlink, dangling symlink, hardlink, and, on Windows, reparse-point/junction behavior.

### Timestamps Are Weak Evidence

`Metadata::modified`, `accessed`, and `created` can be unavailable on some platforms or filesystems. Access time can be disabled or not updated, and timestamp precision differs across filesystems. This makes timestamps useful for display and heuristics, but unsafe as identity.

Clean Disk rules:

- Store timestamps as optional observed metadata, not required identity.
- Do not accept or reject a destructive action based only on path, size, and mtime.
- Use timestamps to enrich UI rows, stale hints, and "recently changed" warnings.
- If comparing scan-time and delete-time metadata, treat timestamp equality as supporting evidence only.
- Protocol DTOs should allow missing created/accessed/modified values without treating them as scan failure.
- Test fixtures should not depend on nanosecond precision unless the platform adapter explicitly guarantees it.

### Disk Usage Has Multiple Sizes

Clean Disk cannot treat "size" as one number. Rust `Metadata::len()` is apparent/logical length, while Unix `MetadataExt::blocks()` reports allocated blocks in 512-byte units. GNU `du` also distinguishes apparent size from disk usage and has explicit hard-link counting behavior.

Clean Disk rules:

- Model separate value objects for apparent bytes, allocated/on-disk bytes, and estimated reclaimable bytes.
- UI labels must say which size is being shown: size, size on disk, or estimated reclaim.
- On Unix-like systems, use allocated blocks where available for "size on disk"; on other platforms, use platform adapters rather than pretending `len()` is disk usage.
- Sparse, compressed, cloned, deduplicated, and hard-linked files can make apparent bytes very different from allocated bytes.
- Directory totals should record which accounting policy produced them: apparent, allocated, hardlink-deduplicated, one-file-system, or follow-links.
- Do not mix byte metrics in one aggregate without tagging the aggregate policy.

### Windows Streams And Allocated Size Need Explicit Support

NTFS supports multiple data streams per file. Microsoft documents that each stream has its own allocation size, actual size, valid data length, and compression/encryption/sparse state. `GetCompressedFileSize` reports actual bytes of disk storage used for compressed or sparse files, but stream enumeration is a separate concern.

Clean Disk rules:

- Treat Windows alternate data streams as a platform accounting capability, not as ordinary child files in the domain model.
- If a Windows adapter does not enumerate streams, protocol responses must expose that limitation as `stream_accounting: not_scanned` or equivalent.
- Do not claim exact Windows allocated totals unless the adapter's accounting policy includes compressed/sparse behavior and documents how alternate streams are handled.
- Do not show ADS names as normal path children without a distinct UI affordance. `file.txt:Zone.Identifier` is not the same kind of thing as `file.txt`.
- Do not recommend deleting alternate streams separately in the first cleanup UX. Treat stream cleanup as an advanced platform feature after explicit design.
- Tests need Windows fixtures for sparse/compressed files and at least one alternate stream if we support exact Windows accounting.

### Reclaimable Bytes Are An Estimate Until The Operation Finishes

The bytes shown before deletion are a planning estimate, not a guarantee. Hardlinks, snapshots, compression, APFS/Btrfs clone behavior, platform Trash behavior, and concurrently changing files can all make the real freed space differ.

Clean Disk rules:

- Name the metric `estimated_reclaimable_bytes` or equivalent in domain/protocol models.
- After moving to Trash, report actual operation result separately from the previous estimate.
- If the selected item has hardlinks or unclear allocation metadata, downgrade confidence in the reclaim estimate.
- Do not promise that moving to Trash immediately frees disk space. On many systems Trash still occupies disk until emptied.
- If the UI shows "Total to reclaim", pair it with wording/metadata that distinguishes queue estimate from actual free-space delta.
- Free-space delta, if measured, belongs to a post-operation platform adapter and can still be noisy.

### APFS Features Make Space Accounting Non-Obvious

Apple documents APFS features such as clones, snapshots, space sharing, fast directory sizing, and sparse files. These are great filesystem features, but they mean a disk cleanup UI must avoid simplistic "sum of file lengths equals space used" claims.

Clean Disk rules:

- Treat APFS clones, snapshots, sparse files, and space sharing as reclaim-estimate uncertainty factors.
- If APFS-specific metadata is unavailable, prefer honest generic labels over fake precision.
- Do not assume deleting one clone frees the apparent size of that file.
- Do not assume removing a file makes all referenced blocks immediately available if snapshots still reference them.
- Use platform adapters for APFS-specific capabilities; domain should store capability flags and confidence, not Apple API types.
- Tests should include sparse-file fixtures where supported.

### Volume Free Space Is A Platform Query

Free-space APIs differ by platform and by meaning. Windows `GetDiskFreeSpaceExW` distinguishes free bytes available to the caller from total free bytes. POSIX `statvfs` distinguishes free blocks from blocks available to unprivileged users. Rust crates such as `fs2` and `sysinfo` expose useful adapters, but Clean Disk needs typed semantics.

Clean Disk rules:

- Model capacity, total free, and user-available free as separate fields where the platform supports them.
- Associate free-space samples with a volume/mount identity and timestamp.
- Do not subtract queued reclaim estimates from free space and show that as guaranteed future free space.
- Re-sample free space after cleanup if the UI wants an actual before/after delta.
- Keep free-space APIs in platform/storage adapters, not domain entities.
- Candidate crates such as `fs2`, `sysinfo`, or `nix` must be checked for platform support and dependency weight before adoption.

### Platform Code Should Be Explicitly Isolated

Clean Disk will have platform-specific behavior for Trash, file identity, permissions, symlinks, mount boundaries, and installers. Cargo supports target-specific dependencies, and Rust modules can isolate `cfg` logic.

Clean Disk rules:

- Keep platform-specific code in adapter crates/modules such as `infrastructure/platform/macos`, `windows`, and `linux`.
- Prefer one platform facade with small `cfg`-selected modules over scattered `#[cfg(target_os = "...")]` across use cases.
- Use target-specific Cargo dependencies for OS-only crates instead of enabling every platform dependency everywhere.
- Keep domain/application crates platform-neutral unless the domain language itself needs a platform enum.
- Add compile checks for all supported targets in CI once Rust exists, even if full integration tests run only on native runners.
- Do not hide unsupported platform behavior behind silent no-ops. Return typed `UnsupportedPlatform` or capability errors.

### Permissions Are Not A Cross-Platform Boolean

Rust's `Permissions::readonly()` is intentionally limited. The standard docs warn that it does not account for ACLs, group membership, mounted read-only filesystems, root behavior, and Windows nuances. They also warn that `set_readonly(false)` on Unix is equivalent to granting write access to owner, group, and others.

Clean Disk rules:

- Do not infer "can delete" or "can write" from `Permissions::readonly()` alone.
- Store readonly/file-attribute hints separately from actual operation outcomes.
- Never "unlock" files by blindly calling `set_readonly(false)` in cleanup code.
- If a future UX offers permission remediation, implement OS-specific adapters with explicit preview, confirmation, and rollback expectations.
- Permission-denied scan/delete failures remain normal typed outcomes, not unexpected crashes.
- Tests should distinguish readonly attribute, Unix mode bits, ACL-like denial when practical, and read-only volume errors.

### Traversal Policy Is Product Behavior

Rust traversal crates expose important policy knobs. `walkdir` can limit open file descriptors, avoid crossing filesystems, and detect loops when following links. `jwalk` offers parallel traversal with streamed sorted entries. `ignore` adds filters and parallel walking. These are implementation candidates, but the product policy must come first.

Clean Disk rules:

- Treat follow symlinks, follow Windows reparse points, one-file-system, max depth, hidden files, package/cache exclusions, and thread count as scan options or fixed policy, not adapter accidents.
- Default to not following symlinks/reparse-point directories until the user explicitly chooses that behavior.
- If following links is supported, loop detection is mandatory.
- Keep mount-boundary behavior explicit; crossing volumes can make scans surprising and slow.
- Cap open file descriptors or choose a traversal adapter that does.
- Prefer scanner adapters that can stream progress and errors without requiring the entire traversal to finish.
- Do not let `.gitignore`-style filtering silently hide disk usage in a disk cleanup product unless the UI clearly says the scan is filtered.

### Directory Iteration Is Fallible And Unordered

Rust `read_dir` returns an iterator of `io::Result<DirEntry>`. New errors can appear after the iterator is created, and entry order is platform/filesystem dependent. For a disk usage scanner, this means traversal is not a simple "open once, everything is fine" operation.

Clean Disk rules:

- Treat per-entry iteration errors as skipped/failed entries, not as a reason to crash the whole scan.
- Directory open errors and entry read errors should be separate scan events because recovery and UI copy differ.
- Sorting for deterministic UI/tests must be explicit. Do not rely on filesystem iteration order.
- Do not collect an entire huge directory only to sort if the UI does not need sorted children immediately.
- If deterministic pagination is needed, sort only the requested child page or build a read-model index after aggregation.
- Drop directory iterators/handles promptly; scanner workers should not keep many directory handles alive longer than needed.
- Tests need unordered input fixtures so accidental reliance on OS order is caught.

### Traversal Adapter Defaults Must Be Audited

Traversal crates are optimized for common developer workflows, not automatically for disk usage products. `ignore::WalkBuilder` enables standard filters by default, including hidden files and ignore files. `walkdir` has explicit root symlink behavior and open-file limits. `jwalk` gives parallel traversal and sorted streaming, but still needs product-level policy mapping.

Clean Disk rules:

- Wrap every traversal crate behind a `ScannerTraversalAdapter` with an explicit `TraversalPolicy`.
- Record effective traversal policy in each scan result: links, root links, hidden entries, ignore files, mount boundary, max depth, thread count, open FD limit.
- Disable ignore/hidden filters by default for disk-usage scans unless the UI labels the scan as filtered.
- Root symlink behavior is its own option. A selected root that is a symlink needs a visible policy choice: scan link, scan target, or reject.
- Open file descriptor budget must be configurable or deliberately fixed by adapter tests.
- Parallel traversal thread count must be part of the scan worker budget, not independent unbounded concurrency.
- Keep adapter defaults under snapshot/unit tests so crate upgrades do not silently change product behavior.

### Cleanup Recommendations Need Explainable Rules

Clean Disk will show cleanup candidates, but "big folder named cache" is not a safe enough rule. OS conventions help: XDG defines a cache base directory for user-specific non-essential cached data, Apple has standard cache locations, and cross-platform helper crates expose user cache/config/data directories. Still, actual deletability depends on the app, location, permissions, and whether files are in use.

Clean Disk rules:

- Every recommendation should carry a rule id, evidence, safety level, confidence, and explanation.
- Use OS-known cache roots and app-known patterns as evidence, not as automatic delete authority.
- Separate "large item" from "safe cleanup candidate". Size alone is not a cleanup rule.
- Recommendations should point to inspectable nodes and let users drill into the tree before queuing.
- Keep recommendation rules in application/policy code, not hardcoded inside UI widgets or scanner adapters.
- Treat system folders, app bundles, package directories, development artifacts, and user documents with different safety classes.
- Re-run identity and metadata checks immediately before Trash even for "safe" recommendations.

### macOS File Access Is A UX Flow

On macOS, App Sandbox, security-scoped bookmarks, user-selected directories, and Full Disk Access can decide whether the scanner can see user data. Apple documentation explicitly says apps should handle failure cases when access is not granted.

Clean Disk rules:

- Permission denied is a first-class scan result, not a generic error.
- For sandboxed builds, model selected roots and security-scoped bookmarks as platform capabilities.
- Balance Full Disk Access with trust: explain why broad access is needed and still let users scan selected folders.
- Release security-scoped resources correctly. Leaking them can exhaust kernel resources.
- macOS packaging decisions affect scanner architecture, so the Rust adapter should not assume unrestricted home-directory access.
- UI should show skipped protected areas with a clear remediation path.

### Bundles And Packages Are UI Policy Views

Apple documents a package as a directory that Finder presents as if it were a single file, while a bundle is a standardized directory hierarchy for code and resources. For Clean Disk this means scanner truth and user presentation can differ.

Clean Disk rules:

- The scanner should still understand bundles/packages as directories in the filesystem.
- Presentation can collapse `.app`, `.framework`, `.plugin`, document packages, and similar directories when that matches user expectations.
- Any collapsed package row must make delete scope clear: deleting the row means moving the whole directory/package to Trash.
- Do not infer safety only from an extension. Some package-like directories are user documents; some are app/runtime assets.
- Search should be able to find package contents when the user expands or opts into package-content search.
- Protocol should include enough classification for UI display: normal directory, bundle/package-like directory, system protected, app data, cache candidate, unknown.

### Extended Attributes Are Metadata, Not Cleanup Targets By Default

macOS and Unix filesystems can store extended attributes, resource-fork related metadata, quarantine markers, tags, and other side metadata. Rust crates can expose xattrs on supported Unix platforms, but mutating them is not ordinary disk cleanup.

Clean Disk rules:

- Do not strip xattrs, quarantine flags, tags, or resource-fork-related metadata as a cleanup operation by default.
- If xattr information is collected, keep it in platform metadata/details, not domain identity.
- Treat xattr support as a platform adapter capability because crate support and semantics differ by OS.
- If an item's size accounting excludes or includes side metadata differently by platform, expose that as accounting-policy confidence.
- Future "remove quarantine/tag/xattr" features would be separate tools with explicit user intent, not part of free-space cleanup.

### Incremental Watchers Are Resync Hints

Cross-platform file watching is useful for refresh UX, but it is not a correctness foundation. The `notify` crate documents platform caveats and large-watch limits. Apple FSEvents can coalesce changes and explicitly signals that subdirectories must be rescanned. Windows USN records are per-volume change records and old records may be removed.

Clean Disk rules:

- Build initial correctness on explicit scans, not watchers.
- Treat watchers/journals as invalidation and refresh hints for already-scanned sessions.
- If an event stream reports overflow, coalescing, or "must scan subdirs", mark affected scan data stale and rescan the subtree or whole root.
- Do not promise realtime correctness from watcher APIs.
- Watcher events should never authorize cleanup. Delete still requires current identity revalidation.
- Keep future watcher/journal integration behind a platform adapter and a scan-session epoch model.

### Windows Reparse Points Need Classification

Windows reparse points include symlinks, junctions, mount points, and filesystem/filter-driver-specific behaviors. Treating them as ordinary directories can create loops, unexpected volume crossings, and misleading cleanup candidates.

Clean Disk rules:

- Classify Windows symlinks/reparse points in the platform filesystem adapter.
- Default scan behavior should not descend into directory reparse points unless policy allows it.
- Surface skipped reparse points as warnings/details, not silent omissions.
- Delete safety must distinguish deleting the link/reparse point from deleting its target.
- Tests need Windows-specific fixtures for symlink files, symlink dirs, junctions if available, and access-denied cases.
- Do not assume Unix symlink rules cover Windows behavior.

### Windows Path Length Is Packaging And Adapter Policy

Windows path behavior is not just a Rust `PathBuf` concern. Microsoft documents legacy `MAX_PATH` behavior, extended-length paths, and a `longPathAware` application manifest requirement. A disk scanner will hit long paths in package managers, node modules, game installs, build outputs, and user archives.

Clean Disk rules:

- Windows builds must deliberately opt into long path support when packaging the Rust daemon/application.
- Platform adapters should preserve `PathBuf`/`OsString` identity and avoid lossy path shortening.
- Verbatim or extended-length paths must not leak into user-facing labels unless no friendlier display form is available.
- Keep display path, original selected path, and operation path separate.
- Do not reject a path only because it is longer than classic `MAX_PATH`.
- Tests need long nested path fixtures on Windows CI once Rust scanning exists.
- If a shell/Finder/Explorer reveal operation cannot open a long path, report that as a UI/platform limitation, not scan corruption.

### Errors Should Encode Recovery Choices

Rust separates recoverable errors with `Result` from unrecoverable bugs with `panic!`. Server code should preserve that distinction.

Clean Disk rules:

- Domain/application errors should be typed enums with stable variants.
- Adapter errors should be mapped at the boundary into application/protocol errors.
- Use `Result<T, E>` for expected failure: permission denied, skipped path, missing file, stale metadata, Trash unsupported, cancelled scan.
- Use `panic!` only for programmer bugs or impossible states.
- Avoid `unwrap()` in daemon paths. `expect()` is acceptable only when it documents a real invariant and a panic is correct.
- Protocol errors should be structured and stable enough for UI behavior.

Practical dependency direction when we add crates:

- Libraries/domain/application: typed errors, likely `thiserror` if we choose an error derive crate.
- Binaries/composition/CLI: report-oriented errors can use a higher-level error wrapper if useful.
- Re-check latest crate versions before adding anything.

### I/O Error Mapping Should Preserve Kind And OS Context

`std::io::ErrorKind` is non-exhaustive, and `std::io::Error` can preserve a raw OS error code. Clean Disk should use those facts instead of string-matching localized OS messages or collapsing every scan failure into `Unknown`.

Clean Disk rules:

- Map expected `ErrorKind` values into typed scan/delete outcomes: permission denied, not found, not directory, read-only filesystem, filesystem loop, storage full, resource busy, unsupported, interrupted, timed out.
- Keep a wildcard branch for future `ErrorKind` variants.
- Preserve `raw_os_error()` inside diagnostics when available, but keep user-facing messages stable and localizable.
- Do not parse `Display` text from `io::Error` for control flow.
- Keep sensitive path context separate from the error itself so logs can redact paths without losing error category.
- For adapter tests, assert on typed outcomes and `ErrorKind`, not exact OS message strings.

### Panic Strategy Is A Release Policy

Cargo profiles let a binary choose whether panics unwind or abort. Rust's `catch_unwind` can catch only unwinding panics and the standard library explicitly says it should not be used as a general try/catch mechanism.

Clean Disk rules:

- Keep `panic = "unwind"` as the default unless we have a deliberate release-size or crash-policy reason to change it.
- Treat panics as bugs, not recoverable scan/delete errors.
- Supervise task panics and convert them into failed session state where the runtime can observe them.
- Do not wrap ordinary application use cases in `catch_unwind`.
- Use `catch_unwind` only at narrow boundaries where a panic must be isolated, for example an FFI/plugin boundary, and document why the boundary is unwind-safe.
- If we install a panic hook, install it in the server binary only. The hook is process-global, so libraries should not own it.
- Panic logs must not dump sensitive paths or huge payloads by default.
- Do not switch daemon releases to `panic = "abort"` until process restart behavior, crash reports, and unsaved session cleanup are explicit.

### Use `#[track_caller]` Only For Invariant Diagnostics

`#[track_caller]` propagates the caller location into panic diagnostics. It is useful for small assertion/invariant helpers, but it should not become normal error reporting.

Clean Disk rules:

- Consider `#[track_caller]` for internal invariant helpers such as `expect_valid_node_id`, `assert_session_state`, and test-only builders that panic on invalid setup.
- Do not use `#[track_caller]` on fallible public APIs that should return typed errors.
- Do not expose user-facing protocol diagnostics based on panic caller locations.
- Keep panics for programmer bugs. Filesystem errors, permission denied, stale identity, and cancelled scans return typed errors.
- Prefer plain typed validation for domain constructors; use caller tracking only when panic is the correct behavior.

### Cancellation Tokens Are Better Than Shared Flags

Tokio's shutdown guidance describes shutdown as three steps: decide when to stop, notify all work, and wait for tasks to finish. `CancellationToken` and `TaskTracker` are designed for this shape.

Clean Disk rules:

- Give every long-lived scan session an explicit cancellation handle.
- Prefer `CancellationToken`-style cooperative cancellation over scattered `AtomicBool` flags or ad-hoc broadcast channels.
- Use child/session tokens when global daemon shutdown should cancel all sessions but a user scan cancel should cancel only one session.
- Pair cancellation with task tracking. A cancelled session is not fully stopped until worker/index/event tasks have drained or reported failure.
- Blocking scanner adapters must periodically observe cancellation or run behind a worker boundary that can stop accepting output and mark the session cancelled.
- Do not rely on dropping a `JoinHandle`, WebSocket connection, or HTTP request future as the only cancellation mechanism.
- Cancellation is a normal lifecycle state, not an error panic.

### Process Shutdown Is A Composition-Root Responsibility

Tokio's shutdown guidance starts with deciding when shutdown begins, then notifying tasks, then waiting for them. That belongs to the server binary/composition root, not domain/application entities.

Clean Disk rules:

- The server binary owns OS signal handling such as Ctrl-C and platform service stop hooks.
- Application services expose shutdown/cancel operations but do not subscribe to OS signals directly.
- Shutdown states should be visible in the protocol: accepting, draining, cancelling sessions, stopped.
- WebSocket clients should receive a terminal event before the daemon closes the connection when graceful shutdown is possible.
- Local state writes and delete receipts should be flushed according to their durability class before process exit.
- Add a bounded shutdown timeout so the daemon does not hang forever on stuck scanner workers.
- SIGKILL/power loss cannot be made graceful; persisted session recovery should assume abrupt termination can happen.

### Async Code Must Respect Blocking, Cancellation, And Backpressure

Async Rust uses cooperative scheduling. Blocking work inside async tasks can stall unrelated tasks. Disk scanning is exactly the kind of workload where this matters.

Clean Disk rules:

- Do not run long blocking filesystem traversal directly inside async route handlers.
- If scanner integration is synchronous/blocking, isolate it in dedicated worker threads or carefully bounded blocking tasks.
- `spawn_blocking` is for blocking operations that finish. Tokio docs warn that long-lived blocking work should prefer dedicated threads.
- Bounded channels are required for scanner-to-indexer and event-publisher-to-client paths.
- Cancellation must be cooperative and explicit. Assume async code can stop at any `.await`.
- Do not hold locks across `.await`.
- For simple shared data with short critical sections, a sync mutex can be fine. For IO/state managers, prefer a task plus message passing.

### Tokio Fs Is Not A Scanner Shortcut

Tokio documents that portable filesystem operations are still ordinary blocking file operations behind the scenes. `tokio::fs` is useful for integrating occasional file IO into async services, but it does not turn a million-entry filesystem traversal into kernel-level nonblocking IO.

Clean Disk rules:

- Do not implement the scanner by issuing per-entry `tokio::fs::metadata` or `tokio::fs::read_dir` calls from route handlers.
- Use the scanner adapter's own traversal/runtime strategy, isolated behind bounded channels and session cancellation.
- Treat `tokio::fs` as suitable for small config/state reads and writes, not for the hot scan path unless profiling proves it.
- Keep the async HTTP/WebSocket runtime as the control plane. The scanner owns its own blocking/parallel IO budget.
- If a future adapter uses `tokio::fs`, document how it avoids saturating Tokio's blocking pool and how cancellation is observed.

### CPU-Bound Work Needs A Separate Budget

Tokio's `spawn_blocking` docs warn that CPU-bound work can overgrow the blocking pool unless concurrency is limited, and mention specialized CPU-bound executors such as Rayon. Clean Disk has both blocking filesystem IO and CPU-heavy post-processing such as sorting, aggregation, search indexing, and checksum-like future work.

Clean Disk rules:

- Treat async runtime threads as IO/control-plane capacity, not a general compute pool.
- Use `spawn_blocking` for bounded blocking work that eventually finishes.
- For many CPU-heavy operations, use a limited worker pool or a Rayon-style adapter after measuring contention.
- If pdu or the scanner adapter already uses parallelism, avoid stacking another full Rayon pool on top without a thread budget.
- Large sort/search/index rebuilds should have explicit concurrency limits and cancellation behavior.
- Do not run CPU-heavy loops directly inside async request handlers or WebSocket send loops.
- Do not add Rayon by default. Add it only when profiling shows CPU-bound parallel work that benefits from it.

### Resource Budgets Should Use Permits, Not Hope

Tokio `Semaphore` is a direct fit when many tasks may want a limited resource: scan sessions, expensive index rebuilds, open preview/stat jobs, or remote API calls in future server mode. This is different from a mutex: a semaphore limits concurrency without making one task own the data.

Clean Disk rules:

- Use explicit permits for bounded resources: concurrent scans, expensive background jobs, and optional remote/server operations.
- Prefer RAII permit ownership so cancelled tasks release capacity automatically when dropped.
- Keep resource limits visible in runtime config and protocol errors, for example `TooManyActiveScans`.
- Do not hide capacity rules inside random queue sizes.
- Do not use semaphores to protect mutable data. Use owned manager tasks, locks with short scopes, or immutable snapshots for state.
- Tests should cover permit release on cancellation, panic, WebSocket disconnect, and failed scan startup.

### Channel Choice Is A Protocol Decision

Tokio documents different channels for different semantics: `mpsc` for many producers to one consumer, `oneshot` for one response, `broadcast` when every receiver should see values, and `watch` when receivers only need the latest value. This matters for scan progress and UI event streams.

Clean Disk rules:

- Use bounded `mpsc` for worker queues and command channels that need backpressure.
- Use `oneshot` for command response paths.
- Use `watch` for latest session summary/progress state where history is intentionally not kept.
- Use `broadcast` only when lag handling is explicit. Tokio broadcast can return `Lagged` when a receiver falls behind.
- WebSocket clients should have a per-client lag policy: drop/coalesce progress, request resync, or close slow clients with a clear reason.
- Do not use unbounded channels for scan progress or event fanout.
- Do not treat every scan event as durable history. Split latest-state progress from durable errors/warnings/delete-plan events.

### `select!` Branch Order Is A Correctness Decision

Tokio documents that `select!` randomly picks the first branch to poll by default for fairness, while `biased;` polls top to bottom. That means `select!` is not just syntax; it controls cancellation responsiveness, progress drain behavior, and CPU cost in hot loops.

Clean Disk rules:

- Use default fair `select!` unless there is a reason to control branch priority.
- If using `biased;`, put shutdown/cancellation branches early enough that hot event streams cannot starve them.
- Do not rely on random fairness as a product policy. Document the intended priority in session/event loops.
- Keep loop branches small. A branch that does CPU-heavy work blocks all other branches in the same task.
- For hot event fanout, consider separate tasks with bounded channels instead of one giant `select!` loop.
- Add focused tests for cancellation while progress events are flooding.

### WebSocket Streams Need Buffer And Liveness Policy

Axum WebSocket implements `Stream` and `Sink`, and tungstenite exposes buffer and message size configuration. This matters because Clean Disk can produce long-running progress streams and large node page responses while clients pause, background tabs throttle, or reconnect.

Clean Disk rules:

- One WebSocket client should have one owned writer path, fed by a bounded queue.
- Set explicit max message/frame/write-buffer policy in the transport adapter when the chosen stack exposes it.
- Progress events may be coalesced; durable events such as errors, skipped paths, and delete results require ack/resync or query recovery.
- Use ping/pong or an equivalent liveness policy only in the transport adapter, not in application use cases.
- On slow clients, prefer clear close/resync behavior over unbounded memory growth.
- WebSocket disconnect should cancel only client subscription work, not automatically cancel the scan unless the command/session policy says so.

### Lock Poisoning Is A State Signal

The standard `Mutex` and `RwLock` use poisoning to signal that a panic happened while protected state may have been inconsistent. `parking_lot` deliberately does not poison locks. That difference is architectural behavior, not a minor API preference.

Clean Disk rules:

- Do not blindly `unwrap()` poisoned locks in daemon/session code.
- If a poisoned lock protects session or delete state, convert it into failed internal state and structured diagnostics.
- Prefer short lock scopes and avoid returning lock guards from public APIs.
- Do not hold any sync or async lock guard across `.await`.
- Use `std::sync` locks first when they are enough and poisoning semantics are acceptable.
- Consider `parking_lot` only when profiling or ergonomics justify it, and document the no-poisoning tradeoff.
- If multiple locks are needed, document lock ordering or refactor to owned manager tasks.
- Deadlock detection tools/features are diagnostics, not a substitute for simpler ownership.

### Async Traits Need A Deliberate Choice

`async fn` in traits is stable, but the Rust Async Working Group still warns about public trait limitations: bounds such as `Send` on returned futures become part of the API, and these traits are not object-safe. This matters because application ports often want dynamic dispatch at the composition root.

Clean Disk rules:

- Domain should stay synchronous and pure where possible.
- Application ports can be async when they represent IO or long-running work.
- For hot paths called per filesystem entry, avoid boxed async trait calls.
- For low-frequency ports called per command/session, object-safe async ergonomics may be worth a small allocation.
- Prefer concrete structs or generics inside infrastructure hot paths.
- If using `async-trait`, treat it as an adapter/application ergonomics choice and re-check the latest crate version before adding it.
- If a public trait uses native `async fn`, decide up front whether the returned future must be `Send`.

Practical default for Clean Disk: object-safe async ports are acceptable for session-level operations, but not for per-node scanner loops.

### Cancellation Safety Is Part Of The Async API

Tokio documents cancellation safety because dropping a future can cancel it while it is mid-operation. `tokio::select!` makes this easy to do accidentally.

Clean Disk rules:

- Every long-running scan operation has explicit cancellation state, not just dropped futures.
- Do not put non-cancel-safe futures directly inside hot `select!` loops.
- When using `select!`, document which branches can be safely cancelled and which must be awaited to completion.
- WebSocket/event subscribers should use bounded queues with clear drop/coalesce policy rather than relying on implicit cancellation.
- Request cancellation from a closed HTTP/WS client must not corrupt session state.
- Cancellation of a scan marks the session as cancelled and drains/cleans owned resources deliberately.
- Never assume dropping a client stream means the scanner worker stopped.

### Task Panics Must Become Session Failures

Tokio catches panics in spawned tasks and returns them through `JoinError`, but dropped `JoinHandle` values detach tasks and lose their output. `spawn_blocking` tasks cannot be aborted once running.

Clean Disk rules:

- Every spawned task must have an owner that eventually awaits, tracks, cancels, or intentionally detaches it.
- Scan/session worker panics are internal failures and should become failed session state plus structured logs.
- Do not convert task panics into normal user-facing validation errors.
- Dropping `JoinHandle` is not a shutdown strategy.
- Avoid long-lived `spawn_blocking` work for scanner integration if it needs reliable cancellation. Prefer dedicated scanner workers with cooperative stop flags.
- If a blocking scanner adapter cannot stop quickly, surface "cancelling" separately from "cancelled".

### Traits Are Ports, Not Decoration

Rust does not need an interface for every struct. Traits are powerful, but they increase API surface, object-safety constraints, generic complexity, and compile times.

Clean Disk rules:

- Define traits at real boundaries: scanner, trash, clock, session repository, tree repository, event publisher.
- Keep concrete structs inside a module when there is only one implementation and no boundary reason.
- Use generics for compile-time policies or hot paths.
- Use `dyn Trait`/`Arc<dyn Trait + Send + Sync>` at composition boundaries when runtime replacement is useful.
- Prefer enums for a closed set of strategies when all variants are known and performance/simplicity matters.
- Avoid blanket "service trait for every service" style.

### Dependency Injection Should Be Explicit And Local

Rust does not need a DI container by default. The common high-signal pattern is "construct at the edge, pass dependencies in", with traits/generics only where they buy testability or replacement.

Clean Disk rules:

- App crates are composition roots and wire concrete dependencies.
- Use constructor injection for long-lived services that really own dependencies.
- Use call-site injection when a dependency is contextual and should not become global state, for example scan options, config views, permissions, or clock snapshots.
- Do not store a giant `AppContext` inside every service.
- Avoid DI frameworks until manual wiring becomes a measured problem.
- If a public wrapper would otherwise expose an internal trait and many internal types, use a newtype wrapper around `Arc<dyn Trait + Send + Sync>` and keep the trait private.

Practical default: manual composition root plus small ports. No DI container for the first Rust daemon.

### Static Initialization Should Not Become Global State

`OnceLock` and `LazyLock` are now in the standard library and cover many cases that previously needed `lazy_static` or `once_cell`. They are useful for immutable tables, static regex-like helpers, and expensive constants, but they are not a license to hide application state globally.

Clean Disk rules:

- Prefer `OnceLock`/`LazyLock` from `std` over adding a global-init crate when MSRV allows it.
- Use lazy statics for immutable process-wide data only: constants, lookup tables, test fixtures, compiled patterns.
- Do not store session registries, app config, adapters, or mutable scan state in lazy globals.
- App config is parsed at process edge and passed through composition roots.
- If a value can be constructed normally and passed as a dependency, do that instead of adding a static.
- Avoid test pollution from statics. If a test needs resettable state, prefer explicit fixtures.

### Send And Sync Are Public Contracts

Rust auto-traits make concurrency safer, but public service types and session handles still need intentional `Send`/`Sync` behavior. Accidentally introducing `Rc`, `RefCell`, raw pointers, or non-thread-safe platform handles can break server integration.

Clean Disk rules:

- Public application services used by the HTTP/WS server should be `Send + Sync` unless there is a deliberate reason.
- Add compile-time assertion tests for important public types: session registry, scanner service, event bus, protocol client handles.
- Do not use `Rc`/`RefCell` in server/session state. Use owned state, message passing, or carefully scoped locks.
- Avoid unsafe `impl Send` or `impl Sync`. If unavoidable, it belongs in a tiny adapter module with safety documentation and tests.
- Do not hide non-thread-safe platform handles inside types that look freely shareable.

### Builder And Typestate Are For Complex Construction

Rust lacks overloaded constructors and default arguments, so Builder is idiomatic when construction has many optional or interdependent parameters.

Clean Disk rules:

- Use simple constructors for simple value objects.
- Use builders for server config, scan options, protocol client config, and possibly delete-plan creation.
- Use typestate builders only when compile-time enforcement removes real risk, for example requiring auth/session token before server start.
- Do not typestate every runtime lifecycle. Dynamic scan sessions and delete plans are better modeled as enums/state machines in registries.

### RAII Guards For Resource Lifetimes

RAII is a Rust-native way to bind resource release to scope exit. It can reduce cleanup bugs when used carefully.

Clean Disk candidates:

- event subscription guard that unregisters on drop;
- temporary scan working directory or temp file cleanup;
- session lease/read lock guard for short synchronous index reads;
- delete-plan confirmation guard if a token/lease should expire or be invalidated.

Rules:

- Destructors must not fail in a way callers need to handle.
- Destructors must not perform long blocking work.
- If cleanup can fail or block, provide explicit `close`, `dispose`, or `shutdown` methods instead of hiding it in `Drop`.

### Capability-Based Filesystem Access Is A Strong Candidate

`cap-std` shows a Rust-friendly way to avoid ambient filesystem authority: pass directory handles/capabilities instead of letting any function open arbitrary paths. This is directly relevant to cleanup/delete safety.

Clean Disk rules:

- Treat capability-based filesystem access as a candidate for cleanup and delete adapters.
- Use normal full-path scanning when necessary, but make ambient authority explicit at the composition root.
- For destructive operations, prefer APIs that operate relative to an authorized directory/session scope when practical.
- Never let protocol strings become direct `std::fs` delete paths.
- Revalidate node identity and metadata immediately before Trash/delete.
- Remember that the filesystem is external mutable state. `&mut` does not mean exclusive filesystem access.

Decision status: candidate implementation approach, not yet an accepted dependency. Re-check `cap-std` version, platform behavior, and Windows edge cases before adopting.

### Sans-IO For Protocol And State Machines

Sans-IO separates protocol/state-machine logic from actual IO. It is common in Rust networking libraries because it makes core logic testable without sockets, async runtimes, or threads.

Clean Disk fit:

- Good fit for protocol framing/state if we build a custom event protocol later.
- Good fit for small state machines such as reconnect/replay handling, event sequence windows, and client command parsing.
- Not necessary for HTTP route handlers themselves, because HTTP/WS framework adapters already own IO.
- Not necessary for pdu scanning, because the scanner is fundamentally filesystem IO. We can still keep scanner progress aggregation as a pure state machine.

Practical rule: use Sans-IO for protocol/state machine logic, not as a religion for every adapter.

### Session State Should Be Owned By Services, Not Global Mutables

Clean Disk will have multiple active scan sessions and WebSocket clients. Rust makes ownership explicit, so use that to our advantage.

Clean Disk rules:

- Use explicit `ScanSessionRegistry`, `DeletePlanRegistry`, and event bus abstractions.
- Prefer handles that clone cheaply and do not expose raw locks to application code.
- Keep lock scopes small and inside non-async methods when possible.
- For read-heavy indexes, consider sharding or immutable snapshots if contention appears.
- Measure before adding complex concurrent maps.

### Manager Tasks And Command Enums Are Useful For Owned State

Tokio's channel tutorial shows a practical pattern: one task owns a resource, callers send a command enum over bounded `mpsc`, and request/response uses `oneshot`.

Clean Disk fit:

- Good for scan session workers.
- Good for event subscriber management.
- Good for state that should have one owner and no shared lock.
- Bad for tiny synchronous data structures where a short mutex is simpler.

Rules:

- Prefer bounded channels.
- Make command enums explicit and typed.
- Include response channels only for commands that need a response.
- Avoid building a generic actor framework unless repeated boilerplate becomes painful.
- Keep manager task APIs behind application/infrastructure services, not exposed directly to protocol.

### Structured Concurrency Over Fire-And-Forget

Rust/Tokio makes it easy to spawn tasks, but untracked background tasks are hard to shut down and debug.

Clean Disk rules:

- Every spawned scan/session/subscriber task must have an owner.
- Use `JoinSet`, task registries, or `TaskTracker`-style tracking for groups of tasks.
- Use `CancellationToken`-style cooperative cancellation for graceful scan cancellation and server shutdown.
- Decide whether dropping a task owner aborts, cancels, drains, or detaches tasks.
- Do not leave fire-and-forget tasks in the daemon.

### Read Models Should Minimize Clone Storms

Rust makes cloning visible, but it does not make cloning free. Large scan trees and search indexes can create accidental allocation pressure.

Clean Disk rules:

- Keep large node data owned by Rust indexes.
- Return lightweight page DTOs to clients.
- Avoid cloning full paths or child lists in hot loops.
- Consider `Arc<str>`, interned strings, path arenas, or compact IDs only after measuring memory pressure.
- Prefer borrowed/internal views inside Rust, owned protocol DTOs only at the boundary.
- Use profiling before optimizing data structures.
- Avoid collecting iterators into temporary vectors just to iterate once.
- Prefer `&Path`, `&OsStr`, `&str`, slices, and iterator adapters in internal APIs where ownership is not needed.
- Use `Cow` only when an API naturally may borrow or allocate. Do not spread lifetime-heavy APIs through application services for theoretical allocation wins.

### Lock-Free Structures Are Last, Not First

Rust has strong low-level concurrency crates such as Crossbeam, but lock-free or work-stealing data structures come with harder reasoning, memory ordering, and testing requirements. They are not a default architecture choice.

Clean Disk rules:

- Prefer ownership, bounded channels, short locks, and immutable snapshots before lock-free structures.
- Consider Crossbeam only for synchronous worker internals or proven hot paths where Tokio channels/Rayon/simple locks are not enough.
- Keep Crossbeam types inside infrastructure/runtime adapters.
- Do not expose lock-free queue/deque types through application ports.
- If lock-free code appears, add focused stress tests and document the invariants it relies on.

### Read-Mostly State Can Use Immutable Snapshots

Some daemon state is write-heavy during scanning, but read-heavy after scan phases or between progress batches. ArcSwap-style read-mostly snapshots can give clients a consistent read model without holding long `RwLock` guards.

Clean Disk fit:

- Good candidate for immutable scan summary snapshots, completed tree indexes, and route/config snapshots.
- Bad candidate for per-file hot-loop mutation while a scan is actively building the tree.
- Useful only after contention or clone storms appear in profiling.

Rules:

- Prefer simple ownership first: session owns mutable tree, queries use short locks or message passing.
- Move to immutable snapshots when query readers need consistent pages while writers publish coarse updates.
- If using ArcSwap or similar crates, keep them inside infrastructure/runtime read-model adapters.
- Do not leak ArcSwap types into domain/application APIs.
- Do not optimize read-mostly snapshots before measuring lock contention and clone cost.

### Shared Buffers Stay At The Boundary

Rust has good primitives for shared immutable memory such as `Arc<T>` and transport-oriented byte buffers such as `Bytes`. They are useful for efficient IO and repeated response/event payloads, but they should not become domain modeling shortcuts.

Clean Disk rules:

- Use `Bytes` only in transport/protocol adapters where shared byte buffers are useful.
- Use `Arc<[T]>`, `Arc<str>`, or interned values only after profiling shows clone/allocation pressure.
- Domain/application APIs should prefer meaningful typed values and borrowed views, not raw byte buffers.
- Do not optimize protocol JSON allocations before pagination, throttling, and snapshot boundaries are correct.
- Avoid custom shared-slice crates until standard `Arc`/`Bytes` shapes are proven insufficient.

### Large Trees Prefer Typed Indices And Arenas

The scan result is a large tree/index model, not a graph of `Rc<RefCell<Node>>` objects. Rust works best when ownership is centralized and relationships are represented by typed IDs/indices.

Clean Disk rules:

- Store the scan tree in Rust-owned indexes, usually `Vec`/arena-like storage plus typed `NodeId`.
- Use a `NodeId` newtype, not raw `usize` or `u32`, at public boundaries.
- For an append-only scan tree disposed with the session, a typed index over `Vec<Node>` is probably enough.
- Use generational keys only if nodes can be removed/reused while stale IDs might still exist.
- Avoid nested `Box<Node>` trees and `Rc<RefCell<Node>>` unless there is a strong reason.
- Keep parent/child relationships as IDs, child ranges, or sibling links depending on query needs.
- Keep path/name storage separate if profiling shows string/path allocation pressure.

Candidate crates are `indextree`, `slotmap`, `genarena`, and typed-index crates. None are accepted dependencies yet. First decide ID semantics, then choose the crate.

### Large Scan Memory Needs Budgets And Fallible Growth

A 500 GB disk can still mean millions of nodes. Rust prevents many memory safety bugs, but it does not make huge allocations free. Standard collections expose `try_reserve` so large expected growth can fail as a typed error instead of panicking on capacity overflow.

Clean Disk rules:

- Each scan session should have explicit memory and node-count budgets.
- Use `try_reserve`/`try_reserve_exact` before known-large growth in tree arenas, path/name stores, and indexes.
- Convert allocation pressure into a typed session failure such as `ResourceExhausted` or `TooManyNodes`, with partial scan stats if available.
- Avoid `collect::<Vec<_>>()` on unbounded filesystem iterators.
- Avoid over-reserving huge `HashMap`s because iteration/retain can depend on capacity, not just length.
- Prefer append-only compact storage and paginated read models over keeping several full alternate trees.
- Add macro benchmarks that record peak memory, not only elapsed scan time.

### Top Lists Should Avoid Full Global Sorts

Clean Disk will often need "largest files" and "largest folders" from hundreds of thousands or millions of entries. Rust's `BinaryHeap` is a standard priority queue and is a good building block for bounded top-K indexes, but final display still needs deterministic ordering.

Clean Disk rules:

- Do not sort every node globally just to show top 50 items.
- Maintain bounded top-K indexes during aggregation where practical.
- Use explicit stable tie-breakers: size desc, path/name asc, node id asc.
- Keep top-file and top-folder indexes separate because users scan them differently.
- Rebuild top indexes from the canonical tree when accounting policy changes.
- Measure before introducing specialized priority queue crates. `BinaryHeap` or partial selection may be enough.

### NodeId Semantics Matter More Than NodeId Storage

Clean Disk clients will cache selected rows, queue delete candidates, and reconnect to event streams. That makes ID semantics part of the product contract.

Rules:

- `NodeId` is stable only inside one scan session unless explicitly documented otherwise.
- A disposed session invalidates all its `NodeId` values.
- If tree nodes are never removed during a session, `NodeId` can be a compact typed index.
- If nodes can be removed/replaced during a session, use generation or session epoch checks to reject stale IDs.
- Every read model page should include the session id and scan epoch it came from.
- If files change during scan, prefer explicit "possibly stale" or "changed during scan" state over silently correcting totals in place.
- Delete candidates must include enough scanned identity metadata to revalidate the current filesystem object before Trash.
- Protocol should never expose "index into internal Vec" as a meaningful number. It is an opaque session-local token.

### Scan Results Are Point-In-Time Views

The filesystem is changing while Clean Disk scans it. That means a scan result is a point-in-time-ish view with known imperfections, not a database transaction.

Clean Disk rules:

- Model scan start time, finish time, session epoch, and stale markers.
- If a file disappears before metadata is read, record a skipped/changed entry rather than failing the whole scan.
- If a directory total changes during traversal, prefer consistency metadata over pretending exactness.
- Cleanup actions use fresh metadata revalidation, not scan-time totals alone.
- UI should surface "changed during scan" and offer rescan for affected roots.
- Tests should include create/delete/replace races during scan fixtures.

### Performance Work Starts With Profiling

The Rust Performance Book emphasizes profiling before optimizing. For Clean Disk this is critical because bottlenecks may be disk IO, metadata calls, allocation, sorting, hashing, channel pressure, or UI transfer.

Clean Disk rules:

- Benchmark scanner adapter throughput separately from UI/protocol overhead.
- Track allocations and peak memory for large home-directory scans.
- Measure search and sorting indexes with realistic path counts.
- Use Criterion-style microbenchmarks for isolated algorithms only after macro behavior is understood.
- Keep performance tests separate from correctness tests.

### Property And Concurrency Testing Where It Pays

Rust's type system removes many classes of bugs, but it does not prove business invariants, filesystem race behavior, or custom concurrent logic.

Clean Disk test guidance:

- Use ordinary unit tests for value objects, policies, and use cases.
- Use property tests for path normalization, pagination invariants, sorting stability, delete safety specifications, and tree index consistency.
- Use realistic fixture scans for integration-style query tests.
- Use concurrency model checking only if we build custom synchronization, atomics, or non-trivial concurrent data structures.
- Do not add Loom around ordinary Tokio channels or simple mutex usage.

### Property Test Failures Must Be Reproducible

Property tests are most valuable when a rare generated failure can be replayed. Proptest has explicit failure persistence support for saving failing cases.

Clean Disk rules:

- Use property tests for compact, deterministic invariants: pagination, sorting, tree index math, path display normalization, delete-plan validation.
- Persist failing property cases for high-risk crates once those tests become part of CI.
- Convert a persisted generated case into a readable unit test when it reveals a real product rule.
- Keep random case counts reasonable for normal CI, and use a slower profile for deeper randomized runs.
- Do not property-test real user directories or non-deterministic filesystem state.
- Do not treat generated cases as a substitute for hand-written edge cases such as symlinks, hardlinks, permissions, locked files, and stale identity.

### Compile-Fail Tests Protect Type-Level Contracts

Rust lets us encode misuse as code that does not compile. That is only valuable if we also protect the intended compile failures from accidental API changes.

Clean Disk candidates:

- invalid `ByteSize`, `NodeId`, `ScanSessionId`, or delete confirmation construction;
- API attempts to call delete without a validated confirmation token;
- protocol/client attempts to pass display paths where identity paths are required;
- public builders that require mandatory fields before `build()`;
- feature or crate boundary checks for forbidden imports.

Rules:

- Use compile-fail tests only for important public misuse cases, not every wrong argument type.
- Keep diagnostics stable enough to review but do not overfit to compiler wording unless user-facing diagnostics matter.
- `trybuild` is a candidate dev-dependency for this if type-level contracts become important.
- Do not add compile-fail tests for private implementation details.

### Mutation Testing Finds Weak Assertions

Coverage shows which code ran. Mutation testing checks whether tests would fail if the code were made wrong. `cargo-mutants` does this by creating modified copies of Rust functions and running `cargo test`.

Clean Disk candidates:

- delete safety specifications;
- stale metadata revalidation;
- path identity/display conversion;
- tree pagination and sorting;
- scan session state transitions;
- protocol error mapping.

Rules:

- Do not run mutation testing on every PR at first. It can be slow.
- Run it manually or on a scheduled CI job for safety-critical domain/application crates.
- Treat surviving mutants as prompts to improve tests, not automatic proof that code is broken.
- Exclude generated code, UI glue, protocol DTO boilerplate, and slow integration-heavy adapters.
- Prefer focused mutation runs on changed or high-risk modules.

### Prefer Fakes Over Strict Internal Mocks

Rust makes ports explicit through traits, but traits should exist because the architecture needs a boundary, not only because a mocking framework wants one.

Clean Disk rules:

- Use in-memory fakes for owned ports: session repository, event publisher, scan tree repository, clock, ID generator, trash adapter.
- Mock or fake external boundaries: filesystem, network, time, process execution, platform Trash APIs.
- Avoid strict call-order or call-count tests for internal collaborators.
- Assert behavior and resulting state, not private wiring.
- Do not introduce a trait only to mock one concrete helper in a unit test.
- Keep fake implementations small and honest. If the fake becomes complex, add contract tests shared by fake and real adapter.

### Filesystem Tests Must Be Sandboxed

Clean Disk tests will create directories, symlinks, hardlinks, permission errors, large files, and deletion candidates. Those tests must never depend on the developer's real home directory.

Clean Disk rules:

- Use per-test temporary directories for filesystem fixtures.
- Keep fixture roots explicit and pass them through ports instead of reading global paths.
- Prefer test fixtures that can run in parallel. If a test must be serial because it touches process-global state, mark it clearly and isolate it.
- Test symlink, hardlink, invalid Unicode, permission denied, file replacement, locked file, and path length behavior with platform-specific cases.
- Do not trust destructor cleanup for critical safety behavior. Test cleanup explicitly when cleanup is the behavior under test.
- `tempfile` and `assert_fs` are candidate dev-dependencies for fixture ergonomics. Verify versions before adding.

### Snapshot Tests For Protocol And CLI Shapes

Snapshot testing is a good fit for versioned wire DTOs and CLI output because small changes are easy to miss in hand-written assertions.

Clean Disk candidates:

- protocol JSON for scan summary, tree row page, node details, event batch, and error response;
- CLI table/JSON output if `clean_disk_cli` becomes real;
- warning/detail payloads for cleanup candidates.

Rules:

- Do not snapshot huge scan trees.
- Redact unstable values such as session IDs, timestamps, event sequence numbers, machine-specific paths, and byte-exact platform metadata.
- Snapshot protocol shape, not domain internals.
- Treat snapshot changes as API review points, not automatic accept buttons.

### Deterministic Output Needs Explicit Ordering

Rust `HashMap` iteration is arbitrary, while `BTreeMap` iteration is ordered by key. Protocol snapshots, CLI output, OpenAPI schema dumps, and benchmark reports should not accidentally change order across runs.

Clean Disk rules:

- Use explicit sorting or ordered maps for protocol examples, snapshots, CLI output, and generated docs.
- Do not rely on `HashMap` iteration order in tests or serialized output.
- Keep internal hot-path maps optimized for lookup first; sort at read-model/protocol boundaries when deterministic output matters.
- Prefer stable sort keys that match product semantics: size desc, name asc, path asc, modified desc.
- Redact and sort diagnostics before snapshotting to avoid noisy diffs.

### Serialization Belongs To Protocol Crates

Serde derives are convenient, but they are also a coupling point.

Clean Disk rules:

- Domain crates should avoid `serde` unless there is a clear domain-level reason.
- `shared/protocol` owns wire DTOs, serialization, versioning, and mapping.
- Infrastructure persistence DTOs are separate from domain models and protocol DTOs.
- Do not derive serialization on domain types just to make HTTP convenient.

### Protocol Compatibility Needs Explicit Serde Policy

Serde can be strict or tolerant depending on attributes. That choice is part of the wire contract, not a local implementation detail.

Clean Disk rules:

- Put a protocol version in the command/query/event envelope, not inside random nested DTOs.
- For commands sent to the daemon, strict decoding can be useful to catch client bugs early.
- For responses/events sent to clients, prefer forward-compatible decoding on clients so new optional fields do not break older UI builds.
- Use `#[serde(default)]` for newly added optional fields where older payloads must still decode.
- Avoid `#[serde(deny_unknown_fields)]` on DTOs meant to be forward compatible across client/server versions.
- Keep protocol DTOs distinct from persistence DTOs so storage migrations and wire evolution do not block each other.
- Snapshot representative DTO JSON and treat snapshot diffs as API review.

### Protocol Enums Should Be Explicitly Tagged

Serde supports externally tagged, internally tagged, adjacently tagged, and untagged enums. Untagged enums are convenient, but Serde chooses the first variant that successfully deserializes, which can make protocol failures ambiguous.

Clean Disk rules:

- Prefer explicitly tagged command/event envelopes for daemon protocols.
- Use a stable operation/event tag such as `type`, `kind`, or `method`, plus a versioned payload.
- Avoid `#[serde(untagged)]` for public command/event protocols unless there is a strong compatibility reason.
- If untagged is used for small convenience DTOs, add tests for ambiguous and invalid payloads.
- Be careful combining strict decoding with `#[serde(flatten)]`; Serde documents that `flatten` is incompatible with `deny_unknown_fields`.
- Keep protocol ergonomics below debuggability. A slightly more verbose tagged payload is better than ambiguous decode errors.

### Binary Formats Are A Measured Optimization

Rust has strong binary serialization options: bincode, postcard, and zero-copy systems such as rkyv. They can be valuable, but they make debugging, compatibility, validation, and cross-client support harder than JSON.

Clean Disk rules:

- Keep JSON as the first HTTP/WebSocket protocol format unless profiling shows serialization or bandwidth is a real bottleneck.
- If a binary format is added, keep it behind the protocol adapter and version it explicitly.
- For untrusted or semi-trusted inputs, require size limits and validation. Do not assume binary means safer.
- Do not use rkyv/zero-copy formats for local daemon commands unless validation and compatibility costs are justified.
- Binary cache files, if introduced, must be disposable or versioned. Never make them the only source of truth for delete safety.
- Protocol snapshots still matter even if the transport later gains a binary mode.

### Protocol Decode Errors Need Field Paths

For HTTP/WebSocket commands, "bad request" is not enough. The UI and logs need to know which field failed without dumping the whole payload. `serde_path_to_error` is a strong candidate because it wraps a Serde deserializer and records the path to the failing field.

Clean Disk rules:

- Decode transport payloads in `interfaces/http_ws` or protocol adapter code, not in domain/application crates.
- Map decode failures into stable protocol errors with `error_code`, field path, and sanitized message.
- Use field paths for developer diagnostics and UI bug reports, but do not leak raw payloads or sensitive full paths by default.
- Keep strict command decoding and forward-compatible event/response decoding as separate policies.
- Add focused tests for nested command DTO failures once protocol DTOs exist.
- Treat `serde_path_to_error` as a protocol adapter dependency candidate only. Check latest version and maintenance before adding it.

### Error Diagnostics Should Split Machine Errors From Human Reports

Rust error practice usually separates typed library errors from report-oriented application errors. Clean Disk needs both: stable protocol error codes for UI behavior and useful diagnostics for logs/CLI.

Clean Disk rules:

- Domain/application crates expose typed error enums.
- Protocol maps typed errors to stable `error_code`, message, details, and retry/safety hints.
- Binaries may use report-oriented wrappers for top-level CLI/server startup errors.
- Do not let `anyhow::Error` cross application ports or protocol boundaries.
- Include source error chains in tracing/logs where useful, but keep protocol errors stable and sanitized.
- Avoid leaking sensitive full paths in high-volume logs or remote protocol errors unless the user-facing feature needs them.

### Human Diagnostic Reports Stay At Binary Boundaries

Crates such as miette, eyre, and color-eyre can produce high-quality human reports for CLI/server startup failures. They are report layers, not domain error types.

Clean Disk rules:

- Use typed errors in domain/application/protocol crates.
- Use report-oriented crates only at binaries, CLI commands, dev tools, or installer/checkup commands.
- Do not expose miette/eyre/color-eyre types through application ports or HTTP/WebSocket protocol DTOs.
- Keep user-facing UI errors structured and localizable. Fancy terminal reports do not solve Flutter UX.
- If a diagnostic report includes paths, apply the same redaction/sensitivity policy as tracing.
- Prefer miette-style diagnostics only where source spans or actionable human help are valuable.

### Cargo Features Must Be Additive

Cargo feature unification means features should usually be additive. Mutually exclusive features are fragile in dependency graphs.

Clean Disk rules:

- Use a workspace root with shared `workspace.package`, `workspace.dependencies`, and `workspace.lints` once Rust exists.
- Keep feature flags additive.
- Prefer separate crates or runtime config over mutually exclusive features.
- Disable dependency default features only when we understand the impact across the workspace.
- Use `cargo tree -e features` and `cargo tree --duplicates` when dependency behavior is surprising.
- Avoid broad optional feature sets until there is a real packaging need.

### SemVer And MSRV Are Part Of Rust Architecture

Even internal crates benefit from clear compatibility rules. Public protocol crates and any future SDK need them.

Clean Disk rules:

- Set `package.rust-version` once the Rust workspace is created.
- Treat `shared/protocol` as the most compatibility-sensitive crate.
- Keep external dependency types out of public APIs to reduce accidental SemVer coupling.
- Use `cargo-semver-checks` only when crates become published/reused or API stability matters.
- Version the wire protocol separately from crate versions.
- Adding protocol fields should be backward compatible where clients can ignore unknown fields.
- Removing/renaming protocol fields or error codes requires an explicit versioned protocol decision.

### Minimal Dependency Versions Are A Library Concern

Cargo normally resolves the newest compatible dependency versions, so local builds might not prove that declared lower bounds are accurate. Cargo's minimal-version flags are currently unstable and full transitive minimal-version checks are explicitly not recommended as a routine gate, but direct-minimal-version checks can be useful for published libraries.

Clean Disk rules:

- For application binaries, lockfiles and tested release builds matter more than minimal dependency version checks.
- For public crates or a future SDK, declared dependency lower bounds should match APIs we actually use.
- Consider direct-minimal-version checks only after a crate has external users or a compatibility promise.
- Do not make full transitive `-Z minimal-versions` a required CI gate for the whole workspace.
- When adding dependencies, write precise enough version requirements and re-check latest stable versions before installing.
- MSRV and dependency lower bounds should be reviewed together.

### Lockfile Policy Should Match The Product

The Cargo team now recommends choosing what is best for the project and suggests committing `Cargo.lock` as a starting point. Clean Disk is an end-user product with binaries, installers, and a delete-capable daemon, so release reproducibility matters.

Clean Disk rules:

- Commit the workspace `Cargo.lock` once Rust crates are added.
- Release builds should come from reviewed lockfile updates, not implicit fresh resolution on release machines.
- Use scheduled or bot-driven dependency updates so the lockfile does not silently go stale.
- Run security/advisory checks against the lockfile and, later, against produced binaries if we adopt auditable builds.
- Public library crates can still test against newer dependencies separately if they gain external users.
- Do not use lockfile pinning as an excuse to ignore SemVer ranges, MSRV, or dependency maintenance.

### Edition And Workspace Lints Are Architecture

Rust edition, resolver, MSRV, and workspace lints shape dependency resolution and safety defaults. They should be chosen deliberately at workspace creation.

Clean Disk rules:

- Prefer Rust 2024 edition for new Rust crates unless a dependency/tooling blocker appears.
- In a virtual Rust workspace, set the resolver explicitly. Rust 2024 implies resolver 3 for packages, but virtual workspaces still need explicit workspace resolver configuration.
- Set `package.rust-version` in the workspace package metadata once the Rust toolchain target is chosen.
- Use `workspace.lints` and require member crates to inherit it.
- Default to forbidding unsafe code in domain/application/protocol crates.
- Allow unsafe only in tiny infrastructure/platform adapter crates when needed.
- Keep Clippy configuration small and aligned with MSRV. Avoid turning on noisy lint groups globally without reviewing impact.

### Architecture Rules Should Be Machine-Checked

Some architecture rules can be enforced with crate boundaries, but some need tooling. Clippy's configurable `disallowed_methods` and `disallowed_types` lints can block dangerous APIs when configured deliberately.

Clean Disk candidates:

- Disallow direct destructive filesystem calls such as `std::fs::remove_file` and `std::fs::remove_dir_all` outside platform cleanup adapters.
- Disallow `std::process::exit` outside binaries.
- Disallow `std::thread::spawn` or direct `tokio::spawn` outside runtime/session infrastructure if task supervision becomes inconsistent.
- Disallow `std::sync::Mutex` in async-heavy crates only if it becomes a real footgun. A sync mutex can still be correct for short non-async critical sections.

Rules:

- Prefer crate boundary checks first. Use Clippy disallow lists for small, high-risk API bans.
- Do not turn Clippy into a fragile architecture compiler for every preference.
- Local exceptions must include a reason and should live in adapter crates, not domain/application code.
- Pair lint rules with tests or `xtask` boundary checks for forbidden imports that Clippy cannot express cleanly.

### Release Profiles Are Product Decisions

Cargo profiles control optimization, debug info, stripping, LTO, codegen units, and panic strategy. For a desktop utility, release profile choices affect startup time, binary size, crash diagnostics, and installer size.

Clean Disk rules:

- Keep dev profiles fast for iteration. Do not globally enable expensive release-like settings in development.
- Decide release settings deliberately: `strip`, `lto`, `codegen-units`, and debug symbol policy belong in release engineering docs, not scattered local commands.
- Keep enough diagnostics for crash reports during beta. A tiny binary is less useful if every crash is opaque.
- Use separate profiles or release scripts for local development, beta diagnostics, and final distribution if needed.
- Do not change `panic` strategy only to shave binary size until daemon crash behavior is explicit.

### Lint Suppressions Should Be Auditable

Rust supports `#[expect]` for lint expectations and lint attributes can include a reason. That is better than permanently hiding warnings with broad `#[allow]`.

Clean Disk rules:

- Prefer local `#[expect(..., reason = "...")]` over broad `#[allow]` when a lint is intentionally triggered and MSRV supports it.
- Use crate-level `allow` only for an explicit workspace policy, generated code, or platform-specific adapter limitation.
- Every local allow/expect in production Rust code should explain why the lint is wrong or intentionally traded off.
- Avoid enabling broad Clippy groups such as full `restriction`; choose focused lints that match our risks.
- Revisit lint expectations during Rust upgrades because unfulfilled expectations can reveal obsolete suppressions.

### Public API Diffs Are Useful After Stabilization

Before Rust crates are stable, API churn is normal. After `shared/protocol`, `interfaces/http_ws`, or a future SDK becomes a contract, public API drift should be visible.

Clean Disk rules:

- Treat protocol JSON snapshots as the first compatibility guard.
- Use `cargo-semver-checks` or `cargo-public-api` only after a crate has an intended public API.
- Public API diff tools are not a replacement for protocol versioning because wire compatibility and Rust API compatibility are different contracts.
- Run API diff checks on release branches or SDK crates, not on every early experimental internal crate.
- Keep public dependencies out of public API so API diffs remain meaningful and dependency updates do not leak into users.

### Tooling Gates Should Be Boring And Strict

Clean Disk should use standard Rust tooling before custom process.

Baseline gates when Rust code exists:

- `cargo fmt --all --check`
- `cargo clippy --workspace --all-targets -- -D warnings`
- `cargo test --workspace`
- `cargo metadata` or an `xtask` boundary check for forbidden dependencies.
- `cargo audit` or `cargo deny` for RustSec advisories and dependency policy.

Clippy guidance:

- Use default Clippy lints in CI.
- Enable selected `pedantic` or `restriction` lints only intentionally.
- Do not enable the full `restriction` group.
- Consider targeted denials for `unwrap_used`, `expect_used`, or `todo` in production crates, with local allows where justified.
- Consider `cargo nextest run` once the Rust workspace grows and test runtime matters.
- Add property tests for domain invariants and index/query behavior if edge cases become dense.
- Use concurrency-focused testing tools only when we build tricky concurrent primitives. Do not add them for ordinary channels and mutexes by default.

### Rustdoc Examples Are Contract Tests

Rustdoc can compile and run documentation examples as tests. This is useful for public crates because examples stay synchronized with real APIs instead of becoming stale prose.

Clean Disk rules:

- Add doctested examples for stable public APIs in `shared/protocol`, `core`, and any future SDK.
- Keep doctests small and deterministic.
- Use doctests to show correct construction and use-case flow, not to run real daemon scans.
- Do not include filesystem side effects in public doctests unless they use temporary fixtures and are clearly bounded.
- Regular unit/integration tests still own behavioral coverage. Doctests protect examples and public ergonomics.
- Avoid doctests for private modules and unstable early APIs where churn would create busywork.

### Nextest Profiles Should Encode Test Policy

`cargo-nextest` repository config supports checked-in profiles, retries, timeouts, and per-test behavior. This is useful once Rust tests split into fast unit tests, slower filesystem integration tests, and rare stress/property runs.

Clean Disk rules:

- Start with `cargo test --workspace`; add `cargo nextest` when Rust test count/runtime makes it pay for itself.
- If nextest is added, check `.config/nextest.toml` into the repo instead of relying on developer-local settings.
- Use a `ci` profile with `fail-fast = false` so CI reports all failing tests in one run.
- Use separate profiles for slow filesystem/integration/property tests rather than making every local run slow.
- Do not use retries to hide deterministic failures.
- If retries are used for a flaky external/system test, mark the reason and track it as debt.
- Configure slow timeouts deliberately for scan benchmarks and large filesystem fixtures. Do not let hung tests run forever.

### Use Xtask Only For Real Workspace Automation

The `cargo xtask` pattern is common for project-local automation written in Rust. It bootstraps from Cargo/Rust, avoids shell portability issues, and can be committed as part of the workspace. It is not official ceremony and should not be added before it helps.

Clean Disk candidates:

- boundary checks for forbidden crate imports;
- protocol codegen or schema snapshot generation;
- benchmark fixture generation;
- release packaging checks;
- cross-platform dev commands that would otherwise become fragile shell scripts.

Rules:

- Do not add `xtask` while normal Cargo/Melos commands are enough.
- If added, keep it small and fast to compile.
- Prefer one `xtask` binary with subcommands.
- Do not hide ordinary `cargo test` or `cargo clippy` behind a custom wrapper unless the wrapper adds real value.
- Keep Rust and Flutter workspace automation coordinated, but do not force every Flutter task through Rust `xtask`.

### Dependency Supply Chain Is A Product Requirement

Clean Disk is a local filesystem utility with delete capabilities, so dependency risk matters more than in a throwaway CLI.

Clean Disk rules:

- Keep dependency count low and use `workspace.dependencies` for shared versions.
- Every dependency that touches filesystem, networking, serialization, process control, or native APIs needs a short rationale.
- Use `cargo-deny` or `cargo-audit` early for RustSec advisories. Prefer `cargo-deny` when we also want license, duplicate-version, ban, and source policy.
- Consider `cargo-vet` later if Clean Disk becomes distributed widely or if dependency trust becomes a release blocker.
- Consider `cargo-auditable` for release binaries if we want deployed executables to be inspectable for exact crate versions.
- Treat `build.rs`, FFI crates, native libraries, git dependencies, and unmaintained crates as review triggers.
- Do not add a crate just because it saves 30 LOC in non-critical code.

### Build Scripts And Proc Macros Are Code Execution

Cargo build scripts are compiled and executed during builds. Rust procedural macros also run during compilation and the Rust Reference explicitly says they have the same security concerns as Cargo build scripts. For a delete-capable desktop app, compile-time code execution is part of supply-chain risk, not just build plumbing.

Clean Disk rules:

- Treat new `build.rs` and procedural macro dependencies as privileged code that runs on developer and CI machines.
- Prefer declarative configuration or generated code checked into the repo when the alternative build script only saves minor boilerplate.
- Native-library build scripts, bindgen, code generators, and installer/signing helpers require explicit ownership and review.
- Do not pass secrets such as signing keys, daemon tokens, or private paths into builds unless release engineering policy requires it.
- Keep build script output deterministic where possible, and configure `rerun-if-*` precisely for our own build scripts.
- Dependency review should flag crates whose only purpose is macro convenience in non-critical code.

### Unused Dependencies Are Audit And Compile-Time Debt

Rust workspaces can accumulate dependencies after refactors. Unused dependencies still increase compile time, advisory surface, license review work, and feature-unification surprises.

Clean Disk rules:

- Run `cargo-machete` periodically because it is fast enough for regular hygiene checks, but review false positives around macros/build scripts.
- Use `cargo-udeps` only as a slower/nightly deeper check when useful.
- Review dependency features manually. Tools can find unused crates, but they do not reliably prove unused optional features.
- Avoid broad features like `tokio/full` unless the daemon genuinely needs them.
- Use `cargo tree --duplicates` and `cargo tree -e features` when compile time or duplicate versions grow.
- Consider `cargo-hakari` only if the Rust workspace becomes large enough that dependency feature unification materially affects build times.

### Compile-Time Hygiene Should Be Measured

Rust compile time can become a product cost in a large workspace. Cargo has build timing reports, and tools such as `sccache` can cache compiler outputs. These are useful, but they should follow measurement.

Clean Disk rules:

- Use Cargo build timings before guessing which crate or feature is slow.
- Keep feature sets narrow, especially for Tokio, serialization, OpenAPI, and platform crates.
- Prefer workspace dependency version alignment to reduce duplicate builds.
- Use `sccache` as developer/CI environment configuration when it helps, not as a hard project requirement.
- Do not introduce Docker-only tools such as cargo-chef unless we actually ship or test Rust in containers.
- Treat generated code and proc macros as compile-time costs that need a reason.
- Do not optimize compile time by weakening architecture boundaries that protect safety.

### Fuzz Untrusted Boundaries, Not The Whole App

Rust's type system is strong, but it will not automatically test hostile protocol payloads, weird platform paths, or custom parsers. `cargo-fuzz` is the common Rust/libFuzzer path, but it uses nightly and should be targeted.

Clean Disk fuzz candidates:

- protocol envelope parsing and version negotiation;
- path display/normalization helpers, especially invalid Unicode and Windows-style prefixes;
- delete-plan validation from DTO input;
- scanner adapter parsing if an external process or text/JSON output ever appears;
- small tree/query invariants if we create custom compact indexes.

Rules:

- Do not fuzz the full daemon.
- Keep fuzz targets small and deterministic.
- Minimize filesystem and clock use in fuzz targets.
- Turn every found crash into a normal regression test.
- Fuzzing is a later hardening gate, not required before the first Rust skeleton.

### Use Miri Only Where It Pays

Miri detects many classes of Undefined Behavior in Rust tests, especially around unsafe code and tricky aliasing. It is powerful but slower and not a replacement for normal tests.

Clean Disk rules:

- The first Rust implementation should avoid unsafe code entirely.
- If unsafe/FFI is introduced for platform Trash APIs or filesystem metadata, add small Miri-friendly tests around the safe wrapper.
- Do not run the whole daemon under Miri by default.
- Use Miri for low-level crates and invariants, not HTTP route behavior.
- If Miri cannot model an OS/platform API, isolate the unsafe wrapper and test the pure validation around it separately.

### Benchmarking Must Match The Question

Criterion is useful for statistics-driven microbenchmarks, but disk scanning performance also needs macro benchmarks with realistic directories.

Clean Disk rules:

- Use macro benchmarks for end-to-end scan throughput: real directory fixtures, cold/warm cache notes, file count, byte count, skipped paths.
- Use Criterion-style microbenchmarks for isolated algorithms: tree index insert/query, sorting, pagination, path formatting, search index updates.
- Never use microbenchmarks alone to choose a scanner architecture.
- Record benchmark environment: OS, filesystem, disk type, target size, cache state, thread count, scanner options.
- Treat CI perf gates carefully because shared CI machines produce noisy timing.

### Observability Should Be Structured

Async daemon logs become hard to understand without correlation.

Clean Disk rules:

- Use structured tracing spans around scan sessions, delete plans, WebSocket connections, and long-running jobs.
- Include stable fields: `session_id`, `node_id`, `delete_plan_id`, `request_id`, `event_seq`, `target`.
- Domain crates should not initialize tracing subscribers.
- The server binary initializes tracing early.
- Use `#[instrument]` on request/session/delete boundaries where spans help, with `skip(...)` for large or sensitive values.
- Avoid logging raw full paths at high volume by default. Paths can be sensitive and logs can explode.
- Support runtime log filtering with `EnvFilter`/`RUST_LOG`-style configuration in development and daemon deployments.
- Prefer structured fields over formatted strings for values the UI or diagnostics may query.
- Do not emit one log event per filesystem entry during normal scans. Aggregate counters and sample noisy details.
- Do not instrument per-file scanner hot loops with verbose spans unless a profiling/debug build explicitly needs it.
- Keep user-facing diagnostics separate from operator logs.

### Local Daemon Tokens Are Secrets

Clean Disk's web UI may talk to a local Rust daemon over HTTP/WebSocket. The local session token is not a cryptographic key for remote zero-trust auth, but it is still a secret because it protects local destructive capabilities.

Clean Disk rules:

- Model local session tokens as a dedicated secret type, not a plain `String` passed through logs.
- Do not derive `Debug`/`Serialize` for token-bearing internal types unless redaction is explicit.
- Consider `secrecy` for token storage if it fits dependency policy; it makes secret access explicit and reduces accidental debug leakage.
- Consider constant-time comparison utilities only for real token equality checks. Do not add crypto-style crates for ordinary IDs.
- Keep token validation in transport/security adapters; delete authorization and stale identity validation still belong in application rules.
- Never log local auth tokens, WebSocket tokens, or full request headers.

### Delete Receipts Need Privacy Boundaries

Cleanup needs an audit trail for user trust: what was queued, what was moved to Trash, what failed, and what changed since scan. But full filesystem paths can expose personal names, project names, clients, medical/legal files, and other sensitive context. OWASP logging guidance calls out file paths and user data as information disclosure risks.

Clean Disk rules:

- Keep local delete receipts as an application feature, not raw process logs.
- Receipt fields should include operation id, time, selected root display, scan session/epoch, result state, estimated bytes, actual adapter result, warnings, and failure reasons.
- Full raw paths should remain local by default and be redacted or user-approved before export/support logs.
- Never include local daemon tokens, request headers, or auth material in receipts.
- Use structured receipt entries so UI can show undo/trash location details without parsing log strings.
- Deletion logs should record enough for user accountability without becoming telemetry.
- If remote/server mode is added, define data-retention and path-redaction policy before enabling delete-capable telemetry.

### Local State Writes Need Durability Classes

Clean Disk will store different kinds of local state: cache indexes, preferences, scan history, delete receipts, and transient runtime files. They do not all need the same durability. Cross-platform directory helpers can place state in OS-standard locations, and temp-file persistence can help avoid partial overwrite, but `persist` itself does not guarantee data is synced to disk.

Clean Disk rules:

- Classify local data before choosing storage: cache, config, local data, state/history, receipt/audit, runtime socket/token.
- Use OS-standard project directories for app-owned files. `directories::ProjectDirs` is a stronger candidate than ad hoc path concatenation when we add this adapter.
- Cache files may be disposable and rebuildable; delete receipts and preferences need stronger write discipline.
- For replacing a JSON/TOML/state file, write a temp file in the same directory, flush, then persist/rename.
- If a receipt must survive power loss, document and implement the extra sync policy. Do not assume atomic rename means durable storage.
- Version persisted formats from the beginning, even if v1 is simple.
- Never place daemon tokens or delete receipts in a world-readable temp directory.

### Atomic Local Writes Need A Commit Policy

Temp-file-then-rename is the usual shape for replacing local state without exposing partial files. Rust crates such as `tempfile` and `atomic-write-file` can help, but their docs still leave platform and durability details to the caller.

Clean Disk rules:

- Write replacement files in the same directory as the destination so the final rename stays on the same filesystem.
- Treat atomic visibility and crash durability as different guarantees.
- For preferences and receipts, define whether we require file sync, directory sync, both, or best-effort visibility only.
- Do not fsync every rebuildable cache write by default. That can make scans and UI state updates feel broken.
- For delete receipts, prefer a slower but clearer durability policy over silently losing the only audit record after a crash.
- Adapter tests should cover interrupted writes by leaving temp files behind and verifying recovery/cleanup behavior.

### Browser-To-Local Daemon Is A Security Boundary

The web UI talking to a localhost Rust daemon is convenient, but browser-origin security still matters. OWASP recommends CSRF tokens/custom headers for browser APIs, MDN documents strict CORS handling, and OWASP REST guidance warns against tokens in URLs.

Clean Disk rules:

- Bind local-only by default: `127.0.0.1` and/or `[::1]`, never `0.0.0.0` unless remote/server mode is explicitly enabled.
- Use a random port and a per-session local token.
- Do not put daemon tokens in URLs. Use headers or WebSocket subprotocol/handshake fields that do not end up in normal access logs.
- Enforce an origin allowlist for HTTP and WebSocket handshakes.
- Use explicit CORS origins and headers; no wildcard CORS for delete-capable endpoints.
- Require a custom header or equivalent token-bearing handshake for state-changing HTTP requests.
- Treat missing/invalid origin or token as an auth failure, not as a generic bad request.
- Remote/server mode must be a separate deployment profile with explicit auth and TLS decisions.

### IPC Transport Is A Deployment Choice

Tokio supports TCP, Unix domain sockets on Unix, and Windows named pipes. The `interprocess` crate offers a cross-platform local-socket abstraction that maps to Unix-domain sockets on Unix and named pipes on Windows. This gives us options, but browser web UI still needs browser-supported transports such as HTTP/WebSocket over TCP.

Clean Disk rules:

- Keep HTTP/WebSocket over loopback TCP as the first transport because it supports desktop UI, browser UI, CLI, and future remote mode.
- Keep command/query/event contracts transport-neutral so a desktop-only local IPC adapter can be added later.
- Unix sockets/named pipes are candidates for packaged desktop mode, not replacements for browser web mode.
- Named pipe security options and first-instance behavior belong in a Windows transport adapter.
- Unix socket paths belong in runtime/state directories with restrictive permissions and cleanup on shutdown.
- Do not duplicate protocol DTOs per transport; only connection/auth framing should differ.
- If local IPC is added, benchmark latency and throughput against loopback before increasing architecture complexity.

### Single Instance And Port Ownership Need A Guard

A packaged desktop app can accidentally start multiple daemons: double-click, auto-launch, old process after crash, or web UI retry. Rust crates such as `fs4` expose cross-platform file locking, and Windows named pipes also have first-instance behavior. This should be an explicit runtime policy.

Clean Disk rules:

- Decide per mode whether multiple daemon instances are allowed.
- In desktop local mode, prefer a per-user single-instance lock before binding ports or creating named pipes.
- Lock files belong in an OS-appropriate runtime/state directory, not the project root.
- The lock owner should publish connection info for the UI: port/socket name, token discovery path, process id if available, and version.
- If a stale lock is suspected, verify liveness before deleting/replacing it.
- Do not rely only on "port already in use" as the instance guard because another process can own the port.
- On Windows named-pipe transport, first-instance pipe behavior can complement but not replace app-level lifecycle state.

### Axum And Tower Are Transport Adapters

If the first daemon uses Axum, the framework belongs in `interfaces/http_ws` or the server app, not in domain/application crates. Axum's `State`, Tower layers, and graceful shutdown are adapter concerns.

Clean Disk rules:

- Handlers translate HTTP/WebSocket requests into application commands/queries.
- Handlers do not own scan session business rules.
- Use Axum `State` for server composition state and `FromRef`-style substates if it keeps handlers small.
- Use Tower layers for transport concerns: request IDs, tracing, timeouts, body limits, local token validation, origin checks, and CORS if web UI needs it.
- Set explicit request body limits for command endpoints. The local daemon should not accept arbitrary-size JSON by accident.
- Keep large data transfer out of request bodies where possible. Use paginated queries and bounded event batches.
- Do not put delete authorization or stale identity validation purely in middleware. Those are application rules.
- Wire Axum graceful shutdown to application shutdown: stop accepting new work, request session cancellation, drain/close event streams, then dispose resources.

### Transport Capacity Limits Are Part Of The Contract

Tower and tower-http provide standard layers for timeouts, request body limits, concurrency limits, rate limits, and load shedding. For a delete-capable local daemon, these limits are not polish; they are operational safety.

Clean Disk rules:

- Set explicit body limits, timeouts, and concurrency limits for HTTP command/query endpoints.
- Keep scan/delete session operations asynchronous at the application level: starting a scan returns a session handle, then progress is streamed/queried.
- Do not let a single slow request occupy a handler indefinitely.
- Use route-specific limits where needed: small command bodies, larger but still bounded import/export endpoints if those ever exist.
- Treat Tower layer order as part of review because `buffer`, `concurrency_limit`, and timeout order changes behavior.
- Do not use rate limits as a substitute for local token/origin checks or delete confirmation.

### OpenAPI Is Useful For REST, Not The Whole Protocol

Clean Disk's HTTP/WebSocket API needs contracts the Flutter/web UI can rely on. OpenAPI generators such as utoipa or aide can help with REST command/query endpoints, but WebSocket events and domain invariants still need explicit protocol snapshots and tests.

Clean Disk rules:

- Treat OpenAPI as an adapter-level contract artifact, not a source of domain truth.
- Generate or snapshot REST schemas once HTTP routes stabilize enough to matter.
- Keep OpenAPI types mapped from `shared/protocol` DTOs where possible, not from domain models.
- Do not document privileged local endpoints without also documenting local-token/origin expectations.
- WebSocket event envelopes still need JSON snapshot tests because OpenAPI is less natural for event streams.
- Do not add OpenAPI crates before there is a stable route surface to document.

### Trash Is A Platform Operation, Not `remove_dir_all`

Moving to Trash/Recycle Bin is not a cross-platform rename into one universal folder. Linux desktop environments use the FreeDesktop Trash specification, Windows has Recycle Bin semantics, and macOS has its own system behavior. The Rust `trash` crate is a candidate adapter, but it must be audited like any delete-capable dependency.

Clean Disk rules:

- The application layer requests `move_to_trash`, never direct recursive delete.
- Trash adapters return structured results: moved, unsupported, permission denied, already gone, partial failure, path changed, identity mismatch.
- If platform Trash is unsupported for a location, the UI must ask before offering permanent delete or a fallback.
- Moving to Trash may not reclaim bytes immediately, so cleanup result and reclaim estimate stay separate.
- Audit `trash` or any equivalent crate for platform support, active maintenance, unsafe/UB notes, and edge cases before accepting it.
- Tests should include partial failures and "file changed after scan" behavior, not only happy-path moves.

### Permanent Delete Requires Race-Aware Adapters

Rust's standard library documents TOCTOU risk in filesystem operations. `remove_dir_all` has platform protections for symlink races, but Clean Disk should still treat permanent delete as a privileged adapter operation because the selected path, parent path, permissions, and target identity can all change after scan.

Clean Disk rules:

- Permanent delete is a separate adapter from move-to-trash and is never the default action.
- Revalidate selected identity immediately before deletion: path, file type, file identity where available, and stale scan epoch.
- Prefer parent-directory-handle or capability-style operations for destructive work when the platform adapter can support it.
- Consider crates such as `cap-std`, `openat`, or `remove_dir_all` only after auditing platform behavior, dependency health, and exact race guarantees.
- If a directory is changing while deletion runs, return partial/changed-tree results instead of pretending the operation was atomic.
- Tests need hostile fixtures: symlink replacement, parent rename where practical, permission flip, file recreated after scan, and concurrent writer.

### Unsafe And FFI Stay At The Edge

The first implementation should avoid unsafe code. If a platform Trash or filesystem API requires unsafe/FFI later, isolate it.

Clean Disk rules:

- No unsafe in domain/application crates.
- Any unsafe code must live in a small platform adapter module.
- Every unsafe block needs a local safety comment explaining invariants.
- Wrap unsafe APIs with a safe Rust interface before exposing them to the rest of the workspace.
- In Rust 2024, use explicit `unsafe extern` blocks and `#[unsafe(...)]` attributes where required.
- `#[unsafe(no_mangle)]`, `#[unsafe(export_name = "...")]`, and `#[unsafe(link_section = "...")]` need local safety rationale.
- `unsafe fn` means the caller must uphold safety invariants. If the function can validate internally, expose a safe function with a small internal unsafe block instead.
- Enable or respect `unsafe_op_in_unsafe_fn` expectations so unsafe operations remain locally visible.

## API Evolution Rules

Clean Disk is likely to iterate on its daemon protocol and internal crates. Rust can make this safe if we avoid overcommitting public shapes too early.

- Keep most crates internal to the workspace until APIs stabilize.
- Use private fields on public structs.
- Use `#[non_exhaustive]` on public protocol enums/errors that clients may match.
- Seal traits that are not meant for downstream implementation.
- Do not expose unstable third-party types in public APIs.
- Prefer adding new DTO fields in backward-compatible protocol versions.
- Keep generated bindings or client SDKs downstream from `shared/protocol`, not domain.

## Pattern Fit For Clean Disk

Top Rust-specific choices:

1. Type-driven domain API - 🎯 10 🛡️ 10 🧠 5  
   Rough implementation cost: 300-700 LOC once Rust crates exist. Newtypes, enums, smart constructors, typed errors.

2. Dedicated scan workers + bounded channels - 🎯 9 🛡️ 10 🧠 7  
   Rough implementation cost: 500-1200 LOC. Best fit if pdu/scanner work is blocking or CPU/disk intensive.

3. Protocol DTO mapping instead of serde on domain - 🎯 9 🛡️ 9 🧠 6  
   Rough implementation cost: 300-800 LOC. Prevents HTTP/WS/client shape from infecting core models.

4. Object-safe async ports only at coarse boundaries - 🎯 8 🛡️ 8 🧠 6  
   Rough implementation cost: 150-400 LOC. Good for composition roots and session-level IO, bad for per-file hot loops.

5. Sans-IO state machines for protocol/replay logic - 🎯 7 🛡️ 8 🧠 7  
   Rough implementation cost: 300-700 LOC if we build custom protocol state. Useful later, not required for first HTTP/WS routes.

6. Manual DI with composition root and call-site injection - 🎯 9 🛡️ 9 🧠 4  
   Rough implementation cost: 100-300 LOC. Better than a DI framework for the first daemon.

7. Capability-based filesystem adapter for cleanup - 🎯 8 🛡️ 9 🧠 7  
   Rough implementation cost: 400-900 LOC if adopted. Strong safety fit, but must verify cross-platform behavior.

8. Manager task with command enum + bounded mpsc/oneshot - 🎯 8 🛡️ 8 🧠 6  
   Rough implementation cost: 250-700 LOC. Good for session workers/event subscribers, not for every object.

9. Typed index/arena scan tree - 🎯 9 🛡️ 9 🧠 6  
   Rough implementation cost: 400-1000 LOC. Likely best shape for huge scan trees and paginated queries.

10. Snapshot tests for protocol DTOs - 🎯 8 🛡️ 8 🧠 4  
   Rough implementation cost: 100-300 LOC once protocol exists. Good API drift detector.

11. Public API review checklist - 🎯 9 🛡️ 9 🧠 3  
   Rough implementation cost: 50-150 LOC of docs/tests/lints once Rust crates exist. Low cost, high value for protocol and future SDK stability.

12. Dependency supply-chain gate - 🎯 8 🛡️ 9 🧠 5  
   Rough implementation cost: 100-250 LOC of config once Rust exists. Start with `cargo-deny`/RustSec policy, consider `cargo-vet` only when release trust matters.

13. Targeted fuzzing for protocol/path/delete boundaries - 🎯 8 🛡️ 8 🧠 6  
   Rough implementation cost: 200-600 LOC once DTOs and validators exist. High value for inputs that can be weird or hostile.

14. Miri for unsafe/FFI wrappers only - 🎯 7 🛡️ 8 🧠 5  
   Rough implementation cost: 50-200 LOC if unsafe appears. Not useful for the whole daemon, very useful for tiny unsafe edges.

15. Explicit Serde compatibility policy - 🎯 9 🛡️ 9 🧠 4  
   Rough implementation cost: 100-250 LOC across DTO attributes and tests. Prevents accidental client/server breakage.

16. Two-level benchmarking strategy - 🎯 9 🛡️ 8 🧠 6  
   Rough implementation cost: 300-900 LOC once Rust scanner exists. Macro benchmarks answer product performance, microbenchmarks protect hot algorithms.

17. Cancellation-safe async session lifecycle - 🎯 9 🛡️ 9 🧠 7  
   Rough implementation cost: 300-800 LOC. Prevents half-cancelled scans, lost event batches, and stuck session workers.

18. Task panic supervision - 🎯 8 🛡️ 9 🧠 5  
   Rough implementation cost: 150-400 LOC. Every worker panic becomes failed session state and traceable diagnostics.

19. Send/Sync assertion tests for public services - 🎯 8 🛡️ 8 🧠 3  
   Rough implementation cost: 50-120 LOC. Cheap guard against accidental `Rc`/`RefCell` or non-thread-safe handles entering server state.

20. Rust 2024 workspace policy - 🎯 8 🛡️ 8 🧠 4  
   Rough implementation cost: 50-150 LOC in Cargo manifests once Rust exists. Better defaults for resolver/MSRV/lints if tooling supports it cleanly.

21. FFI/unsafe adapter quarantine - 🎯 9 🛡️ 10 🧠 6  
   Rough implementation cost: 100-400 LOC if platform APIs require unsafe. Critical for Trash APIs and OS-specific integrations.

22. Mutation testing for safety-critical core - 🎯 8 🛡️ 8 🧠 5  
   Rough implementation cost: 50-200 LOC config plus runtime cost in CI. Best for delete safety, state machines, and query invariants.

23. Dependency hygiene checks - 🎯 8 🛡️ 8 🧠 4  
   Rough implementation cost: 50-150 LOC config once Rust exists. Use `cargo-machete` periodically, `cargo-udeps` selectively, and manual feature review.

24. Fakes over strict mocks - 🎯 9 🛡️ 8 🧠 4  
   Rough implementation cost: 100-300 LOC in test support. Keeps tests behavioral and protects port/adapter design from mock-driven abstractions.

25. Runtime-configurable tracing filters - 🎯 8 🛡️ 8 🧠 3  
   Rough implementation cost: 50-150 LOC in server bootstrap. Useful for debugging real user scans without recompiling or flooding logs.

26. Cross-platform file identity revalidation - 🎯 9 🛡️ 10 🧠 7  
   Rough implementation cost: 250-700 LOC across domain value objects, platform adapters, and delete safety tests. Critical for safe cleanup.

27. Compile-fail tests for type-level safety - 🎯 7 🛡️ 8 🧠 5  
   Rough implementation cost: 80-250 LOC once public contracts exist. Useful for confirmation tokens and builders, not for every private type.

28. Sandboxed filesystem test fixtures - 🎯 9 🛡️ 9 🧠 4  
   Rough implementation cost: 150-400 LOC test support. Essential before testing scan/delete behavior.

29. Axum/Tower as transport adapter only - 🎯 9 🛡️ 8 🧠 5  
   Rough implementation cost: 200-600 LOC in `interfaces/http_ws` and server bootstrap. Keeps Clean Architecture intact.

30. Public API diff checks after stabilization - 🎯 7 🛡️ 8 🧠 4  
   Rough implementation cost: 50-200 LOC CI/test setup when SDK/protocol crates become stable. Not needed for early internal crates.

31. Must-use safety markers - 🎯 8 🛡️ 8 🧠 3  
   Rough implementation cost: 20-80 LOC across core types/builders. Cheap guard against ignored confirmation tokens, query cursors, and validation results.

32. Precise protocol decode paths - 🎯 8 🛡️ 8 🧠 4  
   Rough implementation cost: 80-200 LOC in protocol adapters/tests. Makes UI/server diagnostics sharper without coupling domain to Serde.

33. Proptest regression persistence - 🎯 8 🛡️ 8 🧠 4  
   Rough implementation cost: 50-150 LOC in test config and regression fixtures. Good for tree/query/delete invariants once those exist.

34. Nextest profiles for CI and slow tests - 🎯 8 🛡️ 8 🧠 4  
   Rough implementation cost: 80-220 LOC of config/scripts once Rust tests grow. Useful later, not required for the first skeleton.

35. Panic strategy policy - 🎯 8 🛡️ 9 🧠 3  
   Rough implementation cost: 20-80 LOC of manifest/bootstrap/docs. Important because daemon panics should become observable failures, not silent session loss.

36. Auditable lint suppression policy - 🎯 8 🛡️ 8 🧠 2  
   Rough implementation cost: 20-80 LOC of lint config and local attributes. Keeps Clippy strictness useful without creating warning fatigue.

37. Cancellation tokens plus task tracking - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 150-400 LOC in session runtime. Strong fit for scan cancel, daemon shutdown, and WebSocket disconnect handling.

38. Clippy disallowed API fence - 🎯 8 🛡️ 8 🧠 4  
   Rough implementation cost: 40-140 LOC of config plus local exceptions. Good for destructive filesystem calls and unsupervised process exits.

39. Doctested public examples - 🎯 7 🛡️ 7 🧠 3  
   Rough implementation cost: 80-250 LOC once public crates exist. Useful for `shared/protocol` and future SDK ergonomics, not urgent before APIs stabilize.

40. Xtask for cross-platform Rust automation - 🎯 7 🛡️ 7 🧠 5  
   Rough implementation cost: 150-500 LOC if workspace automation grows. Optional, but better than brittle shell scripts for boundary checks and release tasks.

41. Secret local daemon token type - 🎯 8 🛡️ 9 🧠 4  
   Rough implementation cost: 80-220 LOC in transport/security adapters. Important if web UI controls local delete-capable daemon.

42. Explicitly tagged protocol enums - 🎯 9 🛡️ 8 🧠 3  
   Rough implementation cost: 50-180 LOC across DTO definitions and snapshots. Better diagnostics and compatibility than untagged command/event protocols.

43. Platform adapter isolation with target-specific dependencies - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 150-450 LOC once Trash/file-identity adapters exist. Keeps macOS/Windows/Linux behavior explicit without leaking OS concerns inward.

44. `#[track_caller]` for invariant helpers - 🎯 7 🛡️ 7 🧠 2  
   Rough implementation cost: 10-50 LOC. Useful for developer diagnostics in assertions/tests, not user-facing error handling.

45. Borrowed/internal views for large-tree hot paths - 🎯 8 🛡️ 8 🧠 5  
   Rough implementation cost: 100-400 LOC when scan indexes exist. Reduces clone storms without pushing lifetimes into protocol DTOs.

46. Release profile policy - 🎯 8 🛡️ 8 🧠 4  
   Rough implementation cost: 40-160 LOC of Cargo/profile/release docs. Important for installer size, crash diagnostics, and beta builds.

47. Boundary-only tracing instrumentation - 🎯 8 🛡️ 8 🧠 3  
   Rough implementation cost: 60-180 LOC in server/session/delete adapters. Good observability without drowning hot scanner loops.

48. Separate CPU-bound work budget - 🎯 8 🛡️ 8 🧠 5  
   Rough implementation cost: 120-350 LOC if profiling shows CPU-heavy sorting/search/indexing. Prevents Tokio IO/control-plane threads and scanner pools from fighting each other.

49. `OnceLock`/`LazyLock` for immutable statics only - 🎯 8 🛡️ 8 🧠 2  
   Rough implementation cost: 10-80 LOC. Removes unnecessary lazy-init dependencies while keeping session/app state out of globals.

50. Immutable read-model snapshots - 🎯 7 🛡️ 8 🧠 6  
   Rough implementation cost: 150-500 LOC if query contention appears. ArcSwap-style adapters are a candidate for completed scan summaries and published tree snapshots.

51. Explicit HTTP body limits - 🎯 9 🛡️ 9 🧠 3  
   Rough implementation cost: 40-140 LOC in `interfaces/http_ws`. Important for local daemon hardening even when the client is local UI.

52. OpenAPI for stable REST contracts - 🎯 7 🛡️ 7 🧠 5  
   Rough implementation cost: 150-500 LOC once routes stabilize. Useful for REST command/query docs, not a replacement for WebSocket event snapshots.

53. Direct minimal dependency version checks after stabilization - 🎯 6 🛡️ 7 🧠 5  
   Rough implementation cost: 40-160 LOC of CI/config for public crates. Useful later for SDK/library promises, not for early app-only crates.

54. Channel semantics for event streams - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 120-350 LOC in session/event runtime. Separates latest-state progress from durable events and handles slow WebSocket clients deliberately.

55. Deterministic output ordering - 🎯 9 🛡️ 8 🧠 3  
   Rough implementation cost: 40-160 LOC across read models/tests. Prevents flaky snapshots and confusing CLI/protocol diffs.

56. Transport capacity limits - 🎯 9 🛡️ 9 🧠 4  
   Rough implementation cost: 80-240 LOC in HTTP adapter config/tests. Adds explicit timeout/concurrency/body limits without touching domain rules.

57. Shared buffers at protocol boundary only - 🎯 7 🛡️ 7 🧠 4  
   Rough implementation cost: 40-180 LOC if profiling shows protocol buffer clone pressure. Useful later, but not a core domain pattern.

58. Lock-free/crossbeam only after profiling - 🎯 8 🛡️ 8 🧠 6  
   Rough implementation cost: 150-500 LOC plus stress tests if adopted. Strong tools for proven hot paths, bad default architecture.

59. Lock poisoning policy - 🎯 8 🛡️ 9 🧠 4  
   Rough implementation cost: 80-240 LOC in session/runtime error handling. Prevents poisoned scan/delete state from being ignored or panic-unwrapped.

60. UTF-8 path types only at validated boundaries - 🎯 9 🛡️ 9 🧠 3  
   Rough implementation cost: 40-160 LOC in adapters/tests if `camino` is adopted. Protects arbitrary filesystem scans from accidental UTF-8 assumptions.

61. Binary protocol formats only after profiling - 🎯 8 🛡️ 8 🧠 6  
   Rough implementation cost: 200-700 LOC if adopted later. JSON remains better for first HTTP/WS protocol, diagnostics, and web compatibility.

62. Compile-time hygiene based on Cargo timings - 🎯 8 🛡️ 7 🧠 4  
   Rough implementation cost: 40-180 LOC of docs/config plus CI cache setup if needed. Helps Rust workspace scale without premature build tooling.

63. Human diagnostics only at binary/report boundaries - 🎯 8 🛡️ 8 🧠 3  
   Rough implementation cost: 60-200 LOC if CLI/dev tools need rich reports. Keeps protocol/domain errors structured and UI-friendly.

64. Multiple disk-size metrics - 🎯 10 🛡️ 10 🧠 6  
   Rough implementation cost: 200-600 LOC across domain value objects, platform adapters, protocol DTOs, and UI labels. Critical because apparent size, allocated size, and reclaim estimate are different facts.

65. Reclaim estimate confidence model - 🎯 9 🛡️ 9 🧠 6  
   Rough implementation cost: 150-500 LOC across cleanup/domain/protocol. Prevents the UI from promising exact freed bytes before Trash/delete actually happens.

66. Explicit traversal policy - 🎯 9 🛡️ 9 🧠 6  
   Rough implementation cost: 250-700 LOC in scanner options, adapter mapping, tests, and protocol. Controls symlinks, reparse points, mount boundaries, hidden/filter behavior, threads, and open-FD pressure.

67. macOS access capability flow - 🎯 9 🛡️ 9 🧠 7  
   Rough implementation cost: 250-800 LOC across desktop packaging, platform adapter, UI remediation, and tests. Essential if the app scans protected user folders cleanly.

68. Windows reparse-point classification - 🎯 8 🛡️ 9 🧠 7  
   Rough implementation cost: 200-700 LOC in platform filesystem adapter and Windows tests. Prevents junction/symlink loops and wrong delete target semantics.

69. Trash operation as first-class adapter - 🎯 10 🛡️ 10 🧠 6  
   Rough implementation cost: 250-800 LOC across cleanup application, platform adapter, protocol, and failure tests. Critical because direct delete is the riskiest feature in the product.

70. APFS-aware space confidence - 🎯 9 🛡️ 9 🧠 6  
   Rough implementation cost: 150-500 LOC across platform capability flags, metrics, and UI explanations. APFS clones, snapshots, sparse files, and space sharing make exact reclaim claims unsafe.

71. Volume free-space adapter - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 150-450 LOC across platform adapters/protocol. Separates capacity, total free, and user-available free bytes with timestamps and volume identity.

72. Incremental watchers as invalidation hints - 🎯 8 🛡️ 8 🧠 7  
   Rough implementation cost: 300-900 LOC if added later. Useful for refresh UX, but correctness still comes from scans and stale identity revalidation.

73. Case/Unicode-aware search index - 🎯 8 🛡️ 8 🧠 5  
   Rough implementation cost: 150-500 LOC in search/read-model adapters. Keeps fuzzy/user-friendly search separate from authoritative path identity.

74. Bounded top-K indexes - 🎯 9 🛡️ 8 🧠 5  
   Rough implementation cost: 150-450 LOC in scan aggregation/read models. Avoids full global sorts for largest files/folders while keeping deterministic display order.

75. Scan epoch and stale-result model - 🎯 10 🛡️ 9 🧠 6  
   Rough implementation cost: 200-700 LOC across scan domain/application/protocol/UI. Makes changing files during scan explicit instead of hiding consistency gaps.

76. Metadata flavor as explicit policy - 🎯 10 🛡️ 10 🧠 5  
   Rough implementation cost: 150-450 LOC across scanner options, platform adapters, DTOs, and tests. Prevents symlink/reparse-point target confusion and delete-intent drift.

77. Timestamp as weak evidence - 🎯 9 🛡️ 9 🧠 3  
   Rough implementation cost: 60-180 LOC across metadata value objects and stale-check rules. Keeps mtime/ctime useful without pretending they are identity.

78. macOS bundle/package presentation policy - 🎯 8 🛡️ 8 🧠 5  
   Rough implementation cost: 120-400 LOC in platform classification, protocol flags, and UI tree behavior. Lets scanner stay filesystem-correct while UI matches Finder expectations.

79. Extended attribute/resource-fork handling - 🎯 7 🛡️ 8 🧠 6  
   Rough implementation cost: 150-500 LOC if we expose xattr details. Useful for diagnostics and accounting confidence, but not necessary for first cleanup MVP.

80. Explainable cleanup recommendation rules - 🎯 10 🛡️ 9 🧠 6  
   Rough implementation cost: 250-800 LOC across recommendation policies, rule ids, protocol DTOs, and tests. Critical for trust: candidates need evidence, confidence, and inspectability.

81. Privacy-preserving delete receipts - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 150-450 LOC across cleanup application, local storage/protocol, and redaction tests. Gives users accountability without leaking private paths into logs/telemetry.

82. Fallible directory iteration model - 🎯 10 🛡️ 9 🧠 4  
   Rough implementation cost: 120-350 LOC across scanner events, skip reasons, and deterministic traversal tests. Prevents permission/read errors from aborting large scans.

83. Traversal adapter default audit - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 150-450 LOC across adapter config, policy snapshots, and crate-upgrade tests. Prevents hidden filters, root-symlink behavior, and FD limits from becoming accidental product behavior.

84. I/O error taxonomy mapping - 🎯 9 🛡️ 9 🧠 4  
   Rough implementation cost: 100-300 LOC across adapter error mapping and tests. Keeps platform errors machine-actionable without string-matching OS messages.

85. Memory budget and fallible growth - 🎯 9 🛡️ 9 🧠 6  
   Rough implementation cost: 200-700 LOC across scan session budgets, tree/index allocation paths, protocol failures, and memory benchmarks. Important for million-node scans.

86. Durable local-state classes - 🎯 8 🛡️ 9 🧠 5  
   Rough implementation cost: 150-500 LOC across storage adapters, project dirs, format versioning, and atomic-ish write tests. Separates rebuildable cache from receipts/preferences.

87. Browser-to-local-daemon hardening - 🎯 10 🛡️ 10 🧠 6  
   Rough implementation cost: 250-800 LOC across HTTP/WS adapter, origin/token checks, CORS policy, and tests. Critical because the local daemon can start scans and move files to Trash.

88. Windows long-path packaging policy - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 100-350 LOC across installer manifest, platform path adapter, display mapping, and Windows tests. Prevents false scan/delete failures in deeply nested folders.

89. Composition-root shutdown controller - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 150-450 LOC across server bootstrap, signal handling, task tracking, terminal events, and shutdown tests. Keeps cancellation and persistence disciplined.

90. Transport-neutral IPC adapters - 🎯 8 🛡️ 8 🧠 6  
   Rough implementation cost: 250-900 LOC if added after HTTP/WS. Useful for desktop packaging via Unix sockets/named pipes, but only after browser-compatible loopback transport is solid.

91. Single-instance daemon guard - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 120-400 LOC across runtime lock file, connection-info discovery, stale-lock checks, and platform tests. Prevents duplicate daemons and confusing UI attachment.

92. Rust lockfile release policy - 🎯 9 🛡️ 9 🧠 3  
   Rough implementation cost: 20-120 LOC of repo policy/CI config once Rust exists. Important for reproducible installer builds and auditability.

93. Windows stream/ADS accounting policy - 🎯 8 🛡️ 8 🧠 7  
   Rough implementation cost: 200-700 LOC across Windows filesystem adapter, protocol flags, UI labels, and fixtures. Important for honest Windows "size on disk" claims.

94. Permission capability model - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 120-400 LOC across platform metadata DTOs, delete checks, and tests. Prevents readonly/ACL/mode-bit confusion and dangerous permission "fixes".

95. Scanner-owned blocking IO budget - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 150-450 LOC across session runtime, scanner adapter wiring, and benchmarks. Keeps Tokio HTTP/WebSocket runtime responsive during large scans.

96. Atomic local write commit policy - 🎯 8 🛡️ 9 🧠 5  
   Rough implementation cost: 120-400 LOC across local state adapters and crash/recovery tests. Separates partial-write prevention from true crash durability.

97. Race-aware permanent delete adapter - 🎯 10 🛡️ 10 🧠 8  
   Rough implementation cost: 300-1000 LOC across cleanup application, platform adapters, identity revalidation, and hostile filesystem tests. Critical if permanent delete is ever exposed.

98. Permit-based resource budgets - 🎯 9 🛡️ 9 🧠 4  
   Rough implementation cost: 80-260 LOC across runtime config, session manager, and cancellation tests. Keeps scan/session/job limits explicit without abusing locks.

99. `select!` fairness and priority policy - 🎯 8 🛡️ 8 🧠 4  
   Rough implementation cost: 60-220 LOC across event loops and tests. Prevents hot progress streams from starving cancellation/shutdown paths.

100. WebSocket buffer and liveness policy - 🎯 9 🛡️ 9 🧠 5  
   Rough implementation cost: 150-500 LOC across transport adapter, per-client queues, close/resync behavior, and tests. Important for long scans, background tabs, and slow clients.

101. Compile-time code execution review - 🎯 9 🛡️ 9 🧠 4  
   Rough implementation cost: 60-200 LOC of dependency policy/CI checks. Treats `build.rs` and proc macros as supply-chain risk before installer releases.

What not to do:

- Do not make all state `Arc<Mutex<HashMap<...>>>` from route handlers.
- Do not put `serde` on every domain type for convenience.
- Do not use `String` as authoritative path identity.
- Do not use unbounded channels for scan progress.
- Do not expose external crate types in stable inner-layer APIs.
- Do not use `unwrap()` as normal control flow in daemon code.
- Do not introduce unsafe or FFI outside tiny platform adapters.
- Do not create traits for every struct just to look like SOLID.
- Do not use boxed async trait calls in scanner per-entry hot paths.
- Do not optimize large-tree storage before profiling real scans.
- Do not add a DI container before manual composition becomes painful.
- Do not let raw protocol paths call `std::fs` destructive operations.
- Do not spawn untracked background tasks.
- Do not model the scan tree as nested `Rc<RefCell<Node>>`.
- Do not expose internal numeric vector indexes as meaningful protocol IDs.
- Do not snapshot massive scan results instead of focused protocol/read-model examples.
- Do not hide fallible or blocking work inside `Drop`.
- Do not add dependencies without a reason, owner, and security/license check.
- Do not use `#[serde(deny_unknown_fields)]` on forward-compatible response/event DTOs.
- Do not benchmark only synthetic tiny trees and then claim scanner performance.
- Do not make `cargo-vet` mandatory before there is a real release/security need.
- Do not fuzz the whole async daemon instead of small deterministic boundaries.
- Do not rely on dropping futures or `JoinHandle` values as session shutdown.
- Do not leave task panics unobserved.
- Do not let `Rc<RefCell<_>>` enter async server/session state.
- Do not use unsafe FFI attributes without Rust 2024-style safety rationale.
- Do not trust coverage alone for delete safety.
- Do not add mocks that only verify private call order.
- Do not keep unused dependencies because "Cargo will optimize it away".
- Do not enable broad dependency features without checking what they pull in.
- Do not log every scanned path at info/debug level in normal operation.
- Do not delete based on path, size, and mtime alone when stronger file identity is available.
- Do not run filesystem tests against real user directories.
- Do not let Axum handlers become use-case implementations.
- Do not make public API diff tooling a substitute for wire protocol compatibility tests.
- Do not add `#[must_use]` to everything until the warning signal becomes noise.
- Do not respond to nested protocol decode failures with only generic "bad request" diagnostics.
- Do not use `catch_unwind` as normal application error handling.
- Do not switch to `panic = "abort"` for the daemon before crash/restart policy is explicit.
- Do not hide flaky tests behind retries without tracking the underlying cause.
- Do not leave local lint `allow` attributes without a reason.
- Do not use shared `AtomicBool` flags as the primary cancellation design for session lifecycles.
- Do not put public command/event protocols behind ambiguous `#[serde(untagged)]` enums.
- Do not let local daemon auth tokens appear in `Debug`, logs, snapshots, or protocol error payloads.
- Do not add `xtask` before a normal Cargo command or small script becomes insufficient.
- Do not rely on docs examples that are not compiled or tested once APIs become public.
- Do not scatter platform `cfg` blocks through domain/application use cases.
- Do not add every OS-specific dependency to every target when Cargo target-specific dependencies can isolate them.
- Do not use `#[track_caller]` to avoid returning proper typed errors.
- Do not optimize clones with lifetime-heavy APIs before measuring memory pressure.
- Do not instrument per-file scanner hot loops with verbose tracing spans in normal builds.
- Do not strip all useful release diagnostics before crash reporting policy is clear.
- Do not run CPU-heavy sorting/indexing directly on async request handlers.
- Do not stack full-size Tokio, pdu, and Rayon pools without a thread budget.
- Do not hide mutable app/session state in `OnceLock` or `LazyLock`.
- Do not introduce ArcSwap/read-mostly snapshot crates before measuring read contention.
- Do not disable HTTP body limits just because the daemon listens on localhost.
- Do not treat OpenAPI as the contract for WebSocket event streams.
- Do not make full transitive `-Z minimal-versions` a mandatory workspace gate.
- Do not use `broadcast` without a `Lagged`/slow-client policy.
- Do not serialize or snapshot `HashMap` output without explicit ordering when diffs matter.
- Do not expose `Bytes`, `Arc<[T]>`, or Crossbeam types from domain/application APIs.
- Do not add lock-free queues because locks feel uncool. Measure first.
- Do not add Tower limits in a random layer order without reviewing behavior.
- Do not `unwrap()` poisoned locks protecting session/delete state.
- Do not switch from std locks to `parking_lot` without documenting the no-poisoning tradeoff.
- Do not use UTF-8-only path types for arbitrary scanned filesystem paths.
- Do not replace JSON protocol with bincode/postcard/rkyv before measuring a real bottleneck.
- Do not require sccache/cargo-chef before Cargo timings show compile-time pain.
- Do not let miette/eyre/color-eyre types cross application or protocol boundaries.
- Do not present apparent file size as exact disk usage.
- Do not present estimated queued cleanup bytes as guaranteed freed disk space.
- Do not follow symlinks, Windows reparse points, or cross mount boundaries by accident.
- Do not silently hide scan entries through ignore filters in a disk usage product.
- Do not treat macOS permission denied as an unexpected crash path.
- Do not delete a Windows reparse point target when the user selected the link itself.
- Do not use direct recursive delete as the default cleanup path.
- Do not treat filesystem watchers or journals as a complete replacement for scanning.
- Do not show free-space deltas without saying whether they are sampled, estimated, user-available, or total free.
- Do not lowercase or Unicode-normalize authoritative filesystem identity.
- Do not globally sort millions of nodes when a bounded top-K index answers the UI query.
- Do not pretend one scan is a perfectly consistent transaction over a changing filesystem.
- Do not use `metadata()` when the product question is about the symlink or reparse point itself.
- Do not canonicalize a user path and treat the resolved target as the selected delete identity.
- Do not use timestamps as unique identity or as an exact stale-data proof.
- Do not flatten macOS bundles/packages in the UI without making delete scope clear.
- Do not strip xattrs, quarantine markers, tags, or resource-fork metadata as a generic cleanup feature.
- Do not recommend deletion based only on folder name or size.
- Do not export delete history with raw private paths, local daemon tokens, or request headers.
- Do not `unwrap()` `read_dir` entries during scanning.
- Do not rely on filesystem iteration order for UI pagination, snapshots, or tests.
- Do not accept traversal crate defaults without snapshotting the effective policy.
- Do not let `.gitignore`, hidden-file, or max-size filters silently hide disk usage.
- Do not string-match `io::Error` display text for control flow.
- Do not let huge arena/index growth panic the daemon when a typed resource-exhausted session failure is possible.
- Do not store app cache, preferences, receipts, runtime tokens, and sockets in one generic folder.
- Do not expose a delete-capable local daemon with wildcard CORS or tokens in URLs.
- Do not assume Windows paths fit legacy `MAX_PATH`.
- Do not expose verbatim Windows paths as normal user-facing labels when a friendlier display path is available.
- Do not put OS signal handling inside domain/application services.
- Do not add Unix sockets/named pipes before HTTP/WebSocket contracts are stable enough to reuse.
- Do not rely on port collisions alone as a desktop single-instance strategy.
- Do not release Rust binaries from an unreviewed fresh dependency resolution.
- Do not use `tokio::fs` per entry and assume the scan became nonblocking.
- Do not call `set_readonly(false)` as a generic cleanup unlock operation.
- Do not claim exact Windows size-on-disk totals if alternate streams or sparse/compressed accounting were not handled.
- Do not treat temp-file rename as proof that delete receipts survived power loss.
- Do not expose permanent recursive delete without race-aware identity revalidation and hostile filesystem tests.
- Do not use a mutex as a hidden concurrency limit when a semaphore/permit models the resource directly.
- Do not use `biased;` `select!` without documenting branch priority and cancellation behavior.
- Do not let one slow WebSocket client grow an unbounded queue during a scan.
- Do not treat `build.rs` or proc macros as harmless metadata dependencies.
