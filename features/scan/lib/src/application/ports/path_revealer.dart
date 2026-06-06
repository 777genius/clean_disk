import 'package:clean_disk_core/clean_disk_core.dart';
import 'package:clean_disk_scan/src/domain/scan_models.dart';

abstract interface class PathRevealer {
  Future<Result<Unit>> revealPath(ScanTargetPath path);
}
