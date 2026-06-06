import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class GetDiagnosticsUseCase {
  const GetDiagnosticsUseCase(this._repository);

  final ScanRepository _repository;

  Future<Result<DaemonDiagnostics>> call() {
    return _repository.getDiagnostics();
  }
}
