import 'package:clean_disk_scan/clean_disk_scan.dart';

import 'scan_target_picker_stub.dart'
    if (dart.library.io) 'scan_target_picker_io.dart'
    as platform;

ScanTargetPicker createScanTargetPicker() {
  return platform.createScanTargetPicker();
}
