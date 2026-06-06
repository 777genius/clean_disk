import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';

ScanTargetPicker createScanTargetPicker() {
  return const UnsupportedScanTargetPicker();
}

final class UnsupportedScanTargetPicker implements ScanTargetPicker {
  const UnsupportedScanTargetPicker();

  @override
  Future<Result<ScanTargetPath?>> pickDirectory({
    required ScanTargetPath initialPath,
  }) async {
    return const Result.success(null);
  }
}
