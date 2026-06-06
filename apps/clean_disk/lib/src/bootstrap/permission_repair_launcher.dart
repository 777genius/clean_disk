import 'package:clean_disk_scan/clean_disk_scan.dart';

import 'permission_repair_launcher_stub.dart'
    if (dart.library.io) 'permission_repair_launcher_io.dart'
    as platform;

PermissionRepairLauncher createPermissionRepairLauncher() {
  return platform.createPermissionRepairLauncher();
}
