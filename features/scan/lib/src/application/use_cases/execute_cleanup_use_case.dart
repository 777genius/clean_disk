import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class ExecuteCleanupUseCase
    implements UseCase<Result<CleanupReceipt>, ExecuteCleanupCommand> {
  const ExecuteCleanupUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<CleanupReceipt>> call(ExecuteCleanupCommand input) {
    return _repository.executeCleanup(input);
  }
}
