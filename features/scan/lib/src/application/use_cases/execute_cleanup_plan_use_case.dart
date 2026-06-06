import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class ExecuteCleanupPlanUseCase
    implements UseCase<Result<CleanupReceipt>, ExecuteCleanupPlanCommand> {
  const ExecuteCleanupPlanUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<CleanupReceipt>> call(ExecuteCleanupPlanCommand input) {
    return _repository.executeCleanupPlan(input);
  }
}
