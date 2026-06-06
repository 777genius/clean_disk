import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/application/ports/path_revealer.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

final class RevealPathUseCase implements UseCase<Result<Unit>, ScanTargetPath> {
  const RevealPathUseCase(this._revealer);

  final PathRevealer _revealer;

  @override
  Future<Result<Unit>> call(ScanTargetPath input) {
    return _revealer.revealPath(input);
  }
}
