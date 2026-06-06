import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class CancelScanUseCase
    implements UseCase<Result<ScanSessionStatus>, SessionCommand> {
  const CancelScanUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<ScanSessionStatus>> call(SessionCommand input) {
    return _repository.cancelScan(input);
  }
}
