import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class GetNodeDetailsUseCase
    implements UseCase<Result<NodeDetails>, NodeDetailsQuery> {
  const GetNodeDetailsUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<NodeDetails>> call(NodeDetailsQuery input) {
    return _repository.getNodeDetails(input);
  }
}
