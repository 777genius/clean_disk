import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class ProbePermissionUseCase
    implements UseCase<Result<PermissionProbe>, ScanTarget> {
  const ProbePermissionUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<PermissionProbe>> call(ScanTarget input) {
    return _repository.probePermission(input);
  }
}
