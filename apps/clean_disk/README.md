# Clean Disk App

`apps/clean_disk` is the Clean Disk Flutter application shell and composition root.

Responsibilities:

- Read runtime configuration.
- Register app-level services in GetIt.
- Mount feature modules through Modularity scopes.
- Own top-level routing through GoRouter.
- Wrap the app with `AppHeadlessScope` and `AppTheme`.

Feature packages should not read Dart defines or global GetIt directly. They expose modules, pages, use cases, adapters, and contracts; `apps/clean_disk` decides which concrete implementation is used.

Run from repository root:

```sh
fvm flutter analyze
fvm dart run melos run test
```
