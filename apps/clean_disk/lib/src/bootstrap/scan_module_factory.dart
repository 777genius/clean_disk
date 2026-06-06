import 'package:clean_disk_scan/clean_disk_scan.dart';
import 'package:clean_disk_scan/clean_disk_scan_data.dart';
import 'package:syncfusion_disk_usage_map_adapter/syncfusion_disk_usage_map_adapter.dart';

import 'default_scan_target_path.dart';
import 'path_revealer.dart';
import 'permission_repair_launcher.dart';
import 'scan_module_factory_daemon_stub.dart'
    if (dart.library.io) 'scan_module_factory_daemon_io.dart'
    if (dart.library.html) 'scan_module_factory_daemon_web.dart';
import 'scan_target_catalog.dart';
import 'scan_target_picker.dart';
import 'scan_target_preferences.dart';

const _scanBackend = String.fromEnvironment(
  'CLEAN_DISK_SCAN_BACKEND',
  defaultValue: 'fake',
);
const _scanTargetPath = String.fromEnvironment(
  'CLEAN_DISK_SCAN_TARGET',
  defaultValue: '',
);
const _scanTargetScope = String.fromEnvironment(
  'CLEAN_DISK_SCAN_TARGET_SCOPE',
  defaultValue: 'volume',
);
const _diskUsageMapRenderer = SyncfusionDiskUsageMapRenderer();

ScanModule createScanModule() {
  final config = _createWorkspaceConfig();
  return switch (_scanBackend) {
    'fake' => _createFakeScanModule(config),
    'daemon' => createDaemonScanModule(
      config,
      diskUsageMapRenderer: _diskUsageMapRenderer,
    ),
    final backend => throw UnsupportedError(
      'Unsupported scan backend: $backend',
    ),
  };
}

ScanModule _createFakeScanModule(ScanWorkspaceConfig config) {
  final fixture = FakeScanFeatureFixture();
  return ScanModule(
    config: config,
    diskUsageMapRenderer: _diskUsageMapRenderer,
    useCases: ScanUseCaseBundle.fromPorts(
      repository: fixture.repository,
      eventClient: fixture.eventClient,
      permissionRepairLauncher: createPermissionRepairLauncher(),
      targetPicker: createScanTargetPicker(),
      targetCatalog: createScanTargetCatalog(),
      targetPreferenceStore: createScanTargetPreferenceStore(),
      pathRevealer: createPathRevealer(),
    ),
  );
}

ScanWorkspaceConfig _createWorkspaceConfig() {
  final scanTargetPath = _scanTargetPath.trim();
  final hasConfiguredTarget = scanTargetPath.isNotEmpty;
  return ScanWorkspaceConfig(
    defaultTargetPath: hasConfiguredTarget
        ? scanTargetPath
        : defaultScanTargetPath(),
    defaultTargetScope: hasConfiguredTarget
        ? _targetScopeFromDefine(_scanTargetScope)
        : TargetScope.localPath,
    requiresInitialTargetSelection: !hasConfiguredTarget,
  );
}

TargetScope _targetScopeFromDefine(String value) {
  return switch (value.trim().toLowerCase()) {
    'local_path' || 'path' => TargetScope.localPath,
    'volume' => TargetScope.volume,
    'custom' => TargetScope.custom,
    _ => TargetScope.volume,
  };
}
