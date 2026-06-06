import 'dart:io';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';

PathRevealer createPathRevealer() {
  return const LocalPathRevealer();
}

final class LocalPathRevealer implements PathRevealer {
  const LocalPathRevealer();

  @override
  Future<Result<Unit>> revealPath(ScanTargetPath path) async {
    try {
      final value = path.value;
      if (FileSystemEntity.typeSync(value, followLinks: false) ==
          FileSystemEntityType.notFound) {
        return Result.failure(
          AppFailure.validation(
            message: 'Path does not exist: $value',
            field: 'path',
          ),
        );
      }

      final command = _commandFor(value);
      final result = await Process.run(command.executable, command.arguments);
      if (result.exitCode != 0) {
        return Result.failure(
          AppFailure.unexpected(
            message: 'Could not reveal path: ${result.stderr}',
          ),
        );
      }
      return const Result.success(Unit.value);
    } on Exception catch (error) {
      return Result.failure(
        AppFailure.unexpected(message: 'Could not reveal path', cause: error),
      );
    }
  }

  _RevealCommand _commandFor(String path) {
    if (Platform.isMacOS) {
      return _RevealCommand('/usr/bin/open', ['-R', path]);
    }
    if (Platform.isWindows) {
      return _RevealCommand('explorer.exe', ['/select,$path']);
    }
    final directory = FileSystemEntity.isDirectorySync(path)
        ? path
        : _parentPath(path);
    return _RevealCommand('xdg-open', [directory]);
  }

  String _parentPath(String path) {
    final normalized = path.replaceAll(RegExp(r'[/\\]+$'), '');
    final separatorIndex = normalized.lastIndexOf(RegExp(r'[/\\]'));
    if (separatorIndex <= 0) {
      return Platform.isWindows ? normalized : '/';
    }
    return normalized.substring(0, separatorIndex);
  }
}

final class _RevealCommand {
  const _RevealCommand(this.executable, this.arguments);

  final String executable;
  final List<String> arguments;
}
