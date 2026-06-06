import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class SearchNodesUseCase
    implements UseCase<Result<NodePage>, SearchPageQuery> {
  const SearchNodesUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<NodePage>> call(SearchPageQuery input) {
    return _repository.search(input);
  }
}
