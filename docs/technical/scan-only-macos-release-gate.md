# Scan-Only macOS Release Gate

This gate validates the Phase 11 scan-only macOS release artifact. It is not a signing or notarization replacement. It fails unless a real release `.app` already has the required evidence.

Before signing, use the local bundle smoke to prove the Release app contains the intended helper identity shape:

```sh
cargo build --release -p clean-disk-server
(cd apps/clean_disk && fvm flutter build macos --release)
apps/clean_disk/macos/scripts/smoke_scan_only_bundle.sh --allow-unsigned-presign "apps/clean_disk/build/macos/Build/Products/Release/Clean Disk.app"
```

The pre-sign smoke may accept exactly one helper failure, `unsigned_build`. Any `development_shell`, `debug_build`, `external_scanner_process`, missing helper, or helper outside `Contents/Helpers` failure still blocks the artifact before signing.

Run from the repository root after building, signing, notarizing, and stapling the macOS app:

```sh
apps/clean_disk/macos/scripts/verify_scan_only_release.sh "apps/clean_disk/build/macos/Build/Products/Release/Clean Disk.app"
```

Required evidence:

- app bundle exists as `.app`;
- `Contents/Helpers/clean-disk-server` exists and is executable;
- app and helper pass strict code signature verification;
- app and helper use a real `TeamIdentifier`;
- app and helper are signed with `Developer ID Application`;
- app and helper include hardened runtime evidence;
- app and helper share the same `TeamIdentifier`;
- Gatekeeper assessment passes;
- stapled notarization ticket validates;
- bundled helper `--scan-only-packaging-smoke` passes.

Expected failures:

- Debug or ad-hoc builds fail.
- Unsigned helper fails.
- Helper outside `Contents/Helpers` fails.
- Missing stapled notarization ticket fails.
- A helper signed by a different team fails.

This gate exists because Full Disk Access and future cleanup preflight depend on the scanner process identity. A debug build may be useful for development, but it must not be used as release evidence for permission behavior.
