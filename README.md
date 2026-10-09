# Clean Disk

A fast, cross-platform disk usage analyzer and cleanup app built with **Flutter + Rust**. Find what takes up space, explore folders and files, and review cleanup targets.

<img width="1306" height="749" alt="Clean Disk desktop interface with a folder tree and disk usage visualization" src="https://github.com/user-attachments/assets/5beb9b31-4a91-480e-8f35-f843314378ef" />

## Availability

This repository contains the source code. There is no hosted app or published installer yet. Build and run it locally.

The project includes macOS, Windows, and Linux app shells. Platform support and permissions depend on the local build; macOS packaging checks are included in the repository.

## How it works

- **Flutter UI:** browse scan results, inspect disk usage maps, and review cleanup targets.
- **Rust scanner:** uses `parallel-disk-usage` through a dedicated adapter for parallel filesystem scanning.
- **Local server:** `clean-disk-server` handles scan sessions, paginated queries, progress events, and cleanup operations. Flutter connects over HTTP and WebSocket.
- **Cleanup:** explicit review and confirmation, with current target validation and a platform trash adapter.

The full scan tree stays in Rust. Flutter requests pages of results instead of loading the entire tree into the UI.

## Build and run

### Requirements

- [FVM](https://fvm.app/) with Flutter **3.41.9** (`.fvmrc`).
- Rust **1.95 or newer** and Cargo.
- The native build tools required by Flutter for your desktop platform.
- The sibling source dependencies referenced by `pubspec.yaml`: [Flutter Headless](https://github.com/777genius/flutter_headless) at `../headless` and [Fast Build Runner](https://github.com/777genius/fast_build_runner) at `../fast_build_runner`.

Resolve dependencies from the repository root:

```sh
fvm install
fvm dart pub get
```

Start the Rust server in one terminal:

```sh
export CLEAN_DISK_LOCAL_AUTH_TOKEN="$(openssl rand -hex 32)"
cargo run --release -p clean-disk-server
```

In a second terminal, set `CLEAN_DISK_LOCAL_AUTH_TOKEN` to the same value, then start the UI:

```sh
cd apps/clean_disk
fvm flutter run -d macos
```

Use `-d windows` or `-d linux` for the corresponding desktop target. The default server address is `http://127.0.0.1:17631`; override it with `--dart-define=CLEAN_DISK_DAEMON_BASE_URL=...` if needed.

To preview the UI without a Rust server or real filesystem scanning:

```sh
cd apps/clean_disk
fvm flutter run -d macos --dart-define=CLEAN_DISK_SCAN_BACKEND=fake
```

## Development

Run checks from the repository root:

```sh
fvm flutter analyze
fvm dart run melos run test
cargo test --workspace
```

When code generation is needed:

```sh
fvm dart run melos run codegen
```

## Project structure

```text
apps/clean_disk          Flutter desktop and web UI
apps/clean_disk_server   Local Rust server
features/scan            Scan feature and application contracts
rust/crates/fs_usage_*   Scanner, query engine, and platform adapters
rust/crates/clean_disk_protocol  Shared protocol types
packages/                Design system, localization, cache, and networking
```

See the [technical documentation](docs/technical/README.md) for architecture, platform behavior, and implementation details.

## License

Clean Disk's original code is licensed under the [MIT License](LICENSE). Third-party code, fonts, and dependencies retain their own licenses. The current disk usage map renderer uses Syncfusion, which has separate licensing requirements; the project's MIT license does not grant a Syncfusion license.
