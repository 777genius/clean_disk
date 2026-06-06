import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_preference_store.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class SaveLastScanTargetUseCase
    implements UseCase<Result<Unit>, ScanTarget> {
  const SaveLastScanTargetUseCase(this._store);

  final ScanTargetPreferenceStore _store;

  @override
  Future<Result<Unit>> call(ScanTarget input) {
    return _store.saveLastTarget(input);
  }
}
