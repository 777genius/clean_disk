import 'dart:io';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';

ScanTargetCatalog createScanTargetCatalog() {
  return LocalScanTargetCatalog();
}

final class LocalScanTargetCatalog implements ScanTargetCatalog {
  LocalScanTargetCatalog({
    Map<String, String>? environment,
    bool? isMacOS,
    bool? isWindows,
    bool Function(String path)? directoryExists,
    List<String> Function()? volumePaths,
  }) : _environment = environment ?? Platform.environment,
       _isMacOS = isMacOS ?? Platform.isMacOS,
       _isWindows = isWindows ?? Platform.isWindows,
       _directoryExists =
           directoryExists ?? ((path) => Directory(path).existsSync()),
       _volumePaths =
           volumePaths ??
           (() {
             final volumes = Directory('/Volumes');
             if (!volumes.existsSync()) {
               return const <String>[];
             }
             return [
               for (final entity in volumes.listSync(followLinks: false))
                 if (entity is Directory) entity.path,
             ];
           });

  final Map<String, String> _environment;
  final bool _isMacOS;
  final bool _isWindows;
  final bool Function(String path) _directoryExists;
  final List<String> Function() _volumePaths;

  @override
  Future<Result<List<ScanTargetChoice>>> listChoices() async {
    try {
      final choices = <ScanTargetChoice>[];
      final home = _homePath();
      if (home != null && _directoryExists(home)) {
        choices.add(
          _choice(
            id: 'home',
            kind: ScanTargetChoiceKind.home,
            path: home,
            scope: TargetScope.localPath,
            displayName: 'Home',
          ),
        );
        final downloads = _joinPath(home, 'Downloads');
        if (_directoryExists(downloads)) {
          choices.add(
            _choice(
              id: 'downloads',
              kind: ScanTargetChoiceKind.downloads,
              path: downloads,
              scope: TargetScope.localPath,
              displayName: 'Downloads',
            ),
          );
        }
        final library = _joinPath(home, 'Library');
        if (_directoryExists(library)) {
          choices.add(
            _choice(
              id: 'library',
              kind: ScanTargetChoiceKind.library,
              path: library,
              scope: TargetScope.localPath,
              displayName: 'Library',
            ),
          );
        }
      }

      const applications = '/Applications';
      if (_isMacOS && _directoryExists(applications)) {
        choices.add(
          _choice(
            id: 'applications',
            kind: ScanTargetChoiceKind.applications,
            path: applications,
            scope: TargetScope.localPath,
            displayName: 'Applications',
          ),
        );
      }

      final rootPath = _rootPath();
      if (rootPath != null) {
        choices.add(
          _choice(
            id: 'root',
            kind: ScanTargetChoiceKind.root,
            path: rootPath,
            scope: TargetScope.volume,
            displayName: rootPath,
          ),
        );
      }

      if (_isMacOS) {
        for (final path in _volumePaths()) {
          choices.add(
            _choice(
              id: 'volume:$path',
              kind: ScanTargetChoiceKind.volume,
              path: path,
              scope: TargetScope.volume,
              displayName: _basename(path),
            ),
          );
        }
      }

      return Result.success(_dedupeByPath(choices));
    } on Exception catch (error) {
      return Result.failure(
        AppFailure.unexpected(
          message: 'Could not list scan targets',
          cause: error,
        ),
      );
    }
  }

  ScanTargetChoice _choice({
    required String id,
    required ScanTargetChoiceKind kind,
    required String path,
    required TargetScope scope,
    required String displayName,
  }) {
    return ScanTargetChoice(
      id: id,
      kind: kind,
      displayName: displayName,
      target: ScanTarget(
        path: ScanTargetPath(path),
        scope: scope,
        boundaryPolicy: BoundaryPolicy.stayOnInitialFilesystem,
        hardlinkPolicy: HardlinkPolicy.ignore,
      ),
    );
  }

  List<ScanTargetChoice> _dedupeByPath(List<ScanTargetChoice> choices) {
    final seen = <String>{};
    final deduped = <ScanTargetChoice>[];
    for (final choice in choices) {
      if (seen.add(choice.target.path.value)) {
        deduped.add(choice);
      }
    }
    return deduped;
  }

  String? _homePath() {
    final home = _environment['HOME']?.trim();
    if (home != null && home.isNotEmpty) {
      if (_isMacOS && home.contains('/Library/Containers/')) {
        final userHome = _macosUserHomePath();
        if (userHome != null && _directoryExists(userHome)) {
          return userHome;
        }
      }
      return home;
    }
    final userProfile = _environment['USERPROFILE']?.trim();
    if (userProfile != null && userProfile.isNotEmpty) {
      return userProfile;
    }
    return null;
  }

  String? _macosUserHomePath() {
    final user = _environment['USER']?.trim();
    if (user == null || user.isEmpty) {
      return null;
    }
    return '/Users/$user';
  }

  String? _rootPath() {
    if (_isWindows) {
      final systemDrive = _environment['SystemDrive']?.trim();
      if (systemDrive != null && systemDrive.isNotEmpty) {
        return systemDrive.endsWith('\\') ? systemDrive : '$systemDrive\\';
      }
      return null;
    }
    return '/';
  }

  String _joinPath(String base, String child) {
    final separator = _isWindows ? '\\' : '/';
    if (base.endsWith(separator)) {
      return '$base$child';
    }
    return '$base$separator$child';
  }

  String _basename(String path) {
    final normalized = path.replaceAll(RegExp(r'[/\\]+$'), '');
    final parts = normalized
        .split(RegExp(r'[/\\]+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return parts.isEmpty ? path : parts.last;
  }
}
