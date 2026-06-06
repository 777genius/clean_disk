import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class StartScanUseCase
    implements UseCase<Result<ScanSessionStatus>, StartScanCommand> {
  const StartScanUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<ScanSessionStatus>> call(StartScanCommand input) {
    return _repository.startScan(input);
  }
}
