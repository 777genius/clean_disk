import 'package:clean_disk_design_system/clean_disk_design_system.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

import '../presentation/pages/scan_home_page.dart';
import '../presentation/stores/scan_workspace_store.dart';
import 'scan_feature_composition.dart';

final class ScanModule extends Module {
  ScanModule({
    ScanUseCaseBundle? useCases,
    ScanWorkspaceConfig config = const ScanWorkspaceConfig(),
    DiskUsageMapRenderer? diskUsageMapRenderer,
  }) : _useCases = useCases,
       _config = config,
       _diskUsageMapRenderer = diskUsageMapRenderer;

  final ScanUseCaseBundle? _useCases;
  final ScanWorkspaceConfig _config;
  final DiskUsageMapRenderer? _diskUsageMapRenderer;

  DiskUsageMapRenderer? get diskUsageMapRenderer => _diskUsageMapRenderer;

  @override
  void binds(Binder i) {
    i.registerLazySingleton<ScanWorkspaceConfig>(() => _config);

    final useCases = _useCases;
    if (useCases == null) {
      return;
    }

    i
      ..registerLazySingleton<ScanUseCaseBundle>(() => useCases)
      ..registerFactory<ScanWorkspaceStore>(useCases.createWorkspaceStore);
  }
}
