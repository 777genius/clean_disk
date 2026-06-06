import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

abstract interface class PermissionRepairLauncher {
  Future<Result<Unit>> launchPermissionRepair({
    required ScanTarget target,
    required RuntimeProof proof,
  });
}
