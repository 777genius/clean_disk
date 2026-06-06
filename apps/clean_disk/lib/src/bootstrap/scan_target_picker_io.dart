import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';
import 'package:file_selector/file_selector.dart';

ScanTargetPicker createScanTargetPicker() {
  return const FileSelectorScanTargetPicker();
}

final class FileSelectorScanTargetPicker implements ScanTargetPicker {
  const FileSelectorScanTargetPicker();

  @override
  Future<Result<ScanTargetPath?>> pickDirectory({
    required ScanTargetPath initialPath,
  }) async {
    try {
      final path = await getDirectoryPath(initialDirectory: initialPath.value);
      return Result.success(path == null ? null : ScanTargetPath(path));
    } on Exception catch (error) {
      return Result.failure(
        AppFailure.unexpected(
          message: 'Could not pick scan target',
          cause: error,
        ),
      );
    }
  }
}
