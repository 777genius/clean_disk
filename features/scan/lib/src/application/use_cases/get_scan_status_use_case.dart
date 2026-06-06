import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class GetScanStatusUseCase
    implements UseCase<Result<ScanSessionStatus>, ScanSessionId> {
  const GetScanStatusUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<ScanSessionStatus>> call(ScanSessionId input) {
    return _repository.getSessionStatus(input);
  }
}
