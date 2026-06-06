import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';

PermissionRepairLauncher createPermissionRepairLauncher() {
  return const _UnsupportedPermissionRepairLauncher();
}

final class _UnsupportedPermissionRepairLauncher
    implements PermissionRepairLauncher {
  const _UnsupportedPermissionRepairLauncher();

  @override
  Future<Result<Unit>> launchPermissionRepair({
    required ScanTarget target,
    required RuntimeProof proof,
  }) async {
    return const Result.failure(
      AppFailure.validation(
        message: 'Permission repair is not available on this platform',
        field: 'permissionRepair',
      ),
    );
  }
}
