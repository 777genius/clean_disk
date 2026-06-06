# Clean Disk

Universal Flutter workspace for a disk usage analyzer and cleanup tool.

## Core Rule

Контракты проектируем как Pro, реализацию делаем как MVP.

Public, domain, protocol, and storage contracts must preserve the future shape of the product: segmented snapshots, multiple scanner backends, daemon/helper execution, web/remote read-only mode, scan history, safe cleanup, and versioned DTOs. The first implementation should stay deliberately small: single pdu-backed scan, one segment, lazy metadata, paginated queries, and no future feature pulled forward without a gate.

## Stack

- Flutter `3.41.9` through FVM.
- Dart workspaces + Melos.
- Feature micro-packages.
- Clean Architecture + Hexagonal Ports & Adapters.
- Simple DDD in feature domain layers.
- Modularity for feature lifecycle and scoped DI.
- GetIt for app-level composition.
- Drift through `drift_flutter` for local cache.
- Abstract HTTP client contracts with Dio infrastructure adapter when backend APIs are needed.
- UI through `packages/design_system`, which wraps Headless/Material primitives.

The native scanner is intentionally not wired yet. When added, Rust/pdu/flutter bridge details must sit behind application ports, not inside domain or presentation.

## Structure

```text
apps/clean_disk              # universal Flutter app shell for desktop and web
features/scan               # scan feature package and public UI entry point
packages/core               # Result, Failure, config, base contracts
packages/cache              # Drift cache infrastructure
packages/design_system      # app UI facade over Headless/Material primitives
packages/network            # app HTTP factory behind abstract contracts
packages/abstract_http_client # vendored HTTP contracts
packages/dio_http_client    # vendored Dio implementation
```

## Commands

Run commands from the repository root:

```sh
fvm dart pub get
fvm flutter analyze
fvm dart run melos run test
```

Code generation, when needed:

```sh
fvm dart run melos run codegen
```

Scan-only macOS packaging checks:

```sh
cargo build --release -p clean-disk-server
(cd apps/clean_disk && fvm flutter build macos --release)
apps/clean_disk/macos/scripts/smoke_scan_only_bundle.sh --allow-unsigned-presign "apps/clean_disk/build/macos/Build/Products/Release/Clean Disk.app"
apps/clean_disk/macos/scripts/verify_scan_only_release.sh "apps/clean_disk/build/macos/Build/Products/Release/Clean Disk.app"
```
