import 'package:modularity_flutter/modularity_flutter.dart';

import '../presentation/pages/scan_home_page.dart';
import '../presentation/stores/scan_workspace_store.dart';
import 'scan_feature_composition.dart';

final class ScanModule extends Module {
  ScanModule({
    ScanUseCaseBundle? useCases,
    ScanWorkspaceConfig config = const ScanWorkspaceConfig(),
  }) : _useCases = useCases,
       _config = config;

  final ScanUseCaseBundle? _useCases;
  final ScanWorkspaceConfig _config;

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
