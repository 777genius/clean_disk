import 'default_scan_target_path_stub.dart'
    if (dart.library.io) 'default_scan_target_path_io.dart'
    as platform;

String defaultScanTargetPath() {
  return platform.defaultScanTargetPath();
}
