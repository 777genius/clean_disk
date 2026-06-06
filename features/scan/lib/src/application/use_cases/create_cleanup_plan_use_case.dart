import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class CreateCleanupPlanUseCase
    implements UseCase<Result<ValidatedCleanupPlan>, CreateCleanupPlanCommand> {
  const CreateCleanupPlanUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<ValidatedCleanupPlan>> call(CreateCleanupPlanCommand input) {
    return _repository.createCleanupPlan(input);
  }
}
