import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class GetTopItemsUseCase
    implements UseCase<Result<NodePage>, TopItemsQuery> {
  const GetTopItemsUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<NodePage>> call(TopItemsQuery input) {
    return _repository.getTopItems(input);
  }
}
