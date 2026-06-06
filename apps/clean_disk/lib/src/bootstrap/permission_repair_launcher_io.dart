import 'dart:io';

import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';

PermissionRepairLauncher createPermissionRepairLauncher() {
  return const _PlatformPermissionRepairLauncher();
}

final class _PlatformPermissionRepairLauncher
    implements PermissionRepairLauncher {
  const _PlatformPermissionRepairLauncher();

  @override
  Future<Result<Unit>> launchPermissionRepair({
    required ScanTarget target,
    required RuntimeProof proof,
  }) async {
    return switch (proof.permissionProbe.requiredAction) {
      PermissionRequiredAction.openMacosFullDiskAccess =>
        _openMacosFullDiskAccess(),
      PermissionRequiredAction.runAsAdministrator ||
      PermissionRequiredAction.reviewLinuxPermissions ||
      PermissionRequiredAction.none ||
      PermissionRequiredAction.unknown => const Result.failure(
        AppFailure.validation(
          message: 'Permission repair action is not supported yet',
          field: 'permissionRepair',
        ),
      ),
    };
  }

  Future<Result<Unit>> _openMacosFullDiskAccess() async {
    if (!Platform.isMacOS) {
      return const Result.failure(
        AppFailure.validation(
          message: 'Full Disk Access repair is only available on macOS',
          field: 'permissionRepair',
        ),
      );
    }

    final primary = await _openSettingsUri(
      'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles',
    );
    if (primary.isSuccess) {
      return primary;
    }

    return _openSettingsUri(
      'x-apple.systempreferences:com.apple.preference.security',
    );
  }

  Future<Result<Unit>> _openSettingsUri(String uri) async {
    try {
      final result = await Process.run('/usr/bin/open', [uri]);
      if (result.exitCode == 0) {
        return const Result.success(Unit.value);
      }
      return Result.failure(
        AppFailure.unexpected(
          message: 'Could not open macOS permission settings',
          cause: '${result.stdout}\n${result.stderr}',
        ),
      );
    } on Object catch (error, stackTrace) {
      return Result.failure(
        AppFailure.unexpected(
          message: 'Could not open macOS permission settings',
          cause: '$error\n$stackTrace',
        ),
      );
    }
  }
}
