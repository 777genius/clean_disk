import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/permission_repair_launcher.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class LaunchPermissionRepairUseCase {
  const LaunchPermissionRepairUseCase(this._launcher);

  final PermissionRepairLauncher _launcher;

  Future<Result<Unit>> call({
    required ScanTarget target,
    required RuntimeProof proof,
  }) {
    return _launcher.launchPermissionRepair(target: target, proof: proof);
  }
}
