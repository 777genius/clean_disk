import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class DisposeScanUseCase
    implements UseCase<Result<Unit>, SessionCommand> {
  const DisposeScanUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<Unit>> call(SessionCommand input) {
    return _repository.disposeScan(input);
  }
}
