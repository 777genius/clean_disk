import 'package:clean_disk_scan/clean_disk_scan.dart';

ScanModule createDaemonScanModule(ScanWorkspaceConfig config) {
  throw UnsupportedError(
    'Daemon scan backend is only available on dart:io platforms.',
  );
}
