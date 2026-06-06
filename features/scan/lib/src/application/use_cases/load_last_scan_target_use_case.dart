import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_preference_store.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class LoadLastScanTargetUseCase
    implements UseCase<Result<ScanTarget?>, Unit> {
  const LoadLastScanTargetUseCase(this._store);

  final ScanTargetPreferenceStore _store;

  @override
  Future<Result<ScanTarget?>> call(Unit input) {
    return _store.loadLastTarget();
  }
}
