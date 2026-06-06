import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/scan_target_catalog.dart';

final class ListScanTargetChoicesUseCase
    implements UseCase<Result<List<ScanTargetChoice>>, Unit> {
  const ListScanTargetChoicesUseCase(this._catalog);

  final ScanTargetCatalog _catalog;

  @override
  Future<Result<List<ScanTargetChoice>>> call(Unit input) {
    return _catalog.listChoices();
  }
}
