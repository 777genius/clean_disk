import 'dart:convert';
import 'dart:io';

import 'package:clean_disk_cache/clean_disk_cache.dart';
import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';
import 'package:drift/native.dart';

const _lastScanTargetKey = 'scan.target.last.v1';

ScanTargetPreferenceStore createScanTargetPreferenceStore() {
  return CacheScanTargetPreferenceStore(_createCacheDatabase);
}

final class CacheScanTargetPreferenceStore
    implements ScanTargetPreferenceStore {
  CacheScanTargetPreferenceStore(this._databaseFactory);

  final AppDatabase Function() _databaseFactory;
  AppDatabase? _database;

  AppDatabase get _db {
    return _database ??= _databaseFactory();
  }

  @override
  Future<Result<ScanTarget?>> loadLastTarget() async {
    try {
      final value = await _db.readCacheEntry(_lastScanTargetKey);
      if (value == null) {
        return const Result.success(null);
      }
      final decoded = jsonDecode(value);
      if (decoded is! Map<String, Object?>) {
        return const Result.failure(
          AppFailure.cache(message: 'Saved scan target is invalid'),
        );
      }
      return Result.success(_targetFromJson(decoded));
    } on Exception catch (error) {
      return Result.failure(
        AppFailure.cache(
          message: 'Could not load saved scan target',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Unit>> saveLastTarget(ScanTarget target) async {
    try {
      await _db.putCacheEntry(
        key: _lastScanTargetKey,
        value: jsonEncode(_targetToJson(target)),
      );
      return const Result.success(Unit.value);
    } on Exception catch (error) {
      return Result.failure(
        AppFailure.cache(message: 'Could not save scan target', cause: error),
      );
    }
  }

  Map<String, Object?> _targetToJson(ScanTarget target) {
    return {
      'path': target.path.value,
      'scope': target.scope.name,
      'boundaryPolicy': target.boundaryPolicy.name,
      'hardlinkPolicy': target.hardlinkPolicy.name,
    };
  }

  ScanTarget _targetFromJson(Map<String, Object?> json) {
    final path = json['path'];
    if (path is! String || path.trim().isEmpty) {
      throw const FormatException('Missing scan target path');
    }
    return ScanTarget(
      path: ScanTargetPath(path),
      scope: _targetScope(json['scope']),
      boundaryPolicy: _boundaryPolicy(json['boundaryPolicy']),
      hardlinkPolicy: _hardlinkPolicy(json['hardlinkPolicy']),
    );
  }

  TargetScope _targetScope(Object? value) {
    return switch (value) {
      'localPath' => TargetScope.localPath,
      'volume' => TargetScope.volume,
      'custom' => TargetScope.custom,
      _ => TargetScope.localPath,
    };
  }

  BoundaryPolicy _boundaryPolicy(Object? value) {
    return switch (value) {
      'crossFilesystems' => BoundaryPolicy.crossFilesystems,
      'stayOnInitialFilesystem' => BoundaryPolicy.stayOnInitialFilesystem,
      _ => BoundaryPolicy.stayOnInitialFilesystem,
    };
  }

  HardlinkPolicy _hardlinkPolicy(Object? value) {
    return switch (value) {
      'detect' => HardlinkPolicy.detect,
      'deduplicateForDisplay' => HardlinkPolicy.deduplicateForDisplay,
      'ignore' => HardlinkPolicy.ignore,
      _ => HardlinkPolicy.ignore,
    };
  }
}

AppDatabase _createCacheDatabase() {
  final directory = Directory(_appDataDirectoryPath());
  directory.createSync(recursive: true);
  final databaseFile = File(
    _joinPath(directory.path, 'clean_disk_cache.sqlite'),
  );
  return AppDatabase(executor: NativeDatabase.createInBackground(databaseFile));
}

String _appDataDirectoryPath() {
  final home = Platform.environment['HOME']?.trim();
  if (home != null && home.isNotEmpty) {
    if (Platform.isMacOS) {
      return _joinPath(home, 'Library/Application Support/Clean Disk');
    }
    if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA']?.trim();
      if (appData != null && appData.isNotEmpty) {
        return _joinPath(appData, 'Clean Disk');
      }
    }
    return _joinPath(home, '.clean_disk');
  }
  return _joinPath(Directory.systemTemp.path, 'clean_disk');
}

String _joinPath(String base, String child) {
  final separator = Platform.isWindows ? '\\' : '/';
  final normalizedBase = base.replaceAll(RegExp(r'[/\\]+$'), '');
  if (normalizedBase.isEmpty) {
    return child;
  }
  return '$normalizedBase$separator$child';
}
