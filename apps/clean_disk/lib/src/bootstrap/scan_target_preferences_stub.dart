import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';

ScanTargetPreferenceStore createScanTargetPreferenceStore() {
  return const UnsupportedScanTargetPreferenceStore();
}

final class UnsupportedScanTargetPreferenceStore
    implements ScanTargetPreferenceStore {
  const UnsupportedScanTargetPreferenceStore();

  @override
  Future<Result<ScanTarget?>> loadLastTarget() async {
    return const Result.success(null);
  }

  @override
  Future<Result<Unit>> saveLastTarget(ScanTarget target) async {
    return const Result.success(Unit.value);
  }
}
