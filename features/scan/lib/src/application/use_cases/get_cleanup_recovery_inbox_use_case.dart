import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class GetCleanupRecoveryInboxUseCase
    implements UseCase<Result<CleanupRecoveryInbox>, Unit> {
  const GetCleanupRecoveryInboxUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<CleanupRecoveryInbox>> call(Unit input) {
    return _repository.getCleanupRecoveryInbox();
  }
}
