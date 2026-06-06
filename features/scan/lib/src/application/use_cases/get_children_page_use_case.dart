import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_repository.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class GetChildrenPageUseCase
    implements UseCase<Result<NodePage>, ChildrenPageQuery> {
  const GetChildrenPageUseCase(this._repository);

  final ScanRepository _repository;

  @override
  Future<Result<NodePage>> call(ChildrenPageQuery input) {
    return _repository.getChildrenPage(input);
  }
}
