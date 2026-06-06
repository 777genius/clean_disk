import 'package:clean_disk_app/src/bootstrap/path_revealer_io.dart';
import 'package:clean_disk_app/src/bootstrap/scan_target_catalog_io.dart';
import 'package:clean_disk_app/src/bootstrap/scan_target_preferences_io.dart';
import 'package:clean_disk_cache/clean_disk_cache.dart';
import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cache target preferences save and load target through Drift cache',
    () async {
      final database = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(database.close);
      final store = CacheScanTargetPreferenceStore(() => database);
      final target = ScanTarget(
        path: ScanTargetPath('/Users/belief'),
        scope: TargetScope.localPath,
        boundaryPolicy: BoundaryPolicy.crossFilesystems,
        hardlinkPolicy: HardlinkPolicy.detect,
      );

      final saveResult = await store.saveLastTarget(target);
      final loadResult = await store.loadLastTarget();

      expect(saveResult, const Result<Unit>.success(Unit.value));
      final loaded = (loadResult as ResultSuccess<ScanTarget?>).value;
      expect(loaded?.path.value, '/Users/belief');
      expect(loaded?.scope, TargetScope.localPath);
      expect(loaded?.boundaryPolicy, BoundaryPolicy.crossFilesystems);
      expect(loaded?.hardlinkPolicy, HardlinkPolicy.detect);
    },
  );

  test('cache target preferences fail closed on invalid saved JSON', () async {
    final database = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(database.close);
    final store = CacheScanTargetPreferenceStore(() => database);
    await database.putCacheEntry(key: 'scan.target.last.v1', value: '[]');

    final result = await store.loadLastTarget();

    final failure = (result as ResultFailure<ScanTarget?>).failure;
    expect(failure, isA<CacheFailure>());
    expect(failure.message, 'Saved scan target is invalid');
  });

  test(
    'local target catalog maps sandbox home and dedupes macOS volumes',
    () async {
      final catalog = LocalScanTargetCatalog(
        environment: const {
          'HOME': '/Users/belief/Library/Containers/dev.clean-disk/Data',
          'USER': 'belief',
        },
        isMacOS: true,
        isWindows: false,
        directoryExists: const {
          '/Users/belief',
          '/Users/belief/Downloads',
          '/',
        }.contains,
        volumePaths: () => const ['/Volumes/Data', '/Volumes/Data'],
      );

      final result = await catalog.listChoices();

      final choices = (result as ResultSuccess<List<ScanTargetChoice>>).value;
      expect(choices.map((choice) => choice.target.path.value), [
        '/Users/belief',
        '/Users/belief/Downloads',
        '/',
        '/Volumes/Data',
      ]);
      expect(choices.map((choice) => choice.displayName), [
        'Home',
        'Downloads',
        '/',
        'Data',
      ]);
    },
  );

  test(
    'local path revealer rejects missing path before platform command',
    () async {
      final result = await const LocalPathRevealer().revealPath(
        ScanTargetPath('/definitely/missing/clean-disk-path'),
      );

      final failure = (result as ResultFailure<Unit>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('Path does not exist'));
    },
  );
}
