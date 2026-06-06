import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class GetCapabilitiesUseCase {
  const GetCapabilitiesUseCase(this._repository);

  final ScanRepository _repository;

  Future<Result<DaemonCapabilities>> call() {
    return _repository.getCapabilities();
  }
}
