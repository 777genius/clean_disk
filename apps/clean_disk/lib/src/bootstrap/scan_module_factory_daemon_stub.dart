import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:clean_disk_scan/clean_disk_scan.dart';

ScanModule createDaemonScanModule(
  ScanWorkspaceConfig config, {
  DiskUsageMapRenderer? diskUsageMapRenderer,
}) {
  throw UnsupportedError(
    'Daemon scan backend is only available on dart:io platforms.',
  );
}
