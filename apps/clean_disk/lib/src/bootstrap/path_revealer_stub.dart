import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';

PathRevealer createPathRevealer() {
  return const UnsupportedPathRevealer();
}

final class UnsupportedPathRevealer implements PathRevealer {
  const UnsupportedPathRevealer();

  @override
  Future<Result<Unit>> revealPath(ScanTargetPath path) async {
    return const Result.failure(
      AppFailure.validation(
        message: 'Reveal is not available on this platform',
        field: 'path',
      ),
    );
  }
}
