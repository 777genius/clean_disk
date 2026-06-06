import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';

ScanTargetCatalog createScanTargetCatalog() {
  return const UnsupportedScanTargetCatalog();
}

final class UnsupportedScanTargetCatalog implements ScanTargetCatalog {
  const UnsupportedScanTargetCatalog();

  @override
  Future<Result<List<ScanTargetChoice>>> listChoices() async {
    return const Result.success([]);
  }
}
